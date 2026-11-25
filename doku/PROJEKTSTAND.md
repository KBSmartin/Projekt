# Verlorene Lande: Projektstand

Stand: 19. November 2026

Verlorene Lande ist ein Deckbuilder-Roguelike im Stil von Slay the Spire. Ausrüstung soll über Tags auf ganze Kartenfamilien wirken. Das Spiel läuft als reine Web-App im Browser: Rust, nach WebAssembly gebaut, später statisch auf Cloudflare Pages.

Ein kompletter Lauf ist heute spielbar: Startbildschirm, Charakterwahl, Weltkarte, Kämpfe, Belohnungen, Händler, Rast, Ereignisse und Bosse über drei Gebiete. Das Ausrüstungssystem, die Kernidee aus `KONZEPT.md`, fehlt noch.

## Kurzüberblick

| Bereich | Stand |
| --- | --- |
| Spiellogik (engine) | Fertig für den Lauf ohne Ausrüstung, mit 118 Tests |
| Inhalte | 49 Karten, 3 Charaktere, 15 Gegner, 3 Gebiete, 6 Relikte, 6 Ereignisse |
| Oberfläche | Vollständig spielbar, Pixel-Art-Stil, Übergänge, Sound, Titelmusik |
| Balancing | Smart-Bot gewinnt: Krieger 51,7 %, Schütze 60,3 %, Magier 68,0 % |
| Ausrüstung, Inventar, Items | Noch nicht begonnen (nur `DamageMods` als Andockpunkt) |
| Endlos-Turm | Noch nicht begonnen |
| Veröffentlichung | Standalone-EXE vorhanden, Cloudflare-Deployment fehlt |

## Technik

