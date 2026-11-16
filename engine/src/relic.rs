//! Relics (prototype `RELICS`, called "Artefakte" in KONZEPT.md).
//!
//! Only the rule hooks live here. Names and descriptions move to JSON later.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Relic {
    /// Anker: start every combat with 8 block.
    Anchor,
    /// Blutrubin: start every combat with +1 strength.
    Ruby,
    /// Energiekern: +1 energy per turn.
    Core,
    /// Kräutertee: heal 6 HP after every combat.
    Tea,
    /// Linse: draw 1 more card every turn.
    Lens,
    /// Glücksmünze: 50 % more gold from combats.
    Coin,
}

impl Relic {
    pub const ALL: [Relic; 6] = [
        Relic::Anchor,
        Relic::Ruby,
        Relic::Core,
        Relic::Tea,
        Relic::Lens,
        Relic::Coin,
    ];
}

/// Block at combat start from [`Relic::Anchor`].
pub const ANCHOR_BLOCK: i32 = 8;
/// Strength at combat start from [`Relic::Ruby`].
pub const RUBY_STRENGTH: i32 = 1;
