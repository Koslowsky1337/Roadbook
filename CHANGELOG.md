# Changelog

## Unreleased

- Boat, zeppelin and tram stops now come from Leatrix Maps and QuestieDB. New: Deeprun Tram Stormwind ↔ Ironforge, the Feralas ferry to Feathermoon, Zephras Isle ↔ Alterac Mountains. Tanaris ↔ Riverglades is Horde only. Several stops moved slightly.
- Alliance round trip Auberdine → Menethil Harbor → Southshore → Auberdine added, in that direction only. Zeppelins and boats never need to be discovered: every line of your faction always counts.
- Zeppelins and boats are now also used within one continent when they are faster than walking, for example Undercity – Grom'gol instead of crossing the Eastern Kingdoms on foot. New lines: Undercity ↔ Grom'gol, Rut'theran ↔ Auberdine.
- Fixed: before you had opened a flight map, every flight point counted as known, so flights to places you had never visited could be recommended. Now Roadbook recommends flights on a continent only after you have opened a flight map there.
- Tracker: while the way leads to a flight master or dock first, the distance shown is the distance to that point ("350 yd · then Westfall 37.4 50.7").
- The way to a flight master or dock now shows as its own line in the plan. "Skip" (tracker button, `/rb skip`) or a right-click on that line skips it first, so the arrow points straight to the step; a second right-click brings it back. Useful when a dock or flight master is not exactly where Roadbook expects it.
- The TomTom arrow at a flight master now also names where to fly ("Flight master Thunder Bluff – Flight to Sun Rock Retreat"), as the map pin already did. If a zeppelin or boat follows, it is named too.

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
