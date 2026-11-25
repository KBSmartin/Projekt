//! Browser front end (Leptos, client-side rendering, built with Trunk).
//!
//! All game rules live in `engine`. This crate keeps the current [`Run`] in a
//! signal, renders its phase and forwards clicks as engine actions.

#[cfg(debug_assertions)]
mod debug;
mod sound;
mod text;
mod views;
mod worldmap;

use sound::Sfx;

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

/// Animation an enemy sprite plays in a fight (sheets in `ui/assets/gegner`,
/// 8 frames of 32x32 each).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum EnemyAnim {
    Idle,
    Attack,
    Hit,
}

impl EnemyAnim {
    /// Part of the sprite sheet file name and of the CSS class.
    pub fn file(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Attack => "angriff",
            Self::Hit => "treffer",
        }
    }

    /// One run through all 8 frames (CSS matches).
    fn duration(self) -> Duration {
        Duration::from_millis(match self {
            Self::Idle => 1600,
            Self::Attack => 720,
            Self::Hit => 640,
        })
    }
}

/// Enemies with a sprite sheet in `ui/assets/gegner`; the others still show
/// their placeholder icon.
pub const ENEMY_SPRITES: &[&str] = &["rat"];

/// How each enemy reacts to an action: an attack when the enemies had their
/// turn and it meant to deal damage, a hit when it lost HP otherwise.
fn enemy_reactions(old: &Run, new: &Run) -> Vec<(usize, EnemyAnim)> {
    let (Phase::Combat(a), Phase::Combat(b)) = (&old.phase, &new.phase) else {
        return Vec::new();
    };
    let enemy_turn = b.turn > a.turn;
    a.enemies
        .iter()
        .zip(&b.enemies)
        .enumerate()
        .filter_map(|(i, (ea, eb))| {
            if ea.dead || eb.dead {
                None
            } else if enemy_turn && ea.intent().damage.is_some() {
                Some((i, EnemyAnim::Attack))
            } else if eb.hp < ea.hp {
                Some((i, EnemyAnim::Hit))
            } else {
                None
            }
        })
        .collect()
}

/// How long the greeting plays before the merchant goes back to idle.
const MERCHANT_GREET: Duration = Duration::from_millis(1200);
/// How long the hero figure walks from one map node to the next (CSS matches).
const MAP_WALK: Duration = Duration::from_millis(1400);
/// The hand lowering the piece onto the start point and pulling back (CSS matches).
const PLACE_PIECE: Duration = Duration::from_millis(3000);
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

/// Pages before a run: the start screen and the character choice.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TitlePage {
    Start,
    Choose,
}

/// State of the pixel wipe between screens.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Cover {
    Off,
    /// Tiles grow until the screen is covered.
    Closing,
    /// The new screen is behind; the tiles shrink away.
    Opening,
}

/// One half of the wipe (CSS matches: tile delays plus tile animation).
const WIPE: Duration = Duration::from_millis(820);

/// Which screen a run state shows, to tell whether an action changes it.
fn screen_kind(run: Option<&Run>) -> u8 {
    match run.map(|r| &r.phase) {
        None => 0,
        Some(Phase::RegionIntro) => 1,
        Some(Phase::Map) => 2,
        Some(Phase::Combat(_)) => 3,
        Some(Phase::Reward(_)) => 4,
        Some(Phase::Shop(_)) => 5,
        Some(Phase::Rest) => 6,
        Some(Phase::Event(_)) => 7,
        Some(Phase::Pick(_)) => 8,
        Some(Phase::Victory | Phase::Defeat) => 9,
    }
}

