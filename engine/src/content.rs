//! Game content besides cards and enemies: characters, regions, events and
//! relic descriptions. [`GameData`] bundles everything and checks references.

use crate::card::{CardDb, CardLoadError, Rarity, Tag};
use crate::combat::CombatBonus;
use crate::enemy::{EnemyDb, EnemyLoadError};
use crate::relic::Relic;
use serde::{Deserialize, Serialize};
use std::fmt;

/// A character's passive rule ("Eigenheit").
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case", deny_unknown_fields)]
pub enum CharacterTrait {
    /// Block at the start of every combat.
    StartBlock { amount: i32 },
    /// Flat damage bonus for cards with a tag.
    TagDamage { tag: Tag, amount: i32 },
    /// Extra cards drawn every turn. Not used by the starting characters:
    /// KONZEPT.md reserves permanent extra cards for artifacts.
    ExtraDraw { amount: u32 },
    /// Block whenever a card with this tag is played.
    TagBlock { tag: Tag, amount: i32 },
    /// Block at the start of every turn.
    TurnBlock { amount: i32 },
}

impl CharacterTrait {
    pub fn combat_bonus(self) -> CombatBonus {
        match self {
            CharacterTrait::StartBlock { amount } => CombatBonus {
                start_block: amount,
                ..CombatBonus::default()
            },
            CharacterTrait::TagDamage { tag, amount } => CombatBonus {
                tag_damage: Some((tag, amount)),
                ..CombatBonus::default()
            },
            CharacterTrait::ExtraDraw { amount } => CombatBonus {
                extra_draw: amount,
                ..CombatBonus::default()
            },
            CharacterTrait::TagBlock { tag, amount } => CombatBonus {
                tag_block: Some((tag, amount)),
                ..CombatBonus::default()
            },
            CharacterTrait::TurnBlock { amount } => CombatBonus {
                turn_block: amount,
                ..CombatBonus::default()
            },
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CharacterDef {
    pub id: String,
    pub name: String,
    pub icon: String,
    pub description: String,
    pub max_hp: i32,
    pub trait_name: String,
    pub trait_text: String,
    #[serde(rename = "trait")]
    pub trait_rule: CharacterTrait,
    /// Card ids of the starting deck.
    pub deck: Vec<String>,
}

/// A region ("Gebiet") with its encounters.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RegionDef {
    pub id: String,
    pub name: String,
    pub subtitle: String,
    /// Accent color for the UI.
    pub color: String,
    pub icon: String,
    pub intro: String,
    /// Encounters for map rows 0 to 2.
    pub easy: Vec<Vec<String>>,
    /// Encounters for later rows.
    pub hard: Vec<Vec<String>>,
    pub elites: Vec<Vec<String>>,
    pub boss: Vec<String>,
}

/// Display data for a relic; the rules live in [`Relic`] and the combat code.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RelicInfo {
    pub id: Relic,
    pub name: String,
    pub icon: String,
    pub description: String,
}

/// What a card pick screen does with the chosen card.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PickMode {
    Upgrade,
    Remove,
    /// Replace the card with a random rare card from the character's pool.
    Trade,
}

/// One effect of an event outcome, applied in order.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventEffect {
    /// Heal, capped at max HP. The message can show the amount as `{healed}`.
    Heal(i32),
    /// Raise max HP and current HP.
    GainMaxHp(i32),
    LoseHp(i32),
    GainGold(u32),
    LoseGold(u32),
    AddCard(String),
    /// Opens a reward screen with three rare cards.
    RareCardChoice,
    /// Opens a card pick screen; `cost` is paid when a card is picked.
    Pick {
        mode: PickMode,
        cost: u32,
    },
}

/// Conditions for an event option to be selectable.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Requirement {
    pub min_hp: i32,
    pub min_gold: u32,
    pub upgradable_card: bool,
    pub min_deck: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EventOutcome {
    #[serde(default = "default_weight")]
    pub weight: u32,
    #[serde(default)]
    pub effects: Vec<EventEffect>,
    #[serde(default)]
    pub message: String,
}

