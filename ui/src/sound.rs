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
