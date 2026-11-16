# Verlorene Lande: Konzept Deckbuilder mit Ausrüstung

Nov 13, 2026 · @Martin

## Vision

Dasselbe Deck spielt sich mit einer Zweihandaxt anders als mit Schwert und Schild: Ausrüstung verändert in Verlorene Lande, wie deine Karten wirken, und nicht nur, wie hoch die Zahlen sind.

- **Charaktere:** Drei Charaktere zum Start (später bis zu fünf) mit eigenem Startdeck, eigenem Bonus und Startartefakt.
- **Kampf:** Karten wie in Slay the Spire, mit 3 Energie, 5 Handkarten und sichtbaren Gegner-Absichten.
- **Ausrüstung:** sechs Slots (Helm, Brustpanzer, Handschuhe, Schuhe, Waffe, Schild) in einem Diablo-ähnlichen Inventar. Items wirken über Tags auf ganze Kartenfamilien, zum Beispiel Hieb, Gift oder Block.
- **Artefakte:** Gegenstände ohne Slot, die Regeln ändern, zum Beispiel mehr Energie.
- **Karten und Gebiete:** zufällig erzeugte Wege, und die Reihenfolge der Gebiete wird in jedem Lauf neu gemischt. Nach 3 bis 5 Karten beginnt ein Endlos-Turm.
- **Bauen:** Du kombinierst Items über ihre Tags. Sets und Zusammenfügen folgen nach Version 1.
- **Kein Fortschritt:** Jeder Lauf beginnt von vorn. Es gibt keine dauerhaften Freischaltungen und keine Bestenliste.

Zur Abgrenzung: Megaloot stellt das Inventar in den Mittelpunkt. Hier bleibt das Kartendeck die Hauptsache, und die Ausrüstung ist der zweite Hebel darüber. Auch das Item-System soll anders funktionieren (Tags, Waffenregeln, Kartenanforderungen), damit es kein Nachbau wird.

## Umfang von Version 1

Version 1 ist der spielbare Kern. Erst wenn er sich gut anfühlt, kommen weitere Systeme dazu.

- **Dabei:** drei Charaktere, sechs Slots mit Zwei-Hand-Regel, Raster mit unterschiedlichen Item-Größen, Tags und Affixe, Artefakte, zufällige Gebiete, Endlos-Turm, Tooltips und Pixel-Art. Nur Desktop.
- **Danach:** Set-Boni, Zusammenfügen von drei Items, Neu würfeln und Aufwerten am Rastplatz, erweiterbarer Rucksack sowie die Charaktere vier und fünf. Die Pakte im Turm kommen nach dem ersten spielbaren Turm.
- **Warum so:** Zuerst muss sich zeigen, ob Ausrüstung die Kartenwahl verändert. Jedes weitere System vergrößert sonst nur den Balance-Aufwand.

## Charaktere

Drei bis fünf Charaktere geben jedem Lauf einen anderen Start, weil sich Startdeck, Bonus und passende Ausrüstung unterscheiden. Die Namen sind Arbeitstitel.

| Charakter | Schwerpunkt | Startdeck-Idee | Bonus | Passt zu |
| --- | --- | --- | --- | --- |
| Wächter | Block und Schild | Schildhieb, Bollwerk | Beginnt jeden Kampf mit 4 Block | Einhand und Schild |
| Jägerin | Gift und Wurf | Giftpfeil (2×), Giftwolke | Die erste Gift-Karte jedes Kampfes gibt +2 Gift | Einhand |
| Berserker | Zweihand und Selbstschaden | Blutpakt, Wuchtschlag | Zweihandwaffen haben +20 % Waffenwert | Zweihand |
| Alchemist | Ziehen und Kombos | Schlachtplan, Sammeln | Zieht in Runde 1 eine Karte mehr | frei |
| Wanderer | Ausgeglichen, Einsteiger | Das heutige Startdeck | Beginnt mit einem zufälligen Artefakt | frei |

Zum Start reichen drei Charaktere (Wächter, Jägerin, Berserker), weil sie die drei Waffenstile abdecken. Die übrigen folgen, sobald das Grundsystem steht.

