# Verlorene Lande: To-do-Liste

Stand: 19. November 2026. Die Meilensteine folgen `KONZEPT.md`. Erledigtes ist abgehakt, damit der Fortschritt sichtbar bleibt.

## Als Nächstes

- [x] Ratte als echtes Gegner-Sprite im Spiel, mit Idle-, Angriffs- und Treffer-Animation (`assets/gegner/rat.ps1`)
- [ ] Gegner-Pipeline für die übrigen 14 Gegner nach demselben 3D-Stil aufbauen (Raytracer und Animationsgerüst aus `rat.ps1` in ein gemeinsames Skript ziehen)
- [ ] Gesicht der Ratte von Hand nachschärfen (Nagezähne, zweites Auge), falls gewünscht
- [ ] Magier abschwächen: Der Smart-Bot gewinnt mit ihm 68 %, Ziel sind etwa 50 % und wenig Abstand zwischen den Charakteren
- [ ] Mit M2 (Ausrüstung) beginnen

## M0 Grundlage

- [x] Git-Repo, Rust-Toolchain mit Ziel wasm32, Trunk, Workspace mit engine, ui und sim
- [x] Prototyp-Logik nach Rust portiert, Daten, Engine und Oberfläche getrennt
- [x] Repository auf GitHub
- [ ] Cloudflare-Konto einrichten und ein Test-Deployment auf Cloudflare Pages veröffentlichen
- [ ] Deploy-Weg festlegen: GitHub Actions baut mit Trunk und veröffentlicht per Wrangler

## M1 Engine aufräumen

- [x] Zufallsgenerator mit Seed, alle Zufallsaufrufe laufen darüber
- [x] Karten, Gegner, Relikte, Gebiete und Ereignisse als JSON
- [x] Kampf-Engine ohne Oberfläche testbar, Bot-Simulation als natives Programm (`sim`)
- [x] Tags für alle Karten
- [x] Gegnerwerte skalieren mit der Gebietsnummer (Faktor 1,2)
- [ ] Gebiete als frei gemischten Pool umbauen (die Reihenfolge ist noch fest)
- [ ] Gebiet Höhle anlegen, für fünf Karten pro Lauf ein weiteres Gebiet
- [ ] Entscheiden, ob ein laufender Lauf einen Seiten-Reload übersteht

## M2 Ausrüstung (Grundlage)

- [ ] Item-Datenmodell: Slot, Typ, Zellgröße, Basiswert, Seltenheit, Affixe, Tag
- [ ] Inventaransicht: Charakter mit sechs Slots oben, Raster unten (8 × 4 Zellen)
- [ ] Items mit unterschiedlicher Zellgröße: Platzierungsprüfung, Ziehen und Ablegen, Klick zum Anlegen, Aufräumen-Knopf
- [ ] Einhand- und Zweihandregel mit Schild-Sperre
- [ ] Item-Drops in der Beute (Kampf, Elite, Boss), Gold als Alternative
- [ ] Händler kauft und verkauft Items, Dialog bei vollem Rucksack
- [ ] `DamageMods` in `combat.rs` mit echten Ausrüstungswerten füllen
- [ ] Tooltips mit Vorher-Nachher-Werten für Karten, Items, Artefakte und Status
- [ ] Platzhalter-Grafiken für Items (16 × 16)
- [ ] Spieltest mit einem Charakter und etwa zwölf Items: Verändert die Ausrüstung die Kartenwahl? Erst bei Ja weiterbauen

## M3 Tags und Affixe

- [ ] Etwa 20 Affixe und 40 Items
- [ ] Kartenanforderungen (Schild, Einhandwaffe), nicht erfüllbare Karten ausgegraut
- [ ] Gebietsspezifische Drops
- [ ] Bot-Simulation: Items ändern die Gewinnrate spürbar, aber nicht extrem

## M4 Charaktere und Artefakte

- [x] Charakterwahl-Bildschirm („Wähle dein Schicksal“)
- [x] Drei Charaktere mit Startdeck und Eigenheit (Krieger, Schütze, Magier)
- [x] Kartenpool pro Charakter plus kleiner neutraler Pool
- [x] Bot-Simulation je Charakter
- [ ] Startartefakt je Charakter
- [ ] Relikte zu Artefakten umbauen und auf etwa 15 erweitern (heute 6)
- [ ] Energie-Artefakte nur als Bossbelohnung, höchstens zwei pro Lauf
- [ ] Artefakt-Leiste mit Tooltips

## M5 Endlos-Modus

- [ ] Lauf aus 3 bis 5 Karten mit nahtlosem Übergang in den Turm (Anzahl noch offen)
- [ ] Turm mit Türen-Auswahl und Etagenzähler
- [ ] Skalierung: Schwierigkeit der letzten Karte fortsetzen, dann Faktor 1,08 pro Etage, dazu Item-Level
- [ ] Pakte (Segen und Fluch) alle 5 Etagen
- [ ] Boss-Pool mit Zusatzeffekten alle 10 Etagen
- [ ] Endbildschirm mit erreichter Etage

## M6 Grafik und Politur

- [x] Pixel-Art-Regeln: Schrift, Größen, Rahmen, `assets/`-Skripte
- [x] Kartensymbole, Kartenrahmen, Heldenporträts mit Animationen
- [x] Hintergründe für Titel und alle Gebiete, animierte Effektebenen
- [x] Händler mit Begrüßungs- und Abschiedsanimation
- [x] Weltkarte als 2,5D-Spielbrett mit Schachfiguren, Hand, Nebel, Zoom und Verschieben
- [x] Startbildschirm und Pixel-Übergänge zwischen den Bildschirmen
- [x] Synthetische Soundeffekte und Stummschalter
- [x] Titelmusik
- [ ] Gegner-Sprites (32 × 32) für alle Gegner (Ratte fertig, 14 offen)
- [ ] Item- und Artefakt-Sprites (16 × 16)
- [ ] Musik für Kampf, Karte und Boss
- [ ] Balancing per Bot und von Hand, je Charakter
- [ ] Kurze Einführung im ersten Lauf, die Tags erklärt

## M7 Veröffentlichung

- [x] Standalone-Version als EXE (`build.ps1`, `launcher/`)
- [ ] Eigene Domain und Titelbild
- [ ] Feedback-Weg für Spieler
- [ ] Ein bis zwei Testrunden mit Freunden

## M8 Nach Version 1 (nicht vorher bauen)

- [ ] Set-Boni bei 2 und 4 Teilen, ein Set pro Gebiet
- [ ] Drei-zu-eins-Zusammenfügen am Rastplatz
- [ ] Zerlegen, Affix neu würfeln, Basiswert verbessern
- [ ] Erweiterbarer Rucksack
- [ ] Charaktere vier und fünf

## Offene Entscheidungen

- Anzahl der Karten pro Lauf: fest (zum Beispiel 4) oder zufällig zwischen 3 und 5?
- Soll ein Lauf einen Seiten-Reload überstehen?
- Themen für die Höhle und weitere Gebiete
- Grenzen für Artefakte: Energie-Obergrenze, Anzahl pro Lauf
- Baut Cloudflare Pages Rust selbst, oder GitHub Actions mit Wrangler?
