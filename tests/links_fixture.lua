-- Linien der Testwelt (frei gewählte Punkte auf den Testkarten) und ein leeres Flugnetz:
-- die echten Daten gelten für die echte Welt, die es im Test nicht gibt.
local L = RB_NS.L
local ZEP, BOAT = L["Zeppelin %s – %s"], L["Boat %s – %s"]
LINKS_FIXTURE = {
    { 1411, 51, 13.5, 1420, 61, 59, "Horde", ZEP, "Orgrimmar", "Undercity" },
    { 1411, 50.5, 13, 1434, 31.5, 30, "Horde", ZEP, "Orgrimmar", "Grom'gol" },
    { 1420, 62, 59, 1434, 31.5, 29.5, "Horde", ZEP, "Undercity", "Grom'gol" },
    { 1413, 63.5, 38.5, 1434, 26, 73.5, nil, BOAT, "Ratchet", "Booty Bay" },
    { 1439, 32, 44, 1437, 4.5, 57, "Alliance", BOAT, "Auberdine", "Menethil", true },
    { 1437, 4.5, 57, 1424, 51, 70, "Alliance", BOAT, "Menethil", "Southshore", true },
    { 1424, 51, 70, 1439, 32, 44, "Alliance", BOAT, "Southshore", "Auberdine", true },
}
RB_NS.SetLinks(LINKS_FIXTURE)
RB_NS.SetFlightPaths({})