fn default_weight() -> u32 {
    1
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EventOption {
    pub label: String,
    #[serde(default)]
    pub requires: Requirement,
    /// One outcome is chosen by weight.
    pub outcomes: Vec<EventOutcome>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EventDef {
    pub id: String,
    pub title: String,
    pub icon: String,
    pub text: String,
    pub options: Vec<EventOption>,
}

/// Error while loading or checking game data.
#[derive(Debug)]
pub enum DataError {
    Cards(CardLoadError),
    Enemies(EnemyLoadError),
    Json {
        file: &'static str,
        error: serde_json::Error,
    },
    Invalid(String),
}

impl fmt::Display for DataError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DataError::Cards(e) => write!(f, "{e}"),
            DataError::Enemies(e) => write!(f, "{e}"),
            DataError::Json { file, error } => write!(f, "invalid {file}: {error}"),
            DataError::Invalid(msg) => write!(f, "invalid game data: {msg}"),
        }
    }
}

impl std::error::Error for DataError {}

/// Raw JSON of every data file.
#[derive(Debug, Clone, Copy)]
pub struct DataSources<'a> {
    pub cards: &'a str,
    pub enemies: &'a str,
    pub characters: &'a str,
    pub regions: &'a str,
    pub events: &'a str,
    pub relics: &'a str,
}

impl DataSources<'static> {
    /// The data files shipped with the game, embedded at compile time.
    pub const BUILTIN: Self = Self {
        cards: include_str!("../../data/cards.json"),
        enemies: include_str!("../../data/enemies.json"),
        characters: include_str!("../../data/characters.json"),
        regions: include_str!("../../data/regions.json"),
        events: include_str!("../../data/events.json"),
        relics: include_str!("../../data/relics.json"),
    };
}

/// Minimum cards per rarity in each character's pool, so that reward screens
/// can always offer three different cards.
pub const MIN_POOL_PER_RARITY: usize = 3;

/// All game content.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GameData {
    pub cards: CardDb,
    pub enemies: EnemyDb,
    pub characters: Vec<CharacterDef>,
    pub regions: Vec<RegionDef>,
    pub events: Vec<EventDef>,
    pub relics: Vec<RelicInfo>,
}

fn parse<T: for<'de> Deserialize<'de>>(file: &'static str, json: &str) -> Result<T, DataError> {
    serde_json::from_str(json).map_err(|error| DataError::Json { file, error })
}

impl GameData {
    pub fn builtin() -> Result<Self, DataError> {
        Self::from_sources(DataSources::BUILTIN)
    }

    pub fn from_sources(src: DataSources<'_>) -> Result<Self, DataError> {
        let data = Self {
            cards: CardDb::from_json(src.cards).map_err(DataError::Cards)?,
            enemies: EnemyDb::from_json(src.enemies).map_err(DataError::Enemies)?,
            characters: parse("characters.json", src.characters)?,
            regions: parse("regions.json", src.regions)?,
            events: parse("events.json", src.events)?,
            relics: parse("relics.json", src.relics)?,
        };
        data.validate()?;
        Ok(data)
    }

    pub fn character(&self, id: &str) -> Option<&CharacterDef> {
        self.characters.iter().find(|c| c.id == id)
    }

    pub fn relic(&self, relic: Relic) -> Option<&RelicInfo> {
        self.relics.iter().find(|r| r.id == relic)
    }

    /// Card ids a character can find in rewards and shops with this rarity.
    pub fn pool(&self, character: &str, rarity: Rarity) -> Vec<&str> {
        self.cards
            .cards()
            .iter()
            .filter(|c| c.rarity == rarity && c.in_pool_of(character))
            .map(|c| c.id.as_str())
            .collect()
    }

