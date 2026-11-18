//! Game logic for Verlorene Lande.
//!
//! Rule: this crate knows nothing about the UI or the browser. It must build
//! natively (tests, `sim`) and for `wasm32-unknown-unknown` (`ui`).

pub mod bot;
pub mod card;
pub mod combat;
pub mod content;
pub mod enemy;
pub mod map;
pub mod relic;
pub mod rng;
pub mod run;

pub use card::{Card, CardDb, CardInstance, CardKind, CardLoadError, Effects, Rarity, Tag};
pub use combat::{
    Combat, CombatBonus, CombatError, CombatKind, CombatSetup, DamageMods, EnemyState, LogEntry,
    Outcome, PlayError, PlayerState, Statuses, Who, calc_damage, needs_target,
};
pub use content::{
    CharacterDef, CharacterTrait, DataError, EventDef, EventEffect, GameData, PickMode, RegionDef,
    RelicInfo,
};
pub use enemy::{EnemyDb, EnemyDef, EnemyLoadError, Move};
pub use map::{MAP_COLS, MAP_ROWS, Map, MapNode, NodeKind, START_LANES};
pub use relic::Relic;
pub use rng::GameRng;
pub use run::{
    ActionError, EventResult, EventState, Phase, PickOutcome, PickReturn, PickState, Reward,
    RewardSource, Run, RunStats, Shop,
};
