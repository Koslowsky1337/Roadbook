# Roadbook – was noch zu tun ist

Stand: 14.11.2026. Automatisch geprüft sind: 203 Ablauf-Tests (Deutsch), 11 Tests im englischen Client, der Layout-Prüfer über 30 Bildschirme je Sprache und der Übersetzungs-Check (`python tests/all.py`). Alles hier unten kann nur im Spiel oder von dir erledigt werden.

## 1. Einmalig vor dem ersten Test

- [ ] **Spiel ganz beenden und neu starten.** Die Dateiliste hat sich geändert (`Locales\`, `Share.lua`, kein `Post.lua` mehr) und `Roadbook_Post` ist ein neuer Addon-Ordner – `/reload` reicht dafür nicht.
- [ ] In der Addon-Liste prüfen: **Roadbook** und **Roadbook Post** sind aktiv, TomTom und QuestieDB ebenfalls (Roadbook lädt ohne sie nicht mehr).
- [ ] Nach dem Login: kein roter Fehler (BugSack), im Chat einmalig „Willkommen! /rb öffnet das Roadbook …“ und die Meldung „Neue Post“.

## 2. Im Spiel testen (deutscher Client)

**Übernahme deiner Daten**
- [ ] Deine eigenen Pläne, Notizen und der Fortschritt sind noch da.
- [ ] Reiter Makros: deine zehn Makros aus der Post stehen da, Status passt (aktuell/geändert).
- [ ] Ausgeblendete Post-Notizen/-Pläne sind weiterhin ausgeblendet.

**Abgaberunde und Pfeil**
- [ ] `/rb abgabe` und `/rb turnin` erstellen die Runde; Reihenfolge wirkt sinnvoll.
- [ ] Modus „Alle“: Klick auf einen anderen Schritt – der Pfeil bleibt dort, auch nachdem du etwas aufgehoben hast (früher sprang er zurück).
- [ ] Quest abgeben: Schritt hakt sich ab, Pfeil geht zum nächsten.
- [ ] Wiederholbare Quest abgeben und neu annehmen: der Schritt ist wieder offen.
- [ ] `/rb hier` zweimal an derselben Stelle (ohne geladenen Plan): beide Schritte landen im selben Plan und sind offen.

**Flüge**
- [ ] Beim Flugmeister die Flugkarte öffnen: im Protokoll (`/rb log`) steht „… flight point(s) remembered as known“. Danach `/rb route`: „Flugpunkte: X bekannt“ passt zu deinen Flugpunkten (deine alten Einträge werden dabei von Namen auf Nummern umgestellt).
- [ ] **Unbekannter Flugmeister:** in die Nähe (unter 400 m) eines Flugmeisters gehen, den du noch nicht hast. Erwartet: einmalig die Chatzeile „Unbekannter Flugmeister in der Nähe …“. `/rb fm` setzt einen TomTom-Punkt dorthin. Kommt die Meldung **nicht**, bitte Bescheid geben – dann liefert das Spiel `isUndiscovered` nicht und der Hinweis erscheint erst, nachdem du auf dem Kontinent einmal eine Flugkarte geöffnet hast.
- [ ] Kommt die Meldung fälschlich für einen Flugmeister, den du **schon hast**? Dann ebenfalls melden.
- [ ] Wird ein Flug empfohlen: am Flugmeister nennt der Chat das Ziel, nach der Landung zeigt der Pfeil zum eigentlichen Ziel. Stoppuhr-Gefühl: war der Flug wirklich schneller?

**Neu in der Beta**
- [ ] Reiter „Optionen“: die drei Häkchen wirken sofort (Tracker, Minimap-Knopf, Protokoll); Minus/Plus ändern den Umweg in 30-Sekunden-Schritten, „aus“ bei 0.
- [ ] Unbekannter Flugmeister fast am Weg: er erscheint als eigene blaue Zeile im Plan („unbekannt – mitnehmen“), der Pfeil zeigt zuerst dorthin; nach dem Öffnen der Flugkarte geht es zum Ziel weiter.
- [ ] Abflug bei einem unbekannten Flugmeister: Text „Erst zum unbekannten Flugmeister … (du lernst ihn dabei kennen)“, und der Flug von dort ist im Spiel wirklich möglich.
- [ ] Zeppelin oder Schiff: etwa vier Sekunden nach dem Ablegen kommt „An Bord (…)“, der Anleger-Punkt verschwindet, der Pfeil zeigt zum Ziel. Nach dem Aussteigen rechnet Roadbook neu.
- [ ] Reise-Abschnitt überspringen: „Weiter“ überspringt zuerst die blaue Zeile, beim zweiten Mal den Schritt; Rechtsklick auf die graue Zeile holt sie zurück.
- [ ] Zeppelin auf demselben Kontinent (z. B. Undercity → Grom'gol für ein Ziel im Süden) wird statt des langen Fußwegs vorgeschlagen.

**NPC-Suche (1.1.0, Tag `v1.1.0` am 15.11.2026)**
- [ ] Spiel ganz neu starten (neue Datei `Search.lua`), dann Reiter „NPC-Suche“: jede Kategorie anklicken – kommt die Liste ohne spürbaren Ruckler? In `/rb log` steht je Suche die Dauer in ms.
- [ ] Stimmen die Treffer: nächster Händler, Gastwirt, dein Klassenlehrer, ein Berufslehrer? Keine Allianz-NPCs dabei?
- [ ] „Weg zeigen“ setzt den Pfeil; bleibt er dort, auch wenn ein Plan geladen ist?
- [ ] „Zum Plan hinzufügen“ hängt den NPC an den geladenen bzw. gewählten Plan.
- [ ] `/rb suche händler` und `/rb suche <Namensteil>`.
- [ ] Nach 1.1.0 (noch ohne Tag): Feld „Gebiet“ – z. B. Kategorie Händler + „Orgrimmar“ listet bis zu 20 Händler dort, auch von weit weg; Dauer in `/rb log`. `/rb suche händler in orgrimmar`.
- [ ] Optionen: neue Regler (Flug-Ersparnis, Trefferzahl, Papierkorb-Dauer) und der Haken „Unbekannte Flugmeister im Chat melden“ wirken; der Reiter ist jetzt zweispaltig – steht nichts über oder übereinander?
- [ ] Berufe: deine eigenen Berufe sind links grün mit Stand (z. B. „Angeln 150/150“). Lehrer zeigen „(bis 150/225/300)“; wer dir nichts Neues beibringt, steht grau am Ende. Angeln bei 150: zuerst der Händler mit dem Buch – stimmt das auf Forever, oder lernt man dort anders weiter?
- [ ] Textsuche trifft auch den Titel: „Portal“, „Reagenz“ – kommen sinnvolle Treffer?
- [ ] Textsuche zeigt auch Allianz-NPCs und fremde Klassenlehrer, grau mit „(andere Fraktion)“ bzw. „(andere Klasse)“. Optionen → NPC-Suche: beide Haken wirken auf die Kategorien. „/way kopieren“ öffnet das Kopierfenster, und der Befehl funktioniert in TomTom.

**Zeppeline und Schiffe** (aus den Spieldaten bestätigt: Orgrimmar, Undercity, Grom'gol, Ratchet, Booty Bay)
- [ ] Ziel auf dem anderen Kontinent: Pfeil zeigt zum Anleger, und der steht an der richtigen Stelle.
- [ ] Aus Leatrix Maps übernommen, im Spiel noch nicht abgelaufen: Thunder Bluff ↔ Insel Zephras, Tanaris ↔ Flusslande (laut Leatrix nur Horde) und alle Allianz-Linien samt Tiefenbahn und Feralas-Fähre. Wenn du dort vorbeikommst: stimmt der Anleger?

**Import/Export**
- [ ] „Export“ zeigt Zeilen mit `step;type=…;title=…` – vollständig lesbar, kein `stepype` oder `itle` (das war der Fehler in Beta 1).
- [ ] Plan wählen → „Export“ → Text kopieren → „Plan importieren“ → einfügen → derselbe Plan entsteht als eigener.
- [ ] `/way Durotar 53.5 9.0 Test` und `/way 50 50` ins Importfenster einfügen: es entsteht ein Plan mit zwei Punkten.

**Fenster und Bedienung**
- [ ] `/rb layout` bei offenem Fenster in jedem Reiter, mit ausgeklapptem Tracker, Papierkorb, Kopier- und Importfenster: „0 Auffälligkeiten“. Der Test rechnet Textbreiten nur näherungsweise, das Spiel misst echt.
- [ ] Addon-Menü an der Minimap: Eintrag „Roadbook“ öffnet das Fenster.
- [ ] ESC schließt Hauptfenster, Papierkorb, Kopier- und Importfenster.
- [ ] Tastaturbelegung → Roadbook: beide Einträge sind deutsch beschriftet.
- [ ] Makro im Kampf: „Übernehmen“ und „Aufnehmen“ sind gesperrt.

## 3. Englischer Client (einmal reicht)

- [ ] Client auf Englisch stellen (Battle.net → Spieleinstellungen → Sprache) oder einen Freund bitten: alle Texte englisch, `/rb help` listet englische Befehle, `/rb layout` meldet nichts.
- [ ] Deine bekannten Flugpunkte sind nach dem Sprachwechsel noch bekannt (`/rb route`).

## 4. Offen im Code (bewusst verschoben)

- [ ] Alle Pläne werden bei jedem Zugriff neu aufbereitet (Befund 15). Kein messbares Problem in den Tests; falls es im Spiel bei vielen Plänen ruckelt, baue ich einen Zwischenspeicher ein.
- [ ] Als Geist (TomTom „Leiche behalten“) übernimmt TomTom den Pfeil nicht; nach dem Wiederbeleben einmal auf den Tracker klicken.
- [ ] Das gemerkte Reittempo gilt auch, wenn du gerade zu Fuß bist.
- [ ] Kein Eintrag in den Spiel-Einstellungen von Blizzard; die Optionen stehen im eigenen Reiter des Roadbook-Fensters.

## 5. Veröffentlichung

- [ ] Screenshots für die CurseForge-Gallery: `/rb fotos` eingeben, sieben Bilder abwarten (etwa 15 Sekunden), dann `/reload`. Danach Bescheid geben – der Zuschnitt läuft mit `media/crop_shots.py`. Die Bilder zeigen nur Beispieldaten (Abgaberunde mit Zeppelin, Tracker, Wegbeschreibung, Kurzanleitung, Beispiel-Makros, Optionen, Import), nichts von dir.
- [x] CurseForge-Projekt anlegen: Name **Roadbook**, Logo `media/logo.png`, Lizenz MIT, Kategorie Quests & Leveling (zusätzlich Map & Minimap), Spielversion **Forever**. Summary und Description: siehe unten.
- [ ] Auf der Projektseite unter *Relations* **TomTom** und **QuestieDB** als *Required Dependency* eintragen bzw. prüfen (kommt aus `.pkgmeta`; falls nicht, von Hand eintragen).
- [x] Automatisches Paket wie bei Pastime: in den GitHub-Einstellungen des Repos den CurseForge-Webhook eintragen (`https://www.curseforge.com/api/projects/<Projekt-ID>/package?token=<dein Token>`). Den Token nur dort eintragen, nie in eine Datei.
- [x] Erste Alpha: Tag `v1.0.0-alpha1` (14.11.2026). Auf CurseForge unter *Files* prüfen: Datei ist da und als Alpha markiert, Spielversion „Forever“, im Zip kein `tests`, kein `media`, keine `.md`; in der TOC steht `1.0.0-alpha1`.
- [x] Beta: Tag `v1.0.0-beta1` (14.11.2026). Wie bei der Alpha auf CurseForge unter *Files* prüfen; im Zip darf `CURSEFORGE.md` jetzt nicht mehr liegen.
- [x] Beta 2: Tag `v1.0.0-beta2` (15.11.2026) – behebt den verstümmelten Plan-Export.
- [ ] Vor jedem weiteren Tag: im `CHANGELOG.md` oben einen Abschnitt mit der neuen Version anlegen.
- [x] Release: Tag `v1.0.0` (15.11.2026). Im Spiel bis dahin nicht geprüft: Mitfahr-Erkennung auf Zeppelin/Schiff, englischer Client, Allianz-Linien.
- [ ] Auf GitHub unter *Releases* den Release zu `v1.0.0` anlegen (Text aus dem `CHANGELOG.md`).

### CurseForge-Texte

- **Summary:** Turns your quest log into a turn-in route ordered by travel time, with TomTom waypoints, flight paths, a notebook and a macro library.
- **Description:** den Inhalt von `CURSEFORGE.md` einfügen (Editor auf Markdown stellen). `README.md` ist die Fassung für GitHub.

## Arbeitsweise

- Geändert wird nur im Git-Ordner `D:\Claude\WoW Addons\Roadbook`. Danach: Tests (`python tests/all.py`), in den Spielordner kopieren, committen, pushen – immer alle drei.
- `Roadbook_Post` (deine private Post samt `make_post.py`) liegt nur im Spielordner und gehört nicht ins Repo.
