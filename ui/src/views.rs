//! All screens. Each function renders one phase of the run from a snapshot
//! and turns clicks into engine actions via [`Game::act`].

use crate::{Game, TitlePage, data, text};
use engine::{
    Card, CardInstance, CardKind, Combat, EventResult, EventState, Phase, PickState, Rarity,
    Reward, RewardSource, Run, Shop, Statuses, needs_target,
};
use leptos::prelude::*;

/// Renders the current screen. Reads the signals, so it re-renders on changes.
pub fn screen(game: Game) -> AnyView {
    let deck_open = game.deck_open.get();
    game.run.with(|run| match run {
        None => match game.title_page.get() {
            TitlePage::Start => start_screen(game),
            TitlePage::Choose => choose_screen(game),
        },
        Some(run) => {
            let d = data();
            let color = d.regions[run.region].color.clone();
            let body = match &run.phase {
                Phase::RegionIntro => region_intro(game, run),
                Phase::Map => map_screen(game, run),
                Phase::Combat(c) => combat_screen(game, run, c),
                Phase::Reward(r) => reward_screen(game, run, r),
                Phase::Shop(s) => shop_screen(game, run, s),
                Phase::Rest => rest_screen(game, run),
                Phase::Event(e) => event_screen(game, run, e),
                Phase::Pick(p) => pick_screen(game, run, p),
                Phase::Victory | Phase::Defeat => end_screen(game, run),
            };
            let overlay = deck_open.then(|| deck_overlay(game, run));
            // Fight and map use the whole window; other screens keep the column.
            let full = matches!(run.phase, Phase::Combat(_) | Phase::Map);
            view! {
                {backdrop(&d.regions[run.region].id)}
                <main class=if full { "app full" } else { "app" } style=format!("--acc:{color}")>
                    {body}
                    {overlay}
                </main>
            }
            .into_any()
        }
    })
}

/// Pixel-art background of a region (or "title") plus its animated effect
/// layers; what each layer shows is set in the CSS per region.
fn backdrop(id: &str) -> AnyView {
    view! {
        <div class=format!("bgimg bg-{id}")></div>
        <div class=format!("fx fx-{id}") aria-hidden="true">
            <i class="l1"></i>
            <i class="l2"></i>
            <i class="l3"></i>
            <i class="l4"></i>
        </div>
    }
    .into_any()
}

/// Small 8x8 symbol in running text, shown 2x (`assets/symbole/symbole.ps1`).
pub(crate) fn icon(name: &str, alt: &'static str) -> AnyView {
    view! { <img class="ic" src=format!("assets/symbole/{name}.png") alt=alt /> }.into_any()
}

/// 16x16 picture of a relic (`assets/symbole/bilder.ps1`); the file is named
/// after the variant.
fn relic_icon(relic: engine::Relic) -> AnyView {
    let file = format!("{relic:?}").to_lowercase();
    view! { <img class="rlic" src=format!("assets/symbole/{file}.png") alt="" /> }.into_any()
}

/// 32x32 picture on events, region intros and the end screens, shown 3x.
fn picture(name: &str) -> AnyView {
    view! { <img class="pic" src=format!("assets/symbole/{name}.png") alt="" /> }.into_any()
}

/// HP with the heart, as "current/maximum".
fn hp_label(hp: i32, max: i32) -> AnyView {
    view! { {icon("leben", "LP")} {format!("{}/{}", hp.max(0), max)} }.into_any()
}

/// An amount of gold with the coin.
fn gold_label(amount: impl std::fmt::Display) -> AnyView {
    view! { {icon("gold", "Gold")} {amount.to_string()} }.into_any()
}

/// Sprite sheet prefix of a character's portrait.
pub(crate) fn hero_file(character: &str) -> &'static str {
    match character {
        "marksman" => "schuetze",
        "mage" => "magier",
        _ => "krieger",
    }
}

/// Animated 16x16 portrait, shown 8x. Re-rendered when the animation changes,
/// which restarts the CSS animation.
fn portrait(game: Game, character: &str) -> AnyView {
    let hero = hero_file(character);
    view! {
        <div class="pframe">
            {move || {
                let (anim, _) = game.portrait.get();
                let file = anim.file();
                view! {
                    <div
                        class=format!("portrait pa-{file}")
                        style=format!("background-image:url(assets/portraets/{hero}_{file}.png)")
                    ></div>
                }
            }}
        </div>
    }
    .into_any()
}

