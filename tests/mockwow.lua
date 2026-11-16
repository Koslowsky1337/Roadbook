-- Minimale WoW-Attrappe zum Testen von Roadbook außerhalb des Spiels
LOG = {}
local function log(s) LOG[#LOG + 1] = s end

-- Frames ------------------------------------------------------------------
local Methods = {}
MOCK_METHODS = Methods     -- für tests/layoutsim.lua
ALLFRAMES = {}
local MT = {}
MT.__index = function(t, k)
    local m = Methods[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") and k ~= "Text" then return function() return nil end end
    return nil
end
local function Mock(kind, name, parent)
    return setmetatable({ __kind = kind, __name = name, __parent = parent, scripts = {}, shown = true, text = "",
        checked = false, enabled = true, points = {} }, MT)
end
_G.Mock = Mock
function Methods:SetScript(n, fn) self.scripts[n] = fn end
function Methods:GetScript(n) return self.scripts[n] end
function Methods:HookScript(n, fn) self.scripts[n] = fn end
function Methods:IsVisible()
    if not self.shown then return false end
    if self.__parent then return self.__parent:IsVisible() end
    return true
end
function Methods:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function Methods:Hide() self.shown = false end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.shown end
function Methods:SetText(t) self.text = t ~= nil and tostring(t) or "" end
function Methods:SetPoint(p, a, b, c, d) self.points[p] = { a, b, c, d } end
function Methods:GetText() return self.text end
function Methods:SetChecked(v) self.checked = v and true or false end
function Methods:GetChecked() return self.checked end
function Methods:GetWidth() return 300 end
function Methods:GetHeight() return 20 end
function Methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Methods:GetCenter() return 100, 100 end
function Methods:GetEffectiveScale() return 1 end
function Methods:CreateTexture() return Mock("Texture", nil, self) end
function Methods:CreateFontString() return Mock("FontString", nil, self) end
function Methods:Enable() self.enabled = true end
function Methods:Disable() self.enabled = false end
function Methods:SetEnabled(v) self.enabled = v and true or false end
function Methods:IsEnabled() return self.enabled end
function Methods:Click(button) if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end
function Methods:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
function Methods:UnregisterEvent(e) if self.events then self.events[e] = nil end end
function Methods:StartMoving() end
function Methods:StopMovingOrSizing() end

function CreateFrame(kind, name, parent, template)
    local f = Mock(kind, name, parent)
    f.template = template
    if template == "UICheckButtonTemplate" or template == "PanelTabButtonTemplate" then f.Text = Mock("FontString", nil, f) end
    if name then _G[name] = f end
    table.insert(ALLFRAMES, f)
    return f
end
UIParent = Mock("Frame", "UIParent")
Minimap = Mock("Frame", "Minimap")
GameTooltip = Mock("GameTooltip", "GameTooltip")
DEFAULT_CHAT_FRAME = Mock("Frame")
function DEFAULT_CHAT_FRAME:AddMessage(t) log("CHAT " .. t) end
UISpecialFrames = {}
SlashCmdList = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
date = os.date
time = os.time
GetTime = os.clock
GetCursorPosition = function() return 0, 0 end
IsShiftKeyDown = function() return SHIFT or false end
InCombatLockdown = function() return COMBAT or false end
UnitName = function() return "Tester" end
GetRealmName = function() return "Testrealm" end
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall",
    "GameFontDisable", "GameFontDisableSmall", "GameFontNormalLarge", "GameFontRedSmall", "ChatFontNormal" }) do
    _G[n] = Mock("Font")
end
BACKDROP_DIALOG_32_32 = {}
PanelTemplates_SelectTab = function() end
PanelTemplates_DeselectTab = function() end
PanelTemplates_TabResize = function() end

-- Timer -------------------------------------------------------------------
TIMERS = {}
C_Timer = { After = function(d, fn) table.insert(TIMERS, fn) end }
function RunTimers()
    for _ = 1, 10 do
        local list = TIMERS; TIMERS = {}
        if #list == 0 then return end
        for _, fn in ipairs(list) do fn() end
    end
end

