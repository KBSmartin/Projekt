//! Combat rules, ported from the prototype (`calc`, `hit`, `startCombat`,
//! `draw`, `startTurn`, `playCard`, `playerEnd`, `enemyPhase`, `endTurn`).
//!
//! Deliberate fixes against the prototype are marked with "Fix:".
//!
//! All randomness goes through the [`GameRng`] passed in by the caller, and
//! card and enemy data are passed in as well, so a [`Combat`] is plain data.

use crate::card::{Card, CardDb, CardInstance, CardKind, Tag};
use crate::enemy::{EnemyDb, EnemyDef, Move};
use crate::relic::{ANCHOR_BLOCK, RUBY_STRENGTH, Relic};
use crate::rng::GameRng;
use std::fmt;

/// Energy per turn without relics.
pub const BASE_ENERGY: u32 = 3;
/// Cards drawn per turn without relics.
pub const BASE_DRAW: u32 = 5;
/// Drawing stops at this hand size.
pub const MAX_HAND: usize = 10;
/// Damage per "Brand" card left in hand at end of turn.
pub const BURN_DAMAGE: i32 = 2;
/// Card id added by enemy `burn` moves.
pub const BURN_CARD: &str = "burn";
/// Card id added by enemy `frost` moves.
pub const FROST_CARD: &str = "frost";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CombatKind {
    Fight,
    Elite,
    Boss,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Outcome {
    Win,
    Lose,
}

/// Status effects on the player or an enemy. 0 means not present.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Statuses {
    /// Stärke: added to every attack hit.
    pub strength: i32,
    /// Schwäche: deals 25 % less damage.
    pub weak: u32,
    /// Verwundbar: takes 50 % more damage.
    pub vulnerable: u32,
    /// Gift: loses this much HP at turn start, then it drops by 1.
    pub poison: u32,
    /// Dornen: attackers take this much damage per hit (player only).
    pub thorns: u32,
    /// Blutung: loses this much HP after each of its own attacks, ignoring
    /// block; drops by 1 at the end of its turn (enemies only).
    pub bleed: u32,
}

impl Statuses {
    fn tick_debuffs(&mut self) {
        self.weak = self.weak.saturating_sub(1);
        self.vulnerable = self.vulnerable.saturating_sub(1);
        self.bleed = self.bleed.saturating_sub(1);
    }

    /// Applies poison damage to `hp` and lowers poison by 1. Ignores block.
    fn tick_poison(&mut self, hp: &mut i32) {
        if self.poison > 0 {
            *hp -= self.poison as i32;
            self.poison -= 1;
        }
    }
}

/// Equipment modifiers for the damage formula (KONZEPT.md, "Rechenreihenfolge").
/// Equipment arrives in M2; until then [`DamageMods::NEUTRAL`] is used.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DamageMods {
    /// Flat weapon damage added to the card value.
    pub weapon: i32,
    /// Tag multiplier from equipment in percent (100 = no change).
    pub tag_multiplier_pct: u32,
}

impl DamageMods {
    pub const NEUTRAL: Self = Self {
        weapon: 0,
        tag_multiplier_pct: 100,
    };
}

/// Damage formula, fixed order from KONZEPT.md:
/// card value + weapon + strength, then tag multiplier, then weak (×0.75,
/// floor), then vulnerable (×1.5, floor), never below 0.
/// With [`DamageMods::NEUTRAL`] this equals the prototype's `calc`.
pub fn calc_damage(base: i32, mods: DamageMods, attacker: &Statuses, defender: &Statuses) -> i32 {
    let mut v = i64::from(base) + i64::from(mods.weapon) + i64::from(attacker.strength);
    v = (v * i64::from(mods.tag_multiplier_pct)).div_euclid(100);
    if attacker.weak > 0 {
        v = (v * 3).div_euclid(4);
    }
    if defender.vulnerable > 0 {
        v = (v * 3).div_euclid(2);
    }
    v.clamp(0, i64::from(i32::MAX)) as i32
}