/// Static idle portrait for the character choice.
fn portrait_idle(character: &str) -> AnyView {
    let hero = hero_file(character);
    view! {
        <div
            class="portrait pa-idle"
            style=format!("background-image:url(assets/portraets/{hero}_idle.png)")
        ></div>
    }
    .into_any()
}

/// Left column on the fight and map screens: portrait with name, HP and gold,
/// and the backpack (relics for now, equipment later) with the deck button.
fn side_panel(game: Game, run: &Run, hp: i32, max_hp: i32) -> AnyView {
    const SLOTS: usize = 12;
    let d = data();
    let ch = d.character(&run.character);
    let name = ch.map_or(String::new(), |c| c.name.clone());
    let tip = ch.map_or(String::new(), |c| {
        format!("{}: {}", c.trait_name, c.trait_text)
    });
    let region = &d.regions[run.region];
    let relics: Vec<_> = run.relics.iter().filter_map(|r| d.relic(*r)).collect();
    let slots = (0..SLOTS)
        .map(|i| match relics.get(i) {
            Some(info) => view! {
                <div class="slot full" title=format!("{}: {}", info.name, info.description)>
                    {relic_icon(info.id)}
                </div>
            }
            .into_any(),
            None => view! { <div class="slot"></div> }.into_any(),
        })
        .collect_view();
    view! {
        <aside class="side">
            <div class="box pbox">
                {portrait(game, &run.character)}
                <div class="pname" title=tip>{name}</div>
                {hp_bar(hp, max_hp, false, hp_label(hp, max_hp))}
                <div class="pmeta">
                    <span>{gold_label(run.gold)}</span>
                    <span title=region.subtitle.clone()>
                        {icon(&region.id, "Gebiet")}
                        {format!("{}/{}", run.region + 1, d.regions.len())}
                    </span>
                </div>
            </div>
            <div class="box sack">
                <div class="box-h">"Rucksack"</div>
                <div class="slots">{slots}</div>
                <button class="btn ghost sm" on:click=move |_| game.deck_open.set(true)>
                    {format!("Deck ({})", run.deck.len())}
                </button>
            </div>
        </aside>
    }
    .into_any()
}

// ---------- title ----------

/// Pixel wipe over the whole window: a grid of tiles that grow (closing) or
/// shrink (opening) from left to right, the same direction as the map.
pub fn wipe(cover: crate::Cover) -> AnyView {
    const COLS: usize = 24;
    const ROWS: usize = 14;
    let class = match cover {
        crate::Cover::Off => return ().into_any(),
        crate::Cover::Closing => "wipe closing",
        crate::Cover::Opening => "wipe opening",
    };
    let tiles = (0..ROWS * COLS)
        .map(|i| {
            let (c, r) = (i % COLS, i / COLS);
            view! { <i style=format!("--d:{}ms", c * 11 + r * 6)></i> }
        })
        .collect_view();
    view! { <div class=class aria-hidden="true">{tiles}</div> }.into_any()
}

/// Start screen: title, a short teaser and the main buttons.
fn start_screen(game: Game) -> AnyView {
    let help = RwSignal::new(false);
    view! {
        {backdrop("title")}
        <main class="app">
            <div class="start">
                <img class="emblem" src="assets/logo/zeichen_64.png" alt="" />
                <div class="kicker">"Ein Deckbuilder-Roguelike · Vorab-Version"</div>
                <h1>"Verlorene Lande"</h1>
                <p class="lead">
                    "Drei Gebiete, ein Deck, das du unterwegs selbst schmiedest, und am Ende jedes Weges ein Boss."
                </p>
                <nav class="menu">
                    <button class="btn big" on:click=move |_| game.show_title(TitlePage::Choose)>
                        "Spiel starten"
                    </button>
                    <button class="btn ghost" on:click=move |_| help.update(|h| *h = !*h)>
                        {move || if help.get() { "Anleitung schließen" } else { "Anleitung" }}
                    </button>
                </nav>
                <Show when=move || help.get()>
                    <ul class="how">
                        <li>"Jede Runde: 3 Energie, 5 Karten. Gegner zeigen dir, was sie als Nächstes tun."</li>
                        <li>"Auf der Karte wählst du deinen Weg: Kämpfe, Händler, Rastplätze und Ereignisse. Was weiter voraus liegt, verbirgt der Nebel."</li>
                        <li>"Stirbst du, beginnt ein neuer Lauf. Es wird nichts gespeichert."</li>
                    </ul>
                </Show>
            </div>
        </main>
    }
    .into_any()
}

