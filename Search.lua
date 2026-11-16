-- Roadbook: NPC-Suche (Händler, Lehrer, Gastwirt … aus QuestieDB) und Reiter „NPC-Suche“
local ADDON, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Kategorien. „flag“ ist das NPC-Flag aus QuestieDB; „titles“ sind Teile des
-- englischen Titels aus den Grunddaten (GetRaw), damit die Zuordnung in
-- jeder Client-Sprache gilt („Warrior Trainer“, „Journeyman Tailor“ …).
-- Berufe: „skill“ ist die Fertigkeits-Nummer des Spiels. Bei Kochen, Erster
-- Hilfe und Angeln lehren die Lehrer nur bis „plain“ (150); die Stufe danach
-- steht in einem Buch („book“, Item-Nummer), das ein Händler verkauft, und die
-- Stufe ab 225 gibt es als Quest („quest“, je Fraktion). Beides steht so in den
-- Forever-Daten von QuestieDB (Bücher mit Händlern, Quests mit Questgebern).
---------------------------------------------------------------------------
local TRAINER = 16
local CATS = {
    { head = L["Services"] },
    { key = "vendor", label = L["Vendor"], flag = 4 },
    { key = "repair", label = L["Repair"], flag = 16384 },
    { key = "inn", label = L["Innkeeper"], flag = 128 },
    { key = "bank", label = L["Banker"], flag = 256 },
    { key = "auction", label = L["Auctioneer"], flag = 4096 },
    { key = "flight", label = L["Flight master"], flag = 8 },
    { key = "stable", label = L["Stable master"], flag = 8192 },
    -- Objekte aus QuestieDB: „objects“ sind englische Grundnamen (ganz oder als letztes Wort)
    { head = L["Places"] },
    { key = "mailbox", label = L["Mailbox"], objects = { "mailbox" } },
    { key = "forge", label = L["Forge"], objects = { "forge" } },
    { key = "anvil", label = L["Anvil"], objects = { "anvil" } },
    { key = "fire", label = L["Cooking fire"], objects = { "campfire", "cooking fire", "stove", "bonfire", "cozy fire" } },
    { key = "stone", label = L["Meeting stone"], objects = { "meeting stone" } },
    { key = "moonwell", label = L["Moonwell"], objects = { "moonwell" } },
    { head = L["Trainers"] },
    { key = "class", label = L["Class trainer"], flag = TRAINER, class = true },
    { key = "pet", label = L["Pet trainer"], flag = TRAINER, titles = { "pet trainer" }, only = "HUNTER" },
    { key = "weapon", label = L["Weapon master"], flag = TRAINER, titles = { "weapon master" } },
    { key = "riding", label = L["Riding trainer"], flag = TRAINER, titles = { "riding instructor" } },
    { head = L["Professions"] },
    { key = "alchemy", label = L["Alchemy"], flag = TRAINER, titles = { "alchem" }, skill = 171 },
    { key = "blacksmithing", label = L["Blacksmithing"], flag = TRAINER, titles = { "blacksmith", "armor crafter", "weapon crafter", "armorsmith", "weaponsmith" }, skill = 164 },
    { key = "enchanting", label = L["Enchanting"], flag = TRAINER, titles = { "enchant" }, skill = 333 },
    { key = "engineering", label = L["Engineering"], flag = TRAINER, titles = { "engineer" }, skill = 202 },
    { key = "herbalism", label = L["Herbalism"], flag = TRAINER, titles = { "herbalis" }, skill = 182 },
    { key = "leatherworking", label = L["Leatherworking"], flag = TRAINER, titles = { "leatherwork", "leathercraft" }, skill = 165 },
    { key = "mining", label = L["Mining"], flag = TRAINER, titles = { "miner", "mining" }, skill = 186 },
    { key = "skinning", label = L["Skinning"], flag = TRAINER, titles = { "skinn" }, skill = 393 },
    { key = "tailoring", label = L["Tailoring"], flag = TRAINER, titles = { "tailor" }, skill = 197 },
    { key = "cooking", label = L["Cooking"], flag = TRAINER, titles = { "cook", "butcher" }, skill = 185, plain = 150, book = 16072, quest = { H = 6610, A = 6610 } },
    { key = "firstaid", label = L["First Aid"], flag = TRAINER, titles = { "first aid", "physician", "surgeon", "medic" }, skill = 129, plain = 150, book = 16084, quest = { H = 6622, A = 6624 } },
    { key = "fishing", label = L["Fishing"], flag = TRAINER, titles = { "fish" }, skill = 356, plain = 150, book = 16083, quest = { H = 6607, A = 6607 } },
}