/// Whether playing the card needs an enemy target (prototype `needsTarget`).
pub fn needs_target(card: &Card) -> bool {
    let e = &card.effects;
    (e.damage > 0
        || e.block_damage
        || e.poison > 0
        || e.weak > 0
        || e.vulnerable > 0
        || e.bleed > 0
        || e.double_poison)
        && !e.all_enemies
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlayerState {
    /// May drop below 0 when the player dies.
    pub hp: i32,
    pub max_hp: i32,
    pub block: i32,
    pub status: Statuses,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EnemyState {
    pub def: EnemyDef,
    pub hp: i32,
    pub max_hp: i32,
    pub block: i32,
    pub status: Statuses,
    /// Position in the move cycle; the intent is `moves[move_index % len]`.
    pub move_index: usize,
    pub dead: bool,
}

impl EnemyState {
    /// The move this enemy will make in its next phase.
    pub fn intent(&self) -> &Move {
        &self.def.moves[self.move_index % self.def.moves.len()]
    }
}

/// Combat bonuses that come from the character (and later from equipment).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct CombatBonus {
    /// Block at the start of every combat.
    pub start_block: i32,
    /// Extra cards drawn every turn.
    pub extra_draw: u32,
    /// Flat damage bonus for cards with this tag.
    pub tag_damage: Option<(Tag, i32)>,
    /// Block gained whenever a card with this tag is played.
    pub tag_block: Option<(Tag, i32)>,
    /// Block gained at the start of every player turn.
    pub turn_block: i32,
}

/// Everything the combat needs from the run.
#[derive(Debug, Clone, Copy)]
pub struct CombatSetup<'a> {
    pub hp: i32,
    pub max_hp: i32,
    pub deck: &'a [CardInstance],
    pub relics: &'a [Relic],
    pub bonus: CombatBonus,
    /// Enemy HP and attack damage in percent (100 = as in the data).
    pub enemy_scale_pct: u32,
}

/// Scales a value by a percentage, rounded to the nearest integer.
fn scale(value: u32, pct: u32) -> u32 {
    ((u64::from(value) * u64::from(pct) + 50) / 100) as u32
}

/// Who suffered something in a [`LogEntry`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Who {
    Player,
    Enemy(usize),
}

/// Things that happened outside the player's own card plays, for the UI.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogEntry {
    /// An enemy attacked; `hp_lost` is after block (0 = fully blocked).
    EnemyAttack { enemy: usize, hp_lost: i32 },
    /// Poison ticked.
    Poison { who: Who, damage: i32 },
    /// "Brand" cards burned the player.
    Burn { hp_lost: i32 },
    /// Thorns hit an attacker.
    Thorns { enemy: usize, damage: i32 },
    /// A bleeding enemy lost HP after its attack.
    Bleed { enemy: usize, damage: i32 },
    /// An enemy died.
    EnemyDied { enemy: usize },
}

/// Maximum number of kept log entries.
const LOG_LIMIT: usize = 40;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CombatError {
    NoEnemies,
    UnknownEnemy(String),
    UnknownCard(String),
}

impl fmt::Display for CombatError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CombatError::NoEnemies => write!(f, "combat without enemies"),
            CombatError::UnknownEnemy(id) => write!(f, "unknown enemy '{id}'"),
            CombatError::UnknownCard(id) => write!(f, "unknown card '{id}'"),
        }
    }
}

impl std::error::Error for CombatError {}

/// Why a card could not be played.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlayError {
    CombatOver,
    NoSuchCard,
    UnknownCard(String),
    Unplayable,
    NotEnoughEnergy,
}

impl fmt::Display for PlayError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PlayError::CombatOver => write!(f, "combat is over"),
            PlayError::NoSuchCard => write!(f, "no card at this hand index"),
            PlayError::UnknownCard(id) => write!(f, "unknown card '{id}'"),
            PlayError::Unplayable => write!(f, "card is unplayable"),
            PlayError::NotEnoughEnergy => write!(f, "not enough energy"),
        }
    }
}

impl std::error::Error for PlayError {}