/// Character choice, its own screen after the start screen.
fn choose_screen(game: Game) -> AnyView {
    let d = data();
    let characters = d
        .characters
        .iter()
        .map(|c| {
            let id = c.id.clone();
            view! {
                <button class="char" on:click=move |_| game.start_run(&id)>
                    {portrait_idle(&c.id)}
                    <span class="char-name">{c.name.clone()}</span>
                    <span class="char-hp">{icon("leben", "")} {format!("{} LP", c.max_hp)}</span>
                    <span class="char-desc">{c.description.clone()}</span>
                    <span class="char-trait">
                        <b>{c.trait_name.clone()}</b>
                        ": "
                        {c.trait_text.clone()}
                    </span>
                    <span class="char-deck">{text::deck_summary(&c.deck, d)}</span>
                </button>
            }
        })
        .collect_view();
    view! {
        {backdrop("title")}
        <main class="app">
            <div class="title">
                <h2 class="choose-h">"Wähle dein Schicksal"</h2>
                <div class="chars">{characters}</div>
                <button class="btn ghost back" on:click=move |_| game.show_title(TitlePage::Start)>
                    "Zurück"
                </button>
            </div>
        </main>
    }
    .into_any()
}

// ---------- shared parts ----------

fn top_bar(game: Game, run: &Run, show_hp: bool) -> AnyView {
    let d = data();
    let region = &d.regions[run.region];
    let ch = d.character(&run.character);
    let ch_label = ch.map(|c| view! { {icon(&c.id, "")} {c.name.clone()} });
    let ch_tip = ch.map_or(String::new(), |c| {
        format!("{}: {}", c.trait_name, c.trait_text)
    });
    let relics = run
        .relics
        .iter()
        .filter_map(|r| d.relic(*r))
        .map(|info| {
            view! {
                <span class="relic" title=format!("{}: {}", info.name, info.description)>
                    {relic_icon(info.id)}
                </span>
            }
        })
        .collect_view();
    let hp = show_hp.then(|| view! { <span class="stat">{hp_label(run.hp, run.max_hp)}</span> });
    view! {
        <header class="bar">
            <div class="reg">
                {region.name.clone()}
                <small>
                    {format!("{} · Gebiet {} von {}", region.subtitle, run.region + 1, d.regions.len())}
                </small>
            </div>
            <div class="stats">
                <span class="stat" title=ch_tip>{ch_label}</span>
                {hp}
                <span class="stat">{gold_label(run.gold)}</span>
                <div class="relics">{relics}</div>
                <button class="btn ghost" on:click=move |_| game.deck_open.set(true)>
                    {format!("Deck ({})", run.deck.len())}
                </button>
            </div>
        </header>
    }
    .into_any()
}

fn notice(run: &Run) -> Option<AnyView> {
    let n = run.notice.as_ref()?;
    Some(view! { <p class="notice">{text::pick_outcome(n, data())}</p> }.into_any())
}

fn chips(block: i32, status: &Statuses) -> AnyView {
    let block = (block > 0).then(|| {
        view! {
            <span class="chip blkc" title="Block: hält Schaden ab">
                {icon("block", "Block")}
                {block}
            </span>
        }
    });
    let statuses = text::status_chips(status)
        .into_iter()
        .map(|(file, v, tip)| view! { <span class="chip" title=tip>{icon(file, "")} {v}</span> })
        .collect_view();
    view! { <div class="chips">{block}{statuses}</div> }.into_any()
}

fn hp_bar(hp: i32, max: i32, large: bool, label: AnyView) -> AnyView {
    let pct = f64::from(hp.max(0)) / f64::from(max.max(1)) * 100.0;
    view! {
        <div class=if large { "hp lg" } else { "hp" }>
            <i style=format!("width:{pct}%")></i>
            <b>{label}</b>
        </div>
    }
    .into_any()
}

