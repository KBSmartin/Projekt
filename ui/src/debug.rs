//! Debug panel, only in debug builds (`trunk serve`, `trunk build` without
//! `--release`). Cheats go through the engine's `debug_*` actions.

use crate::{Game, data};
use engine::Phase;
use leptos::prelude::*;

pub fn panel(game: Game) -> impl IntoView {
    let open = RwSignal::new(false);
    let card = RwSignal::new(String::new());
    let relic = RwSignal::new(0usize);
    let seed = RwSignal::new(String::new());
    let character = RwSignal::new(data().characters[0].id.clone());

    let card_options = data()
        .cards
        .cards()
        .iter()
        .filter(|c| !c.id.is_empty())
        .map(|c| {
            let label = match &c.character {
                Some(ch) => format!("{} ({ch})", c.name),
                None => c.name.clone(),
            };
            view! { <option value=c.id.clone()>{label}</option> }
        })
        .collect_view();
    let relic_options = data()
        .relics
        .iter()
        .enumerate()
        .map(|(i, r)| view! { <option value=i.to_string()>{r.name.clone()}</option> })
        .collect_view();
    let char_options = data()
        .characters
        .iter()
        .map(|c| view! { <option value=c.id.clone()>{c.name.clone()}</option> })
        .collect_view();
    if let Some(first) = data().cards.cards().first() {
        card.set(first.id.clone());
    }

    let info = move || {
        game.run.with(|run| match run {
            None => "kein Lauf".to_string(),
            Some(r) => {
                let phase = match &r.phase {
                    Phase::RegionIntro => "Gebiet",
                    Phase::Map => "Karte",
                    Phase::Combat(_) => "Kampf",
                    Phase::Reward(_) => "Belohnung",
                    Phase::Shop(_) => "Händler",
                    Phase::Rest => "Rast",
                    Phase::Event(_) => "Ereignis",
                    Phase::Pick(_) => "Kartenwahl",
                    Phase::Victory => "Sieg",
                    Phase::Defeat => "Niederlage",
                };
                format!(
                    "Seed {} · {} · Gebiet {} · {} LP · {} Gold · Deck {}",
                    r.seed,
                    phase,
                    r.region + 1,
                    r.hp,
                    r.gold,
                    r.deck.len()
                )
            }
        })
    };

    view! {
        <div class="debug" class:open=move || open.get()>
            <button class="debug-toggle" on:click=move |_| open.update(|o| *o = !*o)>
                "🐞 Debug"
            </button>
            <Show when=move || open.get()>
                <div class="debug-body">
                    <div class="debug-info">{info}</div>
                    <div class="debug-row">
                        <button on:click=move |_| game.act(|r, _| r.debug_win_combat())>
                            "Kampf gewinnen"
                        </button>
                        <button on:click=move |_| game.act(|r, _| r.debug_heal())>"Heilen"</button>
                        <button on:click=move |_| game.act(|r, _| r.debug_gold(100))>"+100 Gold"</button>
                        <button on:click=move |_| game.act(|r, _| r.debug_energy(3))>"+3 Energie"</button>
                    </div>
                    <div class="debug-row">
                        <select on:change=move |ev| card.set(event_target_value(&ev))>
                            {card_options.clone()}
                        </select>
                        <button on:click=move |_| {
                            let id = card.get_untracked();
                            game.act(move |r, d| r.debug_add_card(d, &id));
                        }>"Karte ins Deck"</button>
                    </div>
                    <div class="debug-row">
                        <select on:change=move |ev| {
                            relic.set(event_target_value(&ev).parse().unwrap_or(0))
                        }>{relic_options.clone()}</select>
                        <button on:click=move |_| {
                            let i = relic.get_untracked();
                            game.act(move |r, d| r.debug_add_relic(d.relics[i].id));
                        }>"Artefakt nehmen"</button>
                    </div>
                    <div class="debug-row">
                        <select on:change=move |ev| character.set(event_target_value(&ev))>
                            {char_options.clone()}
                        </select>
                        <input
                            placeholder="Seed"
                            prop:value=move || seed.get()
                            on:input=move |ev| seed.set(event_target_value(&ev))
                        />
                        <button on:click=move |_| {
                            match seed.get_untracked().trim().parse::<u64>() {
                                Ok(s) => game.start_run_with_seed(&character.get_untracked(), s),
                                Err(_) => leptos::logging::warn!("Seed ist keine Zahl"),
                            }
                        }>"Lauf mit Seed"</button>
                    </div>
                </div>
            </Show>
        </div>
    }
}
