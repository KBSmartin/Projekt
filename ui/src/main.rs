//! Browser front end (Leptos, client-side rendering, built with Trunk).
//!
//! All game rules live in `engine`. This crate keeps the current [`Run`] in a
//! signal, renders its phase and forwards clicks as engine actions.

#[cfg(debug_assertions)]
mod debug;
mod text;
mod views;
mod worldmap;

use engine::{ActionError, GameData, Phase, Run};
use leptos::prelude::*;
use std::sync::OnceLock;
use std::time::Duration;

/// How long a finished fight stays visible before the reward screen.
const COMBAT_END_DELAY: Duration = Duration::from_millis(900);

static DATA: OnceLock<Result<GameData, String>> = OnceLock::new();

/// The game data. Only called after [`App`] checked that loading worked.
pub fn data() -> &'static GameData {
    match DATA.get() {
        Some(Ok(d)) => d,
        _ => unreachable!("App renders an error screen when data is missing"),
    }
}

fn main() {
    // Show Rust panics as readable messages in the browser console.
    console_error_panic_hook::set_once();
    let _ = DATA.set(GameData::builtin().map_err(|e| e.to_string()));
    leptos::mount::mount_to_body(App);
}

/// Animation the hero portrait plays (sprite sheets in `ui/assets/portraets`).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum PortraitAnim {
    Idle,
    Heal,
    Hit,
    Poison,
}

impl PortraitAnim {
    /// Part of the sprite sheet file name and of the CSS class.
    pub fn file(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Heal => "heilung",
            Self::Hit => "schaden",
            Self::Poison => "gift",
        }
    }

    /// One run through all 8 frames.
    fn duration(self) -> Duration {
        Duration::from_millis(match self {
            Self::Idle => 1440,
            Self::Heal => 880,
            Self::Hit => 720,
            Self::Poison => 1120,
        })
    }
}

/// Animation the merchant plays in the shop (sprite sheets in `ui/assets/haendler`).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum MerchantAnim {
    Idle,
    Greet,
    Farewell,
}

impl MerchantAnim {
    /// Sprite sheet file name and part of the CSS class.
    pub fn file(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Greet => "gruss",
            Self::Farewell => "abschied",
        }
    }
}

/// How long the greeting plays before the merchant goes back to idle.
const MERCHANT_GREET: Duration = Duration::from_millis(1200);
/// How long the hero figure walks from one map node to the next (CSS matches).
const MAP_WALK: Duration = Duration::from_millis(900);
/// The farewell grin plays and stays a moment before the map comes back.
const MERCHANT_FAREWELL: Duration = Duration::from_millis(2200);

const GREETINGS: [&str; 3] = [
    "Willkommen, Abenteurer … sieh dich ruhig um.",
    "Ah … ein Kunde. Tritt näher.",
    "Gold gegen Macht. Ein fairer Handel … meistens.",
];
const FAREWELLS: [&str; 3] = [
    "Wir sehen uns wieder … ganz bestimmt.",
    "Komm bald wieder … solange du noch kannst.",
    "Möge dein Gold … zu mir zurückfinden.",
];