/// Card classes: type (frame shape and colour), rarity (gem and trim) and
/// owning character (background tint).
fn card_class(card: &Card, upgraded: bool, extra: &str) -> String {
    let rarity = match card.rarity {
        Rarity::Starter => "r-start",
        Rarity::Common => "r-common",
        Rarity::Uncommon => "r-uncommon",
        Rarity::Rare => "r-rare",
        Rarity::Junk => "r-junk",
    };
    let owner = match card.character.as_deref() {
        Some("warrior") => "o-warrior",
        Some("marksman") => "o-marksman",
        Some("mage") => "o-mage",
        _ => "o-neutral",
    };
    format!(
        "card {} {rarity} {owner}{}{}",
        text::kind_class(card.kind),
        if upgraded { " up" } else { "" },
        extra
    )
}

fn rarity_name(r: Rarity) -> &'static str {
    match r {
        Rarity::Starter => "Startkarte",
        Rarity::Common => "Gewöhnlich",
        Rarity::Uncommon => "Ungewöhnlich",
        Rarity::Rare => "Selten",
        Rarity::Junk => "Last",
    }
}

fn card_inner(card: &Card, upgraded: bool, damage: i32, block: i32) -> AnyView {
    let cost = if card.effects.unplayable {
        "×".to_string()
    } else {
        card.cost.to_string()
    };
    let name = if upgraded {
        format!("{}+", card.name)
    } else {
        card.name.clone()
    };
    let tags = card
        .tags
        .iter()
        .map(|t| t.name())
        .collect::<Vec<_>>()
        .join(" · ");
    // Long names get a smaller font and may wrap in the banner.
    let name_class = if name.chars().count() > 9 {
        "cn long"
    } else {
        "cn"
    };
    let type_line = if tags.is_empty() {
        card.kind.name().to_string()
    } else {
        format!("{} · {tags}", card.kind.name())
    };
    view! {
        <span class="cost">{cost}</span>
        <span class=name_class>{name}</span>
        <span class="art">
            <img src=format!("assets/karten/{}.png", card.id) alt="" />
        </span>
        <span class="ct">{type_line}</span>
        <span class="cx">{text::card_text(card, damage, block)}</span>
        <span class="gem" title=rarity_name(card.rarity)></span>
    }
    .into_any()
}

/// A deck card outside combat, as a non-interactive tile.
fn card_tile(inst: &CardInstance, run: &Run) -> AnyView {
    let d = data();
    let Some(card) = inst.resolve(&d.cards) else {
        return view! { <div class="card">{inst.id.clone()}</div> }.into_any();
    };
    let (damage, block) = text::values_outside_combat(&card, run, d);
    view! {
        <div class=card_class(&card, inst.upgraded, "")>
            {card_inner(&card, inst.upgraded, damage, block)}
        </div>
    }
    .into_any()
}

/// A deck card outside combat as a button.
fn card_button(
    inst: &CardInstance,
    run: &Run,
    disabled: bool,
    on_click: impl Fn() + 'static,
) -> AnyView {
    let d = data();
    let Some(card) = inst.resolve(&d.cards) else {
        return view! { <div class="card">{inst.id.clone()}</div> }.into_any();
    };
    let (damage, block) = text::values_outside_combat(&card, run, d);
    view! {
        <button class=card_class(&card, inst.upgraded, "") disabled=disabled on:click=move |_| on_click()>
            {card_inner(&card, inst.upgraded, damage, block)}
        </button>
    }
    .into_any()
}

fn kind_order(kind: CardKind) -> u8 {
    match kind {
        CardKind::Attack => 0,
        CardKind::Skill => 1,
        CardKind::Power => 2,
        CardKind::Status => 3,
    }
}

/// Deck indices sorted by card type and name.
fn sorted_deck(run: &Run) -> Vec<usize> {
    let d = data();
    let key = |i: usize| {
        let c = d.cards.get(&run.deck[i].id);
        (
            c.map_or(9, |c| kind_order(c.kind)),
            text::instance_name(&run.deck[i], d),
        )
    };
    let mut idx: Vec<usize> = (0..run.deck.len()).collect();
    idx.sort_by_key(|&i| key(i));
    idx
}