**Startdeck und Pool:** Jedes Startdeck hat wie im Prototyp zehn Karten. Als Vorschlag gibt es einen gemeinsamen Kartenpool plus rund zehn Karten pro Charakter, die nur dieser Charakter in der Beute findet. Das ist noch offen.

**Startartefakt:** Jeder Charakter beginnt mit einem eigenen Artefakt, das seinen Stil unterstreicht.

## Spielschleife

Jeder Lauf wechselt zwischen Weg wählen, Kämpfen und Bauen, und Ausrüstung wird nur außerhalb des Kampfes gewechselt.

1. **Charakter wählen:** Jeder Lauf startet mit einem der Charaktere samt Startdeck, Bonus und Startartefakt.
2. **Karte:** Du wählst den nächsten Ort (Kampf, Elite, Ereignis, Rast, Händler). Weg und Gebiet der Karte werden pro Lauf neu erzeugt. Das ist die Grundlage des bestehenden Prototyps.
3. **Kampf:** Karten spielen, Gegner-Absichten lesen. Beim Ausspielen werden Grundwert, Ausrüstungs-Boni und Tag-Effekte in fester Reihenfolge verrechnet.
4. **Beute:** Nach jedem Kampf wählst du eine Karte, ein Item oder Gold. Elite und Boss geben bessere Items und Artefakte.
5. **Bauen:** Am Rastplatz ordnest du dein Inventar neu und heilst dich. Beim Händler kaufst und verkaufst du Items und entfernst Karten.
6. **Boss und nächste Karte:** Nach dem Boss folgt die nächste Karte mit einem neuen Gebiet. Nach 3 bis 5 Karten beginnt der Endlos-Turm.

**Rechenreihenfolge für Schaden:** Kartenwert, plus Waffenwert, plus Stärke, dann mal Tag-Multiplikatoren aus der Ausrüstung, dann Schwäche und Verwundbar. Diese Reihenfolge steht fest, damit Items vorhersehbar bleiben und Tooltips den Endwert vor dem Ausspielen zeigen können.

**Gebiete:** Es gibt einen Pool von Gebieten, aus dem jeder Lauf für jede Karte eines zieht, ohne Wiederholung. Vorhanden sind Düsterwald (Gift), Aschewüste (Brand) und Frostfestung (Panzer und Frost). Neu gesetzt ist die Höhle, und für eine fünfte Karte braucht der Pool noch ein weiteres Gebiet. Jedes Gebiet hat eigene Gegner und einen eigenen Boss und kann an jeder Position stehen. Deshalb hängt die Schwierigkeit an der Kartennummer und nicht am Gebiet: Gegnerwerte wachsen mit jeder Karte um einen Faktor (Startwert 1,25, per Simulation zu prüfen). Jedes Gebiet lässt eigene Item-Arten fallen, etwa Gift-Dolche im Wald und Eisrüstung im Frost.

## Ausrüstung

Sechs Slots mit je einer klaren Rolle, und die Waffenwahl entscheidet, ob der Schild-Slot nutzbar bleibt.

| Slot | Hauptrolle | Beispiel für einen Effekt |
| --- | --- | --- |
| Helm | Ziehen, Schutz vor Verwundbar | Zu Kampfbeginn 2 Karten mehr ziehen, aber -3 Block |
| Brustpanzer | Maximale LP, Block | Block-Karten geben +2 Block |
| Handschuhe | Angriffsstil, Kartenkosten | Die erste Karte jeder Runde kostet 0 |
| Schuhe | Tempo, Ausweichen | Wirbel-Karten treffen zusätzlich den schwächsten Gegner |
| Waffe (Einhand) | Schaden, ein Tag | Schwert: Hieb-Karten +2 Schaden |
| Waffe (Zweihand) | Mehr Schaden, ein Tag, belegt den Schild-Slot | Hammer: Hieb-Karten +5 Schaden, aber kein Schild |
| Schild | Block, Konter | Schildhieb und andere Schild-Karten sind spielbar |

