# Verlorene Lande

Deckbuilder-Roguelike als reine Web-App (Rust + WebAssembly, statisch auf Cloudflare Pages). Karten wie in Slay the Spire, dazu Ausrüstung, die über Tags auf ganze Kartenfamilien wirkt. Konzept, Meilensteine und Entscheidungen: `KONZEPT.md`.

`prototype/index.html` ist der lauffähige JS-Prototyp (Logik zwischen `/*LOGIC_START*/` und `/*LOGIC_END*/`). Er ist die Referenz für Karten, Kampfregeln, Gegner und Relikte und wird nach Rust portiert, nicht erweitert.

## Aufbau

- `engine/`: reine Spiellogik (Zufall mit Seed, Karten, später Kampf, Ausrüstung, Karte, Turm). Baut nativ und nach `wasm32-unknown-unknown`.
- `ui/`: Leptos-Oberfläche (CSR), gebaut mit Trunk. `ui/index.html` ist der Trunk-Einstieg.
- `sim/`: natives Kommandozeilenprogramm für die Bot-Simulation.
- `launcher/`: Standalone-Startprogramm (siehe Befehle).
- `assets/`: Quellen der Grafiken, `assets/bauen.ps1` erzeugt alle neu und kopiert sie nach `ui/assets/`.
  - `portraets/basis/*.txt`: Porträts als Textraster (ein Zeichen pro Pixel, Palette im Kopf); `portraets/animationen.ps1` baut daraus die Spritesheets (Frames nebeneinander).
  - `karten/karten.ps1`: ein 8 × 8-Symbol pro Karte (`ui/assets/karten/<id>.png`, im Spiel 6-fach), von Hand als Raster mit gemeinsamer Palette. Eine neue Karte braucht dort einen Eintrag, sonst bricht das Skript ab.
- Kartendesign (CSS): Rahmenform und Farbe nach Typ (Angriff abgeschrägte Ecken, Fertigkeit rund, Kraft Bogen, Status gestrichelt), Hintergrundtönung nach Klasse, Rahmen und Edelstein nach Seltenheit.
  - `hintergrund/{wald,wueste,festung}.ps1`: ein Hintergrund pro Gebiet (CSS-Klasse `bg-<region-id>`), gemeinsame Helfer in `pixel.ps1`.
  - Die fertigen PNGs in `ui/assets/` sind eingecheckt und werden von Trunk mitkopiert. Die Skripte brauchen Windows-PowerShell (System.Drawing).
- `data/`: Spielinhalte als JSON (per serde geladen, in die engine eingebettet). Neue Inhalte sind neue Einträge, kein neuer Code.

Die Portierung bleibt regeltreu zum Prototyp. Bewusste Abweichungen tragen im Code den Kommentar `Fix:`.

Der ganze Lauf ist eine Zustandsmaschine in `engine::run::Run`; die ui rendert nur `Run::phase` und ruft Aktionen auf. `engine::bot` spielt Läufe über dieselben Aktionen (Tests und `sim`). Balancing läuft über `engine::bot::smart` (Zugsuche mit simuliertem Gegnerzug): Ziel ist, dass die Charaktere nah beieinanderliegen und der Smart-Bot etwa die Hälfte der Läufe gewinnt. Nach Änderungen an Karten, Gegnern oder Eigenheiten `sim` laufen lassen.

**Regel: engine kennt keine UI.** Keine Abhängigkeit auf leptos, web-sys, wasm-bindgen o. ä. in `engine`. Alle Zufallswürfe laufen über `engine::GameRng` (ChaCha8 mit Seed), nie über andere Zufallsquellen.

## Befehle

```
cargo test                  # alle Tests
cargo run --release -p sim  # Simulation: Smart-Bot, 300 Läufe je Charakter
cargo run --release -p sim -- --bot naive --runs 500 --seed 1000
trunk serve                 # Dev-Server, aus dem Workspace-Root
trunk build --release       # fertige Dateien in dist/
.\build.ps1                 # Standalone: out/Verlorene-Lande.exe und out/Verlorene-Lande-Debug.exe
.\build.ps1 -Only debug     # nur die Debug-Version
```

`launcher/` ist das Startprogramm: ein kleiner Webserver nur mit std, der den Trunk-Build (per `build.rs` eingebettet, `VL_WEB_DIR`) auf 127.0.0.1 ausliefert und den Browser öffnet. Debug-Builds (`trunk serve`, `trunk build` ohne `--release`) zeigen ein Debug-Panel (`ui/src/debug.rs`, `cfg(debug_assertions)`), das die `Run::debug_*`-Aktionen aus `engine/src/run/debug.rs` aufruft. Bots und `sim` rufen die nie auf.

## Sprache

- Bezeichner und Code-Kommentare: Englisch.
- Alle Texte im Spiel (Kartennamen, Beschreibungen, Meldungen): Deutsch.

## Entscheidungen (aus KONZEPT.md)

- Nur Desktop-Browser mit Maus und Tastatur, kein Handy-Layout.
- Pixel-Art in 16 × 16 (Items, Artefakte) und 32 × 32 (Gegner), nur ganzzahlig skaliert (`image-rendering: pixelated`). Bis dahin Platzhalter.
- Heldenporträts: 16 × 16, frontal, dunkle Kontur, Licht von links, je 8 Frames für Idle, Heilung, Schaden, Vergiftung. Gewählt: Krieger „Veteran“, Schütze „Elfe“, Magier „Spitzhut“.
- Kampf und Weltkarte nutzen das ganze Fenster: links Porträt und Rucksack, im Kampf unten links Werte, unten Mitte die Hand. Hintergrund pro Gebiet als Pixel-Bild (320 × 180).
- Kein Speichern, kein dauerhafter Fortschritt, keine Bestenliste.
- Schadensreihenfolge: Kartenwert + Waffenwert + Stärke, dann Tag-Multiplikatoren, dann Schwäche und Verwundbar.
- Tags: Hieb, Gift, Block, Schild, Wurf, Fläche, Ziehen, Zauber (`engine::Tag`). Jede Karte trägt ein bis zwei Tags (Statuskarten keine).
- Charaktere (ersetzen die Arbeitstitel aus KONZEPT.md): Krieger, Schütze, Magier, je mit eigenem Kartenpool, Startdeck und Eigenheit (`data/characters.json`). Dazu ein kleiner neutraler Pool. Dauerhaft mehr Energie oder Handkarten nur über Artefakte.
- Nichts aus „Nach Version 1“ bauen (Sets, Zusammenfügen, Schmieden, erweiterbarer Rucksack, Charaktere 4 und 5).
