# Changelog

## 1.0.0-alpha1

First public version. Please report anything odd: https://github.com/Koslowsky1337/Roadbook/issues

- English is now the base language; German clients keep their German texts. Commands are English (`/rb turnin`, `/rb skip`, `/rb off`, `/rb here`, `/rb waypoints`, `/rb sort`, `/rb trash` …); the German words still work.
- New: share plans as text. *Export* shows a plan, *Import plan* (or `/rb import`) reads a Roadbook export or `/way` lines. The import never runs code.
- New: Roadbook tells you once when an undiscovered flight master is nearby; `/rb fm` sets a waypoint to it.
- New: entry in the addon menu at the minimap, a welcome line on first start, `/rb layout` to check the open windows for cut-off text.
- TomTom and QuestieDB are now required addons.
- Plans, notes and macro suggestions from outside now come from an optional content pack addon (`Roadbook_Post`) instead of a file inside Roadbook.
- Fixed: in *All points* mode, clicking a step moved the arrow there only until the next update.
- Fixed: repeatable quests stayed "done" forever after the first turn-in.
- Fixed: a new "Go to" step at a place you had reached before was ticked off at once.
- Fixed: flying over a "Go to" point on a flight path no longer counts as arriving.
- Known flight points are stored by their number instead of their name, so they survive a change of the client language. Old entries are converted automatically.
- Zone names always come from the game in your client language, also for imported plans.
- A flight is only recommended when it saves at least 30 seconds and at least 20 % of the walking time.
- More boats and zeppelins: Tanaris ↔ Riverglades, Auberdine ↔ Menethil Harbor, Zephras Isle ↔ Dalaran.
- Macros are checked against 255 bytes (umlauts count double), so the game cannot cut them off.
- `/rb here` without a loaded plan adds to your selected plan instead of creating a new one every time.
- The log and its diagnostics are English, so they can be read in bug reports.
- The version shown in the addon list comes from the release tag.