**Zweihand-Regel:** Eine Zweihandwaffe sperrt den Schild-Slot. Ein Schild in Gebrauch sperrt umgekehrt jede Zweihandwaffe. Zweihandwaffen haben etwa 1,6-fache Waffenwerte, damit der Verzicht auf Block und Schild-Karten sich lohnen kann.

**Kartenanforderungen:** Manche Karten brauchen ein Ausrüstungsteil (Schild-Karten einen Schild, Wurf-Karten eine Einhandwaffe). Ohne es sind sie auf der Hand ausgegraut. Das macht die Ausrüstungswahl zur Deck-Entscheidung.

**Seltenheit und Affixe:** Normal (nur Basiswert), selten (Basiswert + 1 Affix), episch (Basiswert + 2 Affixe), legendär (feste Einzigartigkeit mit Regeländerung). Affixe sind kleine Bonus-Zeilen, zum Beispiel +2 Gift oder Karten mit Tag Block geben +1 Block.

**Energie und Handkarten:** Dauerhaft mehr Energie oder mehr Handkarten gibt es nur über Artefakte, nicht über Ausrüstung. So bleibt Ausrüstung der Hebel für Stärke und Tags, und Artefakte ändern die Regeln.

**Rucksack:** Ein Rucksack mit 8 × 4 Zellen nimmt Items auf, die du gerade nicht trägst. Ist er voll, musst du beim nächsten Drop ein Item verkaufen oder liegen lassen. Items belegen je nach Art unterschiedlich viele Zellen, wie bei Diablo.

**Inventaransicht:** Oben steht der Charakter mit seinen sechs Slots, darunter das Raster des Rucksacks. Als Startwerte für die Zellgrößen gelten: Helm, Handschuhe und Schuhe 2 × 2, Brustpanzer 2 × 3, Schild 2 × 3, Einhandwaffe 1 × 3, Zweihandwaffe 2 × 4. Nur Rechtecke, keine freien Formen.

**Bedienung:** Ziehen und Ablegen am Desktop, dazu ein Klick zum Anlegen und ein Knopf zum automatischen Aufräumen. Alle Items zeigen einen Tooltip mit Vorher-Nachher-Werten. Das Spiel ist nur für den Desktop gedacht, deshalb sind Hover-Tooltips möglich.

**Ausbaustufen:** Stufe 1 ist das Raster mit festen Größen. Stufe 2 ergänzt einen erweiterbaren Rucksack (zusätzliche Reihen aus Ereignissen, vom Händler oder durch ein Artefakt). Stufe 2 bauen wir erst, wenn Stufe 1 sich gut anfühlt.

## Kombinieren

Die Items verstärken Tags statt einzelner Karten, und deshalb entstehen Synergien von selbst.

**Tags:** Jede Karte trägt ein bis zwei Tags, zum Beispiel Hieb, Wurf, Gift, Block, Schild, Fläche, Ziehen. Ein Item-Effekt benennt ein Tag und wirkt auf alle Karten, die es tragen. Die Schlüsselkarten des Prototyps lassen sich so einordnen: Schlag und Wuchtschlag sind Hieb, Giftpfeil ist Gift + Wurf, Bollwerk ist Block.

| Item (Beispiel) | Slot | Effekt | Wirkt auf |
| --- | --- | --- | --- |
| Rindenschwert | Waffe (Einhand) | +2 Schaden | Tag Hieb |
| Giftdolch | Waffe (Einhand) | +2 Gift | Tag Gift |
| Sturmhammer | Waffe (Zweihand) | +5 Schaden, Schild gesperrt | Tag Hieb |
| Wachturmschild | Schild | Schild-Karten +50 %, 3 Dornen | Tag Schild |
| Eisenhelm | Helm | Zu Kampfbeginn 2 Karten mehr ziehen, -3 Block | alle Karten |
| Handschuhe der Eile | Handschuhe | Erste Karte jeder Runde kostet 0 | alle Karten |