-- Quests / Items / Karten ---------------------------------------------------
QS = { onQuest = {}, complete = {}, flagged = {} }
C_QuestLog = {
    IsOnQuest = function(q) return QS.onQuest[q] or false end,
    IsComplete = function(q) return QS.complete[q] or false end,
    ReadyForTurnIn = function(q) return QS.complete[q] or false end,
    IsQuestFlaggedCompleted = function(q) return QS.flagged[q] or false end,
}
ITEMS = {}
C_Item = { GetItemCount = function(id) return ITEMS[id] or 0 end }
MAPINFO = {}
C_Map = { GetMapInfo = function(m) return MAPINFO[m] or { name = "Karte" .. m } end }
TAXI = {}
C_TaxiMap = { GetTaxiNodesForMap = function(m) return TAXI[m] or {} end }

-- Makros ------------------------------------------------------------------
Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } }
MACROS = {}
function GetMacroInfo(i) local m = MACROS[i]; if m then return m.name, m.icon, m.body end end
function GetNumMacros()
    local a, c = 0, 0
    for i in pairs(MACROS) do if i <= 120 then a = a + 1 else c = c + 1 end end
    return a, c
end
function CreateMacro(name, icon, body, perChar)
    local from = perChar and 121 or 1
    for i = from, from + (perChar and 29 or 119) do
        if not MACROS[i] then MACROS[i] = { name = name, icon = icon, body = body }; log("CreateMacro " .. name); return i end
    end
end
function EditMacro(i, name, icon, body)
    local m = MACROS[i]
    if name then m.name = name end
    if icon then m.icon = icon end
    if body then m.body = body end
    log("EditMacro " .. m.name)
    return i
end

-- TomTom ------------------------------------------------------------------
TomTom = { waypoints = {}, cbs = {}, arrow = nil, dist = {} }
function TomTom.RegisterCallback(owner, event, fn) TomTom.cbs[event] = fn end
function TomTom:GetKey(w) return ("%d:%.4f:%.4f:%s"):format(w[1], w[2], w[3], tostring(w.title)) end
function TomTom:DefaultCallbacks(opts) return { minimap = {}, world = {}, distance = { [opts.arrivaldistance] = function() end } } end
function TomTom:WaypointExists(m, x, y, t)
    local e = self.waypoints[m]
    return e and e[self:GetKey({ m, x, y, title = t })] and true or false
end
function TomTom:AddWaypoint(m, x, y, opts)
    local uid = { m, x, y, title = opts.title, from = opts.from or "?", callbacks = opts.callbacks }
    self.waypoints[m] = self.waypoints[m] or {}
    self.waypoints[m][self:GetKey(uid)] = uid
    if opts.crazy then self.arrow = uid end
    return uid
end
function TomTom:RemoveWaypoint(uid)
    local e = self.waypoints[uid[1]]
    local k = self:GetKey(uid)
    if e and e[k] then
        e[k] = nil
        if self.arrow == uid then
            self.arrow = nil
            if self.cbs.ArrowTargetChanged then self.cbs.ArrowTargetChanged("ArrowTargetChanged", nil) end
        end
        if self.cbs.WaypointRemoved then self.cbs.WaypointRemoved("WaypointRemoved", uid) end
    end
end
function TomTom:SetCrazyArrow(uid, dist, title)
    self.arrow, self.arrowTitle = uid, title
    if self.cbs.ArrowTargetChanged then self.cbs.ArrowTargetChanged("ArrowTargetChanged", uid) end
end
function TomTom:IsCrazyArrowEmpty() return self.arrow == nil end
function TomTom:GetDistanceToWaypoint(uid) return self.dist[uid.title] or 1000 end
function TT_List()
    local out = {}
    for m, e in pairs(TomTom.waypoints) do for _, uid in pairs(e) do table.insert(out, uid.title .. "|" .. uid.from) end end
    table.sort(out)
    return out
end

-- Fehler / Umgebung -----------------------------------------------------------
ERRORS_FORWARDED = {}
function geterrorhandler() return function(e) table.insert(ERRORS_FORWARDED, tostring(e)) end end
function debugstack() return "[mock stack]" end
function GetBuildInfo() return "1.60.1", "70840", "Nov  5 2026", 16001 end
function GetLocale() return "deDE" end
C_AddOns = { GetAddOnMetadata = function(a, k) return "v4.4.1-release" end }

