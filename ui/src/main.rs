//! Browser front end (Leptos, client-side rendering, built with Trunk).
//!
//! All game rules live in `engine`. This crate keeps the current [`Run`] in a
//! signal, renders its phase and forwards clicks as engine actions.

#[cfg(debug_assertions)]
mod debug;
mod text;
mod views;

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

/// UI state shared by all screens.
#[derive(Clone, Copy)]
pub struct Game {
    /// `None` shows the title and character selection.
    pub run: RwSignal<Option<Run>>,
    /// Hand card waiting for a target.
    pub selected: RwSignal<Option<usize>>,
    pub deck_open: RwSignal<bool>,
    finishing: RwSignal<bool>,
}

impl Game {
    fn new() -> Self {
        Self {
            run: RwSignal::new(None),
            selected: RwSignal::new(None),
            deck_open: RwSignal::new(false),
            finishing: RwSignal::new(false),
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
        self.run.update(|run| {
            if let Some(run) = run
                && let Err(e) = f(run, data())
            {
                leptos::logging::warn!("Aktion abgelehnt: {e}");
            }
        });
        self.schedule_combat_end();
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
                self.run.update(|run| {
                    if let Some(run) = run
                        && let Err(e) = run.finish_combat(data())
                    {
                        leptos::logging::warn!("Kampfende abgelehnt: {e}");
                    }
                });
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
