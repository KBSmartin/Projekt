//! German in-game texts built from engine data.

use engine::{
    Card, CardInstance, CardKind, Combat, GameData, LogEntry, Move, PickMode, PickOutcome, Run,
    Statuses, Who,
};

/// Rules text of a card. `damage` and `block` are the final values to show.
pub fn card_text(card: &Card, damage: i32, block: i32) -> String {
    let e = &card.effects;
    let all = if e.all_enemies { " an alle" } else { "" };
    let mut parts: Vec<String> = Vec::new();
    if e.damage > 0 {
        let hits = if e.hits > 1 {
            format!(" ×{}", e.hits)
        } else {
            String::new()
        };
        parts.push(format!("{damage} Schaden{hits}{all}."));
    }
    if e.block_damage {
        parts.push("Schaden gleich deinem Block.".into());
    }
    if block > 0 {
        parts.push(format!("{block} Block."));
    }
    if e.poison > 0 {
        parts.push(format!("{} Gift{all}.", e.poison));
    }
    if e.double_poison {
        parts.push("Verdopple das Gift des Ziels.".into());
    }
    if e.bleed > 0 {
        parts.push(format!("{} Blutung.", e.bleed));
    }
    if e.weak > 0 {
        parts.push(format!("Schwäche {}.", e.weak));
    }
    if e.vulnerable > 0 {
        parts.push(format!("Verwundbar {}.", e.vulnerable));
    }
    if e.thorns > 0 {
        parts.push(format!("{} Dornen.", e.thorns));
    }
    if e.strength > 0 {
        parts.push(format!("+{} Stärke.", e.strength));
    }
    if e.heal > 0 {
        parts.push(format!("Heile {}.", e.heal));
    }
    if e.hp_loss > 0 {
        parts.push(format!("Verliere {} LP.", e.hp_loss));
    }
    if e.draw > 0 {
        parts.push(format!("Ziehe {}.", e.draw));
    }
    if e.energy > 0 {
        parts.push(format!("+{} Energie.", e.energy));
    }
    if e.burn {
        parts.push("Unspielbar. Am Rundenende: 2 Schaden.".into());
    } else if e.unplayable {
        parts.push(if e.ethereal {
            "Unspielbar. Verflüchtigt sich.".into()
        } else {
            "Unspielbar. Belegt einen Platz.".into()
        });
    } else if e.exhaust || card.kind == CardKind::Power {
        parts.push("Verbraucht.".into());
    }
    parts.join(" ")
}

/// Card values outside combat, with the character's trait applied.
pub fn values_outside_combat(card: &Card, run: &Run, data: &GameData) -> (i32, i32) {
    let bonus = data
        .character(&run.character)
        .map(|c| c.trait_rule.combat_bonus())
        .unwrap_or_default();
    let mut damage = card.effects.damage as i32;
    if let Some((tag, n)) = bonus.tag_damage
        && card.has_tag(tag)
    {
        damage += n;
    }
    let mut block = card.effects.block as i32;
    if let Some((tag, n)) = bonus.tag_block
        && card.has_tag(tag)
    {
        block += n;
    }
    (damage, block)
}

/// Card values in combat, including strength, weak and character bonuses.
pub fn values_in_combat(card: &Card, combat: &Combat) -> (i32, i32) {
    (
        combat.card_damage(card, None),
        card.effects.block as i32 + combat.tag_block_for(card),
    )
}

pub fn kind_class(kind: CardKind) -> &'static str {
    match kind {
        CardKind::Attack => "t-a",
        CardKind::Skill => "t-s",
        CardKind::Power => "t-p",
        CardKind::Status => "t-x",
    }
}

/// Card name with "+" for upgraded cards.
pub fn instance_name(card: &CardInstance, data: &GameData) -> String {
    let name = data
        .cards
        .get(&card.id)
        .map_or(card.id.as_str(), |c| c.name.as_str());
    if card.upgraded {
        format!("{name}+")
    } else {
        name.to_string()
    }
}

pub fn pick_title(mode: PickMode, cost: u32) -> String {
    match mode {
        PickMode::Upgrade => "Wähle eine Karte zum Verbessern.".into(),
        PickMode::Remove if cost > 0 => format!("Wähle eine Karte zum Entfernen ({cost} Gold)."),
        PickMode::Remove => "Wähle eine Karte zum Entfernen.".into(),
        PickMode::Trade => "Wähle eine Karte zum Tauschen.".into(),
    }
}

pub fn pick_outcome(o: &PickOutcome, data: &GameData) -> String {
    let old = instance_name(&o.card, data);
    match (o.mode, &o.new_card) {
        (PickMode::Upgrade, _) => format!("{old} wurde verbessert."),
        (PickMode::Remove, _) => format!("{old} wurde aus dem Deck entfernt."),
        (PickMode::Trade, Some(new)) => format!("{old} wird zu {}.", instance_name(new, data)),
        (PickMode::Trade, None) => format!("{old} wurde getauscht."),
    }
}

