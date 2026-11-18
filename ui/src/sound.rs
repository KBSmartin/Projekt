//! Sound effects: short synthesised WAVs in `ui/assets/sound` (made by
//! `assets/sound/sounds.ps1`). Muting is remembered in the browser.

use std::cell::Cell;
use web_sys::HtmlAudioElement;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Sfx {
    /// Any button.
    Klick,
    /// The piece is lifted off the board.
    Heben,
    /// The piece is set down on a field.
    Setzen,
    /// Screen wipe.
    Wisch,
    /// A card is played.
    Karte,
    /// Gold gained or spent.
    Muenze,
    /// Someone takes damage.
    Treffer,
    /// Block gained.
    Block,
    /// HP healed.
    Heilung,
}

impl Sfx {
    fn file(self) -> &'static str {
        match self {
            Self::Klick => "klick",
            Self::Heben => "heben",
            Self::Setzen => "setzen",
            Self::Wisch => "wisch",
            Self::Karte => "karte",
            Self::Muenze => "muenze",
            Self::Treffer => "treffer",
            Self::Block => "block",
            Self::Heilung => "heilung",
        }
    }

    fn volume(self) -> f64 {
        match self {
            Self::Klick => 0.45,
            Self::Wisch | Self::Heben => 0.5,
            Self::Karte | Self::Muenze => 0.6,
            _ => 0.7,
        }
    }
}

const STORE_KEY: &str = "verlorene-lande-ton-aus";

fn storage() -> Option<web_sys::Storage> {
    web_sys::window()?.local_storage().ok()?
}

thread_local! {
    static MUTED: Cell<bool> = Cell::new(
        storage()
            .and_then(|s| s.get_item(STORE_KEY).ok().flatten())
            .is_some_and(|v| v == "1"),
    );
}

pub fn muted() -> bool {
    MUTED.with(Cell::get)
}

pub fn set_muted(on: bool) {
    MUTED.with(|c| c.set(on));
    music_mute(on);
    // Browser storage may be unavailable (private window); muting then lasts
    // for this visit only.
    if let Some(s) = storage() {
        let _ = s.set_item(STORE_KEY, if on { "1" } else { "0" });
    }
}

/// Plays a sound once. Overlapping plays are fine; each gets its own element.
pub fn play(sfx: Sfx) {
    if muted() {
        return;
    }
    if let Ok(audio) = HtmlAudioElement::new_with_src(&format!("assets/sound/{}.wav", sfx.file())) {
        audio.set_volume(sfx.volume());
        let _ = audio.play();
    }
}

// ---------- title music ----------

thread_local! {
    static MUSIC: std::cell::RefCell<Option<HtmlAudioElement>> = const { std::cell::RefCell::new(None) };
    /// The title screens want music (it may still wait for the first click,
    /// browsers only start audio after the player has interacted).
    static WANT_MUSIC: Cell<bool> = const { Cell::new(true) };
}

const MUSIC_VOLUME: f64 = 0.35;

fn music() -> Option<HtmlAudioElement> {
    MUSIC.with(|m| {
        let mut m = m.borrow_mut();
        if m.is_none() {
            let audio = HtmlAudioElement::new_with_src("assets/sound/titel.wav").ok()?;
            audio.set_loop(true);
            audio.set_volume(0.0);
            *m = Some(audio);
        }
        m.clone()
    })
}

/// Fades the music volume in small steps; optionally pauses at the end.
fn fade(audio: &HtmlAudioElement, to: f64, pause: bool) {
    const STEPS: u64 = 16;
    let from = audio.volume();
    for k in 1..=STEPS {
        let a = audio.clone();
        leptos::prelude::set_timeout(
            move || {
                a.set_volume((from + (to - from) * k as f64 / STEPS as f64).clamp(0.0, 1.0));
                if k == STEPS && pause {
                    let _ = a.pause();
                }
            },
            std::time::Duration::from_millis(k * 75),
        );
    }
}

/// Starts (or keeps) the title music when it is wanted and sound is on.
pub fn music_resume() {
    if muted() || !WANT_MUSIC.with(Cell::get) {
        return;
    }
    if let Some(audio) = music()
        && audio.paused()
    {
        let _ = audio.play();
        fade(&audio, MUSIC_VOLUME, false);
    }
}

/// The title screens are shown (true) or a run starts (false).
pub fn want_music(on: bool) {
    WANT_MUSIC.with(|w| w.set(on));
    if on {
        music_resume();
    } else if let Some(audio) = MUSIC.with(|m| m.borrow().clone())
        && !audio.paused()
    {
        fade(&audio, 0.0, true);
    }
}

fn music_mute(on: bool) {
    if on {
        if let Some(audio) = MUSIC.with(|m| m.borrow().clone()) {
            let _ = audio.pause();
        }
    } else {
        music_resume();
    }
}