fn relic_box(relic: engine::Relic, extra: Option<AnyView>) -> AnyView {
    let Some(info) = data().relic(relic) else {
        return ().into_any();
    };
    view! {
        <div class="relicgain">
            <span>{relic_icon(info.id)}</span>
            <div>
                <b>{info.name.clone()}</b>
                <br />
                {info.description.clone()}
            </div>
            {extra}
        </div>
    }
    .into_any()
}

// ---------- region intro and map ----------

fn region_intro(game: Game, run: &Run) -> AnyView {
    let r = &data().regions[run.region];
    view! {
        {top_bar(game, run, true)}
        <section class="panel">
            {picture(&format!("{}_bild", r.id))}
            <h2>{r.name.clone()}</h2>
            <p class="small">{r.subtitle.clone()}</p>
            <p class="prose">{r.intro.clone()}</p>
            <button class="btn" on:click=move |_| game.act(|r, _| r.continue_from_intro())>
                "Weiter"
            </button>
        </section>
    }
    .into_any()
}

fn map_screen(game: Game, run: &Run) -> AnyView {
    view! {
        <div class="scene map-scene">
            {side_panel(game, run, run.hp, run.max_hp)}
            <section class="field">
                {notice(run)}
                {crate::worldmap::world(game, run)}
            </section>
        </div>
    }
    .into_any()
}

// ---------- combat ----------

fn combat_screen(game: Game, run: &Run, c: &Combat) -> AnyView {
    let d = data();
    let selected = game.selected.get();
    let over = c.is_over();
    let selected_card = selected
        .and_then(|i| c.hand.get(i))
        .and_then(|x| x.resolve(&d.cards));
    let targeting = !over && selected_card.as_ref().is_some_and(needs_target);
    let alive: Vec<usize> = (0..c.enemies.len())
        .filter(|&i| !c.enemies[i].dead)
        .collect();
    let single_target = (alive.len() == 1).then(|| alive[0]);

    let enemies = c
        .enemies
        .iter()
        .enumerate()
        .map(|(i, e)| {
            let is_target = targeting && !e.dead;
            let intent = if e.dead || over {
                Vec::new()
            } else {
                text::intent_parts(e.intent(), c.intent_damage(i))
            };
            let intent = intent
                .into_iter()
                .map(|(file, t, tip)| view! { <span title=tip>{icon(file, "")} {t}</span> })
                .collect_view();
            let class = format!(
                "en{}{}",
                if e.dead { " dead" } else { "" },
                if is_target { " tg" } else { "" }
            );
            view! {
                <div
                    class=class
                    on:click=move |_| {
                        if let (true, Some(s)) = (is_target, selected) {
                            game.act(move |r, d| r.play_card(d, s, Some(i)));
                        }
                    }
                >
                    <div class="intent">{intent}</div>
                    {enemy_sprite(game, i, &e.def, e.dead)}
                    <div class="nm">{e.def.name.clone()}</div>
                    {hp_bar(
                        e.hp,
                        e.max_hp,
                        false,
                        format!("{}/{}", e.hp.max(0), e.max_hp).into_any(),
                    )}
                    {chips(e.block, &e.status)}
                </div>
            }
        })
        .collect_view();

    let log = c
        .log
        .iter()
        .rev()
        .take(3)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .map(|entry| view! { <div>{text::log_line(entry, c)}</div> })
        .collect_view();

    let p = &c.player;
    let hint = match c.outcome {
        Some(engine::Outcome::Win) => "Sieg!",
        Some(engine::Outcome::Lose) => "Du fällst …",
        None if targeting => "Wähle ein Ziel.",
        None => "\u{a0}",
    };

    let hand = c
        .hand
        .iter()
        .enumerate()
        .filter_map(|(i, inst)| {
            let card = inst.resolve(&d.cards)?;
            let playable = c.playable_card(i, &d.cards).is_ok();
            let (damage, block) = text::values_in_combat(&card, c);
            let wants_target = needs_target(&card);
            let class = card_class(
                &card,
                inst.upgraded,
                if selected == Some(i) { " sel" } else { "" },
            );
            Some(view! {
                <button
                    class=class
                    disabled=!playable
                    on:click=move |_| {
                        if wants_target && single_target.is_none() {
                            game.selected
                                .update(|s| *s = if *s == Some(i) { None } else { Some(i) });
                        } else {
                            let t = if wants_target { single_target } else { None };
                            game.act(move |r, d| r.play_card(d, i, t));
                        }
                    }
                >
                    {card_inner(&card, inst.upgraded, damage, block)}
                </button>
            })
        })
        .collect_view();

    view! {
        <div class="scene fight-scene">
            {side_panel(game, run, p.hp, p.max_hp)}
            <section class="field">
                <div class="enemies">{enemies}</div>
                <div class="log" aria-live="polite">{log}</div>
                <p class="hint">{hint}</p>
            </section>
            <section class="box statsbox">
                <div class="statsrow">
                    <div class="orb" title="Energie">
                        {c.energy}
                        <small>{format!("/{}", c.max_energy)}</small>
                    </div>
                    <div class="mid">
                        {hp_bar(p.hp, p.max_hp, true, hp_label(p.hp, p.max_hp))}
                        {chips(p.block, &p.status)}
                    </div>
                </div>
                <div class="piles">
                    {format!("Runde {}", c.turn)}
                    <br />
                    {format!(
                        "Ziehstapel {} · Ablage {} · Verbraucht {}",
                        c.draw_pile.len(),
                        c.discard.len(),
                        c.exhaust.len(),
                    )}
                </div>
                <button class="btn" disabled=over on:click=move |_| game.act(|r, d| r.end_turn(d))>
                    "Zug beenden"
                </button>
                <details class="legend">
                    <summary>"Zeichen erklärt"</summary>
                    <ul class="signs">{text::SIGNS
                        .iter()
                        .map(|(file, t)| view! { <li>{icon(file, "")} <span>{*t}</span></li> })
                        .collect_view()}</ul>
                </details>
            </section>
            <section class="hand">{hand}</section>
        </div>
    }
    .into_any()
}

