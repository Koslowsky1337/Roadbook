**Ten quests ready to turn in, scattered over three zones? Roadbook puts them in the fastest order and points the way.**

Roadbook builds a turn-in round from your quest log, sorts it by travel time and drives the TomTom arrow from stop to stop. It knows which flight points you have discovered, sends you to the flight master when flying is faster, and tells you where to fly. It also comes with a notebook and a macro library.

## Features

- **Turn-in round in one click:** takes every quest in your log that is ready to turn in, looks up the turn-in NPC in QuestieDB and builds a route from where you stand.
- **Ordered by travel time, not by distance:** walking, flights between the flight points you know, zeppelins and boats between continents, and one zone at a time where possible.
- **Flight master first:** when a flight saves time, the arrow first points to the flight master and the chat tells you where to fly. After landing it points to your destination.
- **Undiscovered flight master nearby?** Roadbook tells you once, so you can pick it up on the way. `/rb fm` sets a waypoint.
- **Step tracker** below the minimap: next step, distance, travel hint, and quests ready to turn in that are missing from your plan.
- **Your own plans:** save your TomTom waypoints as a plan, remember your current position with `/rb here`, reorder, rename and sort steps. Everything you delete stays in the trash for 10 minutes.
- **Two modes:** *Route* (one step after the other) and *All points* (all open steps on the map, arrow to the one you reach fastest).
- **Share plans as text:** *Export* shows a plan as plain text, *Import plan* reads it. The import also understands `/way` lines and never runs code.
- **Notebook:** notes per character or for all your characters, and one note per plan.
- **Macro library:** suggested macros can be created, updated, undone and picked up onto the cursor. Suggestions come from an optional content pack (see below).
- **English and German** client support.
- **Lightweight and private:** no bundled libraries, nothing is sent to other players or anywhere else. Your data stays in your own SavedVariables.

## Requirements

- **[TomTom](https://www.curseforge.com/wow/addons/tomtom)** (required) – waypoints and the arrow
- **[QuestieDB](https://www.curseforge.com/wow/addons/questiedb)** (required) – finding the turn-in NPC of a quest

Both are separate addons and are not included. The CurseForge app installs them along with Roadbook.

Game version: WoW Forever.

## Commands

- `/rb` or `/roadbook` – open or close the window
- `/rb turnin` – build and load a turn-in round
- `/rb plan <name>` – load a plan · `/rb off` – unload it
- `/rb skip` – skip the current step · `/rb reset` – reset the plan
- `/rb waypoints` – set the TomTom waypoints and the arrow again
- `/rb sort` – order the open steps by travel time · `/rb route` – route description with flights and times
- `/rb here [name]` – remember your current position as a step
- `/rb tomtom <name>` – save your current TomTom waypoints as a plan
- `/rb import` · `/rb export` – share plans as text
- `/rb fm` – waypoint to an undiscovered flight master nearby
- `/rb note <title>` · `/rb trash` · `/rb tracker` · `/rb minimap`
- `/rb log` · `/rb debug` · `/rb layout` – for bug reports

There is also a minimap button, an entry in the addon menu at the minimap, and two key bindings (Key Bindings → Roadbook).

## Known limits

- Travel times are estimates: straight line × 1.3 on foot, straight line between flight points, a fixed time for zeppelins and boats. Lifts, towers and winding flight paths are not modelled, so a recommended flight can occasionally be slower than walking.
- Roadbook learns your flight points when you open a flight map. Until then it does not recommend flights on that continent.
- Boat and zeppelin docks outside the classic Horde routes were measured by hand. Please report a dock in the wrong place.

## Content packs (optional)

A small addon of your own, for example `Roadbook_Post`, can hand plans, notes and macro suggestions to Roadbook: a guide you write for your guild, or notes you generate with a tool. The format and an example are in the [README on GitHub](https://github.com/Koslowsky1337/Roadbook#content-packs-optional).

## Feedback

Bugs and ideas: [GitHub issues](https://github.com/Koslowsky1337/Roadbook/issues). `/rb log` shows a log you can copy into the report.

## Deutsch

Roadbook baut aus deinem Questlog eine Abgaberunde, sortiert sie nach Reisezeit (zu Fuß, Flug über bekannte Flugpunkte, Zeppelin und Schiff) und führt den TomTom-Pfeil von Halt zu Halt. Lohnt sich ein Flug, zeigt der Pfeil zuerst zum Flugmeister. Dazu kommen ein Schritt-Tracker, eigene Pläne, Import und Export als Text, ein Notizbuch und eine Makro-Bibliothek. Der deutsche Client zeigt alle Texte auf Deutsch; die deutschen Befehlswörter (`/rb abgabe`, `/rb weiter`, `/rb aus`, `/rb hier` …) gehen weiterhin. Benötigt TomTom und QuestieDB.

## Credits

- Waypoints and arrow: [TomTom](https://www.curseforge.com/wow/addons/tomtom) by Cladhaire (used through its public API, not included).
- Quest and NPC data: [QuestieDB](https://www.curseforge.com/wow/addons/questiedb), licensed under GPL-3.0 (read at runtime, not included and not copied).

Roadbook is released under the [MIT license](https://github.com/Koslowsky1337/Roadbook/blob/main/LICENSE).

World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc. in the U.S. and/or other countries. Roadbook is a fan-made addon and is not affiliated with or endorsed by Blizzard Entertainment.
