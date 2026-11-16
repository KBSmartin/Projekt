//! Combat rules, ported 1:1 from the prototype (`calc`, `hit`, `startCombat`,
//! `draw`, `startTurn`, `playCard`, `playerEnd`, `enemyPhase`, `endTurn`).
//!
//! The port keeps the prototype's quirks on purpose, so bot results stay
//! comparable. Known quirks are marked with "Prototype quirk".
//!
//! All randomness goes through the [`GameRng`] passed in by the caller, and
//! card and enemy data are passed in as well, so a [`Combat`] is plain data.

use crate::card::{Card, CardDb, CardInstance, CardKind};
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
}

impl Statuses {
    fn tick_debuffs(&mut self) {
        self.weak = self.weak.saturating_sub(1);
        self.vulnerable = self.vulnerable.saturating_sub(1);
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

/// Everything the combat needs from the run.
#[derive(Debug, Clone, Copy)]
pub struct CombatSetup<'a> {
    pub hp: i32,
    pub max_hp: i32,
    pub deck: &'a [CardInstance],
    pub relics: &'a [Relic],
}

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
            let hp = rng.range(def.hp[0] as i32, def.hp[1] as i32);
            let move_index = match kind {
                CombatKind::Fight => rng.index(def.moves.len()),
                CombatKind::Elite | CombatKind::Boss => 0,
            };
            enemies.push(EnemyState {
                def: def.clone(),
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
        if has(Relic::Anchor) {
            player.block = ANCHOR_BLOCK;
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
            draw_per_turn: BASE_DRAW + u32::from(has(Relic::Lens)),
            turn: 0,
            outcome: None,
        };
        combat.start_turn(rng);
        Ok(combat)
    }

    pub fn is_over(&self) -> bool {
        self.outcome.is_some()
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
                    self.hit_enemy(t, base);
                }
            }
        }
        self.player.block += e.block as i32;
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
        self.player.status.tick_poison(&mut self.player.hp);
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
    fn hit_enemy(&mut self, t: usize, base: i32) {
        let v = calc_damage(
            base,
            DamageMods::NEUTRAL,
            &self.player.status,
            &self.enemies[t].status,
        );
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
            let enemy = &mut self.enemies[s];
            enemy.hp -= self.player.status.thorns as i32;
            if enemy.hp <= 0 {
                enemy.dead = true;
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
        for _ in 0..burns {
            self.hit_player(None, BURN_DAMAGE);
        }
        for c in std::mem::take(&mut self.hand) {
            if c.resolve(db).is_some_and(|c| c.effects.ethereal) {
                self.exhaust.push(c);
            } else {
                self.discard.push(c);
            }
        }
        // Prototype quirk: the player's weak and vulnerable drop before the
        // enemies act, so 1 stack applied by an enemy never takes effect.
        self.player.status.tick_debuffs();
        self.check();
    }

    /// Prototype `enemyPhase`.
    fn enemy_phase(&mut self) {
        for i in 0..self.enemies.len() {
            if self.enemies[i].dead {
                continue;
            }
            {
                let enemy = &mut self.enemies[i];
                enemy.block = 0;
                enemy.status.tick_poison(&mut enemy.hp);
                if enemy.hp <= 0 {
                    // Prototype quirk: no check here; the win is detected later.
                    enemy.dead = true;
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
                for _ in 0..m.hit_count() {
                    self.hit_player(Some(i), n as i32);
                    if self.player.hp <= 0 || self.enemies[i].dead {
                        break;
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
    }
}

#[cfg(test)]
mod tests;