-- Karten / Questlog / QuestieDB ------------------------------------------------
UnitFactionGroup = function() return "Horde" end
function CreateVector2D(x, y) return { x = x, y = y } end
-- { x-Versatz, y-Versatz, Größe (Yards, Standard 100), Kontinent (Standard 1) }
MAPOFF = { [1413] = { 0, 0 }, [1442] = { -100, 0 }, [1456] = { 0, 100 } }
C_Map.GetWorldPosFromMapPos = function(map, v)
    local o = MAPOFF[map]; if not o then return nil end
    local size = o[3] or 100
    return o[4] or 1, { x = o[1] + v.x * size, y = o[2] + v.y * size }
end
-- Umkehrung: kleinste Karte, die den Weltpunkt enthält
C_Map.GetMapPosFromWorldPos = function(cont, v)
    local best, bestSize
    for map, o in pairs(MAPOFF) do
        local size = o[3] or 100
        if (o[4] or 1) == cont and v.x >= o[1] and v.x <= o[1] + size and v.y >= o[2] and v.y <= o[2] + size then
            if not bestSize or size < bestSize then best, bestSize = map, size end
        end
    end
    if not best then return nil end
    local o = MAPOFF[best]
    return best, { x = (v.x - o[1]) / bestSize, y = (v.y - o[2]) / bestSize }
end
ON_TAXI = false
UnitOnTaxi = function() return ON_TAXI end
PLAYER = { map = 1413, x = 0.576, y = 0.213 }
C_Map.GetBestMapForUnit = function() return PLAYER.map end
C_Map.GetPlayerMapPosition = function() return { x = PLAYER.x, y = PLAYER.y } end
QS.log = {}
C_QuestLog.GetNumQuestLogEntries = function() return #QS.log end
C_QuestLog.GetInfo = function(i) local q = QS.log[i]; if q then return { questID = q.id, title = q.title, isHeader = q.header } end end