**Sets (nach Version 1):** Items aus demselben Set geben ab 2 und ab 4 getragenen Teilen Boni, etwa Waldjäger: ab 2 Teilen tickt Gift doppelt so stark, ab 4 Teilen verursacht jede Gift-Karte zusätzlich 3 Schaden. Gebiete werfen bevorzugt ihr eigenes Set ab.

**Zusammenfügen (nach Version 1):** Drei gleiche Items derselben Seltenheit lassen sich am Rastplatz zu einem Item der nächsthöheren Seltenheit verschmelzen. Du behältst die Affixe eines der drei. Das ist der Anreiz, doppelte Drops aufzuheben statt wegzuwerfen.

**Zerlegen und Schmieden (nach Version 1):** Zerlegte Items geben Schrott. Mit Schrott würfelst du am Rastplatz ein Affix neu (kostet mehr bei höherer Seltenheit) oder verbesserst den Basiswert um eine Stufe. In Version 1 verkaufst du überzählige Items stattdessen für Gold.

**Warum das trägt:** Der Build hat zwei Ebenen. Das Deck bestimmt, welche Tags du spielst, und die Ausrüstung bestimmt, wie stark sie sind. Wer viel Gift-Karten hat, sucht Gift-Items, und wer auf Zweihand setzt, baut sein Deck von Block weg.

## Artefakte

Ja, das Spiel braucht Artefakte: Sie tragen Regeländerungen wie mehr Energie, die als Ausrüstungswert die Balance sprengen oder die Slots verstopfen würden.

- **Rolle:** Artefakte belegen keinen Slot und kein Inventar. Sie ändern Regeln, zum Beispiel +1 Energie, +1 Handkarte, Block zu Kampfbeginn, Heilung nach dem Kampf oder neue Tag-Regeln. Im Prototyp heißen sie Relikte, und sechs existieren schon (Anker, Blutrubin, Energiekern, Kräutertee, Linse, Glücksmünze).
- **Quellen:** Startartefakt des Charakters, Elite, Boss, Ereignisse und Händler.
- **Trennung der Ebenen:** Karten sind die Aktionen, Ausrüstung liefert Stärke und Tag-Boni, Artefakte ändern die Regeln. Dauerhaft mehr Energie oder Handkarten gibt es nur als Artefakt.
- **Begrenzung:** Energie-Artefakte kommen nur als Bossbelohnung, höchstens zwei pro Lauf (Startwert). Starke Artefakte bekommen einen Nachteil, etwa +1 Energie, aber Gegner starten mit Block. Der heutige Energiekern bräuchte dafür einen Nachteil.
- **Anzeige:** Eine eigene Leiste über dem Inventar, jedes Artefakt mit Tooltip.

## Endlos-Modus

Nach der letzten Karte des Laufs (3 bis 5 Karten) beginnt nahtlos ein Endlos-Turm, in dem Gegner pro Etage um 8 % stärker werden und dein Build nur durch gute Synergien mithalten kann.

- **Aufbau:** Der Turm besteht aus Etagen ohne große Karte. Du wählst nach jedem Kampf zwischen zwei bis drei Türen (Kampf, Elite, Rast, Händler, Ereignis). Alle 10 Etagen steht ein Boss aus dem Pool der Gebiete, mit einem zufälligen Zusatzeffekt.
- **Skalierung:** Der Turm setzt die Schwierigkeit der letzten Karte fort. Danach wachsen Gegner-LP und -Schaden mit dem Faktor 1,08^(Etage − 1), das ist etwa das Doppelte auf Etage 10, das 4,3-Fache auf Etage 20 und das 9,3-Fache auf Etage 30. Drops erhalten das Item-Level der Etage, und ihre Basiswerte wachsen ungefähr 6 % pro Level. Beide Zahlen sind Startwerte für die Bot-Simulation, kein Beschluss.
- **Pakte:** Alle 5 Etagen wählst du einen von drei Pakten. Jeder gibt einen Segen und verlangt einen Fluch, zum Beispiel +1 Energie gegen Gegner mit +20 % LP. Pakte bleiben bis zum Ende des Laufs aktiv und stapeln sich. So steigt der Druck auch dort, wo die Skalierung allein nicht reicht.
- **Kein Fortschritt:** Stirbst du, endet der Lauf, und der Endbildschirm zeigt die erreichte Etage. Es gibt weder Bestenliste noch Freischaltungen, und es wird nichts gespeichert.
- **Zahlenanzeige:** Werte ab 1000 werden als 1,2k abgekürzt. Normale JavaScript-Zahlen reichen weit über Etage 100, ein eigener Großzahltyp ist nicht nötig.

