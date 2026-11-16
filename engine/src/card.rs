//! Card data types and loading from JSON.
//!
//! Field meanings follow the JS prototype (`CARDS` in prototype/index.html).
//! A value of 0 or `false` means the effect is absent.

use serde::{Deserialize, Serialize};
use std::fmt;

/// Card families that equipment effects can target (see KONZEPT.md, "Kombinieren").
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Tag {
    /// Hieb
    Slash,
    /// Gift
    Poison,
    /// Block
    Block,
    /// Schild
    Shield,
    /// Wurf
    Throw,
    /// Fläche
    Area,
    /// Ziehen
    Draw,
}

impl Tag {
    pub const ALL: [Tag; 7] = [
        Tag::Slash,
        Tag::Poison,
        Tag::Block,
        Tag::Shield,
        Tag::Throw,
        Tag::Area,
        Tag::Draw,
    ];

    /// German in-game name.
    pub fn name(self) -> &'static str {
        match self {
            Tag::Slash => "Hieb",
            Tag::Poison => "Gift",
            Tag::Block => "Block",
            Tag::Shield => "Schild",
            Tag::Throw => "Wurf",
            Tag::Area => "Fläche",
            Tag::Draw => "Ziehen",
        }
    }
}

/// Card type (prototype field `t`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CardKind {
    Attack,
    Skill,
    Power,
    Status,
}

impl CardKind {
    /// German in-game name.
    pub fn name(self) -> &'static str {
        match self {
            CardKind::Attack => "Angriff",
            CardKind::Skill => "Fertigkeit",
            CardKind::Power => "Kraft",
            CardKind::Status => "Status",
        }
    }
}

/// Rarity (prototype field `r`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Rarity {
    Starter,
    Common,
    Uncommon,
    Rare,
    /// Junk cards added by enemies (Brand, Frost, Last).
    Junk,
}

/// What a card does when played. Mirrors the flat effect fields of the prototype.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Effects {
    /// `dmg`: damage per hit.
    pub damage: u32,
    /// `hits`: number of hits; 0 means a single hit.
    pub hits: u32,
    /// `bdmg`: deals damage equal to the player's current block.
    pub block_damage: bool,
    /// `aoe`: hits all enemies instead of one target.
    pub all_enemies: bool,
    /// `blk`
    pub block: u32,
    /// `psn`
    pub poison: u32,
    /// `dblpsn`: doubles the target's poison.
    pub double_poison: bool,
    /// `weak`
    pub weak: u32,
    /// `vuln`
    pub vulnerable: u32,
    /// `thorns`
    pub thorns: u32,
    /// `str`
    pub strength: u32,
    /// `heal`
    pub heal: u32,
    /// `hpl`: player loses this much HP.
    pub hp_loss: u32,
    /// `draw`
    pub draw: u32,
    /// `en`: gain energy.
    pub energy: u32,
    /// `exh`: card is exhausted after playing.
    pub exhaust: bool,
    /// `unp`
    pub unplayable: bool,
    /// `eth`: exhausted at end of turn if still in hand.
    pub ethereal: bool,
    /// `burn`: deals damage to the player at end of turn if still in hand.
    pub burn: bool,
}

/// A card definition as stored in `data/cards.json`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Card {
    /// Stable identifier, same as the key in the prototype.
    pub id: String,
    /// German in-game name.
    pub name: String,
    pub kind: CardKind,
    pub cost: u8,
    pub rarity: Rarity,
    pub tags: Vec<Tag>,
    #[serde(default)]
    pub effects: Effects,
}

impl Card {
    pub fn has_tag(&self, tag: Tag) -> bool {
        self.tags.contains(&tag)
    }
}

/// Error while loading card data.
#[derive(Debug)]
pub enum CardLoadError {
    /// The JSON could not be parsed or did not match the schema.
    Json(serde_json::Error),
    /// Two cards share the same id.
    DuplicateId(String),
    /// A card has a missing, duplicate or excess tag.
    InvalidTags { id: String, reason: &'static str },
    /// A card has an empty id or name.
    EmptyField { id: String, field: &'static str },
}

impl fmt::Display for CardLoadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CardLoadError::Json(e) => write!(f, "invalid card JSON: {e}"),
            CardLoadError::DuplicateId(id) => write!(f, "duplicate card id '{id}'"),
            CardLoadError::InvalidTags { id, reason } => {
                write!(f, "card '{id}' has invalid tags: {reason}")
            }
            CardLoadError::EmptyField { id, field } => {
                write!(f, "card '{id}' has an empty field '{field}'")
            }
        }
    }
}

impl std::error::Error for CardLoadError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            CardLoadError::Json(e) => Some(e),
            _ => None,
        }
    }
}

/// Card data shipped with the game, embedded at compile time so it also works in WASM.
pub const BUILTIN_CARDS_JSON: &str = include_str!("../../data/cards.json");

/// All card definitions, in file order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CardDb {
    cards: Vec<Card>,
}

impl CardDb {
    /// Parses and validates a JSON array of cards.
    pub fn from_json(json: &str) -> Result<Self, CardLoadError> {
        let cards: Vec<Card> = serde_json::from_str(json).map_err(CardLoadError::Json)?;
        for (i, card) in cards.iter().enumerate() {
            validate(card)?;
            if cards[..i].iter().any(|c| c.id == card.id) {
                return Err(CardLoadError::DuplicateId(card.id.clone()));
            }
        }
        Ok(Self { cards })
    }

    /// Loads the embedded `data/cards.json`.
    pub fn builtin() -> Result<Self, CardLoadError> {
        Self::from_json(BUILTIN_CARDS_JSON)
    }

    pub fn get(&self, id: &str) -> Option<&Card> {
        self.cards.iter().find(|c| c.id == id)
    }

    pub fn cards(&self) -> &[Card] {
        &self.cards
    }

    pub fn len(&self) -> usize {
        self.cards.len()
    }

    pub fn is_empty(&self) -> bool {
        self.cards.is_empty()
    }
}

/// KONZEPT.md: every card carries one or two tags. Status cards (junk) may carry none.
fn validate(card: &Card) -> Result<(), CardLoadError> {
    if card.id.trim().is_empty() {
        return Err(CardLoadError::EmptyField {
            id: card.id.clone(),
            field: "id",
        });
    }
    if card.name.trim().is_empty() {
        return Err(CardLoadError::EmptyField {
            id: card.id.clone(),
            field: "name",
        });
    }
    let invalid = |reason| CardLoadError::InvalidTags {
        id: card.id.clone(),
        reason,
    };
    if card.tags.len() > 2 {
        return Err(invalid("more than two tags"));
    }
    if card.tags.is_empty() && card.kind != CardKind::Status {
        return Err(invalid("non-status card without tag"));
    }
    if card.tags.len() == 2 && card.tags[0] == card.tags[1] {
        return Err(invalid("duplicate tag"));
    }
    Ok(())
}