/// State of one combat.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Combat {
    pub kind: CombatKind,
    pub player: PlayerState,
    pub enemies: Vec<EnemyState>,
    /// The top of the draw pile is the end of the vector.
    pub draw_pile: Vec<CardInstance>,
    pub hand: Vec<CardInstance>,
    pub discard: Vec<CardInstance>,
    pub exhaust: Vec<CardInstance>,
    pub energy: u32,
    pub max_energy: u32,
    pub draw_per_turn: u32,
    /// Starts at 1 for the first player turn.
    pub turn: u32,
    pub outcome: Option<Outcome>,
    /// Flat damage bonus for cards with a tag (from [`CombatBonus`]).
    pub tag_damage: Option<(Tag, i32)>,
    /// Block for playing cards with a tag (from [`CombatBonus`]).
    pub tag_block: Option<(Tag, i32)>,
    /// Block at the start of every player turn (from [`CombatBonus`]).
    pub turn_block: i32,
    /// Recent events, oldest first.
    pub log: Vec<LogEntry>,
}

impl Combat {
    /// Starts a combat and runs the first turn start (prototype `startCombat`).
    pub fn start(
        setup: CombatSetup<'_>,
        kind: CombatKind,
        enemy_ids: &[&str],
        enemy_db: &EnemyDb,
        card_db: &CardDb,
        rng: &mut GameRng,
    ) -> Result<Self, CombatError> {
        if enemy_ids.is_empty() {
            return Err(CombatError::NoEnemies);
        }
        for id in setup
            .deck
            .iter()
            .map(|c| c.id.as_str())
            .chain([BURN_CARD, FROST_CARD])
        {
            if card_db.get(id).is_none() {
                return Err(CombatError::UnknownCard(id.to_string()));
            }
        }

        let mut enemies = Vec::with_capacity(enemy_ids.len());
        for &id in enemy_ids {
            let def = enemy_db
                .get(id)
                .ok_or_else(|| CombatError::UnknownEnemy(id.to_string()))?;
            let rolled = rng.range(def.hp[0] as i32, def.hp[1] as i32);
            let hp = scale(rolled as u32, setup.enemy_scale_pct) as i32;
            let move_index = match kind {
                CombatKind::Fight => rng.index(def.moves.len()),
                CombatKind::Elite | CombatKind::Boss => 0,
            };
            let mut def = def.clone();
            for m in &mut def.moves {
                m.damage = m.damage.map(|d| scale(d, setup.enemy_scale_pct));
            }
            enemies.push(EnemyState {
                def,
                hp,
                max_hp: hp,
                block: 0,
                status: Statuses::default(),
                move_index,
                dead: false,
            });
        }

        let mut draw_pile = setup.deck.to_vec();
        rng.shuffle(&mut draw_pile);

        let has = |r: Relic| setup.relics.contains(&r);
        let mut player = PlayerState {
            hp: setup.hp,
            max_hp: setup.max_hp,
            block: 0,
            status: Statuses::default(),
        };
        player.block = setup.bonus.start_block;
        if has(Relic::Anchor) {
            player.block += ANCHOR_BLOCK;
        }
        if has(Relic::Ruby) {
            player.status.strength = RUBY_STRENGTH;
        }

        let mut combat = Self {
            kind,
            player,
            enemies,
            draw_pile,
            hand: Vec::new(),
            discard: Vec::new(),
            exhaust: Vec::new(),
            energy: 0,
            max_energy: BASE_ENERGY + u32::from(has(Relic::Core)),
            draw_per_turn: BASE_DRAW + u32::from(has(Relic::Lens)) + setup.bonus.extra_draw,
            turn: 0,
            outcome: None,
            tag_damage: setup.bonus.tag_damage,
            tag_block: setup.bonus.tag_block,
            turn_block: setup.bonus.turn_block,
            log: Vec::new(),
        };
        combat.start_turn(rng);
        Ok(combat)
    }

    pub fn is_over(&self) -> bool {
        self.outcome.is_some()
    }

    /// Equipment and character modifiers for a card's damage.
    pub fn damage_mods(&self, card: &Card) -> DamageMods {
        let weapon = match self.tag_damage {
            Some((tag, bonus)) if card.has_tag(tag) => bonus,
            _ => 0,
        };
        DamageMods {
            weapon,
            ..DamageMods::NEUTRAL
        }
    }