/// Random line for flavour text only (not game logic, so not the run's RNG).
fn any_line(lines: &[&'static str]) -> &'static str {
    lines[(js_sys::Math::random() * lines.len() as f64) as usize % lines.len()]
}

/// Player HP and poison, inside a fight from the fight itself.
fn vitals(run: &Run) -> (i32, u32) {
    match &run.phase {
        Phase::Combat(c) => (c.player.hp, c.player.status.poison),
        _ => (run.hp, 0),
    }
}

/// UI state shared by all screens.
#[derive(Clone, Copy)]
pub struct Game {
    /// `None` shows the title and character selection.
    pub run: RwSignal<Option<Run>>,
    /// Hand card waiting for a target.
    pub selected: RwSignal<Option<usize>>,
    pub deck_open: RwSignal<bool>,
    /// Current portrait animation and a counter, so a new trigger restarts it.
    pub portrait: RwSignal<(PortraitAnim, u32)>,
    /// Merchant animation with a restart counter, and what he is saying.
    pub merchant: RwSignal<(MerchantAnim, u32)>,
    pub merchant_line: RwSignal<&'static str>,
    /// The merchant is saying goodbye; the shop is closed for buying.
    pub leaving_shop: RwSignal<bool>,
    /// Map node the hero figure is walking to; the step happens on arrival.
    pub walking: RwSignal<Option<usize>>,
    finishing: RwSignal<bool>,
}

impl Game {
    fn new() -> Self {
        Self {
            run: RwSignal::new(None),
            selected: RwSignal::new(None),
            deck_open: RwSignal::new(false),
            portrait: RwSignal::new((PortraitAnim::Idle, 0)),
            merchant: RwSignal::new((MerchantAnim::Idle, 0)),
            merchant_line: RwSignal::new(""),
            leaving_shop: RwSignal::new(false),
            walking: RwSignal::new(None),
            finishing: RwSignal::new(false),
        }
    }

    /// The hero figure walks over the map to the chosen node, then the run
    /// enters it.
    pub fn walk_to(self, id: usize) {
        if self.walking.get_untracked().is_some() {
            return;
        }
        self.walking.set(Some(id));
        set_timeout(
            move || {
                self.walking.set(None);
                self.act(move |r, d| r.choose_node(d, id));
            },
            MAP_WALK,
        );
    }

    fn vitals(self) -> Option<(i32, u32)> {
        self.run.with_untracked(|r| r.as_ref().map(vitals))
    }

    /// Picks the portrait reaction to an HP change: losing at most the poison
    /// the player had counts as poison, other losses as a hit, gains as healing.
    fn react(self, before: Option<(i32, u32)>) {
        let (Some((hp0, poison0)), Some((hp1, _))) = (before, self.vitals()) else {
            return;
        };
        let anim = if hp1 < hp0 {
            if poison0 > 0 && (hp0 - hp1) as u32 <= poison0 {
                PortraitAnim::Poison
            } else {
                PortraitAnim::Hit
            }
        } else if hp1 > hp0 {
            PortraitAnim::Heal
        } else {
            return;
        };
        self.play(anim);
    }

    /// Plays a one-shot animation, then returns to idle (unless replaced).
    pub fn play(self, anim: PortraitAnim) {
        let key = self.portrait.get_untracked().1.wrapping_add(1);
        self.portrait.set((anim, key));
        if anim != PortraitAnim::Idle {
            set_timeout(
                move || {
                    if self.portrait.get_untracked().1 == key {
                        self.portrait.set((PortraitAnim::Idle, key.wrapping_add(1)));
                    }
                },
                anim.duration(),
            );
        }
    }

    pub fn start_run(self, character: &str) {
        // Random seed; the end screen shows it so runs can be reproduced.
        let seed = (js_sys::Math::random() * 9_007_199_254_740_992.0) as u64;
        self.start_run_with_seed(character, seed);
    }

    pub fn start_run_with_seed(self, character: &str, seed: u64) {
        match Run::new(data(), character, seed) {
            Ok(run) => {
                self.selected.set(None);
                self.deck_open.set(false);
                self.play(PortraitAnim::Idle);
                self.run.set(Some(run));
            }
            Err(e) => leptos::logging::error!("Lauf konnte nicht starten: {e}"),
        }
    }

    pub fn to_title(self) {
        self.run.set(None);
    }

    /// Runs an engine action on the current run. When it ends a fight, the
    /// fight stays visible for a moment and then moves on to the result.
    pub fn act(self, f: impl FnOnce(&mut Run, &GameData) -> Result<(), ActionError>) {
        self.selected.set(None);
        let before = self.vitals();
        let was_shop = self.in_shop();
        self.run.update(|run| {
            if let Some(run) = run
                && let Err(e) = f(run, data())
            {
                leptos::logging::warn!("Aktion abgelehnt: {e}");
            }
        });
        self.react(before);
        if !was_shop && self.in_shop() {
            self.greet();
        }
        self.schedule_combat_end();
    }

    fn in_shop(self) -> bool {
        self.run
            .with_untracked(|r| matches!(r.as_ref().map(|r| &r.phase), Some(Phase::Shop(_))))
    }

    fn set_merchant(self, anim: MerchantAnim) -> u32 {
        let key = self.merchant.get_untracked().1.wrapping_add(1);
        self.merchant.set((anim, key));
        key
    }

    /// The merchant welcomes the adventurer, then waits.
    fn greet(self) {
        self.leaving_shop.set(false);
        self.merchant_line.set(any_line(&GREETINGS));
        let key = self.set_merchant(MerchantAnim::Greet);
        set_timeout(
            move || {
                if self.merchant.get_untracked().1 == key {
                    self.set_merchant(MerchantAnim::Idle);
                }
            },
            MERCHANT_GREET,
        );
    }

    /// Leaving the shop: the merchant grins and says goodbye, then the run
    /// moves on to the map.
    pub fn leave_shop(self) {
        if self.leaving_shop.get_untracked() {
            return;
        }
        self.leaving_shop.set(true);
        self.merchant_line.set(any_line(&FAREWELLS));
        self.set_merchant(MerchantAnim::Farewell);
        set_timeout(
            move || {
                self.leaving_shop.set(false);
                if self.in_shop() {
                    self.act(|r, _| r.leave_shop());
                }
            },
            MERCHANT_FAREWELL,
        );
    }

    /// Not generic on purpose: calling the generic `act` from here would make
    /// the compiler instantiate `act` endlessly.
    fn schedule_combat_end(self) {
        let over = self.run.with_untracked(
            |run| matches!(run.as_ref().map(|r| &r.phase), Some(Phase::Combat(c)) if c.is_over()),
        );
        if !over || self.finishing.get_untracked() {
            return;
        }
        self.finishing.set(true);
        set_timeout(
            move || {
                self.finishing.set(false);
                let before = self.vitals();
                self.run.update(|run| {
                    if let Some(run) = run
                        && let Err(e) = run.finish_combat(data())
                    {
                        leptos::logging::warn!("Kampfende abgelehnt: {e}");
                    }
                });
                self.react(before);
            },
            COMBAT_END_DELAY,
        );
    }
}

#[component]
fn App() -> impl IntoView {
    if let Some(Err(e)) = DATA.get() {
        return view! {
            <main class="app">
                <h1>"Verlorene Lande"</h1>
                <p class="error">"Spieldaten fehlerhaft: " {e.clone()}</p>
            </main>
        }
        .into_any();
    }
    let game = Game::new();
    #[cfg(debug_assertions)]
    let debug = debug::panel(game);
    #[cfg(not(debug_assertions))]
    let debug = ();
    view! {
        <div class="root">
            {move || views::screen(game)}
            {debug}
        </div>
    }
    .into_any()
}