// ---------- reward, shop, rest, event, pick ----------

fn reward_screen(game: Game, run: &Run, reward: &Reward) -> AnyView {
    let d = data();
    let heading = match reward.source {
        RewardSource::Combat(_) => "Sieg".to_string(),
        RewardSource::Event(i) => d.events[i].title.clone(),
    };
    let gold =
        (reward.gold > 0).then(|| view! { <p class="gain">{format!("+{} Gold", reward.gold)}</p> });
    let relic = reward.relic.map(|r| relic_box(r, None));
    let cards = reward
        .cards
        .iter()
        .enumerate()
        .map(|(i, inst)| {
            card_button(inst, run, false, move || {
                game.act(move |r, d| r.take_reward_card(d, i))
            })
        })
        .collect_view();
    view! {
        {top_bar(game, run, true)}
        <section class="panel">
            <h2>{heading}</h2>
            {gold}
            {relic}
            <p>"Wähle eine Karte für dein Deck."</p>
            <div class="grid">{cards}</div>
            <button class="btn ghost" on:click=move |_| game.act(|r, d| r.skip_reward(d))>
                "Überspringen"
            </button>
        </section>
    }
    .into_any()
}

fn shop_screen(game: Game, run: &Run, shop: &Shop) -> AnyView {
    let items = shop
        .cards
        .iter()
        .enumerate()
        .map(|(i, item)| {
            let affordable = run.gold >= item.price;
            view! {
                <div class=if item.sold { "item sold" } else { "item" }>
                    {card_tile(&item.card, run)}
                    <button
                        class="btn ghost"
                        disabled=item.sold || !affordable
                        on:click=move |_| game.act(move |r, _| r.buy_card(i))
                    >
                        <span class=if affordable { "price" } else { "price no" }>
                            {gold_label(item.price)}
                        </span>
                    </button>
                </div>
            }
        })
        .collect_view();
    let relic = shop.relic.as_ref().map(|item| {
        let button = view! {
            <button
                class="btn ghost"
                disabled=item.sold || run.gold < item.price
                on:click=move |_| game.act(|r, _| r.buy_relic())
            >
                {if item.sold { "Verkauft".into_any() } else { gold_label(item.price) }}
            </button>
        }
        .into_any();
        relic_box(item.relic, Some(button))
    });
    let can_remove = run.can_remove_at_shop() && run.gold >= shop.remove_cost;
    view! {
        {top_bar(game, run, true)}
        {notice(run)}
        <section class="panel wide shop" class:closing=move || game.leaving_shop.get()>
            {merchant(game)}
            <div class="grid">{items}</div>
            {relic}
            <div class="row">
                <button
                    class="btn ghost"
                    disabled=!can_remove
                    on:click=move |_| game.act(|r, _| r.shop_remove())
                >
                    "Karte entfernen "
                    {gold_label(shop.remove_cost)}
                </button>
                <button
                    class="btn"
                    disabled=move || game.leaving_shop.get()
                    on:click=move |_| game.leave_shop()
                >
                    "Weiterziehen"
                </button>
            </div>
        </section>
    }
    .into_any()
}

