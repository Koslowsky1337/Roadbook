-- Roadbook: Kern (Speicher, Post, Ereignisse, Befehle)
local ADDON, ns = ...
local L = ns.L
_G.Roadbook = ns

-- Version aus der TOC (der Packager setzt sie aus dem Tag); im Entwicklungsordner steht dort der Platzhalter
local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local tocVersion = meta and meta(ADDON, "Version")
ns.VERSION = (type(tocVersion) == "string" and not tocVersion:find("@", 1, true)) and tocVersion or "dev"
ns.FROM = "Roadbook"

---------------------------------------------------------------------------
-- Protokoll (RoadbookDB.log)
-- Eintrag: { d = Datum, t = Zeit, l = Stufe, c = Bereich, m = Text, p = Charakter, s = Sitzung, st = Stack }
-- Stufen:  E = Fehler, W = Warnung, I = Info (immer gespeichert), D = Debug (nur mit /rb debug)
---------------------------------------------------------------------------

local MAX_ENTRIES = 400
local LEVEL_NAME = { E = "ERROR", W = "WARNING", I = "INFO", D = "DEBUG" }
local LEVEL_COLOR = { E = "ff6060", W = "ffb040", I = "a0c0ff", D = "909090" }

local pending = {}        -- Einträge vor dem Laden der SavedVariables
local echoed = {}         -- Fehler nur einmal pro Sitzung im Chat zeigen
ns.errorCount = 0

local function trim(log)
    local extra = #log - MAX_ENTRIES
    if extra > 0 then
        for _ = 1, extra do table.remove(log, 1) end
    end
end

function ns.LogInit()
    local db = ns.DB
    db.log = type(db.log) == "table" and db.log or {}
    db.logSession = (tonumber(db.logSession) or 0) + 1
    ns.session = db.logSession
    for _, e in ipairs(pending) do
        e.s = ns.session
        table.insert(db.log, e)
    end
    wipe(pending)
    trim(db.log)
end

function ns.DebugOn()
    return ns.DB and ns.DB.debug and true or false
end

function ns.Log(level, cat, fmt, ...)
    if level == "D" and not ns.DebugOn() then return end
    local msg
    if select("#", ...) > 0 then
        local ok, res = pcall(string.format, fmt, ...)
        msg = ok and res or (tostring(fmt) .. L[" [format error]"])
    else
        msg = tostring(fmt)
    end
    local entry = {
        d = date("%Y-%m-%d %H:%M:%S"), t = time(), l = level, c = cat, m = msg,
        p = ns.playerName or (UnitName and UnitName("player")) or "?", s = ns.session,
    }
    if ns.DB and ns.DB.log then
        table.insert(ns.DB.log, entry)
        trim(ns.DB.log)
    else
        table.insert(pending, entry)
    end
    if level == "E" then ns.errorCount = ns.errorCount + 1 end

    local echo = (level == "E" and not echoed[msg]) or (ns.DebugOn() and level ~= "I")
    if echo and ns.Print then
        if level == "E" then echoed[msg] = true end
        ns.Print(("|cff%s[%s]|r %s: %s%s"):format(LEVEL_COLOR[level], LEVEL_NAME[level], cat, msg,
            level == "E" and "  |cff909090(/rb log)|r" or ""))
    end
    return entry
end

---------------------------------------------------------------------------
-- Fehler abfangen: protokollieren und trotzdem an BugSack weiterreichen
---------------------------------------------------------------------------
local function handler(err)
    local stack = debugstack and debugstack(2, 12, 0) or ""
    return { err = err, stack = stack }
end

local function collect(ok, ...)
    return ok, select("#", ...), { ... }
end

function ns.Safe(cat, fn, ...)
    local n, args = select("#", ...), { ... }
    local ok, rn, r = collect(xpcall(function() return fn(unpack(args, 1, n)) end, handler))
    if ok then return unpack(r, 1, rn) end
    local info = type(r[1]) == "table" and r[1] or { err = r[1] }
    local entry = ns.Log("E", cat, "%s", tostring(info.err))
    if entry then entry.st = info.stack end
    local eh = geterrorhandler and geterrorhandler()
    if eh then pcall(eh, info.err) end
    return nil