/// (symbol, explanation) for the legend in a fight.
pub const SIGNS: &[(&str, &str)] = &[
    ("staerke", "Stärke: +1 Schaden pro Punkt bei jedem Angriff"),
    ("schwaeche", "Schwäche: 25 % weniger Schaden"),
    ("verwundbar", "Verwundbar: 50 % mehr Schaden erlitten"),
    (
        "gift",
        "Gift: verliert zu Rundenbeginn LP, dann sinkt es um 1",
    ),
    (
        "blutung",
        "Blutung: Gegner verliert nach jedem eigenen Angriff LP, sinkt jede Runde um 1",
    ),
    ("dornen", "Dornen: Angreifer erleiden Schaden"),
    ("block", "Block: hält Schaden ab, verfällt zu Rundenbeginn"),
];

/// (symbol file, value, tooltip) for each active status.
pub fn status_chips(s: &Statuses) -> Vec<(&'static str, i32, &'static str)> {
    let mut out = Vec::new();
    let mut add = |v: i32, icon, tip| {
        if v != 0 {
            out.push((icon, v, tip));
        }
    };
    add(
        s.strength,
        "staerke",
        "Stärke: +1 Schaden pro Punkt bei jedem Angriff",
    );
    add(
        s.weak as i32,
        "schwaeche",
        "Schwäche: richtet 25 % weniger Schaden an",
    );
    add(
        s.vulnerable as i32,
        "verwundbar",
        "Verwundbar: erleidet 50 % mehr Schaden",
    );
    add(
        s.poison as i32,
        "gift",
        "Gift: verliert zu Rundenbeginn LP, danach sinkt das Gift um 1",
    );
    add(
        s.bleed as i32,
        "blutung",
        "Blutung: verliert nach jedem eigenen Angriff so viele LP, danach sinkt die Blutung jede Runde um 1",
    );
    add(
        s.thorns as i32,
        "dornen",
        "Dornen: wer dich angreift, erleidet Schaden",
    );
    out
}

/// (symbol file, text, tooltip) parts of an enemy intent. `damage` is the final
/// damage per hit.
pub fn intent_parts(m: &Move, damage: Option<i32>) -> Vec<(&'static str, String, &'static str)> {
    let mut out = Vec::new();
    if let Some(d) = damage {
        let hits = if m.hits > 1 {
            format!("×{}", m.hits)
        } else {
            String::new()
        };
        out.push(("angriff", format!("{d}{hits}"), "Angriff"));
    }
    let mut add = |v: u32, file, sign, tip| {
        if v > 0 {
            out.push((file, format!("{sign}{v}"), tip));
        }
    };
    add(m.block, "block", "", "Block");
    add(m.strength, "staerke", "+", "Stärke");
    add(m.heal, "heilung", "", "Heilung");
    add(m.weak, "schwaeche", "", "Schwäche auf dich");
    add(m.vulnerable, "verwundbar", "", "Verwundbar auf dich");
    add(m.poison, "gift", "", "Gift auf dich");
    add(m.burn, "brand", "+", "Brand-Karten in dein Deck");
    add(m.frost, "frost", "+", "Frost-Karten in dein Deck");
    out
}

pub fn log_line(entry: &LogEntry, combat: &Combat) -> String {
    let name = |i: usize| {
        combat
            .enemies
            .get(i)
            .map_or("Gegner", |e| e.def.name.as_str())
            .to_string()
    };
    match *entry {
        LogEntry::EnemyAttack { enemy, hp_lost } if hp_lost > 0 => {
            format!("{} trifft dich für {hp_lost}.", name(enemy))
        }
        LogEntry::EnemyAttack { enemy, .. } => {
            format!("{} greift an, dein Block hält.", name(enemy))
        }
        LogEntry::Poison {
            who: Who::Player,
            damage,
        } => format!("Gift: {damage} Schaden."),
        LogEntry::Poison {
            who: Who::Enemy(i),
            damage,
        } => format!("{} erleidet {damage} Giftschaden.", name(i)),
        LogEntry::Burn { hp_lost } => format!("Brand: {hp_lost} Schaden."),
        LogEntry::Thorns { enemy, damage } => {
            format!("Dornen treffen {} für {damage}.", name(enemy))
        }
        LogEntry::Bleed { enemy, damage } => {
            format!("{} blutet und verliert {damage}.", name(enemy))
        }
        LogEntry::EnemyDied { enemy } => format!("{} fällt.", name(enemy)),
    }
}

/// Short summary of a starting deck, e.g. "5× Schlag, 4× Block, 1× Schildstoß".
pub fn deck_summary(ids: &[String], data: &GameData) -> String {
    let mut counts: Vec<(&str, usize)> = Vec::new();
    for id in ids {
        let name = data.cards.get(id).map_or(id.as_str(), |c| c.name.as_str());
        match counts.iter_mut().find(|(n, _)| *n == name) {
            Some((_, c)) => *c += 1,
            None => counts.push((name, 1)),
        }
    }
    counts
        .iter()
        .map(|(n, c)| format!("{c}× {n}"))
        .collect::<Vec<_>>()
        .join(", ")
}