    /// Extra block for playing this card (from [`CombatBonus::tag_block`]).
    pub fn tag_block_for(&self, card: &Card) -> i32 {
        match self.tag_block {
            Some((tag, block)) if card.has_tag(tag) => block,
            _ => 0,
        }
    }

    /// Damage per hit the card would deal to `target` right now, or against an
    /// enemy without status effects if `target` is `None`. For card texts.
    pub fn card_damage(&self, card: &Card, target: Option<usize>) -> i32 {
        let default = Statuses::default();
        let defender = target
            .and_then(|t| self.enemies.get(t))
            .map_or(&default, |e| &e.status);
        let base = if card.effects.block_damage {
            self.player.block
        } else {
            card.effects.damage as i32
        };
        calc_damage(base, self.damage_mods(card), &self.player.status, defender)
    }

    /// Damage per hit of the enemy's next attack against the player, if it attacks.
    pub fn intent_damage(&self, enemy: usize) -> Option<i32> {
        let e = self.enemies.get(enemy)?;
        let n = e.intent().damage?;
        Some(calc_damage(
            n as i32,
            DamageMods::NEUTRAL,
            &e.status,
            &self.player.status,
        ))
    }

    fn push_log(&mut self, entry: LogEntry) {
        self.log.push(entry);
        if self.log.len() > LOG_LIMIT {
            self.log.remove(0);
        }
    }

    /// Effective values of the hand card at `index`, if it can be played now.
    pub fn playable_card(&self, index: usize, db: &CardDb) -> Result<Card, PlayError> {
        if self.is_over() {
            return Err(PlayError::CombatOver);
        }
        let inst = self.hand.get(index).ok_or(PlayError::NoSuchCard)?;
        let card = inst
            .resolve(db)
            .ok_or_else(|| PlayError::UnknownCard(inst.id.clone()))?;
        if card.effects.unplayable {
            return Err(PlayError::Unplayable);
        }
        if u32::from(card.cost) > self.energy {
            return Err(PlayError::NotEnoughEnergy);
        }
        Ok(card)
    }

    /// Plays the hand card at `index` (prototype `playCard`). An invalid or dead
    /// `target` falls back to the first living enemy.
    pub fn play_card(
        &mut self,
        index: usize,
        target: Option<usize>,
        db: &CardDb,
        rng: &mut GameRng,
    ) -> Result<(), PlayError> {
        let card = self.playable_card(index, db)?;
        let inst = self.hand.remove(index);
        self.energy -= u32::from(card.cost);
        let e = &card.effects;

        let alive: Vec<usize> = (0..self.enemies.len())
            .filter(|&i| !self.enemies[i].dead)
            .collect();
        let targets: Vec<usize> = if e.all_enemies {
            alive
        } else {
            match target {
                Some(t) if t < self.enemies.len() && !self.enemies[t].dead => vec![t],
                _ => alive.first().copied().into_iter().collect(),
            }
        };

        if e.damage > 0 || e.block_damage {
            let mods = self.damage_mods(&card);
            for &t in &targets {
                for _ in 0..e.hits.max(1) {
                    if self.enemies[t].dead {
                        break;
                    }
                    let base = if e.block_damage {
                        self.player.block
                    } else {
                        e.damage as i32
                    };
                    self.hit_enemy(t, base, mods);
                }
            }
        }
        self.player.block += e.block as i32 + self.tag_block_for(&card);
        self.player.status.thorns += e.thorns;
        self.player.status.strength += e.strength as i32;
        for &t in &targets {
            let enemy = &mut self.enemies[t];
            if enemy.dead {
                continue;
            }
            enemy.status.poison += e.poison;
            enemy.status.weak += e.weak;
            enemy.status.vulnerable += e.vulnerable;
            enemy.status.bleed += e.bleed;
            if e.double_poison {
                enemy.status.poison *= 2;
            }
        }
        if e.heal > 0 {
            let healed = (e.heal as i32)
                .min(self.player.max_hp - self.player.hp)
                .max(0);
            self.player.hp += healed;
        }
        self.player.hp -= e.hp_loss as i32;
        self.energy += e.energy;
        if e.draw > 0 {
            self.draw(e.draw, rng);
        }
        if e.exhaust || card.kind == CardKind::Power {
            self.exhaust.push(inst);
        } else {
            self.discard.push(inst);
        }
        self.check();
        Ok(())
    }