local CLASSES = { "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" }

local function playerClass()
    local _, token = UnitClass("player")
    return token or ""
end

-- Einstellungen der Suche (Reiter Optionen): otherFaction, allClasses.
-- Standard: Kategorien zeigen nur, was zu diesem Charakter passt.
function ns.SearchOpt()
    ns.DB.search = ns.DB.search or {}
    return ns.DB.search
end

-- Kategorien für diesen Charakter (Tierlehrer nur für Jäger)
function ns.NpcCategories()
    local out, class = {}, playerClass()
    for _, c in ipairs(CATS) do
        if not c.only or c.only == class then out[#out + 1] = c end
    end
    return out
end

local function findCategory(text)
    text = text:lower()
    for _, c in ipairs(ns.NpcCategories()) do
        if c.key and (c.key == text or c.label:lower() == text) then return c end
    end
end

---------------------------------------------------------------------------
-- Verzeichnis aller NPCs (Name, Flags) und dahinter aller Objekte (Briefkästen,
-- Schmieden, Erzadern …; idx.obj). Wird beim ersten Öffnen des Reiters
-- häppchenweise aufgebaut, damit das Spiel nicht ruckt; eine Suche vor dem
-- Ende liest den Rest in einem Zug.
---------------------------------------------------------------------------
local CHUNK = debugprofilestop and 10 or 400   -- je Stück; ns.RunSliced misst die Zeit
local idx

local function hasDB() return _G.NpcDB and NpcDB.Get and NpcDB.GetAllIds end

local function indexStep(all)
    if not idx then
        local ok, ids = pcall(NpcDB.GetAllIds)
        idx = { src = (ok and type(ids) == "table") and ids or {}, pos = 0, ids = {}, names = {}, subs = {}, flags = {}, obj = {}, raw = {} }
        idx.npcs = #idx.src
        local ODB = _G.ObjectDB
        local ok2, oids = pcall(ODB and ODB.GetAllIds or error)
        for _, id in ipairs(ok2 and type(oids) == "table" and oids or {}) do idx.src[#idx.src + 1] = id end
    end
    local last = all and #idx.src or math.min(#idx.src, idx.pos + CHUNK)
    for i = idx.pos + 1, last do
        local id = idx.src[i]
        local isObj = i > idx.npcs
        local db = isObj and ObjectDB or NpcDB
        local name = db.Get(id, "name")
        if type(name) == "string" and name ~= "" then
            local n = #idx.ids + 1
            local sub = not isObj and NpcDB.Get(id, "subName")
            idx.ids[n], idx.names[n], idx.flags[n] = id, name:lower(), not isObj and tonumber(NpcDB.Get(id, "npcFlags")) or 0
            idx.subs[n] = type(sub) == "string" and sub:lower() or ""
            if isObj then
                idx.obj[n] = true
                local okR, rawName = pcall(ObjectDB.GetRaw or ObjectDB.Get, id, "name")
                idx.raw[n] = (okR and type(rawName) == "string") and rawName:lower() or ""
            end
        end
    end
    idx.pos = last
    idx.done = last >= #idx.src
    if idx.done and not idx.logged then
        idx.logged = true
        ns.Log("I", "search", "NPC index ready: %d NPCs and objects", #idx.ids)
    end
    return idx.done
end

function ns.BuildNpcIndex()
    if not hasDB() or (idx and (idx.done or idx.running)) then return end
    indexStep()
    idx.running = true
    ns.RunSliced(function() return indexStep() end, function()
        idx.running = nil
        if ns.WarmSpawns then ns.WarmSpawns() end
    end)
end

local titleCache = {}
local function rawTitle(id)
    local t = titleCache[id]
    if t == nil then
        local ok, v = pcall(NpcDB.GetRaw or NpcDB.Get, id, "subName")
        t = (ok and type(v) == "string") and v:lower() or ""
        titleCache[id] = t
    end
    return t
end

local function hasFlag(flags, f) return flags % (f * 2) >= f end

local function inCategory(cat, i)
    if cat.objects then
        if not idx.obj[i] then return false end
        local n = idx.raw[i]   -- englischer Grundname: gilt in jeder Client-Sprache
        for _, o in ipairs(cat.objects) do
            if n == o or n:sub(-#o - 1) == " " .. o then return true end
        end
        return false
    end
    if idx.obj[i] or not hasFlag(idx.flags[i], cat.flag) then return false end
    local t = rawTitle(idx.ids[i])
    if cat.class then
        if not ns.SearchOpt().allClasses then return t:find(playerClass():lower() .. " trainer", 1, true) ~= nil end
        for _, c in ipairs(CLASSES) do
            if t:find(c .. " trainer", 1, true) then return true end
        end
        return false
    end
    if not cat.titles then return true end
    for _, part in ipairs(cat.titles) do
        if t:find(part, 1, true) then return true end
    end
    return false
end

-- Rang und Höchstwert des Spielers in einem Beruf (nil: nicht gelernt)
function ns.PlayerSkill(skill)
    if ns.staging then   -- Fototour: Beispiel-Berufe
        local demo = ns.staging.skills and ns.staging.skills[skill]
        if demo then return demo[1], demo[2] end
        return nil
    end
    if GetProfessions and GetProfessionInfo then
        local p = { GetProfessions() }
        for k = 1, 6 do
            if p[k] then
                local ok, _, _, rank, max, _, _, line = pcall(GetProfessionInfo, p[k])
                if ok and line == skill then return rank or 0, max or 0 end
            end
        end
    end
    local SI = _G.C_SkillInfo
    if SI and SI.GetNumSkillLines and SI.GetSkillLineInfo then
        local ok, n = pcall(SI.GetNumSkillLines)
        for i = 1, ok and n or 0 do
            local ok2, line = pcall(SI.GetSkillLineInfo, i)
            if ok2 and type(line) == "table" and line.skillID == skill and not line.isHeader then
                return line.rank or 0, line.maxRank or 0
            end
        end
    end
end

-- Bis zu welchem Wert lehrt ein Berufslehrer? Steht im englischen Grundtitel
-- („Journeyman Tailor“, „Expert Alchemist“ …); nil, wenn der Titel nichts sagt.
local CAPS = { { "apprentice", 75 }, { "junior", 75 }, { "journeyman", 150 }, { "expert", 225 },
               { "artisan", 300 }, { "master", 300 }, { "superior", 300 } }
local function teachCap(id, cat)
    if not cat.skill then return nil end
    local t = rawTitle(id)
    for _, c in ipairs(CAPS) do
        if t:find(c[1], 1, true) then return c[2] end
    end
    return cat.plain
end

-- Passt der NPC nicht zu diesem Charakter? Liefert dann den Grund als Text.
local function unfit(id, faction)
    local friendly = NpcDB.Get(id, "friendlyToFaction")
    if type(friendly) == "string" and friendly ~= "" and not friendly:find(faction, 1, true) then
        return L["other faction"]
    end
    local t, mine = rawTitle(id), playerClass():lower()
    for _, c in ipairs(CLASSES) do
        if c ~= mine and t:find(c .. " trainer", 1, true) then return L["other class"] end
    end
end

local zoneNames = {}
local function zoneName(map)
    local n = zoneNames[map]
    if not n then
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
        n = (info and info.name or "?"):lower()
        zoneNames[map] = n
    end
    return n
end

-- Nächster Fundort eines NPCs nach Luftlinie (anderer Kontinent: weit hinten);
-- mit „place“ zählen nur Fundorte in Gebieten, deren Name diesen Text enthält
-- Die Fundorte werden je NPC/Objekt einmal gelesen und gemerkt: QuestieDB entpackt sie bei
-- jeder Abfrage neu, und an den gemerkten Punkten hängen auch die Wege zu den Flugmeistern.
local spawnCache = { npc = {}, obj = {} }
local function spawnsOf(id, db)
    local cache = db and spawnCache.obj or spawnCache.npc
    local list = cache[id]
    if list then return list end
    list = {}
    local spawns = (db or NpcDB).Get(id, "spawns")
    local any = false
    for area, pts in pairs(type(spawns) == "table" and spawns or {}) do
        local map = ns.AreaToUiMap(area)
        for _, xy in ipairs(type(pts) == "table" and pts or {}) do
            local x, y = xy[1], xy[2]
            if map and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                any = true
                local p = ns.WorldPos(map, x, y, true)
                if p then
                    list[#list + 1] = { map = map, x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10, p = p }
                end
            end
        end
    end
    if #list > 0 or not any then cache[id] = list end   -- Kartendaten fehlen noch: später erneut versuchen
    return list
end

local function nearestSpawn(id, here, place, db)
    local best, bestD
    for _, s in ipairs(spawnsOf(id, db)) do
        if not place or zoneName(s.map):find(place, 1, true) then
            local d = 1e7
            if s.p.c == here.c then
                local dx, dy = s.p.x - here.x, s.p.y - here.y
                d = math.sqrt(dx * dx + dy * dy)
            end
            if not bestD or d < bestD then best, bestD = s, d end
        end
    end
    return best, bestD
end

-- Vorwärmen: Sobald das Verzeichnis steht, liest Roadbook im Hintergrund die Fundorte von allem,
-- was in einer Kategorie vorkommt (Händler, Lehrer, Briefkästen …), in kleinen Portionen. Ein Klick
-- muss dann nur noch nach deinem Standort sortieren. Alle 190.000 Fundorte der Datenbank zu laden
-- würde dagegen viel Speicher kosten; was nur die Textsuche trifft, wird beim ersten Treffer gemerkt.
local WARM_CHUNK = debugprofilestop and 4 or 40
local SERVICE_FLAGS = { 4, 8, 16, 128, 256, 4096, 8192, 16384 }
function ns.WarmSpawns()
    if not (idx and idx.done) or idx.warm then return end
    idx.warm = 0
    local objCats = {}
    for _, c in ipairs(CATS) do if c.objects then objCats[#objCats + 1] = c end end
    local t0, n = debugprofilestop and debugprofilestop() or 0, 0
    ns.RunSliced(function()
        local my, budget = idx, WARM_CHUNK
        while budget > 0 and my.warm < #my.ids do
            my.warm = my.warm + 1
            local i, want = my.warm, false
            if my.obj[i] then
                for _, c in ipairs(objCats) do if inCategory(c, i) then want = true break end end
            else
                for _, f in ipairs(SERVICE_FLAGS) do if hasFlag(my.flags[i], f) then want = true break end end
            end
            if want then
                spawnsOf(my.ids[i], my.obj[i] and ObjectDB or nil)
                budget, n = budget - 1, n + 1
            end
        end
        if my.warm < #my.ids then return false end
        ns.Log("I", "search", "Spawn points preloaded for %d NPCs and objects, %d ms",
            n, (debugprofilestop and debugprofilestop() or 0) - t0)
        return true
    end)
end

-- Objekte haben keine Fraktion. Steht ein Gastwirt in der Nähe (Briefkästen stehen fast immer
-- am Gasthaus), gilt dessen Fraktion; ohne Gastwirt in der Nähe gilt das Objekt als passend.
local INN_RANGE = 80
local inns
local function objUnfit(spot, faction)
    if not inns then
        inns = {}
        for i = 1, #idx.ids do
            if not idx.obj[i] and hasFlag(idx.flags[i], 128) then
                local id = idx.ids[i]
                local friendly = NpcDB.Get(id, "friendlyToFaction")
                local spawns = NpcDB.Get(id, "spawns")
                for area, list in pairs(type(spawns) == "table" and spawns or {}) do
                    local map = ns.AreaToUiMap(area)
                    for _, xy in ipairs(map and type(list) == "table" and list or {}) do
                        local p = type(xy[1]) == "number" and type(xy[2]) == "number" and ns.WorldPos(map, xy[1], xy[2], true)
                        if p then inns[#inns + 1] = { c = p.c, x = p.x, y = p.y, friendly = type(friendly) == "string" and friendly or "" } end
                    end
                end
            end
        end
    end
    local best, bestD
    for _, inn in ipairs(inns) do
        if inn.c == spot.p.c then
            local dx, dy = inn.x - spot.p.x, inn.y - spot.p.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < INN_RANGE and (not bestD or d < bestD) then best, bestD = inn, d end
        end
    end
    if best and best.friendly ~= "" and not best.friendly:find(faction, 1, true) then return L["other faction"] end
end

local MAX_TEXT_HITS = 300   -- Namenssuche: so viele NPCs werden höchstens auf Fundorte geprüft
local SHORTLIST = 12        -- so viele nächste Kandidaten bekommen die genaue Reisezeit
local PLACE_LIST = 20       -- mit Gebiet: mindestens so viele Treffer werden gelistet

-- query = { cat = <Kategorie> } oder { text = "Teil von Name oder Titel" }, dazu
-- wahlweise place = "Teil des Gebietsnamens" (dann nur Treffer dort, längere Liste).
-- Die Textsuche findet alles; Kategorien zeigen die andere Fraktion nur, wenn das
-- in den Optionen an ist. Unpassende Treffer tragen „unfit“ (Grund als Text).
-- Liefert die nächsten NPCs nach Reisezeit, oder nil und eine Meldung.
function ns.FindNpcs(query, limit)
    if ns.staging then return ns.staging.npcs end   -- Fototour: Beispieltreffer
    if not hasDB() then return nil, L["QuestieDB is missing – the NPC search needs it."] end
    local here = ns.PlayerPos()
    if not here then return nil, L["Your position is not available here (e.g. in instances)."] end
    local text = query.text and ns.Trim(query.text):lower() or nil
    if not query.cat and #(text or "") < 2 then return nil, L["Type at least two letters."] end
    local place = query.place and ns.Trim(query.place):lower() or ""
    if place == "" then place = nil end
    if not (idx and idx.done) then indexStep(true) end
    local t0 = debugprofilestop and debugprofilestop() or 0
    local faction = (UnitFactionGroup("player") == "Alliance") and "A" or "H"

    local otherFaction = ns.SearchOpt().otherFaction
    -- Beruf: Lehrer, die dem Spieler nichts mehr beibringen (cap <= eigener Höchstwert), ans Ende
    local cat = query.cat
    local _, myMax = nil, nil
    if cat and cat.skill then _, myMax = ns.PlayerSkill(cat.skill) end
    local cands, hits = {}, 0
    local function add(id, book, obj)
        local spot, d = nearestSpawn(id, here, place, obj and ObjectDB)
        if not spot then return end
        local bad
        if obj then
            bad = objUnfit(spot, faction)
            if bad and cat and not otherFaction then return end
        end
        local cap = cat and not book and not obj and teachCap(id, cat) or nil
        local low = (cap and myMax and cap <= myMax) or nil
        cands[#cands + 1] = { id = id, spot = spot, d = d, cap = cap, low = low, book = book, obj = obj, unfit = bad,
                              rank = book and 0 or (low and 2 or 1) }
    end
    -- Kochen, Erste Hilfe, Angeln: ab 150 steht die nächste Stufe in einem Buch beim
    -- Händler, ab 225 gibt es sie als Quest
    if cat and cat.book and myMax == cat.plain and _G.ItemDB and ItemDB.Get then
        local okV, vendors = pcall(ItemDB.Get, cat.book, "vendors")
        local okN, item = pcall(ItemDB.Get, cat.book, "name")
        for _, id in ipairs(okV and type(vendors) == "table" and vendors or {}) do
            add(id, (L["sells %s"]):format(okN and type(item) == "string" and item or "?"))
        end
    elseif cat and cat.quest and myMax == 225 and _G.QuestDB and QuestDB.Get then
        local q = cat.quest[faction]
        local okS, started = pcall(QuestDB.Get, q, "startedBy")
        local okN, name = pcall(QuestDB.Get, q, "name")
        for _, id in ipairs(okS and type(started) == "table" and type(started[1]) == "table" and started[1] or {}) do
            add(id, (L["quest: %s"]):format(okN and type(name) == "string" and name or "?"))
        end
    end
    for i = 1, #idx.ids do
        local id = idx.ids[i]
        local ok
        if text then
            ok = idx.names[i]:find(text, 1, true) ~= nil or idx.subs[i]:find(text, 1, true) ~= nil
        else
            ok = inCategory(query.cat, i)
                and (idx.obj[i] or otherFaction or unfit(id, faction) ~= L["other faction"])
        end
        if ok then
            hits = hits + 1
            if hits > MAX_TEXT_HITS and text then break end
            add(id, nil, idx.obj[i])
        end
    end
    table.sort(cands, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.d < b.d
    end)

    local out = {}
    local want = limit or math.max(ns.Opt("searchHits"), place and PLACE_LIST or 0)
    for i = 1, math.min(math.max(SHORTLIST, want + 4), #cands) do
        local c = cands[i]
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(c.spot.map)
        local sub = not c.obj and NpcDB.Get(c.id, "subName")
        local unfitWhy = c.unfit
        if not c.obj then unfitWhy = unfit(c.id, faction) end
        out[#out + 1] = {
            id = c.id, name = (c.obj and ObjectDB or NpcDB).Get(c.id, "name"), sub = type(sub) == "string" and sub or nil,
            map = c.spot.map, x = c.spot.x, y = c.spot.y, zone = info and info.name or "?", obj = c.obj,
            cost = ns.LegCost(here, c.spot.p) or 1e9, unfit = unfitWhy,
            cap = c.cap, low = c.low, book = c.book, rank = c.rank,
        }
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.cost < b.cost
    end)
    for i = #out, want + 1, -1 do out[i] = nil end
    ns.Log("I", "search", "NPC search %s%s: %d hits, %d with a position, %.0f ms",
        text and ("\"" .. text .. "\"") or query.cat.key, place and (" in \"" .. place .. "\"") or "", hits, #cands, (debugprofilestop and debugprofilestop() or 0) - t0)
    if #out == 0 then return nil, L["Nothing found."] end
    return out
end

---------------------------------------------------------------------------
-- Was man mit einem Treffer machen kann
---------------------------------------------------------------------------
local searchUid
local goal   -- der Treffer, zu dem „Weg zeigen“ gerade führt: { r, step, sig, travelUid }

-- Der beste Weg zum Treffer, wie bei einem Plan-Schritt: lohnt sich ein Flug, ein Zeppelin, ein
-- Teleport oder führt der Weg über einen Gebietsübergang, zeigt der Pfeil zuerst dorthin.
local function routeGoal()
    local tt = _G.TomTom
    if not (tt and goal) then return end
    local tr = ns.ComputeTravel and ns.ComputeTravel(goal.step) or nil
    local sig = tr and tr.sig or "direct"
    if sig == goal.sig then return end
    goal.sig = sig
    if goal.travelUid then
        pcall(tt.RemoveWaypoint, tt, goal.travelUid)
        goal.travelUid = nil
    end
    if tr and tr.waypoint then
        local w = tr.waypoint
        local ok, uid = pcall(tt.AddWaypoint, tt, w.map, w.x / 100, w.y / 100,
            { title = ns.StepTitle(w), from = "Roadbook search", persistent = false, crazy = true })
        goal.travelUid = ok and uid or nil
    elseif searchUid and tt.SetCrazyArrow then
        pcall(tt.SetCrazyArrow, tt, searchUid, 15, goal.r.name)
    end
    if tr then
        ns.Print(tr.text .. L[" – for "] .. goal.r.name)
        ns.Log("I", "search", "Route to %s: %s", goal.r.name, tr.text)
    end
end

-- Alle 2 Sekunden: Weg zum Treffer nachführen (gelandet, Übergang durchquert …); endet am Ziel
-- oder wenn du den Punkt bei TomTom entfernst
function ns.CheckSearchGoal()
    local tt = _G.TomTom
    if not goal or ns.staging then return end
    local here, to = ns.PlayerPos(), ns.StepPos(goal.step)
    local arrived = here and to and here.c == to.c and ((here.x - to.x) ^ 2 + (here.y - to.y) ^ 2) < 30 * 30
    if not tt or arrived or not (searchUid and ns.UidAlive(tt, searchUid)) then
        if tt and goal.travelUid then pcall(tt.RemoveWaypoint, tt, goal.travelUid) end
        goal = nil
        return
    end
    if UnitOnTaxi and UnitOnTaxi("player") then return end   -- im Flug nichts ändern
    routeGoal()
end

-- Weg zum Treffer: ein TomTom-Punkt am Ziel (der vorige Such-Punkt verschwindet), dazu der Reiseweg
function ns.GoToNpc(r)
    local tt = _G.TomTom
    if not (tt and r) then return end
    if goal and goal.travelUid then pcall(tt.RemoveWaypoint, tt, goal.travelUid) end
    goal = nil
    if searchUid and tt.RemoveWaypoint then pcall(tt.RemoveWaypoint, tt, searchUid) end
    -- eigener Absender: der Abgleich räumt nur Punkte mit from = "Roadbook" auf
    local ok, uid = pcall(tt.AddWaypoint, tt, r.map, r.x / 100, r.y / 100,
        { title = r.name, from = "Roadbook search", persistent = false, crazy = true })
    searchUid = ok and uid or nil
    ns.Print((L["Waypoint set: %s (%s %.1f %.1f)."]):format(r.name, r.zone, r.x, r.y))
    ns.Log("I", "search", "Waypoint to NPC %d (%s) at %d %.1f %.1f", r.id, r.name, r.map, r.x, r.y)
    if searchUid then
        goal = { r = r, step = { key = "search", map = r.map, x = r.x, y = r.y, title = r.name } }
        routeGoal()
    end
end

function ns.AddNpcStep(r)
    if not r then return end
    ns.AddSpotStep({ type = "goto", map = r.map, x = r.x, y = r.y, zone = r.zone, title = r.name, note = r.sub })
end

-- /rb find <Kategorie oder Namensteil> [in <Gebiet>]: direkt zum nächsten Treffer
function ns.FindCommand(rest)
    rest = ns.Trim(rest or "")
    if rest == "" then ns.ShowFrame("search") return end
    local function find(what, place)
        local cat = findCategory(what)
        return ns.FindNpcs(cat and { cat = cat, place = place } or { text = what, place = place }, 1)
    end
    local what, place = rest:match("^(.-)%s+in%s+(.+)$")
    local res, err
    if what then res = find(what, place) end
    if not res then res, err = find(rest) end   -- auch für Namen, in denen „in“ vorkommt
    if res then ns.GoToNpc(res[1]) else ns.Print(err) end
end

---------------------------------------------------------------------------
-- Reiter „NPC-Suche“
---------------------------------------------------------------------------
local LEFT_W = 220

function ns.Build_search(panel, tab)
    local head = ns.FontString(panel, "GameFontNormal")
    head:SetPoint("TOPLEFT", 4, 0)
    head:SetText(L["NPC search"])

    local listInset = ns.CreateInset(panel)
    listInset:SetPoint("TOPLEFT", 0, -16)
    listInset:SetPoint("BOTTOMLEFT", 0, 0)
    listInset:SetWidth(LEFT_W)

    local selCat, results, selected, message
    local edit, placeEdit

    local function run(query)
        query.place = placeEdit:GetText()
        results, message = ns.FindNpcs(query)
        selected = results and results[1] or nil
        ns.UpdateUI()
    end

    local catList = ns.CreateScrollList(listInset, 20, function(parent)
        local row = ns.CreateRow(parent)
        row.rank = ns.FontString(row, "GameFontHighlightSmall", "RIGHT")   -- eigener Stand im Beruf
        row.rank:SetPoint("RIGHT", -4, 0)
        row.rank:SetWidth(52)
        row.text = ns.FontString(row, "GameFontHighlight")
        row.text:SetPoint("LEFT", 12, 0)
        row.text:SetPoint("RIGHT", row.rank, "LEFT", -2, 0)
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self)
            if not self.cat then return end
            selCat = self.cat
            edit:SetText("")
            edit:ClearFocus()
            run({ cat = self.cat })
        end)
        return row
    end)
    catList.scroll:SetPoint("TOPLEFT", 6, -6)
    catList.scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPLEFT", LEFT_W + 12, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)

    local label = ns.FontString(right, "GameFontNormal")
    label:SetPoint("TOPLEFT", 2, -4)
    label:SetText(L["Name:"])
    edit = ns.AutoWrap(CreateFrame("EditBox", nil, right, "InputBoxTemplate"), "search")
    edit:SetAutoFocus(false)
    edit:SetSize(220, 20)
    edit:SetPoint("LEFT", label, "LEFT", 66, 0)
    local placeLabel = ns.FontString(right, "GameFontNormal")
    placeLabel:SetPoint("TOPLEFT", 2, -30)
    placeLabel:SetText(L["Zone:"])
    placeEdit = ns.AutoWrap(CreateFrame("EditBox", nil, right, "InputBoxTemplate"), "search")
    placeEdit:SetAutoFocus(false)
    placeEdit:SetSize(220, 20)
    placeEdit:SetPoint("LEFT", placeLabel, "LEFT", 66, 0)
    -- Name leer und Kategorie gewählt: die Kategorie noch einmal (z. B. mit neuem Gebiet)
    local function runText()
        edit:ClearFocus()
        placeEdit:ClearFocus()
        local text = ns.Trim(edit:GetText() or "")
        if text == "" and selCat then run({ cat = selCat }) return end
        selCat = nil
        run({ text = text })
    end
    placeEdit:SetScript("OnEnterPressed", runText)
    local bSearch = ns.CreateButton(right, L["Search"], 90, runText)
    bSearch:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    ns.SetTooltip(bSearch, L["Search"], L["Finds NPCs by a part of their name or title and lists the nearest ones by travel time. With a zone, only NPCs there are listed."])

    local resInset = ns.CreateInset(right)
    resInset:SetPoint("TOPLEFT", 0, -54)
    resInset:SetPoint("BOTTOMRIGHT", 0, 48)
    local resList = ns.CreateScrollList(resInset, 20, function(parent)
        local row = ns.CreateRow(parent)
        row.where = ns.FontString(row, "GameFontHighlightSmall", "RIGHT")
        row.where:SetPoint("RIGHT", -4, 0)
        row.where:SetWidth(190)
        row.where:SetWordWrap(false)
        row.text = ns.FontString(row, "GameFontHighlight")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetPoint("RIGHT", row.where, "LEFT", -6, 0)
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self)
            if self.result then selected = self.result; ns.UpdateUI() end
        end)
        return row
    end)
    resList.scroll:SetPoint("TOPLEFT", 6, -6)
    resList.scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local emptyText = ns.FontString(resInset, "GameFontDisable", "CENTER")
    emptyText:SetPoint("LEFT", 20, 0)
    emptyText:SetPoint("RIGHT", -20, 0)

    local info = ns.FontString(right, "GameFontHighlightSmall")
    info:SetPoint("BOTTOMLEFT", 2, 30)
    info:SetPoint("RIGHT", -4, 0)
    info:SetWordWrap(false)

    local bGo = ns.CreateButton(right, L["Show the way"], 140, function() ns.GoToNpc(selected) end)
    bGo:SetPoint("BOTTOMLEFT", 0, 2)
    ns.SetTooltip(bGo, L["Show the way"], L["Sets a TomTom waypoint and points the arrow at this NPC."])
    local bAdd = ns.CreateButton(right, L["Add to plan"], 140, function() ns.AddNpcStep(selected) end)
    bAdd:SetPoint("LEFT", bGo, "RIGHT", 4, 0)
    ns.SetTooltip(bAdd, L["Add to plan"], L["Adds this NPC as a step to the loaded plan, otherwise to the selected plan of your own or to a new one."])

    local bWay = ns.CreateButton(right, L["Copy /way"], 120, function()
        local r = selected
        if r then ns.ShowCopy(L["Copy /way"], ("/way %s %.1f %.1f %s"):format(r.zone, r.x, r.y, r.name)) end
    end)
    bWay:SetPoint("LEFT", bAdd, "RIGHT", 4, 0)
    ns.SetTooltip(bWay, L["Copy /way"], L["Shows the TomTom command for this NPC to copy, e.g. to share it in chat."])

    -- Fototour: eine Kategorie mit Treffern zeigen
    tab.demo = function()
        for _, c in ipairs(ns.NpcCategories()) do
            if c.key == "vendor" then selCat = c end
        end
        edit:SetText("")
        placeEdit:SetText("")
        run({ cat = selCat })
    end

    tab.update = function()
        ns.BuildNpcIndex()
        catList:SetData(ns.NpcCategories(), function(row, c)
            row.cat = c.key and c or nil
            if c.head then
                row:Disable()
                row.selected:Hide()
                row.text:SetFontObject(GameFontNormalSmall)
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetText(c.head)
                row.rank:SetText("")
                row.text:SetTextColor(1, 0.82, 0)
            else
                row:Enable()
                row.text:SetFontObject(GameFontHighlight)
                row.text:SetPoint("LEFT", 12, 0)
                local rank, max = nil, nil
                if c.skill then rank, max = ns.PlayerSkill(c.skill) end
                -- eigene Berufe grün, mit Stand
                row.text:SetText(rank and ("|cff40ff40%s|r"):format(c.label) or c.label)
                row.rank:SetText(rank and ("|cff40ff40%d/%d|r"):format(rank, max) or "")
                row.text:SetTextColor(1, 1, 1)
                row.selected:SetShown(c == selCat)
            end
        end)

        resList:SetData(results or {}, function(row, r)
            row.result = r
            local text = r.name
            if r.unfit then
                text = ("|cff999999%s (%s)|r"):format(r.name, r.unfit)
            elseif r.book then
                text = ("%s |cff40ff40(%s)|r"):format(r.name, r.book)
            elseif r.low then
                text = ("|cff999999%s (%s)|r"):format(r.name, (L["up to %d"]):format(r.cap))
            elseif r.cap then
                text = ("%s |cffffd100(%s)|r"):format(r.name, (L["up to %d"]):format(r.cap))
            end
            row.text:SetText(text)
            row.where:SetText(("%s · %s"):format(r.zone, ns.FmtTime(r.cost)))
            row.selected:SetShown(r == selected)
        end)
        emptyText:SetShown(not results)
        emptyText:SetText(message or L["Pick a category on the left or search for a name or title. A zone lists only the NPCs there."])

        local has = selected ~= nil
        info:SetShown(has)
        bGo:SetEnabled(has)
        bAdd:SetEnabled(has)
        bWay:SetEnabled(has)
        if has then
            local extra = ""
            if selected.book then
                extra = " · " .. selected.book
            elseif selected.cap then
                extra = " · " .. (selected.low and L["teaches up to skill %d – nothing new for you"] or L["teaches up to skill %d"]):format(selected.cap)
            end
            info:SetText(("%s%s %.1f %.1f%s"):format(selected.sub and (selected.sub .. " · ") or "", selected.zone, selected.x, selected.y, extra))
        end
    end
end