## Technik und Cloudflare

Das Spiel bleibt eine reine Browser-App aus statischen Dateien, die Cloudflare kostenlos ausliefert. Einen Server braucht das Spiel nicht.

**Hosting:** Cloudflare Pages liefert die fertig gebauten Dateien aus. Anfragen an statische Dateien sind laut der [Migrationsanleitung](https://developers.cloudflare.com/workers/static-assets/migrate-from-pages/) auf Pages wie auf Workers kostenlos. Veröffentlicht wird per Git-Anbindung des Repos oder per Wrangler von Hand. Die Anleitung stellt Workers als Plattform mit breiterem Funktionsumfang dar und beschreibt den Umzug von Pages dorthin. Für ein statisches Spiel ohne Server reicht Pages, und sollte ein Umzug nötig werden, ist der Weg dokumentiert.

**Aufbau des Codes:**

- **data:** JSON-Dateien (per serde eingelesen) für Karten, Items, Affixe, Sets, Gegner, Ereignisse. Neue Inhalte sind neue Einträge statt neuer Code, und Claude kann sie in großer Zahl entwerfen.
- **engine:** ein eigenes Rust-Crate mit reinen Funktionen für Kampf, Ausrüstung, Karte und Turm, ohne Zugriff auf die Oberfläche. Es wird einmal nach WebAssembly und einmal nativ gebaut. Dadurch läuft die Bot-Simulation als normales Programm gegen genau denselben Code, nur deutlich schneller als im Prototyp.
- **Zufall mit Seed:** Alle Zufallswürfe laufen über einen Generator mit Startwert (zum Beispiel rand\_chacha, damit das Ergebnis auf jedem System gleich ist). Das trägt Fehlerreproduktion und die Bot-Tests.
- **ui:** Darstellung und Eingaben. Vorschlag: Leptos als Oberfläche im DOM, Pixel-Art als CSS-Bilder. Die Alternativen stehen im Abschnitt Rust und WebAssembly.
- **Speichern:** Es gibt keinen dauerhaften Fortschritt und kein Konto, und jeder Lauf beginnt von vorn. Ob ein laufender Lauf ein Neuladen der Seite überstehen soll, ist noch offen.

**Build und Deployment:** Trunk baut aus dem Rust-Code den Ordner dist (HTML, JS-Glue, WASM und Assets), den Cloudflare Pages per Git-Push oder per Wrangler veröffentlicht. Die genaue Konfiguration prüfen wir beim Einrichten gegen die aktuelle Cloudflare-Dokumentation.

**Grafik:** Pixel-Art als PNG im Ordner assets, ganzzahlig skaliert (image-rendering: pixelated) und mit kleiner gemeinsamer Palette. Feste Größen: 16 × 16 für Items und Artefakte, 32 × 32 für Gegner und Charaktere. Bis die Bilder fertig sind, dienen Platzhalter (Emojis oder im Code erzeugte Pixelraster), und jedes Bild lässt sich später einzeln austauschen. Gezeichnet wird zum Beispiel in Aseprite oder Piskel.

**Plattform:** Nur Desktop-Browser mit Maus und Tastatur, kein Handy-Layout. Dadurch sind Ziehen und Ablegen sowie Hover-Tooltips ohne Kompromisse möglich.

### Rust und WebAssembly

Rust bleibt die Kernsprache, kompiliert nach WebAssembly. Das läuft auf Cloudflare Pages ohne Besonderheit, weil am Ende nur statische Dateien (.wasm, .js, .html, Bilder) ausgeliefert werden.

**Dafür:** Die Regeln (Slots, Zwei-Hand-Sperre, Tags) lassen sich als Enums und Typen abbilden, und der Compiler meldet vergessene Fälle. Die Engine läuft nativ für schnelle Bot-Tests und im Browser als derselbe Code.

**Dagegen:** Der Prototyp ist JavaScript und wird neu geschrieben. Die Oberfläche mit Raster, Ziehen und Ablegen und Tooltips ist in Rust mühsamer als in TypeScript. Compile-Zeiten und Fehlermeldungen bremsen das schnelle Ausprobieren. Eine WASM-Datei lässt sich schwerer in kleine Teile zerlegen als ein JavaScript-Bundle.

| Weg | Beschreibung | Passt wenn |
| --- | --- | --- |
| A: Rust-Engine mit Leptos-Oberfläche (Vorschlag) | Die Oberfläche besteht aus normalen Elementen im DOM, Tooltips und Raster entstehen mit CSS. Gebaut wird mit Trunk. | Das Spiel soll eine ausgebaute Oberfläche mit viel Text, Raster und Tooltips haben. |
| B: macroquad | Schlankes 2D-Framework, das nach WASM exportiert. Oberflächenelemente und Tooltips baust du selbst. | Das ganze Spiel soll ein Bild auf einer Zeichenfläche sein. |
| C: Bevy | Voll-Engine mit ECS. Ältere Angaben nennen 15 bis 30 MB für eine Web-Version, die Zahl müsste neu gemessen werden. Für ein rundenbasiertes Oberflächen-Spiel mehr Aufwand als Nutzen. | Spiel wird später stark in Richtung Echtzeit und Effekte erweitert. |
| D: Rust-Engine mit TypeScript-Oberfläche | Die Engine ist ein WASM-Modul (wasm-bindgen), die Oberfläche bleibt TypeScript. | Der leichteste Weg für die Oberfläche, aber zwei Sprachen im Projekt. |

**Werkzeuge und Zubehör:**

- **rustup** mit dem Ziel wasm32-unknown-unknown, dazu **Trunk** als Build-Werkzeug und Dev-Server. Trunk nutzt wasm-bindgen, und mit wasm-opt wird die Datei für die Veröffentlichung kleiner.
- **Cargo-Workspace** mit den Crates engine (Regeln), ui (Oberfläche) und sim (Bot-Simulation).
- **serde und serde\_json** für die Daten, **rand\_chacha** für den Zufall mit Startwert.
- **console\_error\_panic\_hook**, damit Abstürze als lesbare Meldung in der Browser-Konsole landen.
- **cargo test, clippy und rustfmt** für Tests und Stil.
- **Release-Profil** mit opt-level "s", lto und codegen-units 1, damit die WASM-Datei klein bleibt.
- **GitHub Actions** für Build und Veröffentlichung. Ob Cloudflare Pages selbst Rust bauen kann, ist ungeprüft.
- **Audio:** Web Audio über web-sys oder eine kleine JavaScript-Brücke.
- **Pixel-Art:** Aseprite oder Piskel.
- **Entwicklung:** Claude Code im Terminal auf dem eigenen Rechner, weil die Rust-Toolchain lokal laufen muss.

## To-do-Liste

Die Reihenfolge baut so aufeinander auf, dass nach jedem Meilenstein ein spielbarer Stand existiert.

### M0 Grundlage

- [ ] Git-Repo anlegen, Rust-Toolchain installieren (rustup, Ziel wasm32-unknown-unknown, Trunk) und einen Cargo-Workspace mit den Crates engine, ui und sim aufsetzen
- [ ] Prototyp-Logik (Karten, Kampf, Relikte) als Referenz nach Rust portieren: Daten, Engine, Oberfläche getrennt
- [ ] Cloudflare-Konto einrichten, ein leeres Test-Deployment auf Cloudflare Pages veröffentlichen
- [ ] Deploy-Weg festlegen: GitHub Actions baut mit Trunk und veröffentlicht per Wrangler (vorher prüfen, ob die Build-Umgebung von Pages Rust kann)

### M1 Engine aufräumen

- [ ] Seed-fähigen Zufallsgenerator einbauen und alle Zufallsaufrufe darüber leiten
- [ ] Karten, Gegner, Artefakte, Gebiete und Ereignisse in JSON-Dateien auslagern
- [ ] Kampf-Engine ohne Oberfläche testbar halten, Bot-Simulation als natives Rust-Programm neu schreiben und mit den Ergebnissen des JS-Prototyps vergleichen
- [ ] Tags für alle bestehenden Karten vergeben
- [ ] Gebiete als frei mischbaren Pool umbauen, Gegnerwerte mit der Kartennummer skalieren, Gebiet Höhle anlegen
- [ ] Optional: Zwischenstand des laufenden Laufs im Browser sichern (Entscheidung offen)

### M2 Ausrüstung (Grundlage)

- [ ] Item-Datenmodell: Slot, Typ, Zellgröße, Basiswert, Seltenheit, Affixe, Tag
- [ ] Inventaransicht für Desktop: Charakter oben mit sechs Slots, Raster unten (Startwert 8 × 4 Zellen)
- [ ] Items belegen unterschiedlich viele Zellen: Platzierungsprüfung, Ziehen und Ablegen, Klick zum Anlegen, Knopf zum Aufräumen
- [ ] Einhand- und Zweihandregel mit Schild-Sperre
- [ ] Item-Drops in der Beute (Kampf, Elite, Boss), Gold als Alternative zur Karte
- [ ] Händler kauft und verkauft Items, Dialog bei vollem Rucksack
- [ ] Fest definierte Rechenreihenfolge im Kampf, Tooltips mit Vorher-Nachher-Werten für Karten, Items, Artefakte und Status
- [ ] Platzhalter-Grafiken in den festen Größen (16 × 16 und 32 × 32)
- [ ] Spieltest mit einem Charakter und rund zwölf Items: Verändert die Ausrüstung, welche Karten du nimmst? Erst bei Ja weiterbauen

### M3 Tags und Affixe

- [ ] Rund 20 Affixe und rund 40 Items schreiben (Entwürfe per Claude, Prüfung von Hand)
- [ ] Kartenanforderungen (Schild, Einhandwaffe) mit ausgegrauten Karten
- [ ] Gebietsspezifische Drops
- [ ] Bot-Simulation: Items ändern die Gewinnrate spürbar, aber nicht extrem

### M4 Charaktere und Artefakte

- [ ] Charakterwahl-Bildschirm zu Laufbeginn
- [ ] Drei Charaktere mit Startdeck, Bonus und Startartefakt (Wächter, Jägerin, Berserker als Arbeitstitel)
- [ ] Kartenpool pro Charakter plus gemeinsamer Pool (Entscheidung offen)
- [ ] Relikte zu Artefakten umbauen und auf rund 15 Artefakte erweitern
- [ ] Regel für Energie-Artefakte: nur als Bossbelohnung, höchstens zwei pro Lauf
- [ ] Artefakt-Leiste mit Tooltips
- [ ] Bot-Simulation je Charakter

### M5 Endlos-Modus

- [ ] Lauf aus 3 bis 5 Karten (Anzahl fest oder zufällig, Entscheidung offen) mit nahtlosem Übergang in den Turm
- [ ] Turm-Ablauf mit Türen-Auswahl und Etagenzähler
- [ ] Skalierung: Schwierigkeit der letzten Karte fortsetzen, dann Faktor 1,08 pro Etage, dazu Item-Level
- [ ] Pakte (Segen und Fluch) alle 5 Etagen, zum Start rund 12 Stück (erst nach dem ersten spielbaren Turm)
- [ ] Boss-Pool mit Zusatzeffekten alle 10 Etagen
- [ ] Endbildschirm mit erreichter Etage, ohne Speichern

### M6 Grafik und Politur

- [ ] Pixel-Art-Regeln festlegen: Palette, Größen 16 × 16 und 32 × 32, Ordner assets
- [ ] Pixel-Art für Karten, Gegner, Items, Artefakte und Charaktere (Umfang vorher zählen), Platzhalter nach und nach ersetzen
- [ ] Balancing per Bot und von Hand, je Charakter
- [ ] Einfache synthetische Sounds und Stummschalter
- [ ] Kurze Einführung im ersten Lauf, die Tags erklärt

### M7 Veröffentlichung

- [ ] Eigene Domain und Titelbild
- [ ] Feedback-Weg für Spieler einrichten
- [ ] Ein bis zwei Testrunden mit Freunden vor dem Start

### M8 Nach Version 1

- [ ] Set-Boni bei 2 und 4 Teilen, ein Set pro Gebiet
- [ ] Drei-zu-eins-Zusammenfügen am Rastplatz
- [ ] Zerlegen zu Schrott, Affix neu würfeln, Basiswert verbessern
- [ ] Erweiterbarer Rucksack mit zusätzlichen Reihen
- [ ] Charaktere vier und fünf

## Risiken und offene Fragen

Das größte Risiko ist der Inhaltsumfang: 40 Items mit Affixen und Tags müssen ausbalanciert werden, bevor sich das System lohnt.

**Risiken**

- Balance im Endlos-Modus: Die Skalierung braucht Bot-Tests je Charakter, sonst kippt der Turm ab Etage 15 in Unmöglich oder Langeweile.
- Zu viele Systeme auf einmal: Version 1 enthält nur den Kern. Sets, Zusammenfügen, Schmieden und der Rucksack-Ausbau kommen später. Der Spieltest nach M2 entscheidet, ob Ausrüstung die Kartenwahl verändert.
- Rust-Umstieg: Der Prototyp wird neu geschrieben, und Compile-Zeiten bremsen das Ausprobieren. Gegenmaßnahme: zuerst die Engine mit Tests portieren, die Oberfläche danach, und den JS-Prototyp als Referenz behalten.
- WASM-Größe und Ladezeit: Release-Profil auf Größe trimmen und die Dateigröße früh im Test-Deployment messen.
- Tooltips sind beschlossen und tragen das Spiel, weil sie Kombinationen erklären. Sie gehören in jeden Meilenstein.
- Pixel-Art ist der größte Posten außerhalb des Codes: Karten, Gegner, Items, Artefakte und Charaktere. Umfang vorab zählen, mit Platzhaltern starten und die Größen früh festlegen.
- Zufällige Gebietsreihenfolge: Gegnerwerte nach Kartennummer skalieren, nicht nach Gebiet, damit jedes Gebiet an jeder Stelle fair bleibt.

**Offene Fragen**

- Oberfläche in Rust: Leptos (Vorschlag), macroquad, Bevy oder Rust-Engine mit TypeScript-Oberfläche?
- Kann Cloudflare Pages Rust selbst bauen, oder baut GitHub Actions und lädt per Wrangler hoch?
- Kartenpool: Hat jeder Charakter einen eigenen Pool oder gibt es zusätzlich einen gemeinsamen?
- Anzahl der Karten pro Lauf: fest (zum Beispiel 4) oder zufällig zwischen 3 und 5?
- Wer zeichnet die Pixel-Art: du selbst, KI-Bilder mit Nacharbeit oder eine Mischung?
- Soll ein Lauf einen Seiten-Reload überstehen, oder ist alles weg?
- Welche Themen haben Höhle und die weiteren Gebiete?
- Grenzen für Artefakte: Obergrenze für Energie, Anzahl der Artefakte pro Lauf?

&#32;

## Quellen

- [Cloudflare: Von Pages zu Workers Static Assets migrieren](https://developers.cloudflare.com/workers/static-assets/migrate-from-pages/), abgerufen am 13.11.2026
- [Bevy Cheat Book: WASM-Webseite (Version 0.12, veraltet)](https://bevy-cheatbook.github.io/platforms/wasm/webpage.html), abgerufen am 16.11.2026
- [Rust und WASM für Spiele, macroquad als einfacher Einstieg](https://www.abratabia.com/webassembly/rust-wasm-games.php), abgerufen am 16.11.2026
- [Leptos-Buch: WASM-Dateigröße optimieren](https://book-ru.leptos.dev/deployment/binary_size.html), abgerufen am 16.11.2026