    /// Ends the player's turn, runs the enemy phase and starts the next turn
    /// (prototype `endTurn`).
    pub fn end_turn(&mut self, db: &CardDb, rng: &mut GameRng) -> Result<(), PlayError> {
        if self.is_over() {
            return Err(PlayError::CombatOver);
        }
        self.player_end(db);
        if !self.is_over() {
            self.enemy_phase();
        }
        if !self.is_over() {
            self.start_turn(rng);
        }
        Ok(())
    }

    fn start_turn(&mut self, rng: &mut GameRng) {
        self.turn += 1;
        if self.turn > 1 {
            self.player.block = 0;
        }
        self.player.block += self.turn_block;
        let before = self.player.hp;
        self.player.status.tick_poison(&mut self.player.hp);
        if self.player.hp < before {
            self.push_log(LogEntry::Poison {
                who: Who::Player,
                damage: before - self.player.hp,
            });
        }
        self.check();
        if self.is_over() {
            return;
        }
        self.energy = self.max_energy;
        self.draw(self.draw_per_turn, rng);
    }

    /// Draws `n` cards, reshuffling the discard pile when the draw pile is empty.
    fn draw(&mut self, n: u32, rng: &mut GameRng) {
        for _ in 0..n {
            if self.hand.len() >= MAX_HAND {
                break;
            }
            if self.draw_pile.is_empty() {
                if self.discard.is_empty() {
                    break;
                }
                self.draw_pile = std::mem::take(&mut self.discard);
                rng.shuffle(&mut self.draw_pile);
            }
            if let Some(card) = self.draw_pile.pop() {
                self.hand.push(card);
            }
        }
    }

    /// Player attacks an enemy (prototype `hit(P, t, base)`).
    fn hit_enemy(&mut self, t: usize, base: i32, mods: DamageMods) {
        let v = calc_damage(base, mods, &self.player.status, &self.enemies[t].status);
        let enemy = &mut self.enemies[t];
        let absorbed = enemy.block.min(v);
        enemy.block -= absorbed;
        enemy.hp -= v - absorbed;
        if enemy.hp <= 0 {
            enemy.dead = true;
        }
    }

    /// Damage to the player. `source` is the attacking enemy; `None` means raw
    /// damage (Brand) that skips the formula and thorns. Returns HP lost.
    fn hit_player(&mut self, source: Option<usize>, base: i32) -> i32 {
        let v = match source {
            Some(s) => calc_damage(
                base,
                DamageMods::NEUTRAL,
                &self.enemies[s].status,
                &self.player.status,
            ),
            None => base,
        };
        let absorbed = self.player.block.min(v);
        self.player.block -= absorbed;
        let loss = v - absorbed;
        self.player.hp -= loss;
        // Thorns trigger on every hit, even a fully blocked one.
        if let Some(s) = source
            && self.player.status.thorns > 0
        {
            let damage = self.player.status.thorns as i32;
            let enemy = &mut self.enemies[s];
            enemy.hp -= damage;
            let died = enemy.hp <= 0;
            if died {
                enemy.dead = true;
            }
            self.push_log(LogEntry::Thorns { enemy: s, damage });
            if died {
                self.push_log(LogEntry::EnemyDied { enemy: s });
            }
        }
        loss
    }

    /// Prototype `chk`.
    fn check(&mut self) {
        for e in &mut self.enemies {
            if e.hp <= 0 {
                e.dead = true;
            }
        }
        if self.player.hp <= 0 {
            self.outcome = Some(Outcome::Lose);
            return;
        }
        if self.enemies.iter().all(|e| e.dead) {
            self.outcome = Some(Outcome::Win);
        }
    }

