//! Game logic for Verlorene Lande.
//!
//! Rule: this crate knows nothing about the UI or the browser. It must build
//! natively (tests, `sim`) and for `wasm32-unknown-unknown` (`ui`).

pub mod card;
pub mod combat;
pub mod enemy;
pub mod relic;
pub mod rng;

pub use card::{Card, CardDb, CardInstance, CardKind, CardLoadError, Effects, Rarity, Tag};
pub use combat::{
    Combat, CombatError, CombatKind, CombatSetup, DamageMods, EnemyState, Outcome, PlayError,
    PlayerState, Statuses, calc_damage, needs_target,
};
pub use enemy::{EnemyDb, EnemyDef, EnemyLoadError, Move};
pub use relic::Relic;
pub use rng::GameRng;