/// Enemy in a fight: its animated sprite (shown 4x) when one exists, otherwise
/// the placeholder icon. Re-rendered when its animation changes, so a new
/// trigger restarts it.
fn enemy_sprite(game: Game, i: usize, def: &engine::EnemyDef, dead: bool) -> AnyView {
    let Some(frame) = crate::enemy_frame(&def.id) else {
        return view! { <div class="sprite">{def.icon.clone()}</div> }.into_any();
    };
    // Frames with a margin hang over the box at the sides and at the top.
    let top = if frame > 32 { 16 } else { 0 };
    let id = def.id.clone();
    let name = def.name.clone();
    view! {
        {move || {
            let (anim, _) = game
                .enemy_anim
                .with(|v| v.get(i).copied())
                .unwrap_or((crate::EnemyAnim::Idle, 0));
            let anim = if dead && anim != crate::EnemyAnim::Die {
                crate::EnemyAnim::Dead
            } else {
                anim
            };
            let file = anim.file();
            view! {
                <div
                    class=format!("esprite {}", anim.class())
                    style=format!(
                        "--f:{frame};--top:{top};background-image:url(assets/gegner/{id}_{file}.png)"
                    )
                    role="img"
                    aria-label=name.clone()
                ></div>
            }
        }}
    }
    .into_any()
}

/// The hooded merchant with his speech bubble; the sprite sheet and CSS class
/// follow [`crate::MerchantAnim`], a new trigger restarts the animation.
fn merchant(game: Game) -> AnyView {
    view! {
        <div class="merchant">
            {move || {
                let (anim, _) = game.merchant.get();
                let file = anim.file();
                view! {
                    <div
                        class=format!("mk ma-{file}")
                        style=format!("background-image:url(assets/haendler/{file}.png)")
                        role="img"
                        aria-label="Der Händler"
                    ></div>
                }
            }}
            <div class="mtalk">
                <h2>"Händler"</h2>
                {move || {
                    let line = game.merchant_line.get();
                    (!line.is_empty()).then(|| view! { <p class="bubble">{line}</p> })
                }}
            </div>
        </div>
    }
    .into_any()
}

fn rest_screen(game: Game, run: &Run) -> AnyView {
    let can_upgrade = run.can_upgrade(data());
    view! {
        {top_bar(game, run, true)}
        <section class="panel">
            {picture("rast")}
            <h2>"Rastplatz"</h2>
            <p class="small">"Ein Feuer, das noch warm ist."</p>
            <div class="row">
                <button class="btn" on:click=move |_| game.act(|r, _| r.rest_heal())>
                    {format!("Ausruhen: heile {} LP", run.rest_heal_amount())}
                </button>
                <button
                    class="btn"
                    disabled=!can_upgrade
                    on:click=move |_| game.act(|r, d| r.rest_upgrade(d))
                >
                    "Schmieden: Karte verbessern"
                </button>
            </div>
        </section>
    }
    .into_any()
}