    /// Prototype `playerEnd`.
    fn player_end(&mut self, db: &CardDb) {
        let burns = self
            .hand
            .iter()
            .filter(|c| c.resolve(db).is_some_and(|c| c.effects.burn))
            .count();
        if burns > 0 {
            let mut hp_lost = 0;
            for _ in 0..burns {
                hp_lost += self.hit_player(None, BURN_DAMAGE);
            }
            self.push_log(LogEntry::Burn { hp_lost });
        }
        for c in std::mem::take(&mut self.hand) {
            if c.resolve(db).is_some_and(|c| c.effects.ethereal) {
                self.exhaust.push(c);
            } else {
                self.discard.push(c);
            }
        }
        // Weak affects the player's attacks, so it drops after the player's turn.
        // Fix: the prototype also lowered vulnerable here, before the enemies
        // acted, so 1 stack from an enemy never mattered. It now drops at the
        // end of the enemy phase. Each stack thus counts exactly once.
        self.player.status.weak = self.player.status.weak.saturating_sub(1);
        self.check();
    }

    /// Prototype `enemyPhase`.
    fn enemy_phase(&mut self) {
        let vulnerable_at_start = self.player.status.vulnerable > 0;
        for i in 0..self.enemies.len() {
            if self.enemies[i].dead {
                continue;
            }
            {
                let enemy = &mut self.enemies[i];
                enemy.block = 0;
                let before = enemy.hp;
                enemy.status.tick_poison(&mut enemy.hp);
                let damage = before - enemy.hp;
                let died = enemy.hp <= 0;
                if died {
                    enemy.dead = true;
                }
                if damage > 0 {
                    self.push_log(LogEntry::Poison {
                        who: Who::Enemy(i),
                        damage,
                    });
                }
                if died {
                    self.push_log(LogEntry::EnemyDied { enemy: i });
                    continue;
                }
            }
            let m = self.enemies[i].intent().clone();
            {
                let enemy = &mut self.enemies[i];
                enemy.block += m.block as i32;
                enemy.status.strength += m.strength as i32;
                if m.heal > 0 {
                    enemy.hp = (enemy.hp + m.heal as i32).min(enemy.max_hp);
                }
            }
            if let Some(n) = m.damage {
                let mut hp_lost = 0;
                for _ in 0..m.hit_count() {
                    hp_lost += self.hit_player(Some(i), n as i32);
                    if self.player.hp <= 0 || self.enemies[i].dead {
                        break;
                    }
                }
                self.push_log(LogEntry::EnemyAttack { enemy: i, hp_lost });
                // Bleeding: every own attack opens the wound again.
                let damage = self.enemies[i].status.bleed as i32;
                if damage > 0 && !self.enemies[i].dead {
                    let enemy = &mut self.enemies[i];
                    enemy.hp -= damage;
                    let died = enemy.hp <= 0;
                    if died {
                        enemy.dead = true;
                    }
                    self.push_log(LogEntry::Bleed { enemy: i, damage });
                    if died {
                        self.push_log(LogEntry::EnemyDied { enemy: i });
                    }
                }
            }
            if self.enemies[i].dead {
                self.check();
                if self.is_over() {
                    return;
                }
                continue;
            }
            if self.player.hp > 0 {
                let s = &mut self.player.status;
                s.weak += m.weak;
                s.vulnerable += m.vulnerable;
                s.poison += m.poison;
                for _ in 0..m.burn {
                    self.discard.push(CardInstance::new(BURN_CARD));
                }
                for _ in 0..m.frost {
                    self.discard.push(CardInstance::new(FROST_CARD));
                }
            }
            let enemy = &mut self.enemies[i];
            enemy.status.tick_debuffs();
            enemy.move_index += 1;
            self.check();
            if self.is_over() {
                return;
            }
        }
        // Vulnerable affects enemy attacks, so it drops after an enemy phase in
        // which it was already active. Stacks applied during this phase count
        // from the next enemy phase on.
        if vulnerable_at_start {
            self.player.status.vulnerable = self.player.status.vulnerable.saturating_sub(1);
        }
        // Fix: the prototype did not check here, so a fight won by poison was
        // only detected after the player's own poison ticked, which could
        // turn the win into a loss.
        self.check();
    }
}

#[cfg(test)]
mod tests;
