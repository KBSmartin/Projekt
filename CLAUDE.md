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
  - `haendler/haendler.ps1`: der Händler (32 × 32, schwarze Kutte, nur rote Augen in der Kapuze) mit je 8 Frames `idle`, `gruss` (beim Betreten), `abschied` (teuflisches Grinsen beim Verlassen; der Lauf geht erst nach der Animation weiter, `Game::leave_shop`). Sprüche in `ui/src/main.rs`.
  - `karte/karte.ps1`: Weltkarte: 8 × 8-Symbole je Knotenart, Boden je Gebiet (kachelbar, Draufsicht), aufrechte Deko-Sprites, Nebeltextur und Nebelballen. `karte/figuren.ps1`: Spielfigur je Held (24 × 32, aus 3D-Formen gerendert wie eine gedrechselte Schachfigur).
- Weltkarte (`ui/src/worldmap.rs`): 2,5D-Spielbrett, eine per CSS 3D gekippte Bodenebene mit Holzrahmen (`--tilt`), Knoten als runde Spielfelder, Wege gepunktet, darauf aufrecht gedrehte Sprites (`.bb`) für Deko, Nebelballen und die Spielfigur. Deko: am hinteren Brettrand ein Waldsaum bzw. Felsgrat, vorne niedriges Gebüsch (`edges`), dazwischen kleine Szenen je Gebiet (`themes`: Hain, Teich, Ruinen, Oase, Eissee, ...), die sich abwechseln. 2–3 Knoten pro Reihe (`Map::generate`, Fix gegenüber dem Prototyp). Reihen laufen von links nach rechts (`SPAN`: Brettbreite in Prozent der Ansicht, `XS`: Ausgleich für Abstände), die Kamera folgt dem Helden. Das Brett hat dicke Seitenkanten (`.bside`, `.plane::after`); die Legende klappt oben rechts auf (`Game::legend_open`). Nebel des Krieges verdeckt alles ab zwei Reihen hinter der aktuellen (`SIGHT`); reine Anzeige, die engine kennt ihn nicht. Links liegen drei nummerierte Startpunkte (`Map::starts`, `START_LANES`, `Run::choose_start`); erst nach der Wahl senkt eine Hand die Figur aufs Brett (`Game::place_start`). Ohne gewählten Start ist die ganze erste Reihe erreichbar (Bots). Klick auf ein Feld hebt die Figur an und setzt sie dorthin (`Game::walk_to`), dann folgt `choose_node`. Die Ansicht lässt sich mit der Maus ziehen (`Game::map_pan`, ein Zug zentriert wieder), das Mausrad zoomt (`Game::map_zoom`). Die Hand (`hand.png`, einfaches Pixel-Raster in `karte/hand.ps1`) kommt von links oben, ohne Arm. Der Nebel (`.fogwar`, flache Nebelfläche) bleibt auf dem Brett und blendet weich ein; das Brett hat abgerundete Ecken. Es liegt unter dem ganzen Fenster; die Seitenleiste wird nur leicht durchsichtig, wenn das Brett wirklich darunter liegt (gemessen, `HUD_EDGE`).
  - `karten/karten.ps1`: ein 8 × 8-Symbol pro Karte (`ui/assets/karten/<id>.png`, im Spiel 6-fach), von Hand als Raster mit gemeinsamer Palette. Eine neue Karte braucht dort einen Eintrag, sonst bricht das Skript ab.
  - `karten/rahmen.ps1`: 8-Bit-Pixelrahmen je Kartentyp (12 × 12, als CSS `border-image` 2-fach).