fn event_screen(game: Game, run: &Run, state: &EventState) -> AnyView {
    let d = data();
    let ev = &d.events[state.event];
    let body = match &state.result {
        Some(result) => {
            let msg = match result {
                EventResult::Message(m) => m.clone(),
                EventResult::Picked(o) => text::pick_outcome(o, d),
            };
            view! {
                <p class="gain result">{msg}</p>
                <button class="btn" on:click=move |_| game.act(|r, d| r.leave_event(d))>
                    "Weiter"
                </button>
            }
            .into_any()
        }
        None => {
            let options = ev
                .options
                .iter()
                .enumerate()
                .map(|(i, opt)| {
                    let ok = run.requirement_met(d, &opt.requires);
                    view! {
                        <button
                            class="btn ghost"
                            disabled=!ok
                            on:click=move |_| game.act(move |r, d| r.choose_event_option(d, i))
                        >
                            {opt.label.clone()}
                        </button>
                    }
                })
                .collect_view();
            view! { <div class="opts">{options}</div> }.into_any()
        }
    };
    view! {
        {top_bar(game, run, true)}
        <section class="panel">
            {picture(&ev.id)}
            <h2>{ev.title.clone()}</h2>
            <p class="prose">{ev.text.clone()}</p>
            {body}
        </section>
    }
    .into_any()
}

fn pick_screen(game: Game, run: &Run, pick: &PickState) -> AnyView {
    let d = data();
    let cards = sorted_deck(run)
        .into_iter()
        .map(|i| {
            card_button(&run.deck[i], run, !run.pick_allowed(d, i), move || {
                game.act(move |r, d| r.pick_card(d, i))
            })
        })
        .collect_view();
    view! {
        {top_bar(game, run, true)}
        <section class="panel wide">
            <h2>{text::pick_title(pick.mode, pick.cost)}</h2>
            <div class="grid">{cards}</div>
            <button class="btn ghost" on:click=move |_| game.act(|r, _| r.cancel_pick())>
                "Zurück"
            </button>
        </section>
    }
    .into_any()
}

// ---------- end and overlay ----------

fn end_screen(game: Game, run: &Run) -> AnyView {
    let d = data();
    let won = run.phase == Phase::Victory;
    let ch = d.character(&run.character).map_or("", |c| c.name.as_str());
    let summary = if won {
        "Alle drei Gebiete bezwungen.".to_string()
    } else {
        format!("Gefallen in {}.", d.regions[run.region].name)
    };
    view! {
        {top_bar(game, run, true)}
        <section class="panel">
            {picture(if won { "sieg" } else { "grab" })}
            <h1 class="end">{if won { "Die Lande sind befreit" } else { "Dein Lauf endet hier" }}</h1>
            <p>
                {format!(
                    "{ch}: {summary} {} Orte besucht, {} Kämpfe gewonnen, {} Karten im Deck.",
                    run.stats.nodes,
                    run.stats.fights + run.stats.elites,
                    run.deck.len(),
                )}
            </p>
            <p class="small">{format!("Seed {}", run.seed)}</p>
            <button class="btn" on:click=move |_| game.to_title()>"Neuer Lauf"</button>
        </section>
    }
    .into_any()
}

fn deck_overlay(game: Game, run: &Run) -> AnyView {
    let d = data();
    let cards = sorted_deck(run)
        .into_iter()
        .map(|i| card_tile(&run.deck[i], run))
        .collect_view();
    let relics = (!run.relics.is_empty()).then(|| {
        let list = run
            .relics
            .iter()
            .filter_map(|r| d.relic(*r))
            .map(|info| {
                view! {
                    <div>
                        {relic_icon(info.id)}
                        <span>
                            <b>{info.name.clone()}</b>
                            {format!(": {}", info.description)}
                        </span>
                    </div>
                }
            })
            .collect_view();
        view! {
            <h3>"Relikte"</h3>
            <div class="rl">{list}</div>
        }
    });
    let trait_line = d.character(&run.character).map(|c| {
        view! { {icon(&c.id, "")} {format!("{} · {}: {}", c.name, c.trait_name, c.trait_text)} }
    });
    view! {
        <div class="ov" on:click=move |_| game.deck_open.set(false)>
            <div class="ovin" on:click=|ev| ev.stop_propagation()>
                <div class="row between">
                    <h2>{format!("Dein Deck ({})", run.deck.len())}</h2>
                    <button class="btn" on:click=move |_| game.deck_open.set(false)>
                        "Schließen"
                    </button>
                </div>
                <p class="small">{trait_line}</p>
                <div class="grid">{cards}</div>
                {relics}
            </div>
        </div>
    }
    .into_any()
}
