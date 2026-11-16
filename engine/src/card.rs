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
    /// Zauber (added for the Magier, not in the KONZEPT.md example list)
    Spell,
}

impl Tag {
    pub const ALL: [Tag; 8] = [
        Tag::Slash,
        Tag::Poison,
        Tag::Block,
        Tag::Shield,
        Tag::Throw,
        Tag::Area,
        Tag::Draw,
        Tag::Spell,
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
            Tag::Spell => "Zauber",
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
    /// Blutung on the target (not in the prototype, replaces `dblpsn` on Ausbluten).
    pub bleed: u32,
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
    /// Placeholder symbol until the pixel art exists.
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub icon: String,
    /// Character whose card pool this card belongs to; `None` = every character.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub character: Option<String>,
}

impl Card {
    pub fn has_tag(&self, tag: Tag) -> bool {
        self.tags.contains(&tag)
    }

    /// Whether this card can show up in rewards and shops for `character`.
    pub fn in_pool_of(&self, character: &str) -> bool {
        matches!(
            self.rarity,
            Rarity::Common | Rarity::Uncommon | Rarity::Rare
        ) && self.character.as_deref().is_none_or(|c| c == character)
    }

    /// Whether the card can be upgraded at all (prototype `upgradable`, minus the
    /// "already upgraded" check, which belongs to [`CardInstance`]).
    pub fn is_upgradable(&self) -> bool {
        self.rarity != Rarity::Junk
    }

    /// The upgraded version of this card (prototype `stats` with `c.up`).
    ///
    /// Damage and block grow by 40 % rounded up; poison, heal, strength, thorns,
    /// weak and vulnerable grow by fixed amounts. If none of these apply, the
    /// card instead costs 1 less, or loses Exhaust, or gives 1 more energy.
    pub fn upgraded(&self) -> Card {
        let mut c = self.clone();
        let e = &mut c.effects;
        let mut changed = false;
        // ceil(x * 1.4) in integers; checked against the prototype's float math.
        let grow = |x: &mut u32, changed: &mut bool| {
            if *x > 0 {
                *x = (*x * 14).div_ceil(10);
                *changed = true;
            }
        };
        let add = |x: &mut u32, n: u32, changed: &mut bool| {
            if *x > 0 {
                *x += n;
                *changed = true;
            }
        };
        grow(&mut e.damage, &mut changed);
        grow(&mut e.block, &mut changed);
        add(&mut e.poison, 2, &mut changed);
        add(&mut e.heal, 3, &mut changed);
        add(&mut e.strength, 1, &mut changed);
        add(&mut e.thorns, 2, &mut changed);
        add(&mut e.bleed, 2, &mut changed);
        add(&mut e.weak, 1, &mut changed);
        add(&mut e.vulnerable, 1, &mut changed);
        if !changed {
            if c.cost > 0 {
                c.cost -= 1;
            } else if e.exhaust {
                e.exhaust = false;
            } else if e.energy > 0 {
                e.energy += 1;
            }
        }
        c
    }
}

/// A card in a deck or pile: a reference to its definition plus upgrade state.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct CardInstance {
    pub id: String,
    #[serde(default)]
    pub upgraded: bool,
}

