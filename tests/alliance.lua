-- Allianz: eigene Linien, Rundfahrt nur in einer Richtung
-- Aufruf: FACTION=Alliance python tests/run.py . tests/alliance.lua
local ns = RB_NS
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "Roadbook")
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_LOGIN")
RunTimers()
-- Menethil (Kontinent 8), Southshore (8), Auberdine (Kontinent 1), Undercity/Grom'gol (8, nur Horde)
MAPOFF[1437] = { 0, 5000, 1000, 8 }; MAPOFF[1424] = { 0, 0, 1000, 8 }; MAPOFF[1439] = { 0, 0, 1000, 1 }
MAPOFF[1420] = { 3000, 0, 1000, 8 }; MAPOFF[1434] = { 3000, 9000, 1000, 8 }
ns.ClearRouteCache()
local menethil, southshore, auberdine = ns.WorldPos(1437, 10, 55), ns.WorldPos(1424, 50, 65), ns.WorldPos(1439, 35, 45)
local text, _, how = ns.LegText(menethil, southshore)
check(how == "schiff" and text:find("Southshore", 1, true), "Menethil → Southshore mit dem Schiff: " .. tostring(text))
check(select(3, ns.LegText(southshore, menethil)) == "lauf", "Southshore → Menethil fährt kein Schiff (Rundfahrt)")
text, _, how = ns.LegText(southshore, auberdine)
check(how == "schiff" and text:find("Southshore", 1, true), "Southshore → Auberdine: " .. tostring(text))
check(select(3, ns.LegText(ns.WorldPos(1420, 60, 58), ns.WorldPos(1434, 40, 40))) == "lauf", "Horde-Zeppelin zählt für die Allianz nicht")
print(("Allianz: %d ok, %d Fehler"):format(passes, fails))