local function DB(rows)
    return {
        Get = function(id, key) local r = rows[id]; return r and r[key] end,
        -- Grunddaten ohne Übersetzung: im Test unter "raw_<Feld>" abgelegt
        GetRaw = function(id, key) local r = rows[id]; return r and (r["raw_" .. key] or r[key]) end,
        GetAllIds = function() local ids = {}; for id in pairs(rows) do ids[#ids + 1] = id end; table.sort(ids); return ids end,
    }
end
UnitClass = function() return "Krieger", "WARRIOR" end
QuestDB = DB({
    [894] = { finishedBy = { nil, { 4141 } } }, [6541] = { finishedBy = { { 8582 } } },
    [97003] = { finishedBy = { { 267310 } } }, [872] = { finishedBy = { { 3429 } } },
    [6401] = { finishedBy = { { 11864 } } }, [5722] = { finishedBy = { { 11834 } } },
    [6607] = { name = "Angelquest", startedBy = { { 3004 } } },
    [999] = { finishedBy = { { 1, 2 } } }, [998] = { finishedBy = {} },
})
NpcDB = DB({
    [8582] = { name = "Kadrak", spawns = { [17] = { { 48.12, 5.42 } } } },
    [267310] = { name = "Gur'ak", spawns = { [17] = { { 52.65, 29.06 } } } },
    [3429] = { name = "Thork", spawns = { [17] = { { 51.5, 30.87 } } } },
    [11864] = { name = "Tammra Windfield", spawns = { [406] = { { 47.46, 58.38 } } } },
    [11834] = { name = "Maur Grimmtotem", spawns = { [2437] = { { -1, -1 } } } },
    [1] = { name = "Allianzler", friendlyToFaction = "A", spawns = { [17] = { { 58, 22 } } } },
    [2] = { name = "Hordler", friendlyToFaction = "H", spawns = { [17] = { { 70, 70 } } } },
    -- für die NPC-Suche (Spieler steht im Brachland bei 57.6, 21.3)
    [3001] = { name = "Naher Händler", npcFlags = 4 + 1, friendlyToFaction = "H", spawns = { [17] = { { 58, 23 } } } },
    [3002] = { name = "Ferner Händler", npcFlags = 4 + 16384, friendlyToFaction = "AH", spawns = { [17] = { { 20, 80 }, { 30, 70 } } } },
    [3003] = { name = "Allianz-Händler", subName = "Reagenzien", npcFlags = 4, friendlyToFaction = "A", spawns = { [17] = { { 57.7, 21.4 } } } },
    [3004] = { name = "Sorek", subName = "Kriegerlehrer", raw_subName = "Warrior Trainer", npcFlags = 16 + 3, friendlyToFaction = "H", spawns = { [17] = { { 50, 30 } } } },
    [3005] = { name = "Zauberin", subName = "Magierlehrerin", raw_subName = "Mage Trainer", npcFlags = 16, friendlyToFaction = "H", spawns = { [17] = { { 57, 22 } } } },
    [3006] = { name = "Schneiderin", subName = "Schneidergesellin", raw_subName = "Journeyman Tailor", npcFlags = 16, spawns = { [17] = { { 55, 25 } } } },
    [3008] = { name = "Mulgore-Händler", subName = "Reagenzien", npcFlags = 4, friendlyToFaction = "H", spawns = { [406] = { { 40, 40 } } } },
    [3009] = { name = "Schneidermeisterin", raw_subName = "Expert Tailor", npcFlags = 16, spawns = { [17] = { { 30, 60 } } } },
    [3010] = { name = "Angler", raw_subName = "Fisherman", npcFlags = 16, spawns = { [17] = { { 57, 21 } } } },
    [3007] = { name = "Händler ohne Ort", npcFlags = 4, spawns = { [2437] = { { -1, -1 } } } },
})
ItemDB = DB({ [16083] = { name = "Angelbuch", vendors = { 3002 } } })
-- Berufe des Spielers: Schneiderei 150/150, Angeln 150/150 (Tests schalten sie an)
SKILLS = {}
GetProfessions = function() local t = {}; for i = 1, #SKILLS do t[i] = i end; return unpack(t) end
GetProfessionInfo = function(i) local s = SKILLS[i]; return s.name, nil, s.rank, s.max, nil, nil, s.line end
ObjectDB = DB({ [4141] = { name = "Steuerkonsole", spawns = { [17] = { { 52.4, 11.65 } } } } })
LibQuestieDB = { Support = { Get = function(n)
    if n == "ZoneDB" then return { private = { areaIdToUiMapId = "return { [17] = 1413, [406] = 1442, [215] = 1412 }",
                                               areaIdToUiMapIdOverride = "return { }" } } end
end } }

CVARS = { UnitNameOwn = "1", UnitNameNPC = "1" }
GetCVar = function(n) return CVARS[n] end
SetCVar = function(n, v) CVARS[n] = v end
ADDON_SENT = {}
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
               SendAddonMessage = function(prefix, text, channel) ADDON_SENT[#ADDON_SENT + 1] = prefix .. "|" .. text .. "|" .. channel end }
IN_GUILD, IN_GROUP = false, false
IsInGuild = function() return IN_GUILD end
IsInGroup = function() return IN_GROUP end
IsInRaid = function() return false end
GetNumGroupMembers = function() return IN_GROUP and 2 or 0 end
-- Gruppenmitglieder: UNITS.party1 = { name, class, level, map, x, y }
UNITS, PLAYER_CLASS, SPELLS_KNOWN, BIND, HEARTH_CD = {}, "WARRIOR", {}, "Wegekreuz", 0
UnitName = function(u) if UNITS[u] then return UNITS[u].name end; if u == nil or u == "player" then return "Tester" end end
UnitClass = function(u) if UNITS[u] then return "?", UNITS[u].class end; return "Klasse", PLAYER_CLASS end
UnitLevel = function(u) return UNITS[u] and UNITS[u].level or 30 end
C_Map.GetBestMapForUnit = function(u) return (UNITS[u] or PLAYER).map end
C_Map.GetPlayerMapPosition = function(_, u) local p = UNITS[u] or PLAYER; return { x = p.x, y = p.y } end
IsPlayerSpell = function(id) return SPELLS_KNOWN[id] or false end
C_Spell = { GetSpellName = function(id) return id == 3567 and "Teleportieren: Orgrimmar" or nil end }
GetBindLocation = function() return BIND end
GetItemCooldown = function() return HEARTH_CD > 0 and GetTime() or 0, HEARTH_CD end
QUEST_XP = {}
GetQuestLogRewardXP = function(q) return QUEST_XP[q] or 0 end
UnitXPMax = function() return 5000 end
GetSubZoneText = function() return "Wegekreuz" end
GetZoneText = function() return "Brachland" end
PICKED = {}
function ClearCursor() end
function PickupMacro(i) table.insert(PICKED, i) end