end

function ns.Wrap(cat, fn)
    return function(...) return ns.Safe(cat, fn, ...) end
end

-- Alle per SetScript gesetzten Skripte eines Frames automatisch absichern
function ns.AutoWrap(frame, cat)
    local orig = frame.SetScript
    frame.SetScript = function(self, script, fn)
        if type(fn) == "function" and script ~= "OnUpdate" then
            fn = ns.Wrap(cat .. ":" .. script, fn)
        end
        return orig(self, script, fn)
    end
    return frame
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function ns.FormatLog(maxLines)
    local log = ns.DB and ns.DB.log or {}
    local lines = {}
    local from = math.max(1, #log - (maxLines or 250) + 1)
    local lastSession
    for i = from, #log do
        local e = log[i]
        if e.s ~= lastSession then
            table.insert(lines, (L["---- Session %s%s ----"]):format(tostring(e.s), e.s == ns.session and L[" (current)"] or ""))
            lastSession = e.s
        end
        table.insert(lines, ("%s [%s] %s/%s: %s"):format(e.d or "?", LEVEL_NAME[e.l] or e.l, e.p or "?", e.c or "?", e.m or ""))
        if e.st and e.st ~= "" then table.insert(lines, "    " .. e.st:gsub("\n", "\n    ")) end
    end
    if #lines == 0 then return L["The log is empty."] end
    return table.concat(lines, "\n")
end

function ns.SessionErrors()
    local n = 0
    for _, e in ipairs(ns.DB and ns.DB.log or {}) do
        if e.s == ns.session and e.l == "E" then n = n + 1 end
    end
    return n
end


---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
function ns.Print(text)
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then frame:AddMessage("|cffffd100Roadbook:|r " .. tostring(text)) end
end

local function fill(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            t[k] = (type(v) == "table") and {} or v
        end
    end
    return t
end

local function str(v) if v == nil then return nil end return tostring(v) end
ns.str = str

function ns.Trim(s)
    return ((s or ""):gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function ns.FirstLine(s)
    s = ns.Trim(s)
    return (s:match("^[^\n]*") or s)
end

-- Einfache Prüfsumme, um zu merken, welche Fassung einer Post-Notiz/eines Post-Plans ausgeblendet wurde
function ns.Hash(s)
    s = tostring(s or "")
    local h = 0
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
    return h
end

function ns.NextId(prefix)
    ns.DB.seq = (ns.DB.seq or 0) + 1
    return ("%s%d"):format(prefix or "n", ns.DB.seq)
end

---------------------------------------------------------------------------
-- Speicher
-- RoadbookDB      (Account):   Notizen "für alle Charaktere", Fensterposition,
--                              Minimap-Knopf, Sicherungen von Account-Makros
-- RoadbookCharDB  (Charakter): alles andere – aktiver Plan, Fortschritt,
--                              eigene Pläne, eigene Notizen, Makro-Sicherungen
---------------------------------------------------------------------------
local DB_DEFAULTS = {
    seq = 0, notes = {}, macroBackups = {}, minimap = {}, frame = false,
    debug = false, log = {}, logSession = 0, hidden = {}, tracker = {},
}
local CHAR_DEFAULTS = {
    activePlan = false, selectedPlan = false, seenPost = false,
    done = {}, turnedIn = {}, skipped = {}, modes = {}, focus = {},
    plans = {}, notes = {}, macroBackups = {}, finished = {},
    trash = {}, hidden = {}, taxi = {},
}

local function InitDB()
    RoadbookDB = fill(type(RoadbookDB) == "table" and RoadbookDB or {}, DB_DEFAULTS)
    RoadbookCharDB = fill(type(RoadbookCharDB) == "table" and RoadbookCharDB or {}, CHAR_DEFAULTS)
    ns.DB, ns.C = RoadbookDB, RoadbookCharDB
    ns.LogInit()
end

---------------------------------------------------------------------------
-- Post: Inhalte von außen (Pläne, Notizen, Makro-Vorschläge). Ein eigenes kleines
-- Addon (z. B. „Roadbook_Post“, Dependencies: Roadbook) setzt RoadbookPost = [==[ return { ... } ]==]. Der Text wird hier
-- ohne Zugriff auf irgendetwas ausgewertet (reine Daten). Ein Fehler darin
-- legt nur die Post lahm, nicht das Addon.
---------------------------------------------------------------------------
local function charMatches(key)
    if type(key) ~= "string" then return false end
    return key == ns.playerName or key == (ns.playerName .. "-" .. (ns.realm or ""))
end

local function list(t) return type(t) == "table" and t or {} end

function ns.LoadPost()
    local P = { version = nil, message = nil, plans = {}, notes = {}, macros = {} }
    ns.post, ns.postError = P, nil

    local src = _G.RoadbookPost
    if type(src) ~= "string" or ns.Trim(src) == "" then
        ns.Log("I", "post", "No post found (no Roadbook_Post addon, or RoadbookPost is empty).")
        return
    end

    local fn, err = loadstring(src, "Roadbook-Post")
    if not fn then ns.postError = tostring(err) end
    if fn then
        setfenv(fn, {})
        local ok, data = pcall(fn)
        if not ok then ns.postError = tostring(data)
        elseif type(data) ~= "table" then ns.postError = L["The post does not contain a table."]
        else ns.ParsePost(P, data) end
    end
    if ns.postError then ns.Log("E", "post", "Post is broken: %s", ns.postError) end
end

function ns.ParsePost(P, data)
    local warn = function(fmt, ...) ns.Log("W", "post", fmt, ...) end

    P.version = str(data.version) or "?"
    local global = list(data.global)
    local mine, found = {}, false
    for key, section in pairs(list(data.chars)) do
        if charMatches(key) and type(section) == "table" then mine, found = section, true end
    end
    if not found then ns.Log("I", "post", "No section for %s in the post.", tostring(ns.playerName)) end
    P.message = str(mine.message) or str(data.message)

    -- Notizen aus der Post (nur lesen)
    local function addNote(n, allChars)
        if type(n) ~= "table" then return end
        local id = "c:" .. (str(n.id) or str(n.title) or tostring(#P.notes + 1))
        table.insert(P.notes, {
            id = id, title = str(n.title) or L["Note"], body = str(n.body) or "",
            post = true, account = allChars, plan = str(n.plan),
        })
    end
    if P.message then
        table.insert(P.notes, { id = "c:post", title = L["Post of "] .. P.version, body = P.message, post = true })
    end
    for _, n in ipairs(list(mine.notes)) do addNote(n, false) end
    for _, n in ipairs(list(global.notes)) do addNote(n, true) end

    -- Pläne (immer pro Charakter)
    for i, p in ipairs(list(mine.plans)) do
        local plan = ns.NormalizePlan(p, "post", function(msg) warn("Plan %s: %s", tostring(p.id or i), msg) end)
        if plan then table.insert(P.plans, plan) else warn("Plan no. %d is invalid (no steps?) – skipped.", i) end
    end

    -- Makros: Charakter-Makros aus dem Charakter-Abschnitt, Account-Makros global
    local function addMacro(m, scope)
        if type(m) ~= "table" or type(m.name) ~= "string" or type(m.body) ~= "string" then
            warn("Macro without name/text skipped (%s).", scope)
            return
        end
        table.insert(P.macros, {
            name = m.name, body = m.body, scope = scope, icon = m.icon,
            group = str(m.group) or L["Other"], note = str(m.note),
        })
    end
    for _, m in ipairs(list(mine.macros)) do addMacro(m, "char") end
    for _, m in ipairs(list(global.macros)) do addMacro(m, "account") end
    ns.Log("I", "post", "Post %s loaded: %d plans, %d notes, %d macros.", P.version, #P.plans, #P.notes, #P.macros)
end

function ns.HasNewPost()
    return ns.post and ns.post.version and ns.post.version ~= ns.C.seenPost
end

function ns.MarkPostSeen()
    if ns.post and ns.post.version then ns.C.seenPost = ns.post.version end
    if ns.UpdateMinimapBadge then ns.UpdateMinimapBadge() end
end

---------------------------------------------------------------------------
-- Gebündelte Aktualisierung
---------------------------------------------------------------------------
local refreshQueued = false
function ns.ScheduleRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.25, function()
        refreshQueued = false
        ns.Refresh()
    end)
end

function ns.Refresh()
    -- /rb shots zeigt gestellte Daten: keine Wegpunkte setzen, nur neu zeichnen
    if ns.staging then if ns.UpdateUI then ns.UpdateUI() end return end
    ns.Safe("refresh", function()
        if ns.SyncWaypoints then ns.SyncWaypoints() end
        if ns.CheckProgress then ns.CheckProgress() end
    end)
    if ns.UpdateUI then ns.UpdateUI() end
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.eventFrame = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", ns.Wrap("event", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            InitDB()
            ev:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        ns.playerName = UnitName("player")
        ns.realm = GetRealmName and GetRealmName() or ""
        local build, buildNum = "?", "?"
        if GetBuildInfo then build, buildNum = GetBuildInfo() end
        local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local ttVersion = _G.TomTom and meta and meta("TomTom", "Version") or "fehlt"
        ns.Log("I", "start", "Roadbook %s · Client %s (%s) · %s · TomTom %s · %s-%s",
            ns.VERSION, tostring(build), tostring(buildNum), GetLocale and GetLocale() or "?",
            tostring(ttVersion), tostring(ns.playerName), tostring(ns.realm))
        ns.LoadPost()
        if ns.InitTomTom then ns.InitTomTom() end
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end

        for _, e in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE",
                              "BAG_UPDATE_DELAYED", "UPDATE_MACROS", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
                              "TAXIMAP_OPENED", "PLAYER_CONTROL_GAINED", "ZONE_CHANGED_NEW_AREA" }) do
            pcall(ev.RegisterEvent, ev, e)
        end

        -- Aktiven Plan nach dem Einloggen wieder laden (TomTom braucht einen Moment)
        C_Timer.After(3, ns.Wrap("login-plan", function()
            if ns.PurgeTrash then ns.PurgeTrash() end
            local plan = ns.ActivePlan and ns.ActivePlan()
            if plan then
                ns.Log("I", "plan", "Active plan loaded again after login: %s", plan.id)
            elseif ns.C.activePlan then
                ns.Log("W", "plan", "Active plan %s no longer exists – unloaded.", tostring(ns.C.activePlan))
                ns.C.activePlan = false
            end
            ns.Refresh()
        end))

        C_Timer.After(5, ns.Wrap("login-post", function()
            if not ns.DB.welcomed then
                ns.DB.welcomed = true
                ns.Print(L["Welcome! |cffffffff/rb|r opens Roadbook – the quick guide is in the Notes tab."])
            end
            if ns.postError then
                ns.Print(L["|cffff6060Post is broken:|r "] .. ns.postError)
            elseif ns.HasNewPost() then
                local extra = ""
                local pending = ns.CountPendingMacros and ns.CountPendingMacros() or 0
                if pending > 0 then extra = (L[" – %d macro(s) new/changed"]):format(pending) end
                ns.Print((L["|cff80ff80New post|r (version %s)%s. Open with |cffffffff/rb|r."]):format(ns.post.version, extra))
                if ns.post.message then ns.Print(ns.FirstLine(ns.post.message)) end
            end
        end))

    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        if questID then
            ns.C.turnedIn[questID] = time()
            ns.Log("I", "quest", "Quest %d turned in.", questID)
        end
        ns.ScheduleRefresh()

    elseif event == "TAXIMAP_OPENED" then
        if ns.OnTaxiMapOpened then ns.OnTaxiMapOpened() end

    elseif event == "UPDATE_MACROS" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if ns.UpdateUI then ns.UpdateUI() end

    else
        ns.ScheduleRefresh()
    end
end))

---------------------------------------------------------------------------
-- Befehle
---------------------------------------------------------------------------
local HELP = {
    L["|cffffffff/rb|r – open or close the window"],
    L["|cffffffff/rb plan <name>|r – load a plan (part of the name is enough)"],
    L["|cffffffff/rb off|r – unload the active plan (removes its waypoints)"],
    L["|cffffffff/rb skip|r – skip the current step"],
    L["|cffffffff/rb reset|r – reset the active plan (skipped and ticked-off steps open again)"],
    L["|cffffffff/rb waypoints|r – set the TomTom waypoints and the arrow again"],
    L["|cffffffff/rb sort|r – order the open steps by travel time"],
    L["|cffffffff/rb route|r – route description with flights and estimated time"],
    L["|cffffffff/rb here [name]|r – remember your current position as a step"],
    L["|cffffffff/rb tracker|r – show or hide the step tracker"],
    L["|cffffffff/rb note <title>|r – create a new note"],
    L["|cffffffff/rb turnin|r – build and load a turn-in round from all quests ready to turn in"],
    L["|cffffffff/rb tomtom <name>|r – save your current TomTom waypoints as a plan"],
    L["|cffffffff/rb trash|r – restore deleted notes and plans"],
    L["|cffffffff/rb minimap|r – show or hide the minimap button"],
    L["|cffffffff/rb log|r – show the log (|cffffffff/rb log clear|r)"],
    L["|cffffffff/rb import|r – import a plan from text · |cffffffff/rb export|r – show the selected plan as text"],
    L["|cffffffff/rb fm|r – waypoint to an undiscovered flight master nearby"],
    L["|cffffffff/rb options|r – settings · |cffffffff/rb detour <seconds>|r – detour worth taking for an undiscovered flight master (0 = off)"],
    L["|cffffffff/rb debug|r – detailed log on/off · |cffffffff/rb layout|r – check the open windows for cut-off text"],
}

local function findPlan(query)
    query = (query or ""):lower()
    if query == "" then return nil end
    for _, plan in ipairs(ns.GetPlans()) do
        if plan.title:lower() == query or plan.id:lower() == query then return plan end
    end
    for _, plan in ipairs(ns.GetPlans()) do
        if plan.title:lower():find(query, 1, true) then return plan end
    end
end

-- Befehlswörter: englisch, die deutschen bleiben als Zweitname
local ALIAS = {
    load = "plan", laden = "plan", stop = "off", aus = "off", next = "skip", weiter = "skip",
    ["zurück"] = "reset", zuruecksetzen = "reset", ["zurücksetzen"] = "reset",
    wp = "waypoints", wegpunkte = "waypoints", pfeil = "waypoints", arrow = "waypoints",
    sortieren = "sort", weg = "route", notiz = "note", neu = "note", new = "note",
    abgabe = "turnin", abgaben = "turnin", hier = "here", papierkorb = "trash",
    flugmeister = "fm", importieren = "import", exportieren = "export",
    umweg = "detour", optionen = "options", einstellungen = "options", settings = "options",
    fotos = "shots", screenshots = "shots",
}

local function planFor(rest)
    return (rest ~= "" and findPlan(rest)) or ns.ActivePlan() or ns.GetPlan(ns.C.selectedPlan)
end

function ns.HandleSlash(msg)
    msg = ns.Trim(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = (cmd or ""):lower()
    cmd = ALIAS[cmd] or cmd

    if cmd == "" then
        ns.ToggleFrame()
    elseif cmd == "plan" then
        local plan = findPlan(rest)
        if plan then ns.ActivatePlan(plan.id) else ns.Print(L["No plan found: "] .. rest) end
    elseif cmd == "off" then
        ns.DeactivatePlan()
    elseif cmd == "skip" then
        ns.SkipCurrentStep()
    elseif cmd == "reset" then
        local plan = planFor(rest)
        if plan then ns.ResetPlan(plan) else ns.Print(L["No plan loaded – use “/rb reset <name>” or “Reset” in the Roadbook window."]) end
    elseif cmd == "waypoints" then
        ns.ResetWaypoints()
    elseif cmd == "sort" then
        local plan = planFor(rest)
        if plan then ns.SortPlan(plan) else ns.Print(L["No plan loaded."]) end
    elseif cmd == "route" then
        ns.ShowCopy(L["Route description"], ns.RouteText(planFor(rest)))
    elseif cmd == "note" then
        local note = ns.CreateNote(rest ~= "" and rest or nil)
        ns.ShowFrame("notes")
        if ns.SelectNote then ns.SelectNote(note.id) end
    elseif cmd == "turnin" then
        ns.CreateTurnInPlan()
    elseif cmd == "tomtom" then
        ns.CreatePlanFromTomTom(rest ~= "" and rest or nil)
    elseif cmd == "import" then
        ns.ShowImport()
    elseif cmd == "export" then
        local plan = planFor(rest)
        if plan then ns.ShowCopy(L["Export: "] .. plan.title, ns.ExportPlan(plan)) else ns.Print(L["No plan loaded or selected."]) end
    elseif cmd == "fm" then
        ns.WaypointNewTaxi()
    elseif cmd == "detour" then
        if tonumber(rest) then ns.SetPickupMax(tonumber(rest)) end
        ns.Print((L["Detour for an undiscovered flight master: %s"]):format(ns.PickupText()))
    elseif cmd == "options" then
        ns.ShowFrame("options")
    elseif cmd == "shots" then
        ns.PhotoTour()
    elseif cmd == "log" then
        local arg = rest:lower()
        if arg == "clear" or arg == "leeren" then
            wipe(ns.DB.log)
            ns.Print(L["Log cleared."])
        else
            ns.ShowCopy(L["Roadbook log"], ns.FormatLog(250))
        end
    elseif cmd == "debug" then
        ns.DB.debug = not ns.DB.debug
        ns.Print(L["Debug log "] .. (ns.DB.debug and L["|cff80ff80on|r – warnings also appear in chat."] or L["|cffff6060off|r."]))
        ns.Log("I", "debug", "Debug %s", ns.DB.debug and "on" or "off")
    elseif cmd == "layout" then
        local found = ns.LayoutCheck()
        ns.Print((L["Layout check: %d problem(s) – see |cffffffff/rb log|r"]):format(#found))
    elseif cmd == "here" then
        ns.AddHereStep(nil, rest ~= "" and rest or nil)
    elseif cmd == "tracker" then
        ns.DB.tracker = ns.DB.tracker or {}
        ns.DB.tracker.hidden = not ns.DB.tracker.hidden
        ns.Print(L["Tracker "] .. (ns.DB.tracker.hidden and L["hidden."] or L["shown."]))
        ns.UpdateUI()
    elseif cmd == "trash" then
        ns.ShowTrash()
    elseif cmd == "minimap" then
        ns.DB.minimap.hidden = not ns.DB.minimap.hidden
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
end

SLASH_ROADBOOK1 = "/rb"
SLASH_ROADBOOK2 = "/roadbook"
SlashCmdList["ROADBOOK"] = function(msg) ns.Safe("slash", ns.HandleSlash, msg) end

-- Tastaturbelegung (Bindings.xml) und Addon-Menü an der Minimap
BINDING_HEADER_ROADBOOK = "Roadbook"
BINDING_NAME_ROADBOOK_TOGGLE = L["Open/close Roadbook"]
BINDING_NAME_ROADBOOK_SKIP = L["Skip the current step"]
function Roadbook_Toggle() ns.Safe("key", ns.ToggleFrame) end
function Roadbook_SkipStep() ns.Safe("key", ns.SkipCurrentStep) end
function Roadbook_OnAddonCompartmentClick() ns.Safe("compartment", ns.ToggleFrame) end
