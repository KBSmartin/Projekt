//! Browser front end (Leptos, client-side rendering, built with Trunk).
//! For now it shows a single card from the engine with placeholder art.

use engine::{Card, CardDb, GameRng, Tag};
use leptos::prelude::*;

/// Card shown on the M0 test page.
const SHOWCASE_CARD: &str = "strike";

/// Native size of placeholder sprites in pixels (KONZEPT.md: 16x16 or 32x32).
const SPRITE_SIZE: u32 = 16;
/// Integer scale factor for pixel art.
const SPRITE_SCALE: u32 = 6;

fn main() {
    leptos::mount::mount_to_body(App);
}

#[component]
fn App() -> impl IntoView {
    let content = match CardDb::builtin() {
        Ok(db) => match db.get(SHOWCASE_CARD) {
            Some(card) => view! { <CardView card=card.clone() /> }.into_any(),
            None => {
                view! { <p class="error">"Karte nicht gefunden: " {SHOWCASE_CARD}</p> }.into_any()
            }
        },
        Err(e) => {
            view! { <p class="error">"Kartendaten fehlerhaft: " {e.to_string()}</p> }.into_any()
        }
    };

    view! {
        <main>
            <h1>"Verlorene Lande"</h1>
            {content}
        </main>
    }
}

#[component]
fn CardView(card: Card) -> impl IntoView {
    let tags = card
        .tags
        .iter()
        .map(|t| view! { <span class="tag">{t.name()}</span> })
        .collect_view();
    let color = card.tags.first().map_or("#a89f8a", |t| tag_color(*t));

    view! {
        <article class="card">
            <header>
                <span class="cost">{card.cost}</span>
                <span class="name">{card.name.clone()}</span>
            </header>
            <div class="art">
                <Sprite seed=seed_from_str(&card.id) color=color />
            </div>
            <div class="kind">{card.kind.name()}</div>
            <p class="text">{card_text(&card)}</p>
            <footer class="tags">{tags}</footer>
        </article>
    }
}

/// Placeholder art: a mirrored 16x16 pixel pattern derived from a seed.
#[component]
fn Sprite(seed: u64, color: &'static str) -> impl IntoView {
    let mut rng = GameRng::new(seed);
    let half = SPRITE_SIZE / 2;
    let mut pixels = Vec::new();
    for y in 1..SPRITE_SIZE - 1 {
        for x in 1..half {
            if rng.range(0, 99) < 45 {
                pixels.push((x, y));
                pixels.push((SPRITE_SIZE - 1 - x, y));
            }
        }
    }
    let rects = pixels
        .into_iter()
        .map(|(x, y)| {
            view! { <rect x=x.to_string() y=y.to_string() width="1" height="1" fill=color /> }
        })
        .collect_view();
    let px = (SPRITE_SIZE * SPRITE_SCALE).to_string();

    view! {
        <svg
            class="sprite"
            viewBox=format!("0 0 {SPRITE_SIZE} {SPRITE_SIZE}")
            width=px.clone()
            height=px
            shape-rendering="crispEdges"
        >
            {rects}
        </svg>
    }
}

fn tag_color(tag: Tag) -> &'static str {
    match tag {
        Tag::Slash => "#d9a441",
        Tag::Poison => "#6fbf73",
        Tag::Block => "#7cc4f0",
        Tag::Shield => "#9fa8c7",
        Tag::Throw => "#c98a5a",
        Tag::Area => "#e8833a",
        Tag::Draw => "#b48ad9",
    }
}

/// FNV-1a hash, so every card id gets a stable sprite.
fn seed_from_str(s: &str) -> u64 {
    s.bytes().fold(0xcbf2_9ce4_8422_2325, |h, b| {
        (h ^ u64::from(b)).wrapping_mul(0x0100_0000_01b3)
    })
}

/// German rules text, ported from `cardText` in the prototype.
fn card_text(card: &Card) -> String {
    let e = &card.effects;
    let all = if e.all_enemies { " an alle" } else { "" };
    let mut parts: Vec<String> = Vec::new();
    if e.damage > 0 {
        let hits = if e.hits > 1 {
            format!(" ×{}", e.hits)
        } else {
            String::new()
        };
        parts.push(format!("{} Schaden{hits}{all}.", e.damage));
    }
    if e.block_damage {
        parts.push("Schaden gleich deinem Block.".into());
    }
    if e.block > 0 {
        parts.push(format!("{} Block.", e.block));
    }
    if e.poison > 0 {
        parts.push(format!("{} Gift{all}.", e.poison));
    }
    if e.double_poison {
        parts.push("Verdopple das Gift des Ziels.".into());
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
    } else if e.exhaust || card.kind == engine::CardKind::Power {
        parts.push("Verbraucht.".into());
    }
    parts.join(" ")
}