- **Sprache und Ziel:** Rust 1.100, kompiliert nach `wasm32-unknown-unknown`.
- **Oberfläche:** Leptos 0.8 im CSR-Modus, gebaut und ausgeliefert mit Trunk 0.22.
- **Zufall:** Alle Würfe laufen über `engine::GameRng` (ChaCha8 mit Seed). Läufe sind damit reproduzierbar.
- **Inhalte:** JSON-Dateien in `data/`, per serde geladen und in die engine eingebettet. Neue Karten, Gegner oder Relikte sind neue Einträge, kein neuer Code.
- **Grafik und Ton:** werden per PowerShell-Skript erzeugt (System.Drawing für PNGs, C# per `Add-Type` für WAVs). Die fertigen Dateien liegen eingecheckt in `ui/assets/`.

### Aufbau des Workspace

| Ordner | Inhalt |
| --- | --- |
| `engine/` | Reine Spiellogik ohne UI-Abhängigkeit: Karten, Kampf, Gegner, Relikte, Karte, Lauf, Bots |
| `ui/` | Leptos-Oberfläche: Bildschirme, Weltkarte, Sound, Debug-Panel |
| `sim/` | Kommandozeilenprogramm für Bot-Simulationen (Balancing) |
| `launcher/` | Standalone-Startprogramm: kleiner Webserver, der den eingebetteten Build ausliefert und den Browser öffnet |
| `data/` | Spielinhalte als JSON |
| `assets/` | Quellskripte für alle Grafiken und Töne, `assets/bauen.ps1` erzeugt alles neu |
| `prototype/` | Der ursprüngliche JS-Prototyp, Referenz für die Regeln |
| `doku/` | Diese Dokumentation und die To-do-Liste |

### Wichtige Regeln im Code

- Die engine kennt keine UI: keine Abhängigkeit auf leptos, web-sys oder wasm-bindgen.
- Die Portierung bleibt regeltreu zum Prototyp. Bewusste Abweichungen tragen den Kommentar `Fix:`.
- Bezeichner und Kommentare sind englisch, alle Texte im Spiel deutsch.
- Nach Änderungen an Karten, Gegnern oder Eigenheiten läuft `sim`.

## Spiellogik (engine)

Der ganze Lauf ist eine Zustandsmaschine in `engine::run::Run`. Die Oberfläche zeigt nur `Run::phase` an und ruft Aktionen auf. Bots und Tests spielen über dieselben Aktionen.

- **Kampf** (`combat.rs`): 3 Energie, 5 Handkarten, sichtbare Gegner-Absichten. Status wie Stärke, Schwäche, Verwundbar, Gift und Blutung. Die Schadensreihenfolge ist festgelegt: Kartenwert plus Waffenwert plus Stärke, dann Tag-Multiplikatoren, dann Schwäche und Verwundbar.
- **Blutung** ist neu gegenüber dem Prototyp. Ein Gegner mit Blutung X verliert nach jedem eigenen Angriff X LP, Block hilft nicht. Am Ende seines Zuges sinkt die Blutung um 1.
- **Karten** (`card.rs`): Typen Angriff, Fertigkeit, Kraft und Status. Tags: Hieb, Gift, Block, Schild, Wurf, Fläche, Ziehen, Zauber. Jede Karte trägt ein bis zwei Tags, Statuskarten keine. Karten lassen sich verbessern.
- **Charaktere:** Krieger, Schütze und Magier, je mit Kartenpool, Startdeck und Eigenheit. Dazu ein kleiner neutraler Pool.
- **Karte** (`map.rs`): zufällig erzeugte Wege. Die erste Reihe hat 3 Knoten, die übrigen 2 bis 3, die letzte 2. Drei feste Startpunkte (`START_LANES`). Knotenarten: Kampf, Elite, Ereignis, Rast, Händler, Boss.
- **Gebiete:** Düsterwald, Aschewüste, Frostfestung. Gegnerwerte wachsen mit der Gebietsnummer um den Faktor 1,2.
- **Bots** (`bot.rs`, `bot/smart.rs`): ein einfacher Bot und ein Smart-Bot mit Zugsuche und simuliertem Gegnerzug. Ziel fürs Balancing: Die Charaktere liegen nah beieinander, und der Smart-Bot gewinnt etwa die Hälfte der Läufe.
- **Debug-Aktionen** (`run/debug.rs`): nur für das Debug-Panel, Bots rufen sie nie auf.

## Oberfläche (ui)

### Bildschirme und Abläufe

- **Startbildschirm** mit eigenem Hintergrund und Titelmusik, danach die Charakterwahl „Wähle dein Schicksal“.
- **Übergänge:** Bei jedem Bildschirmwechsel deckt ein Pixel-Wischeffekt das Bild ab (`Game::wipe`). Der neue Stand erscheint unter der Abdeckung.
- **Kampf und Karte** nutzen das ganze Fenster: links Porträt und Rucksack, im Kampf unten links die Werte, unten in der Mitte die Hand.
- **Händler:** schwarze Kutte, nur rote Augen. Er begrüßt den Abenteurer beim Betreten und verabschiedet ihn mit teuflischem Grinsen. Der Lauf geht erst nach der Abschiedsanimation weiter.
- **Debug-Panel:** nur in Debug-Builds (`cfg(debug_assertions)`).

### Weltkarte (`ui/src/worldmap.rs`)

- 2,5D-Spielbrett: eine per CSS 3D gekippte Bodenebene mit Holzrahmen, dicken Seitenkanten und abgerundeten Ecken.
- Knoten als runde Spielfelder mit 8 × 8-Symbolen, Wege gepunktet. Nicht wählbare Wege sind blass.
- Deko je Gebiet: Waldsaum oder Felsgrat hinten, Gebüsch vorne, dazwischen wechselnde Szenen wie Hain, Teich, Ruinen, Oase oder Eissee.
- Spielfigur je Held als gedrechselte Schachfigur. Nach der Wahl eines der drei Startpunkte setzt eine Hand die Figur aufs Brett. Ein Klick auf ein Feld hebt die Figur an und setzt sie dort ab.
- Nebel des Krieges verdeckt alles ab zwei Reihen hinter der aktuellen. Er ist reine Anzeige, die engine kennt ihn nicht.
- Ziehen mit der Maus verschiebt die Ansicht, das Mausrad zoomt. Die Seitenleiste wird leicht durchsichtig, wenn das Brett darunter liegt.
- Legende zum Aufklappen oben rechts.

### Grafik

- Durchgehender 8-Bit-Stil, Schrift „Press Start 2P“, nur ganzzahlig skaliert.
- Ein 8 × 8-Symbol pro Karte, Pixelrahmen je Kartentyp, Edelstein nach Seltenheit.
- Heldenporträts 16 × 16 mit je 8 Frames für Idle, Heilung, Schaden und Vergiftung.
- Ein eigenes Hintergrundbild für Titel und jedes Gebiet (320 × 180), dazu animierte Effektebenen wie Schnee, Glut, Nebel, Glühwürmchen oder Nordlicht.
- Gegner werden aus 3D-Formen gerendert und auf Pixel gerastert (`assets/gegner/`). Die Waldratte ist fertig: gebeugt hockend, 32 × 32, im Kampf 4-fach, mit je 8 Frames für Ruhe, Angriff (Ausholen und Zubeißen, wenn der Gegnerzug Schaden vorsah) und Treffer (Zurückweichen mit kurzem Aufblitzen). `assets/pruefen.ps1` prüft die Blätter. Die übrigen 14 Gegner zeigen noch Emoji-Platzhalter.

### Ton

- **Soundeffekte** (`assets/sound/sounds.ps1`, `ui/src/sound.rs`): Klick, Figur heben und setzen, Bildwechsel, Karte, Münze, Treffer, Block, Heilung. Welche Aktion welchen Ton auslöst, steht in `cues` in `ui/src/main.rs`.
- **Titelmusik** (`assets/sound/musik.ps1`): mittelalterlich, D-Dorisch im 3/4-Takt mit 96 bpm, etwa 64 Sekunden als nahtlose Schleife. Laute, Blockflöte, Bordun und Rahmentrommel. Sie startet mit dem ersten Klick, weil Browser Autoplay sperren, und blendet beim Laufstart aus.
- **Stummschalter** unten rechts, der Zustand wird im Browser gemerkt.

## Bauen und Starten

```
cargo test                  # alle Tests
cargo run --release -p sim  # Simulation: Smart-Bot, 300 Läufe je Charakter
trunk serve                 # Dev-Server auf http://127.0.0.1:8080
trunk build --release       # fertige Dateien in dist/
.\build.ps1                 # Standalone: out/Verlorene-Lande.exe und Debug-Version
.\assets\bauen.ps1          # alle Grafiken und Töne neu erzeugen
```

Voraussetzungen: Rust mit dem Ziel `wasm32-unknown-unknown`, Trunk, für die Asset-Skripte Windows-PowerShell 5.1.

## Nicht im Repository

- `target/`, `dist/` und `out/` sind Build-Ausgaben und stehen in `.gitignore`.
- `assets/probe/` enthält Versuche (zum Beispiel die Rattenvarianten) und ist bewusst nicht eingecheckt.

## Weiterführend

- `KONZEPT.md`: Vision, Systeme, Meilensteine und offene Fragen.
- `CLAUDE.md`: Arbeitsregeln und technische Details für die Entwicklung.
- `doku/TODO.md`: was als Nächstes ansteht.
