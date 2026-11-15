-- Roadbook: NPC-Suche (Händler, Lehrer, Gastwirt … aus QuestieDB) und Reiter „NPC-Suche“
local ADDON, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Kategorien. „flag“ ist das NPC-Flag aus QuestieDB; „titles“ sind Teile des
-- englischen Titels aus den Grunddaten (GetRaw), damit die Zuordnung in
-- jeder Client-Sprache gilt („Warrior Trainer“, „Journeyman Tailor“ …).
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
    { head = L["Trainers"] },
    { key = "class", label = L["Class trainer"], flag = TRAINER, class = true },
    { key = "pet", label = L["Pet trainer"], flag = TRAINER, titles = { "pet trainer" }, only = "HUNTER" },
    { key = "weapon", label = L["Weapon master"], flag = TRAINER, titles = { "weapon master" } },
    { key = "riding", label = L["Riding trainer"], flag = TRAINER, titles = { "riding instructor" } },
    { head = L["Professions"] },
    { key = "alchemy", label = L["Alchemy"], flag = TRAINER, titles = { "alchem" } },
    { key = "blacksmithing", label = L["Blacksmithing"], flag = TRAINER, titles = { "blacksmith", "armor crafter", "weapon crafter" } },
    { key = "enchanting", label = L["Enchanting"], flag = TRAINER, titles = { "enchant" } },
    { key = "engineering", label = L["Engineering"], flag = TRAINER, titles = { "engineer" } },
    { key = "herbalism", label = L["Herbalism"], flag = TRAINER, titles = { "herbalis" } },
    { key = "leatherworking", label = L["Leatherworking"], flag = TRAINER, titles = { "leatherwork" } },
    { key = "mining", label = L["Mining"], flag = TRAINER, titles = { "miner", "mining" } },
    { key = "skinning", label = L["Skinning"], flag = TRAINER, titles = { "skinn" } },
    { key = "tailoring", label = L["Tailoring"], flag = TRAINER, titles = { "tailor" } },
    { key = "cooking", label = L["Cooking"], flag = TRAINER, titles = { "cook", "butcher" } },
    { key = "firstaid", label = L["First Aid"], flag = TRAINER, titles = { "first aid", "physician", "surgeon", "medic" } },
    { key = "fishing", label = L["Fishing"], flag = TRAINER, titles = { "fish" } },
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
-- Verzeichnis aller NPCs (Name, Flags). Wird beim ersten Öffnen des Reiters
-- häppchenweise aufgebaut, damit das Spiel nicht ruckt; eine Suche vor dem
-- Ende liest den Rest in einem Zug.
---------------------------------------------------------------------------
local CHUNK = 400
local idx

local function hasDB() return _G.NpcDB and NpcDB.Get and NpcDB.GetAllIds end