impl CardInstance {
    pub fn new(id: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            upgraded: false,
        }
    }

    /// Effective card values, with the upgrade applied. `None` if the id is unknown.
    pub fn resolve(&self, db: &CardDb) -> Option<Card> {
        let base = db.get(&self.id)?;
        Some(if self.upgraded {
            base.upgraded()
        } else {
            base.clone()
        })
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
        Self::from_cards(cards)
    }

    /// Validates already parsed cards (useful for tests and generated content).
    pub fn from_cards(cards: Vec<Card>) -> Result<Self, CardLoadError> {
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

#[cfg(test)]
mod tests {
    use super::*;

    /// Wraps a single card JSON object into an array and loads it.
    fn load_one(card_json: &str) -> Result<CardDb, CardLoadError> {
        CardDb::from_json(&format!("[{card_json}]"))
    }

    #[test]
    fn builtin_cards_load() {
        let db = CardDb::builtin().expect("data/cards.json must be valid");
        for id in ["strike", "defend", "bash", "burn", "frost"] {
            assert!(db.get(id).is_some(), "combat needs card '{id}'");
        }
    }

    fn card(effects: &str, cost: u8) -> Card {
        let json = format!(
            r#"[{{"id":"x","name":"X","kind":"skill","cost":{cost},"rarity":"common","tags":["draw"],"effects":{effects}}}]"#
        );
        CardDb::from_json(&json).unwrap().cards()[0].clone()
    }

    #[test]
    fn upgrade_matches_prototype_numbers() {
        let db = CardDb::builtin().unwrap();
        let up = |id: &str| db.get(id).unwrap().upgraded();
        assert_eq!(up("strike").effects.damage, 9); // ceil(6 * 1.4)
        assert_eq!(up("defend").effects.block, 7); // ceil(5 * 1.4)
        assert_eq!(up("heavy").effects.damage, 20); // 14 * 1.4 = 19.6
        let bash = up("bash");
        assert_eq!((bash.effects.damage, bash.effects.vulnerable), (12, 3));
        let venom = up("venom");
        assert_eq!((venom.effects.damage, venom.effects.poison), (5, 6));
        // Exact multiples of 5 must not round up (float trap in the prototype).
        assert_eq!(card(r#"{"block":25}"#, 3).upgraded().effects.block, 35);
    }

    #[test]
    fn upgrade_fallbacks_without_numbers() {
        // Schildhieb: no number to grow, so it costs 1 less.
        let slam = CardDb::builtin().unwrap().get("slam").unwrap().upgraded();
        assert_eq!(slam.cost, 0);
        // Sammeln (cost 0, exhaust, energy): loses exhaust.
        let focus = card(r#"{"energy":1,"exhaust":true}"#, 0).upgraded();
        assert!(!focus.effects.exhaust);
        assert_eq!(focus.effects.energy, 1);
        // Cost 0 without exhaust but with energy: +1 energy.
        assert_eq!(card(r#"{"energy":2}"#, 0).upgraded().effects.energy, 3);
    }

    #[test]
    fn instance_resolves_with_upgrade() {
        let db = CardDb::builtin().unwrap();
        let mut c = CardInstance::new("strike");
        assert_eq!(c.resolve(&db).unwrap().effects.damage, 6);
        c.upgraded = true;
        assert_eq!(c.resolve(&db).unwrap().effects.damage, 9);
        assert!(CardInstance::new("nope").resolve(&db).is_none());
    }

    #[test]
    fn builtin_strike_matches_prototype() {
        let db = CardDb::builtin().unwrap();
        let strike = db.get("strike").expect("strike exists");
        assert_eq!(strike.name, "Schlag");
        assert_eq!(strike.kind, CardKind::Attack);
        assert_eq!(strike.cost, 1);
        assert_eq!(strike.rarity, Rarity::Starter);
        assert_eq!(strike.tags, vec![Tag::Slash]);
        assert_eq!(strike.effects.damage, 6);
        assert_eq!(strike.effects.block, 0);
    }

    #[test]
    fn builtin_tags_follow_konzept() {
        let db = CardDb::builtin().unwrap();
        let tags = |id: &str| db.get(id).unwrap().tags.clone();
        assert_eq!(tags("strike"), vec![Tag::Slash]);
        assert_eq!(tags("heavy"), vec![Tag::Slash]);
        assert_eq!(tags("venom"), vec![Tag::Poison, Tag::Throw]);
        assert_eq!(tags("guard"), vec![Tag::Block]);
    }

    #[test]
    fn builtin_cards_cover_every_tag() {
        let db = CardDb::builtin().unwrap();
        for tag in Tag::ALL {
            assert!(
                db.cards().iter().any(|c| c.has_tag(tag)),
                "no card with tag {tag:?}"
            );
        }
    }

    #[test]
    fn get_unknown_id_is_none() {
        assert!(CardDb::builtin().unwrap().get("does_not_exist").is_none());
    }

    #[test]
    fn missing_effects_default_to_zero() {
        let db = load_one(
            r#"{"id":"x","name":"X","kind":"skill","cost":0,"rarity":"common","tags":["draw"]}"#,
        )
        .unwrap();
        assert_eq!(db.get("x").unwrap().effects, Effects::default());
    }

    #[test]
    fn malformed_json_is_rejected() {
        assert!(matches!(
            CardDb::from_json("[{"),
            Err(CardLoadError::Json(_))
        ));
    }

    #[test]
    fn unknown_tag_is_rejected() {
        let r = load_one(
            r#"{"id":"x","name":"X","kind":"attack","cost":1,"rarity":"common","tags":["fire"]}"#,
        );
        assert!(matches!(r, Err(CardLoadError::Json(_))));
    }

    #[test]
    fn unknown_effect_field_is_rejected() {
        // Catches typos and prototype short names such as "dmg".
        let r = load_one(
            r#"{"id":"x","name":"X","kind":"attack","cost":1,"rarity":"common","tags":["slash"],"effects":{"dmg":6}}"#,
        );
        assert!(matches!(r, Err(CardLoadError::Json(_))));
    }

    #[test]
    fn duplicate_id_is_rejected() {
        let card =
            r#"{"id":"x","name":"X","kind":"attack","cost":1,"rarity":"common","tags":["slash"]}"#;
        let r = CardDb::from_json(&format!("[{card},{card}]"));
        assert!(matches!(r, Err(CardLoadError::DuplicateId(id)) if id == "x"));
    }

    #[test]
    fn more_than_two_tags_is_rejected() {
        let r = load_one(
            r#"{"id":"x","name":"X","kind":"attack","cost":1,"rarity":"common","tags":["slash","poison","area"]}"#,
        );
        assert!(matches!(r, Err(CardLoadError::InvalidTags { .. })));
    }

    #[test]
    fn duplicate_tag_is_rejected() {
        let r = load_one(
            r#"{"id":"x","name":"X","kind":"attack","cost":1,"rarity":"common","tags":["slash","slash"]}"#,
        );
        assert!(matches!(r, Err(CardLoadError::InvalidTags { .. })));
    }

    #[test]
    fn untagged_card_is_rejected_unless_status() {
        let attack = load_one(
            r#"{"id":"x","name":"X","kind":"attack","cost":1,"rarity":"common","tags":[]}"#,
        );
        assert!(matches!(attack, Err(CardLoadError::InvalidTags { .. })));

        let junk = load_one(
            r#"{"id":"curse","name":"Last","kind":"status","cost":0,"rarity":"junk","tags":[],"effects":{"unplayable":true}}"#,
        );
        assert!(junk.is_ok());
    }

    #[test]
    fn empty_name_is_rejected() {
        let r = load_one(
            r#"{"id":"x","name":" ","kind":"attack","cost":1,"rarity":"common","tags":["slash"]}"#,
        );
        assert!(matches!(
            r,
            Err(CardLoadError::EmptyField { field: "name", .. })
        ));
    }

    #[test]
    fn serde_roundtrip_keeps_cards_equal() {
        let db = CardDb::builtin().unwrap();
        let json = serde_json::to_string(db.cards()).unwrap();
        assert_eq!(CardDb::from_json(&json).unwrap(), db);
    }
}
