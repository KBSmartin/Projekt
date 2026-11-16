//! Enemy data types and loading from JSON (prototype `EN`).

use serde::{Deserialize, Serialize};
use std::fmt;

/// One step of an enemy's move cycle. The cycle repeats in order.
/// A value of 0 means the effect is absent.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Move {
    /// `n`: damage per hit. `None` means the move is not an attack
    /// (the prototype checks `m.n !== undefined`, so an attack for 0 is possible).
    pub damage: Option<u32>,
    /// `h`: number of hits; 0 means a single hit.
    pub hits: u32,
    /// `blk`: block for the enemy itself.
    pub block: u32,
    /// `str`: strength for the enemy itself.
    pub strength: u32,
    /// `heal`: heals the enemy itself, capped at max HP.
    pub heal: u32,
    /// `weak`: applied to the player.
    pub weak: u32,
    /// `vuln`: applied to the player.
    pub vulnerable: u32,
    /// `psn`: applied to the player.
    pub poison: u32,
    /// `burn`: number of "Brand" cards added to the player's discard pile.
    pub burn: u32,
    /// `frost`: number of "Frost" cards added to the player's discard pile.
    pub frost: u32,
}

impl Move {
    pub fn hit_count(&self) -> u32 {
        self.hits.max(1)
    }
}

/// An enemy definition as stored in `data/enemies.json`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EnemyDef {
    pub id: String,
    /// German in-game name.
    pub name: String,
    /// Inclusive HP range `[min, max]`, rolled at combat start.
    pub hp: [u32; 2],
    pub moves: Vec<Move>,
}

/// Error while loading enemy data.
#[derive(Debug)]
pub enum EnemyLoadError {
    Json(serde_json::Error),
    DuplicateId(String),
    Invalid { id: String, reason: &'static str },
}

impl fmt::Display for EnemyLoadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EnemyLoadError::Json(e) => write!(f, "invalid enemy JSON: {e}"),
            EnemyLoadError::DuplicateId(id) => write!(f, "duplicate enemy id '{id}'"),
            EnemyLoadError::Invalid { id, reason } => {
                write!(f, "enemy '{id}' is invalid: {reason}")
            }
        }
    }
}

impl std::error::Error for EnemyLoadError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            EnemyLoadError::Json(e) => Some(e),
            _ => None,
        }
    }
}

/// Enemy data shipped with the game, embedded at compile time.
pub const BUILTIN_ENEMIES_JSON: &str = include_str!("../../data/enemies.json");

/// All enemy definitions, in file order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EnemyDb {
    enemies: Vec<EnemyDef>,
}

impl EnemyDb {
    pub fn from_json(json: &str) -> Result<Self, EnemyLoadError> {
        let enemies: Vec<EnemyDef> = serde_json::from_str(json).map_err(EnemyLoadError::Json)?;
        for (i, e) in enemies.iter().enumerate() {
            let invalid = |reason| EnemyLoadError::Invalid {
                id: e.id.clone(),
                reason,
            };
            if e.id.trim().is_empty() || e.name.trim().is_empty() {
                return Err(invalid("empty id or name"));
            }
            if e.hp[0] == 0 || e.hp[0] > e.hp[1] {
                return Err(invalid("hp must be [min, max] with 0 < min <= max"));
            }
            if e.hp[1] > i32::MAX as u32 {
                return Err(invalid("hp too large"));
            }
            if e.moves.is_empty() {
                return Err(invalid("no moves"));
            }
            if enemies[..i].iter().any(|o| o.id == e.id) {
                return Err(EnemyLoadError::DuplicateId(e.id.clone()));
            }
        }
        Ok(Self { enemies })
    }

    pub fn builtin() -> Result<Self, EnemyLoadError> {
        Self::from_json(BUILTIN_ENEMIES_JSON)
    }

    pub fn get(&self, id: &str) -> Option<&EnemyDef> {
        self.enemies.iter().find(|e| e.id == id)
    }

    pub fn enemies(&self) -> &[EnemyDef] {
        &self.enemies
    }

    pub fn len(&self) -> usize {
        self.enemies.len()
    }

    pub fn is_empty(&self) -> bool {
        self.enemies.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builtin_enemies_load() {
        let db = EnemyDb::builtin().expect("data/enemies.json must be valid");
        assert_eq!(db.len(), 15, "all enemies of the prototype");
    }

    #[test]
    fn builtin_rat_matches_prototype() {
        let db = EnemyDb::builtin().unwrap();
        let rat = db.get("rat").unwrap();
        assert_eq!(rat.name, "Waldratte");
        assert_eq!(rat.hp, [11, 15]);
        assert_eq!(rat.moves.len(), 2);
        assert_eq!(rat.moves[0].damage, Some(5));
        assert_eq!(rat.moves[1].damage, Some(3));
        assert_eq!(rat.moves[1].poison, 2);
    }

    #[test]
    fn non_attack_move_has_no_damage() {
        let db = EnemyDb::builtin().unwrap();
        let wolf = db.get("wolf").unwrap();
        assert_eq!(wolf.moves[1].damage, None);
        assert_eq!(wolf.moves[1].strength, 2);
    }

    #[test]
    fn invalid_enemies_are_rejected() {
        let bad_hp = r#"[{"id":"x","name":"X","hp":[10,5],"moves":[{"damage":1}]}]"#;
        assert!(matches!(
            EnemyDb::from_json(bad_hp),
            Err(EnemyLoadError::Invalid { .. })
        ));
        let no_moves = r#"[{"id":"x","name":"X","hp":[5,5],"moves":[]}]"#;
        assert!(matches!(
            EnemyDb::from_json(no_moves),
            Err(EnemyLoadError::Invalid { .. })
        ));
        let typo = r#"[{"id":"x","name":"X","hp":[5,5],"moves":[{"n":1}]}]"#;
        assert!(matches!(
            EnemyDb::from_json(typo),
            Err(EnemyLoadError::Json(_))
        ));
        let one = r#"{"id":"x","name":"X","hp":[5,5],"moves":[{"damage":1}]}"#;
        assert!(matches!(
            EnemyDb::from_json(&format!("[{one},{one}]")),
            Err(EnemyLoadError::DuplicateId(_))
        ));
    }
}
