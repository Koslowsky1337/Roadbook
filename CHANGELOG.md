# Changelog

## 1.5.0

- Walks between zones now go through the zone crossings (passes, gates, bridges) instead of anywhere along the border. The starting list comes from Leatrix Maps; Roadbook checks it against the spots where you actually change zones on foot, corrects listed crossings and learns missing ones (shared by all your characters). If a crossing lies off the straight line, the TomTom arrow and the tracker lead you to it first (can be switched off). `/rb crossings` or the button in the options shows the crossings you have seen as text to pass on.

## 1.4.0

- Walks are no longer estimated as the straight line through mountains. Roadbook works out from the QuestieDB data (where NPCs and objects exist) which ground is reachable and estimates the way around. Where the data shows no connection, the straight line is used as before. Can be switched off in the options.

## 1.3.0

- Mages: your teleports are travel legs now. If a teleport gets you there faster, the tracker says so (needs a Rune of Teleportation).
- Hearthstone as a travel leg when it is ready and saves at least 15 minutes (adjustable). Roadbook learns where it leads when you set your home or use the stone once.
- Group: a mage with Roadbook shares their known portals invisibly with the group; the others get the tip to ask for a portal when it saves at least 10 minutes (adjustable). A warlock in the group who is much closer to your destination is suggested for a summon.
- Plans: each open turn-in shows its XP, and the plan and the tracker show the sum and its share of your current level; skipped steps do not count. Can be switched off in the options.
- The Roadbook window is wider, so step titles and places are no longer cut off as early.
- Options: all four can be switched off separately, including sharing your own portals.

## 1.2.2

- `/rb shots`: names above characters are hidden during the tour and the search shows sample professions, so the pictures contain nothing of your own.

## 1.2.1

- Update notice: Roadbook exchanges its version number invisibly with other Roadbook users in your guild and group and tells you in chat when a newer version exists. Only the version number is sent; the notice can be switched off in the options.

## 1.2.0

- NPC search: a zone field lists only the NPCs in that zone, also far away ones (up to 20). `/rb find vendor in Orgrimmar` does the same.
- NPC search: the text search also matches the title below the name, e.g. "portal" or "reagent". The text search finds every NPC and marks those of the other faction or another class.
- Options: two settings for the NPC search, whether the categories also list the other faction and whether Class trainer lists all classes. By default they show what fits your character.
- NPC search, professions: your own professions are green with your skill. Trainers show up to which skill they teach; those that cannot teach you anything new are grey and listed last. For Cooking, First Aid and Fishing at 150 the vendor of the Expert book comes first, at 225 the quest giver of the Artisan quest.
- Options: how much time a flight must save before it is recommended, how many search results are listed, how long the trash keeps items, and whether undiscovered flight masters are announced in chat.
- NPC search: "Copy /way" shows the TomTom command for the selected NPC to copy and share.

## 1.1.0

- New tab **NPC search**: pick a category (vendor, repair, innkeeper, banker, auctioneer, flight master, stable master, your class trainer, weapon master, riding and profession trainers) or type part of a name. Roadbook lists the nearest NPCs of your faction by travel time. *Show the way* sets a TomTom waypoint, *Add to plan* adds the NPC as a step.
- `/rb find <name or category>` points the arrow straight at the nearest match.

## 1.0.0

First release. Roadbook builds a turn-in round from your quest log, orders it by travel time (walking, known flight points, zeppelins, boats, tram) and drives the TomTom arrow from stop to stop. It also has your own plans, import and export as text, a notebook and a macro library. Requires TomTom and QuestieDB.

Since 1.0.0-beta2:

- An imported plan now starts from the beginning: steps you had ticked off by hand at the same places are open again. Quests you have really turned in stay done.

## 1.0.0-beta2

- Fixed: exported plans were garbled in the copy window, so sharing did not work. The game reads `|t`, `|n` and similar as control codes in text boxes, and the export used `|` as separator. The export now uses `;`. Text exported with 1.0.0-beta1 can still be imported.
- Fixed: the travel line in the plan showed an empty box instead of an arrow.
- `/rb shots` shows each window in turn with example data (a turn-in round with a zeppelin, sample notes and macros) and takes a screenshot of it, for the addon page. Your own plans, notes and macros are not shown and not changed.

## 1.0.0-beta1

Please report anything odd: https://github.com/Koslowsky1337/Roadbook/issues

- New tab **Options**: step tracker, minimap button, detailed log, and how much detour an undiscovered flight master is worth (0 to 10 minutes, default 2; also `/rb detour <seconds>`).
- Undiscovered flight masters are now part of the route: if one is almost on your way (up to two minutes of detour) it becomes a stop of its own, and a flight can start at a flight master you learn on the way. Flights *to* an undiscovered flight point are still never recommended.
- On a zeppelin or boat the dock waypoint now disappears by itself: when you are carried along without walking, the arrow switches to your destination.
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