    fn validate(&self) -> Result<(), DataError> {
        let invalid = |msg: String| Err(DataError::Invalid(msg));
        let card_exists = |id: &str| self.cards.get(id).is_some();
        let enemy_exists = |id: &str| self.enemies.get(id).is_some();

        if self.characters.is_empty() {
            return invalid("no characters".into());
        }
        for (i, ch) in self.characters.iter().enumerate() {
            if self.characters[..i].iter().any(|o| o.id == ch.id) {
                return invalid(format!("duplicate character '{}'", ch.id));
            }
            if ch.max_hp <= 0 || ch.deck.is_empty() {
                return invalid(format!("character '{}' needs HP and a deck", ch.id));
            }
            if let Some(id) = ch.deck.iter().find(|id| !card_exists(id)) {
                return invalid(format!("character '{}' has unknown card '{id}'", ch.id));
            }
            for rarity in [Rarity::Common, Rarity::Uncommon, Rarity::Rare] {
                let n = self.pool(&ch.id, rarity).len();
                if n < MIN_POOL_PER_RARITY {
                    return invalid(format!(
                        "character '{}' has only {n} {rarity:?} cards",
                        ch.id
                    ));
                }
            }
        }
        for card in self.cards.cards() {
            if let Some(owner) = &card.character
                && self.character(owner).is_none()
            {
                return invalid(format!(
                    "card '{}' has unknown character '{owner}'",
                    card.id
                ));
            }
        }

        if self.regions.is_empty() {
            return invalid("no regions".into());
        }
        for r in &self.regions {
            let groups = [&r.easy, &r.hard, &r.elites];
            if groups
                .iter()
                .any(|g| g.is_empty() || g.iter().any(Vec::is_empty))
                || r.boss.is_empty()
            {
                return invalid(format!("region '{}' has an empty encounter list", r.id));
            }
            let all = groups
                .iter()
                .flat_map(|g| g.iter().flatten())
                .chain(&r.boss);
            for id in all {
                if !enemy_exists(id) {
                    return invalid(format!("region '{}' has unknown enemy '{id}'", r.id));
                }
            }
        }

        if self.events.is_empty() {
            return invalid("no events".into());
        }
        for ev in &self.events {
            for opt in &ev.options {
                if opt.outcomes.iter().map(|o| o.weight).sum::<u32>() == 0 {
                    return invalid(format!("event '{}' has an option without outcome", ev.id));
                }
                for effect in opt.outcomes.iter().flat_map(|o| &o.effects) {
                    if let EventEffect::AddCard(id) = effect
                        && !card_exists(id)
                    {
                        return invalid(format!("event '{}' adds unknown card '{id}'", ev.id));
                    }
                }
            }
        }

        for relic in Relic::ALL {
            if self.relic(relic).is_none() {
                return invalid(format!("relic {relic:?} has no description"));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builtin_data_is_valid() {
        let data = GameData::builtin().expect("data/*.json must be valid");
        assert_eq!(data.characters.len(), 3);
        assert_eq!(data.regions.len(), 3);
        assert_eq!(data.events.len(), 6);
    }

    #[test]
    fn characters_have_their_own_cards() {
        let data = GameData::builtin().unwrap();
        let names: Vec<&str> = data.characters.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, ["Krieger", "Schütze", "Magier"]);
        // No card of one character is in another character's pool or deck.
        for ch in &data.characters {
            for id in &ch.deck {
                let card = data.cards.get(id).unwrap();
                assert!(card.character.as_deref().is_none_or(|c| c == ch.id));
            }
        }
        let warrior_rares = data.pool("warrior", Rarity::Rare);
        let mage_rares = data.pool("mage", Rarity::Rare);
        assert!(warrior_rares.iter().all(|id| !mage_rares.contains(id)));
    }

    #[test]
    fn shield_bash_is_only_in_the_warrior_deck() {
        let data = GameData::builtin().unwrap();
        for ch in &data.characters {
            let has_bash = ch.deck.iter().any(|id| id == "bash");
            assert_eq!(has_bash, ch.id == "warrior", "{}", ch.id);
        }
    }

    #[test]
    fn traits_become_combat_bonuses() {
        let data = GameData::builtin().unwrap();
        let bonus = |id: &str| data.character(id).unwrap().trait_rule.combat_bonus();
        assert!(bonus("warrior").turn_block > 0);
        assert!(matches!(bonus("marksman").tag_damage, Some((Tag::Throw, n)) if n > 0));
        assert!(matches!(bonus("mage").tag_block, Some((Tag::Spell, n)) if n > 0));
    }

    #[test]
    fn broken_references_are_rejected() {
        let src = DataSources::BUILTIN;
        let bad_region = src.regions.replace("\"mother\"", "\"nobody\"");
        let r = GameData::from_sources(DataSources {
            regions: &bad_region,
            ..src
        });
        assert!(matches!(r, Err(DataError::Invalid(_))));

        let bad_deck = src.characters.replacen("\"bash\"", "\"nothing\"", 1);
        let r = GameData::from_sources(DataSources {
            characters: &bad_deck,
            ..src
        });
        assert!(matches!(r, Err(DataError::Invalid(_))));

        let bad_event = src.events.replace("\"curse\"", "\"nothing\"");
        let r = GameData::from_sources(DataSources {
            events: &bad_event,
            ..src
        });
        assert!(matches!(r, Err(DataError::Invalid(_))));
    }
}
