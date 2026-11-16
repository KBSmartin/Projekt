//! Game logic for Verlorene Lande.
//!
//! Rule: this crate knows nothing about the UI or the browser. It must build
//! natively (tests, `sim`) and for `wasm32-unknown-unknown` (`ui`).

pub mod card;
pub mod rng;

pub use card::{Card, CardDb, CardKind, CardLoadError, Effects, Rarity, Tag};
pub use rng::GameRng;