local function indexStep(all)
    if not idx then
        local ok, ids = pcall(NpcDB.GetAllIds)
        idx = { src = (ok and type(ids) == "table") and ids or {}, pos = 0, ids = {}, names = {}, subs = {}, flags = {} }
    end
    local last = all and #idx.src or math.min(#idx.src, idx.pos + CHUNK)
    for i = idx.pos + 1, last do
        local id = idx.src[i]
        local name = NpcDB.Get(id, "name")
        if type(name) == "string" and name ~= "" then
            local n = #idx.ids + 1
            local sub = NpcDB.Get(id, "subName")
            idx.ids[n], idx.names[n], idx.flags[n] = id, name:lower(), tonumber(NpcDB.Get(id, "npcFlags")) or 0
            idx.subs[n] = type(sub) == "string" and sub:lower() or ""
        end
    end
    idx.pos = last
    idx.done = last >= #idx.src
    if idx.done and not idx.logged then
        idx.logged = true
        ns.Log("I", "search", "NPC index ready: %d NPCs", #idx.ids)
    end
    return idx.done
end

function ns.BuildNpcIndex()
    if not hasDB() or (idx and (idx.done or idx.running)) then return end
    local function tick()
        if indexStep() then
            idx.running = nil
        else
            idx.running = true
            C_Timer.After(0.02, tick)
        end
    end
    tick()
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
    if not hasFlag(idx.flags[i], cat.flag) then return false end
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
local function nearestSpawn(id, here, place)
    local spawns = NpcDB.Get(id, "spawns")
    local best, bestD
    for area, list in pairs(type(spawns) == "table" and spawns or {}) do
        local map = ns.AreaToUiMap(area)
        if map and place and not zoneName(map):find(place, 1, true) then map = nil end
        for _, xy in ipairs(type(list) == "table" and list or {}) do
            local x, y = xy[1], xy[2]
            if map and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                local p = ns.WorldPos(map, x, y, true)
                if p then
                    local d = 1e7
                    if p.c == here.c then
                        local dx, dy = p.x - here.x, p.y - here.y
                        d = math.sqrt(dx * dx + dy * dy)
                    end
                    if not bestD or d < bestD then
                        best, bestD = { map = map, x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10, p = p }, d
                    end
                end
            end
        end
    end
    return best, bestD
end

local MAX_TEXT_HITS = 300   -- Namenssuche: so viele NPCs werden höchstens auf Fundorte geprüft
local SHORTLIST = 12        -- so viele nächste Kandidaten bekommen die genaue Reisezeit
local PLACE_LIST = 20       -- mit Gebiet: so viele Treffer werden gelistet

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
    local cands, hits = {}, 0
    for i = 1, #idx.ids do
        local id = idx.ids[i]
        local ok
        if text then
            ok = idx.names[i]:find(text, 1, true) ~= nil or idx.subs[i]:find(text, 1, true) ~= nil
        else
            ok = inCategory(query.cat, i)
                and (otherFaction or unfit(id, faction) ~= L["other faction"])
        end
        if ok then
            hits = hits + 1
            if hits > MAX_TEXT_HITS and text then break end
            local spot, d = nearestSpawn(id, here, place)
            if spot then cands[#cands + 1] = { id = id, spot = spot, d = d } end
        end
    end
    table.sort(cands, function(a, b) return a.d < b.d end)

    local out = {}
    for i = 1, math.min(place and PLACE_LIST or SHORTLIST, #cands) do
        local c = cands[i]
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(c.spot.map)
        local sub = NpcDB.Get(c.id, "subName")
        out[#out + 1] = {
            id = c.id, name = NpcDB.Get(c.id, "name"), sub = type(sub) == "string" and sub or nil,
            map = c.spot.map, x = c.spot.x, y = c.spot.y, zone = info and info.name or "?",
            cost = ns.LegCost(here, c.spot.p) or 1e9, unfit = unfit(c.id, faction),
        }
    end
    table.sort(out, function(a, b) return a.cost < b.cost end)
    for i = #out, (limit or (place and PLACE_LIST or 8)) + 1, -1 do out[i] = nil end
    ns.Log("I", "search", "NPC search %s%s: %d hits, %d with a position, %.0f ms",
        text and ("\"" .. text .. "\"") or query.cat.key, place and (" in \"" .. place .. "\"") or "", hits, #cands, (debugprofilestop and debugprofilestop() or 0) - t0)
    if #out == 0 then return nil, L["Nothing found."] end
    return out
end

---------------------------------------------------------------------------
-- Was man mit einem Treffer machen kann
---------------------------------------------------------------------------
local searchUid

-- Direkter Weg: ein TomTom-Punkt mit Pfeil (der vorige Such-Punkt verschwindet)
function ns.GoToNpc(r)
    local tt = _G.TomTom
    if not (tt and r) then return end
    if searchUid and tt.RemoveWaypoint then pcall(tt.RemoveWaypoint, tt, searchUid) end
    -- eigener Absender: der Abgleich räumt nur Punkte mit from = "Roadbook" auf
    local ok, uid = pcall(tt.AddWaypoint, tt, r.map, r.x / 100, r.y / 100,
        { title = r.name, from = "Roadbook search", persistent = false, crazy = true })
    searchUid = ok and uid or nil
    ns.Print((L["Waypoint set: %s (%s %.1f %.1f)."]):format(r.name, r.zone, r.x, r.y))
    ns.Log("I", "search", "Waypoint to NPC %d (%s) at %d %.1f %.1f", r.id, r.name, r.map, r.x, r.y)
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
local LEFT_W = 180

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
        row.text = ns.FontString(row, "GameFontHighlight")
        row.text:SetPoint("LEFT", 12, 0)
        row.text:SetPoint("RIGHT", -4, 0)
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
                row.text:SetTextColor(1, 0.82, 0)
            else
                row:Enable()
                row.text:SetFontObject(GameFontHighlight)
                row.text:SetPoint("LEFT", 12, 0)
                row.text:SetText(c.label)
                row.text:SetTextColor(1, 1, 1)
                row.selected:SetShown(c == selCat)
            end
        end)

        resList:SetData(results or {}, function(row, r)
            row.result = r
            row.text:SetText(r.unfit and ("|cff999999%s (%s)|r"):format(r.name, r.unfit) or r.name)
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
            info:SetText(("%s%s %.1f %.1f"):format(selected.sub and (selected.sub .. " · ") or "", selected.zone, selected.x, selected.y))
        end
    end
end