- Kartendesign im 8-Bit-Stil: Pixelrahmen je Typ (Angriff abgeschrägt, Fertigkeit gerundet, Kraft mit Goldnieten, Status angeschlagen), geditherter Hintergrund nach Klasse, Bildrahmen und Edelstein nach Seltenheit, Schrift im ganzen Spiel „Press Start 2P“ (Größen möglichst Vielfache von 8 px, Kartentexte 8 px).
- Blutung (`Statuses::bleed`, Karteneffekt `bleed`): neu, nicht aus dem Prototyp. Ein Gegner mit Blutung X verliert nach jedem eigenen Angriff X LP (Block hilft nicht); am Ende seines Zuges sinkt die Blutung um 1. Ausbluten (Schütze, selten) ist dafür ein Wurf-Angriff mit 3 Schaden und 5 Blutung statt „Gift verdoppeln“.
  - `hintergrund/{titel,wald,wueste,festung}.ps1`: eigener Hintergrund für den Startbildschirm und je Gebiet (CSS-Klasse `bg-<region-id>` bzw. `bg-title`), gemeinsame Helfer in `pixel.ps1`.
  - `hintergrund/wald.ps1` schreibt zusätzlich `fx/wald_glanz.png` (Bachglitzern, Runen, Pilze), deckungsgleich zum Bild (CSS `background-size: cover` wie `.bgimg`).
  - `hintergrund/effekte.ps1`: durchsichtige Effektebenen (Schnee, Glut, Asche, Blätter, Nebel, Glühwürmchen, Sterne, Nordlicht, Feuerschein) nach `ui/assets/hintergrund/fx/`. Welche Ebene wo und wie läuft, steht im CSS unter `.fx-<id>`; Bewegung in Schritten von einem Bildpixel.
  - `sound/sounds.ps1`: Soundeffekte, synthetisiert als kurze WAVs nach `ui/assets/sound/` (Klick, Figur heben/setzen, Bildwechsel, Karte, Münze, Treffer, Block, Heilung). Abgespielt über `ui/src/sound.rs`; welche Aktion welchen Ton auslöst, steht in `cues` (`ui/src/main.rs`). Stummschalten unten rechts, gemerkt im Browser. `sound/musik.ps1`: Titelmusik (mittelalterlich, D-Dorisch, Laute per Karplus-Strong, Blockflöte, Bordun, Rahmentrommel; synthetisiert in C# per `Add-Type`, nahtlose Schleife) nach `ui/assets/sound/titel.wav`; läuft auf Start- und Auswahlbildschirm, startet mit dem ersten Klick (Autoplay-Sperre der Browser) und blendet beim Laufstart aus (`sound::want_music`).
  - Die fertigen PNGs und WAVs in `ui/assets/` sind eingecheckt und werden von Trunk mitkopiert. Die Skripte brauchen Windows-PowerShell (System.Drawing).
- `data/`: Spielinhalte als JSON (per serde geladen, in die engine eingebettet). Neue Inhalte sind neue Einträge, kein neuer Code.

Die Portierung bleibt regeltreu zum Prototyp. Bewusste Abweichungen tragen im Code den Kommentar `Fix:`.

Der ganze Lauf ist eine Zustandsmaschine in `engine::run::Run`; die ui rendert nur `Run::phase` und ruft Aktionen auf. `Game::act` wendet eine Aktion auf eine Kopie an; wechselt dadurch der Bildschirm, läuft ein Pixel-Wischeffekt (`Game::wipe`, `views::wipe`) und der neue Stand wird unter der Abdeckung gezeigt. Vor dem Lauf gibt es Startbildschirm und Charakterauswahl (`TitlePage`). `engine::bot` spielt Läufe über dieselben Aktionen (Tests und `sim`). Balancing läuft über `engine::bot::smart` (Zugsuche mit simuliertem Gegnerzug): Ziel ist, dass die Charaktere nah beieinanderliegen und der Smart-Bot etwa die Hälfte der Läufe gewinnt. Nach Änderungen an Karten, Gegnern oder Eigenheiten `sim` laufen lassen.

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
- Gegner-Stil (in Arbeit): aus 3D-Formen gerendert und auf Pixel gerastert (Licht von oben links, Kantenlicht, Schattenwurf); Ratte: Variante „Geduckt, Kopf tief“ gewählt.
- Heldenporträts: 16 × 16, frontal, dunkle Kontur, Licht von links, je 8 Frames für Idle, Heilung, Schaden, Vergiftung. Gewählt: Krieger „Veteran“, Schütze „Elfe“, Magier „Spitzhut“.
- Kampf und Weltkarte nutzen das ganze Fenster: links Porträt und Rucksack, im Kampf unten links Werte, unten Mitte die Hand. Hintergrund pro Gebiet als Pixel-Bild (320 × 180).
- Kein Speichern, kein dauerhafter Fortschritt, keine Bestenliste.
- Schadensreihenfolge: Kartenwert + Waffenwert + Stärke, dann Tag-Multiplikatoren, dann Schwäche und Verwundbar.
- Tags: Hieb, Gift, Block, Schild, Wurf, Fläche, Ziehen, Zauber (`engine::Tag`). Jede Karte trägt ein bis zwei Tags (Statuskarten keine).
- Charaktere (ersetzen die Arbeitstitel aus KONZEPT.md): Krieger, Schütze, Magier, je mit eigenem Kartenpool, Startdeck und Eigenheit (`data/characters.json`). Dazu ein kleiner neutraler Pool. Dauerhaft mehr Energie oder Handkarten nur über Artefakte.
- Nichts aus „Nach Version 1“ bauen (Sets, Zusammenfügen, Schmieden, erweiterbarer Rucksack, Charaktere 4 und 5).