/// Sounds for what an action changed: cards played, damage, block, healing
/// and gold. At most one of each, so a big turn does not turn into noise.
fn cues(old: &Run, new: &Run) -> Vec<Sfx> {
    let mut out = Vec::new();
    if let (Phase::Combat(a), Phase::Combat(b)) = (&old.phase, &new.phase) {
        if b.hand.len() < a.hand.len() {
            out.push(Sfx::Karte);
        }
        let foes = |c: &engine::Combat| c.enemies.iter().map(|e| e.hp.max(0)).sum::<i32>();
        if foes(b) < foes(a) || b.player.hp < a.player.hp {
            out.push(Sfx::Treffer);
        }
        if b.player.block > a.player.block {
            out.push(Sfx::Block);
        }
        if b.player.hp > a.player.hp {
            out.push(Sfx::Heilung);
        }
    } else if vitals(new).0 > vitals(old).0 {
        out.push(Sfx::Heilung);
    }
    if new.gold != old.gold {
        out.push(Sfx::Muenze);
    }
    out
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
    /// Animation per enemy of the current fight, each with a restart counter.
    pub enemy_anim: RwSignal<Vec<(EnemyAnim, u32)>>,
    /// The merchant is saying goodbye; the shop is closed for buying.
    pub leaving_shop: RwSignal<bool>,
    /// Map node the hero figure is walking to; the step happens on arrival.
    pub walking: RwSignal<Option<usize>>,
    pub title_page: RwSignal<TitlePage>,
    pub cover: RwSignal<Cover>,
    /// Map legend shown (kept across screens).
    pub legend_open: RwSignal<bool>,
    /// A hand is setting the piece onto the chosen start point.
    pub placing: RwSignal<bool>,
    /// Map view moved by the player (percent of the view width), and whether
    /// the last press was a drag (then it is not a click on a field).
    pub map_pan: RwSignal<f64>,
    pub map_dragged: RwSignal<bool>,
    /// Map zoom from the mouse wheel and the vertical shift when zoomed in
    /// (pixels); both kept across screens.
    pub map_zoom: RwSignal<f64>,
    pub map_pan_y: RwSignal<f64>,
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
            enemy_anim: RwSignal::new(Vec::new()),
            leaving_shop: RwSignal::new(false),
            walking: RwSignal::new(None),
            title_page: RwSignal::new(TitlePage::Start),
            cover: RwSignal::new(Cover::Off),
            legend_open: RwSignal::new(false),
            placing: RwSignal::new(false),
            map_pan: RwSignal::new(0.0),
            map_dragged: RwSignal::new(false),
            map_zoom: RwSignal::new(1.0),
            map_pan_y: RwSignal::new(0.0),
            finishing: RwSignal::new(false),
        }
    }

    /// Covers the screen with the pixel wipe, runs `f` while it is covered,
    /// then uncovers the new screen. During a running wipe `f` runs at once,
    /// so no state change is ever dropped.
    fn wipe(self, f: impl FnOnce() + 'static) {
        if self.cover.get_untracked() != Cover::Off {
            f();
            return;
        }
        sound::play(Sfx::Wisch);
        self.cover.set(Cover::Closing);
        set_timeout(
            move || {
                f();
                self.cover.set(Cover::Opening);
                set_timeout(move || self.cover.set(Cover::Off), WIPE);
            },
            WIPE,
        );
    }

    /// Chooses a start point: a hand sets the piece onto it, then the first
    /// fields can be chosen.
    pub fn place_start(self, index: usize) {
        if self.placing.get_untracked() {
            return;
        }
        self.map_pan.set(0.0);
        self.placing.set(true);
        self.act(move |r, _| r.choose_start(index));
        // Lifted now, the tock when the hand sets the piece down.
        sound::play(Sfx::Heben);
        set_timeout(|| sound::play(Sfx::Setzen), PLACE_PIECE * 54 / 100);
        set_timeout(move || self.placing.set(false), PLACE_PIECE);
    }

    /// Switches between start screen and character choice.
    pub fn show_title(self, page: TitlePage) {
        self.wipe(move || self.title_page.set(page));
    }

    /// The hero figure walks over the map to the chosen node, then the run
    /// enters it.
    pub fn walk_to(self, id: usize) {
        if self.walking.get_untracked().is_some() || self.placing.get_untracked() {
            return;
        }
        self.map_pan.set(0.0);
        sound::play(Sfx::Heben);
        self.walking.set(Some(id));
        set_timeout(
            move || {
                sound::play(Sfx::Setzen);
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

    /// Plays a one-shot animation on an enemy, then returns it to idle
    /// (unless a newer one replaced it).
    fn play_enemy(self, i: usize, anim: EnemyAnim) {
        let mut key = 0;
        self.enemy_anim.update(|v| {
            if v.len() <= i {
                v.resize(i + 1, (EnemyAnim::Idle, 0));
            }
            key = v[i].1.wrapping_add(1);
            v[i] = (anim, key);
        });
        set_timeout(
            move || {
                self.enemy_anim.update(|v| {
                    if v.get(i).is_some_and(|e| e.1 == key) {
                        v[i] = (EnemyAnim::Idle, key.wrapping_add(1));
                    }
                });
            },
            anim.duration(),
        );
    }

    pub fn start_run(self, character: &str) {
        // Random seed; the end screen shows it so runs can be reproduced.
        let seed = (js_sys::Math::random() * 9_007_199_254_740_992.0) as u64;
        self.start_run_with_seed(character, seed);
    }

    pub fn start_run_with_seed(self, character: &str, seed: u64) {
        match Run::new(data(), character, seed) {
            Ok(run) => self.wipe(move || {
                sound::want_music(false);
                self.selected.set(None);
                self.deck_open.set(false);
                self.play(PortraitAnim::Idle);
                self.run.set(Some(run));
            }),
            Err(e) => leptos::logging::error!("Lauf konnte nicht starten: {e}"),
        }
    }

    pub fn to_title(self) {
        self.wipe(move || {
            self.title_page.set(TitlePage::Start);
            self.run.set(None);
            sound::want_music(true);
        });
    }

    /// Runs an engine action on a copy of the run and shows the result. When
    /// it ends a fight, the fight stays visible for a moment and then moves on
    /// to the result. Input during a screen wipe is ignored.
    pub fn act(self, f: impl FnOnce(&mut Run, &GameData) -> Result<(), ActionError>) {
        if self.cover.get_untracked() != Cover::Off {
            return;
        }
        self.selected.set(None);
        let Some(mut next) = self.run.get_untracked() else {
            return;
        };
        if let Err(e) = f(&mut next, data()) {
            leptos::logging::warn!("Aktion abgelehnt: {e}");
            return;
        }
        self.commit(next);
    }

    /// Shows a new run state; when it changes the screen, behind a wipe.
    /// Not generic, so `act` and the delayed combat end can share it.
    fn commit(self, next: Run) {
        let changes =
            self.run.with_untracked(|r| screen_kind(r.as_ref())) != screen_kind(Some(&next));
        let apply = move || {
            let before = self.vitals();
            let was_shop = self.in_shop();
            let heard = self
                .run
                .with_untracked(|old| old.as_ref().map(|o| cues(o, &next)));
            let foes = self
                .run
                .with_untracked(|old| old.as_ref().map(|o| enemy_reactions(o, &next)));
            let new_fight = matches!(next.phase, Phase::Combat(_))
                && !self.run.with_untracked(|old| {
                    matches!(old.as_ref().map(|o| &o.phase), Some(Phase::Combat(_)))
                });
            if new_fight {
                self.enemy_anim.set(Vec::new());
            }
            self.run.set(Some(next));
            for cue in heard.into_iter().flatten() {
                sound::play(cue);
            }
            for (i, anim) in foes.into_iter().flatten() {
                self.play_enemy(i, anim);
            }
            self.react(before);
            if !was_shop && self.in_shop() {
                self.greet();
            }
            self.schedule_combat_end();
        };
        if changes {
            self.wipe(apply);
        } else {
            apply();
        }
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
                let Some(mut next) = self.run.get_untracked() else {
                    return;
                };
                match next.finish_combat(data()) {
                    Ok(()) => self.commit(next),
                    Err(e) => leptos::logging::warn!("Kampfende abgelehnt: {e}"),
                }
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
    // Every button clicks (disabled buttons get no click events at all). The
    // first click also starts the title music: browsers block audio before it.
    let on_click = |e: leptos::ev::MouseEvent| {
        sound::music_resume();
        let hit = event_target::<web_sys::Element>(&e)
            .closest("button")
            .ok()
            .flatten();
        if hit.is_some() {
            sound::play(Sfx::Klick);
        }
    };
    let muted = RwSignal::new(sound::muted());
    view! {
        <div class="root" on:click=on_click>
            {move || views::screen(game)}
            {debug}
            <button
                class="mute"
                title=move || if muted.get() { "Ton an" } else { "Ton aus" }
                aria-label=move || if muted.get() { "Ton an" } else { "Ton aus" }
                on:click=move |_| {
                    sound::set_muted(!muted.get_untracked());
                    muted.set(sound::muted());
                }
            >
                {move || if muted.get() { "🔇" } else { "🔊" }}
            </button>
            {move || views::wipe(game.cover.get())}
        </div>
    }
    .into_any()
}
