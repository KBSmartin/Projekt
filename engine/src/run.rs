//! A whole run as a state machine: map, combat, rewards, shop, rest site,
//! events and card picks. Ported from the prototype's flow (`newRun`,
//! `goNode`, `afterNode`, `rewards`, `genShop`, `applyPick`, `EVENTS`).
//!
//! The UI only calls the action methods and renders [`Run::phase`]. The same
//! actions let the simulation play whole runs.

use crate::card::{CardInstance, Rarity};
use crate::combat::{Combat, CombatKind, CombatSetup, Outcome, PlayError};
use crate::content::{EventEffect, GameData, PickMode, Requirement};
use crate::map::{Map, NodeKind};
use crate::relic::Relic;
use crate::rng::GameRng;
use std::fmt;

pub const START_GOLD: u32 = 60;
/// Gold for a removal at the shop; it rises with every removal.
pub const SHOP_REMOVE_COST: u32 = 55;
pub const SHOP_REMOVE_STEP: u32 = 25;
pub const SHOP_RELIC_PRICE: u32 = 130;
/// The shop only removes cards while the deck is larger than this.
pub const MIN_DECK: usize = 5;
pub const TEA_HEAL: i32 = 6;
pub const CARD_CHOICES: usize = 3;
pub const SHOP_CARDS: usize = 5;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct RunStats {
    pub nodes: u32,
    pub fights: u32,
    pub elites: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RewardSource {
    Combat(CombatKind),
    /// Index into [`GameData::events`].
    Event(usize),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Reward {
    pub gold: u32,
    pub relic: Option<Relic>,
    pub cards: Vec<CardInstance>,
    pub source: RewardSource,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ShopCard {
    pub card: CardInstance,
    pub price: u32,
    pub sold: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ShopRelic {
    pub relic: Relic,
    pub price: u32,
    pub sold: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Shop {
    pub cards: Vec<ShopCard>,
    pub relic: Option<ShopRelic>,
    pub remove_cost: u32,
}

/// What happened to a picked card.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PickOutcome {
    pub mode: PickMode,
    /// The card as it was before.
    pub card: CardInstance,
    /// The card after an upgrade or trade; `None` after a removal.
    pub new_card: Option<CardInstance>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EventResult {
    Message(String),
    Picked(PickOutcome),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EventState {
    /// Index into [`GameData::events`].
    pub event: usize,
    /// `None` while the options are shown.
    pub result: Option<EventResult>,
}

/// Where a card pick returns to.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PickReturn {
    Shop(Shop),
    Rest,
    Event(usize),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PickState {
    pub mode: PickMode,
    pub cost: u32,
    pub back: PickReturn,
}

/// The screen the run is on.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Phase {
    /// Introduction of the current region.
    RegionIntro,
    Map,
    /// Stays here with `outcome` set until [`Run::finish_combat`].
    Combat(Box<Combat>),
    Reward(Reward),
    Shop(Shop),
    Rest,
    Event(EventState),
    Pick(PickState),
    Victory,
    Defeat,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ActionError {
    /// The action does not fit the current phase.
    WrongPhase,
    /// Index out of range, requirement not met or similar.
    NotAllowed,
    NotEnoughGold,
    Play(PlayError),
    /// The game data is inconsistent (should be caught by validation).
    Data(String),
}

impl fmt::Display for ActionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ActionError::WrongPhase => write!(f, "action not possible in this phase"),
            ActionError::NotAllowed => write!(f, "action not allowed"),
            ActionError::NotEnoughGold => write!(f, "not enough gold"),
            ActionError::Play(e) => write!(f, "{e}"),
            ActionError::Data(e) => write!(f, "{e}"),
        }
    }
}

impl std::error::Error for ActionError {}

type ActionResult = Result<(), ActionError>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Run {
    pub seed: u64,
    rng: GameRng,
    pub character: String,
    pub hp: i32,
    pub max_hp: i32,
    pub gold: u32,
    pub deck: Vec<CardInstance>,
    pub relics: Vec<Relic>,
    /// Index into [`GameData::regions`].
    pub region: usize,
    pub map: Map,
    pub current: Option<usize>,
    pub visited: Vec<usize>,
    pub stats: RunStats,
    pub phase: Phase,
    /// Result of the last pick at a rest site or shop, for a short notice.
    pub notice: Option<PickOutcome>,
}

impl Run {
    /// Starts a new run (prototype `newRun`).
    pub fn new(data: &GameData, character: &str, seed: u64) -> Result<Self, ActionError> {
        let ch = data.character(character).ok_or(ActionError::NotAllowed)?;
        let mut rng = GameRng::new(seed);
        let map = Map::generate(&mut rng);
        Ok(Self {
            seed,
            rng,
            character: ch.id.clone(),
            hp: ch.max_hp,
            max_hp: ch.max_hp,
            gold: START_GOLD,
            deck: ch.deck.iter().map(CardInstance::new).collect(),
            relics: Vec::new(),
            region: 0,
            map,
            current: None,
            visited: Vec::new(),
            stats: RunStats::default(),
            phase: Phase::RegionIntro,
            notice: None,
        })
    }

    pub fn is_over(&self) -> bool {
        matches!(self.phase, Phase::Victory | Phase::Defeat)
    }

    /// Node ids the player can move to now.
    pub fn available_nodes(&self) -> Vec<usize> {
        match self.current {
            None => self.map.rows[0].clone(),
            Some(id) => self.map.nodes[id].next.clone(),
        }
    }

    pub fn can_upgrade(&self, data: &GameData) -> bool {
        self.deck.iter().any(|c| self.is_upgradable(data, c))
    }

    fn is_upgradable(&self, data: &GameData, c: &CardInstance) -> bool {
        !c.upgraded
            && data
                .cards
                .get(&c.id)
                .is_some_and(|card| card.is_upgradable())
    }

    /// Whether a deck card may be chosen in the current pick.
    pub fn pick_allowed(&self, data: &GameData, deck_index: usize) -> bool {
        let Phase::Pick(pick) = &self.phase else {
            return false;
        };
        let Some(card) = self.deck.get(deck_index) else {
            return false;
        };
        match pick.mode {
            PickMode::Upgrade => self.is_upgradable(data, card),
            PickMode::Remove | PickMode::Trade => true,
        }
    }

    pub fn requirement_met(&self, data: &GameData, req: &Requirement) -> bool {
        self.hp >= req.min_hp
            && self.gold >= req.min_gold
            && (!req.upgradable_card || self.can_upgrade(data))
            && self.deck.len() >= req.min_deck
    }

    /// HP healed at a rest site.
    pub fn rest_heal_amount(&self) -> i32 {
        self.max_hp * 3 / 10
    }

    /// Shop removals are possible while the deck is larger than [`MIN_DECK`].
    pub fn can_remove_at_shop(&self) -> bool {
        self.deck.len() > MIN_DECK
    }

    fn heal(&mut self, amount: i32) -> i32 {
        let healed = amount.min(self.max_hp - self.hp).max(0);
        self.hp += healed;
        healed
    }

    // ---------- map ----------

    pub fn continue_from_intro(&mut self) -> ActionResult {
        if self.phase != Phase::RegionIntro {
            return Err(ActionError::WrongPhase);
        }
        self.phase = Phase::Map;
        Ok(())
    }

    /// Moves to a map node and opens its screen (prototype `goNode`).
    pub fn choose_node(&mut self, data: &GameData, id: usize) -> ActionResult {
        if self.phase != Phase::Map {
            return Err(ActionError::WrongPhase);
        }
        if !self.available_nodes().contains(&id) {
            return Err(ActionError::NotAllowed);
        }
        self.current = Some(id);
        self.visited.push(id);
        self.stats.nodes += 1;
        self.notice = None;
        let node = self.map.nodes[id].clone();
        self.phase = match node.kind {
            NodeKind::Fight => self.start_combat(data, CombatKind::Fight, node.row)?,
            NodeKind::Elite => self.start_combat(data, CombatKind::Elite, node.row)?,
            NodeKind::Boss => self.start_combat(data, CombatKind::Boss, node.row)?,
            NodeKind::Shop => Phase::Shop(self.generate_shop(data)),
            NodeKind::Rest => Phase::Rest,
            NodeKind::Event => Phase::Event(EventState {
                event: self.rng.index(data.events.len()),
                result: None,
            }),
        };
        Ok(())
    }

    fn start_combat(
        &mut self,
        data: &GameData,
        kind: CombatKind,
        row: usize,
    ) -> Result<Phase, ActionError> {
        let region = &data.regions[self.region];
        let enemies: Vec<String> = match kind {
            CombatKind::Boss => region.boss.clone(),
            CombatKind::Elite => self.rng.pick(&region.elites).cloned().unwrap_or_default(),
            CombatKind::Fight => {
                let list = if row <= 2 { &region.easy } else { &region.hard };
                self.rng.pick(list).cloned().unwrap_or_default()
            }
        };
        let ids: Vec<&str> = enemies.iter().map(String::as_str).collect();
        let bonus = data
            .character(&self.character)
            .map(|c| c.trait_rule.combat_bonus())
            .unwrap_or_default();
        let setup = CombatSetup {
            hp: self.hp,
            max_hp: self.max_hp,
            deck: &self.deck,
            relics: &self.relics,
            bonus,
        };
        let combat = Combat::start(setup, kind, &ids, &data.enemies, &data.cards, &mut self.rng)
            .map_err(|e| ActionError::Data(e.to_string()))?;
        Ok(Phase::Combat(Box::new(combat)))
    }

    // ---------- combat ----------

    fn combat_mut(&mut self) -> Result<&mut Combat, ActionError> {
        match &mut self.phase {
            Phase::Combat(c) => Ok(c),
            _ => Err(ActionError::WrongPhase),
        }
    }

    pub fn play_card(
        &mut self,
        data: &GameData,
        index: usize,
        target: Option<usize>,
    ) -> ActionResult {
        let Phase::Combat(combat) = &mut self.phase else {
            return Err(ActionError::WrongPhase);
        };
        combat
            .play_card(index, target, &data.cards, &mut self.rng)
            .map_err(ActionError::Play)
    }

    pub fn end_turn(&mut self, data: &GameData) -> ActionResult {
        let Phase::Combat(combat) = &mut self.phase else {
            return Err(ActionError::WrongPhase);
        };
        combat
            .end_turn(&data.cards, &mut self.rng)
            .map_err(ActionError::Play)
    }

    /// Leaves a finished combat: rewards on a win, game over on a loss.
    pub fn finish_combat(&mut self, data: &GameData) -> ActionResult {
        let combat = self.combat_mut()?;
        let Some(outcome) = combat.outcome else {
            return Err(ActionError::NotAllowed);
        };
        let (hp, kind) = (combat.player.hp, combat.kind);
        self.hp = hp.min(self.max_hp);
        self.phase = match outcome {
            Outcome::Lose => {
                self.hp = self.hp.max(0);
                Phase::Defeat
            }
            Outcome::Win => Phase::Reward(self.combat_reward(data, kind)),
        };
        Ok(())
    }

    /// Prototype `rewards`.
    fn combat_reward(&mut self, data: &GameData, kind: CombatKind) -> Reward {
        let mut gold = match kind {
            CombatKind::Boss => 50,
            CombatKind::Elite => self.rng.range(25, 35) as u32,
            CombatKind::Fight => self.rng.range(10, 18) as u32,
        };
        if self.relics.contains(&Relic::Coin) {
            gold = gold * 3 / 2;
        }
        self.gold += gold;
        if self.relics.contains(&Relic::Tea) {
            self.heal(TEA_HEAL);
        }
        let relic = if kind == CombatKind::Fight {
            None
        } else {
            let r = self.random_new_relic();
            if let Some(r) = r {
                self.relics.push(r);
            }
            r
        };
        match kind {
            CombatKind::Elite => self.stats.elites += 1,
            _ => self.stats.fights += 1,
        }
        let cards = self.card_choices(data, kind);
        Reward {
            gold,
            relic,
            cards,
            source: RewardSource::Combat(kind),
        }
    }

    fn random_new_relic(&mut self) -> Option<Relic> {
        let missing: Vec<Relic> = Relic::ALL
            .into_iter()
            .filter(|r| !self.relics.contains(r))
            .collect();
        self.rng.pick(&missing).copied()
    }

    /// Three different cards from the character's pool (prototype `cardChoices`).
    fn card_choices(&mut self, data: &GameData, kind: CombatKind) -> Vec<CardInstance> {
        let weights: &[(Rarity, u32)] = match kind {
            CombatKind::Boss => &[(Rarity::Rare, 1)],
            CombatKind::Elite => &[
                (Rarity::Common, 35),
                (Rarity::Uncommon, 45),
                (Rarity::Rare, 20),
            ],
            CombatKind::Fight => &[
                (Rarity::Common, 60),
                (Rarity::Uncommon, 32),
                (Rarity::Rare, 8),
            ],
        };
        let mut out: Vec<CardInstance> = Vec::new();
        // Data validation guarantees enough cards per rarity; the attempt
        // limit only protects against endless loops with broken data.
        for _ in 0..100 {
            if out.len() >= CARD_CHOICES {
                break;
            }
            let Some(&rarity) = self.rng.weighted(weights) else {
                break;
            };
            let pool: Vec<&str> = data
                .pool(&self.character, rarity)
                .into_iter()
                .filter(|id| !out.iter().any(|c| c.id == *id))
                .collect();
            if let Some(id) = self.rng.pick(&pool) {
                out.push(CardInstance::new(*id));
            }
        }
        out
    }

    pub fn take_reward_card(&mut self, data: &GameData, index: usize) -> ActionResult {
        let Phase::Reward(reward) = &self.phase else {
            return Err(ActionError::WrongPhase);
        };
        let card = reward
            .cards
            .get(index)
            .ok_or(ActionError::NotAllowed)?
            .clone();
        self.deck.push(card);
        self.after_node(data);
        Ok(())
    }

    pub fn skip_reward(&mut self, data: &GameData) -> ActionResult {
        if !matches!(self.phase, Phase::Reward(_)) {
            return Err(ActionError::WrongPhase);
        }
        self.after_node(data);
        Ok(())
    }

    /// Prototype `afterNode`: back to the map, or on to the next region after a boss.
    fn after_node(&mut self, data: &GameData) {
        let at_boss = self
            .current
            .is_some_and(|id| self.map.nodes[id].kind == NodeKind::Boss);
        if !at_boss {
            self.phase = Phase::Map;
            return;
        }
        // Prototype `advanceRegion`.
        self.heal(self.max_hp * 4 / 10);
        if self.region + 1 >= data.regions.len() {
            self.phase = Phase::Victory;
            return;
        }
        self.region += 1;
        self.map = Map::generate(&mut self.rng);
        self.current = None;
        self.visited.clear();
        self.phase = Phase::RegionIntro;
    }

    // ---------- shop ----------

    /// Prototype `genShop`.
    fn generate_shop(&mut self, data: &GameData) -> Shop {
        let weights = [
            (Rarity::Common, 55),
            (Rarity::Uncommon, 33),
            (Rarity::Rare, 12),
        ];
        let mut cards: Vec<ShopCard> = Vec::new();
        for _ in 0..200 {
            if cards.len() >= SHOP_CARDS {
                break;
            }
            let Some(&rarity) = self.rng.weighted(&weights) else {
                break;
            };
            let pool = data.pool(&self.character, rarity);
            let Some(&id) = self.rng.pick(&pool) else {
                continue;
            };
            if cards.iter().any(|c| c.card.id == id) {
                continue;
            }
            let base: i32 = match rarity {
                Rarity::Common => 45,
                Rarity::Uncommon => 75,
                _ => 125,
            };
            cards.push(ShopCard {
                card: CardInstance::new(id),
                price: (base + self.rng.range(-6, 6)) as u32,
                sold: false,
            });
        }
        let relic = self.random_new_relic().map(|relic| ShopRelic {
            relic,
            price: SHOP_RELIC_PRICE,
            sold: false,
        });
        Shop {
            cards,
            relic,
            remove_cost: SHOP_REMOVE_COST,
        }
    }

    pub fn buy_card(&mut self, index: usize) -> ActionResult {
        let gold = self.gold;
        let Phase::Shop(shop) = &mut self.phase else {
            return Err(ActionError::WrongPhase);
        };
        let item = shop.cards.get_mut(index).ok_or(ActionError::NotAllowed)?;
        if item.sold {
            return Err(ActionError::NotAllowed);
        }
        if gold < item.price {
            return Err(ActionError::NotEnoughGold);
        }
        item.sold = true;
        self.gold -= item.price;
        self.deck.push(item.card.clone());
        Ok(())
    }

    pub fn buy_relic(&mut self) -> ActionResult {
        let gold = self.gold;
        let Phase::Shop(shop) = &mut self.phase else {
            return Err(ActionError::WrongPhase);
        };
        let item = shop.relic.as_mut().ok_or(ActionError::NotAllowed)?;
        if item.sold {
            return Err(ActionError::NotAllowed);
        }
        if gold < item.price {
            return Err(ActionError::NotEnoughGold);
        }
        item.sold = true;
        self.gold -= item.price;
        self.relics.push(item.relic);
        Ok(())
    }

    /// Opens the pick screen to remove a card for gold.
    pub fn shop_remove(&mut self) -> ActionResult {
        let Phase::Shop(shop) = &self.phase else {
            return Err(ActionError::WrongPhase);
        };
        if !self.can_remove_at_shop() {
            return Err(ActionError::NotAllowed);
        }
        if self.gold < shop.remove_cost {
            return Err(ActionError::NotEnoughGold);
        }
        let Phase::Shop(shop) = std::mem::replace(&mut self.phase, Phase::Map) else {
            unreachable!()
        };
        self.notice = None;
        self.phase = Phase::Pick(PickState {
            mode: PickMode::Remove,
            cost: shop.remove_cost,
            back: PickReturn::Shop(shop),
        });
        Ok(())
    }

    pub fn leave_shop(&mut self) -> ActionResult {
        if !matches!(self.phase, Phase::Shop(_)) {
            return Err(ActionError::WrongPhase);
        }
        self.notice = None;
        self.phase = Phase::Map;
        Ok(())
    }

    // ---------- rest site ----------

    pub fn rest_heal(&mut self) -> ActionResult {
        if self.phase != Phase::Rest {
            return Err(ActionError::WrongPhase);
        }
        self.heal(self.rest_heal_amount());
        self.phase = Phase::Map;
        Ok(())
    }

    pub fn rest_upgrade(&mut self, data: &GameData) -> ActionResult {
        if self.phase != Phase::Rest {
            return Err(ActionError::WrongPhase);
        }
        if !self.can_upgrade(data) {
            return Err(ActionError::NotAllowed);
        }
        self.phase = Phase::Pick(PickState {
            mode: PickMode::Upgrade,
            cost: 0,
            back: PickReturn::Rest,
        });
        Ok(())
    }

    // ---------- events ----------

    pub fn choose_event_option(&mut self, data: &GameData, option: usize) -> ActionResult {
        let Phase::Event(EventState {
            event,
            result: None,
        }) = self.phase
        else {
            return Err(ActionError::WrongPhase);
        };
        let opt = data.events[event]
            .options
            .get(option)
            .ok_or(ActionError::NotAllowed)?;
        if !self.requirement_met(data, &opt.requires) {
            return Err(ActionError::NotAllowed);
        }
        let weighted: Vec<(usize, u32)> = opt
            .outcomes
            .iter()
            .enumerate()
            .map(|(i, o)| (i, o.weight))
            .collect();
        let &chosen = self
            .rng
            .weighted(&weighted)
            .ok_or(ActionError::NotAllowed)?;
        let outcome = &opt.outcomes[chosen];

        let mut healed = 0;
        for effect in &outcome.effects {
            match effect {
                EventEffect::Heal(n) => healed += self.heal(*n),
                EventEffect::GainMaxHp(n) => {
                    self.max_hp += n;
                    self.hp += n;
                }
                EventEffect::LoseHp(n) => self.hp = (self.hp - n).max(1),
                EventEffect::GainGold(n) => self.gold += n,
                EventEffect::LoseGold(n) => self.gold = self.gold.saturating_sub(*n),
                EventEffect::AddCard(id) => self.deck.push(CardInstance::new(id.clone())),
                EventEffect::RareCardChoice => {
                    let cards = self.card_choices(data, CombatKind::Boss);
                    self.phase = Phase::Reward(Reward {
                        gold: 0,
                        relic: None,
                        cards,
                        source: RewardSource::Event(event),
                    });
                    return Ok(());
                }
                EventEffect::Pick { mode, cost } => {
                    self.phase = Phase::Pick(PickState {
                        mode: *mode,
                        cost: *cost,
                        back: PickReturn::Event(event),
                    });
                    return Ok(());
                }
            }
        }
        let message = outcome.message.replace("{healed}", &healed.to_string());
        self.phase = Phase::Event(EventState {
            event,
            result: Some(EventResult::Message(message)),
        });
        Ok(())
    }

    /// Leaves an event after its result was shown.
    pub fn leave_event(&mut self, data: &GameData) -> ActionResult {
        if !matches!(
            self.phase,
            Phase::Event(EventState {
                result: Some(_),
                ..
            })
        ) {
            return Err(ActionError::WrongPhase);
        }
        self.after_node(data);
        Ok(())
    }

    // ---------- card picks ----------

    /// Upgrades, removes or trades a deck card (prototype `applyPick`).
    pub fn pick_card(&mut self, data: &GameData, deck_index: usize) -> ActionResult {
        if !self.pick_allowed(data, deck_index) {
            return Err(ActionError::NotAllowed);
        }
        let Phase::Pick(pick) = std::mem::replace(&mut self.phase, Phase::Map) else {
            unreachable!("checked by pick_allowed")
        };
        if self.gold < pick.cost {
            self.phase = Phase::Pick(pick);
            return Err(ActionError::NotEnoughGold);
        }
        self.gold -= pick.cost;
        let card = self.deck[deck_index].clone();
        let new_card = match pick.mode {
            PickMode::Upgrade => {
                self.deck[deck_index].upgraded = true;
                Some(self.deck[deck_index].clone())
            }
            PickMode::Remove => {
                self.deck.remove(deck_index);
                None
            }
            PickMode::Trade => {
                let pool = data.pool(&self.character, Rarity::Rare);
                let id = self.rng.pick(&pool).copied().unwrap_or(card.id.as_str());
                let new = CardInstance::new(id);
                self.deck[deck_index] = new.clone();
                Some(new)
            }
        };
        let outcome = PickOutcome {
            mode: pick.mode,
            card,
            new_card,
        };
        self.phase = match pick.back {
            PickReturn::Shop(mut shop) => {
                shop.remove_cost += SHOP_REMOVE_STEP;
                self.notice = Some(outcome);
                Phase::Shop(shop)
            }
            PickReturn::Rest => {
                self.notice = Some(outcome);
                Phase::Map
            }
            PickReturn::Event(event) => Phase::Event(EventState {
                event,
                result: Some(EventResult::Picked(outcome)),
            }),
        };
        Ok(())
    }

    /// Returns from the pick screen without choosing.
    pub fn cancel_pick(&mut self) -> ActionResult {
        if !matches!(self.phase, Phase::Pick(_)) {
            return Err(ActionError::WrongPhase);
        }
        let Phase::Pick(pick) = std::mem::replace(&mut self.phase, Phase::Map) else {
            unreachable!()
        };
        self.phase = match pick.back {
            PickReturn::Shop(shop) => Phase::Shop(shop),
            PickReturn::Rest => Phase::Rest,
            PickReturn::Event(event) => Phase::Event(EventState {
                event,
                result: None,
            }),
        };
        Ok(())
    }
}

#[cfg(test)]
mod tests;
