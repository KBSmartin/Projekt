# Verlorene Lande

Deckbuilder-Roguelike als reine Web-App (Rust + WebAssembly, statisch auf Cloudflare Pages). Karten wie in Slay the Spire, dazu Ausrüstung, die über Tags auf ganze Kartenfamilien wirkt. Konzept, Meilensteine und Entscheidungen: `KONZEPT.md`.

`prototype/index.html` ist der lauffähige JS-Prototyp (Logik zwischen `/*LOGIC_START*/` und `/*LOGIC_END*/`). Er ist die Referenz für Karten, Kampfregeln, Gegner und Relikte und wird nach Rust portiert, nicht erweitert.

## Aufbau

- `engine/`: reine Spiellogik (Zufall mit Seed, Karten, später Kampf, Ausrüstung, Karte, Turm). Baut nativ und nach `wasm32-unknown-unknown`.
- `ui/`: Leptos-Oberfläche (CSR), gebaut mit Trunk. `ui/index.html` ist der Trunk-Einstieg.
- `sim/`: natives Kommandozeilenprogramm für die Bot-Simulation.
- `data/`: Spielinhalte als JSON (per serde geladen, in die engine eingebettet). Neue Inhalte sind neue Einträge, kein neuer Code.

**Regel: engine kennt keine UI.** Keine Abhängigkeit auf leptos, web-sys, wasm-bindgen o. ä. in `engine`. Alle Zufallswürfe laufen über `engine::GameRng` (ChaCha8 mit Seed), nie über andere Zufallsquellen.

## Befehle

```
cargo test                  # alle Tests
cargo run -p sim            # Simulation (nativ)
trunk serve                 # Dev-Server, aus dem Workspace-Root
trunk build --release       # fertige Dateien in dist/
```

## Sprache

- Bezeichner und Code-Kommentare: Englisch.
- Alle Texte im Spiel (Kartennamen, Beschreibungen, Meldungen): Deutsch.

## Entscheidungen (aus KONZEPT.md)

- Nur Desktop-Browser mit Maus und Tastatur, kein Handy-Layout.
- Pixel-Art in 16 × 16 (Items, Artefakte) und 32 × 32 (Gegner, Charaktere), nur ganzzahlig skaliert (`image-rendering: pixelated`). Bis dahin Platzhalter.
- Kein Speichern, kein dauerhafter Fortschritt, keine Bestenliste.
- Schadensreihenfolge: Kartenwert + Waffenwert + Stärke, dann Tag-Multiplikatoren, dann Schwäche und Verwundbar.
- Tags: Hieb, Gift, Block, Schild, Wurf, Fläche, Ziehen (`engine::Tag`). Jede Karte trägt ein bis zwei Tags.
- Nichts aus „Nach Version 1“ bauen (Sets, Zusammenfügen, Schmieden, erweiterbarer Rucksack, Charaktere 4 und 5).
