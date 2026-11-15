-- Roadbook: Pläne als Text teilen (Export/Import)
--
-- Format (eine Zeile je Schritt, lesbar und ohne ausführbaren Code):
--   RB1 <Titel>
--   mode=route
--   note=<Text>
--   step;type=turnin;quest=1064;map=1456;x=22.8;y=20.9;title=…;text=…;note=…
-- Kein „|“ im Text: WoW liest |t, |n, |c … in Textfeldern als Steuerzeichen und würde
-- den Export beim Anzeigen und Kopieren verstümmeln. Der Import versteht auch die
-- alte Fassung mit „|“ (1.0.0-alpha1/beta1).
-- Karten stehen als Nummer (uiMapID) drin, damit ein Plan in jeder Sprache passt.
-- Der Import liest außerdem einfache /way-Zeilen (wie bei TomTom).
local ADDON, ns = ...
local L = ns.L

local MAX_TEXT, MAX_STEPS = 20000, 200
local STEP_KEYS = { "type", "quest", "item", "count", "map", "x", "y", "title", "text", "note" }
local NUMERIC = { quest = true, item = true, count = true, map = true, x = true, y = true }

local function esc(v)
    return (tostring(v):gsub("\\", "\\\\"):gsub("|", "\\p"):gsub(";", "\\s"):gsub("\r", ""):gsub("\n", "\\n"))
end
local function unesc(v)
    return (v:gsub("\\(.)", function(c) return (c == "n" and "\n") or (c == "p" and "|") or (c == "s" and ";") or c end))
end

function ns.ExportPlan(plan)
    local lines = { "RB1 " .. esc(plan.title or "Plan"), "mode=" .. (ns.PlanMode(plan) == "alle" and "all" or "route") }
    if plan.note and plan.note ~= "" then lines[#lines + 1] = "note=" .. esc(plan.note) end
    for _, st in ipairs(plan.steps) do
        local parts = { "step" }
        for _, k in ipairs(STEP_KEYS) do
            local v = st[k]
            if v ~= nil and not (k == "count" and v == 1) then parts[#parts + 1] = k .. "=" .. esc(v) end
        end
        lines[#lines + 1] = table.concat(parts, ";")
    end
    return table.concat(lines, "\n")
end

-- Gebietsname -> Karten-Nummer in der Sprache des Clients (für /way-Zeilen)
local zoneByName
local function zoneMap(name)
    if not zoneByName then
        zoneByName = {}
        local function walk(map, depth)
            local ok, kids = pcall(C_Map.GetMapChildrenInfo, map)
            if not (ok and type(kids) == "table") then return end
            for _, k in ipairs(kids) do
                if k.mapID and k.name then
                    local key = k.name:lower()
                    zoneByName[key] = zoneByName[key] or k.mapID
                    if depth < 3 then walk(k.mapID, depth + 1) end
                end
            end
        end
        if C_Map and C_Map.GetMapChildrenInfo then walk(947, 1) end   -- 947 = Azeroth
    end
    return zoneByName[name:lower()]
end

local function wayStep(line)
    local rest = line:match("^/[wW][aA][yY]%s+(.+)$")
    if not rest then return nil end
    local map = tonumber(rest:match("^#(%d+)%s"))
    if map then rest = rest:gsub("^#%d+%s+", "") end
    local zone, x, y, title = rest:match("^(.-)%s*(%d+[%.,]?%d*)[%s,]+(%d+[%.,]?%d*)%s*(.*)$")
    if not x then return nil end
    x, y = tonumber((x:gsub(",", "."))), tonumber((y:gsub(",", ".")))
    if not map then
        if zone ~= "" then map = zoneMap(zone) else map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") end
    end
    if not (map and x and y) then return nil end
    return { type = "goto", map = map, x = x, y = y, title = (title ~= "" and title) or L["Waypoint"] }
end

-- Text lesen. Rückgabe: Rohplan { title, mode, note, steps } oder nil, Fehlertext
function ns.ParsePlanText(text)
    text = ns.Trim(text)
    if text == "" then return nil, L["Nothing to import – paste a Roadbook export or /way lines."] end
    if #text > MAX_TEXT then return nil, L["The text is too long to import."] end
    local plan = { title = L["Imported plan"], mode = "route", steps = {} }
    local isExport, skipped = false, 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        line = ns.Trim(line)
        if line:sub(1, 4) == "RB1 " then
            isExport = true
            plan.title = unesc(line:sub(5))
        elseif line:match("^mode=") then
            plan.mode = (line:sub(6) == "all") and "alle" or "route"
        elseif line:match("^note=") then
            plan.note = unesc(line:sub(6))
        elseif line:match("^step[;|]") then
            local raw = {}
            for k, v in line:gsub("||", "|"):gmatch("[;|](%a+)=([^;|]*)") do
                v = unesc(v)
                if NUMERIC[k] then raw[k] = tonumber(v) else raw[k] = v end
            end
            if ns.NormalizeStep(raw) then plan.steps[#plan.steps + 1] = raw else skipped = skipped + 1 end
        elseif line ~= "" then
            local st = wayStep(line)
            if st then plan.steps[#plan.steps + 1] = st else skipped = skipped + 1 end
        end
        if #plan.steps > MAX_STEPS then return nil, (L["Too many steps (max. %d)."]):format(MAX_STEPS) end
    end
    if #plan.steps == 0 then return nil, L["No steps found – paste a Roadbook export or /way lines."] end
    if not isExport then plan.mode = "alle" end
    return plan, nil, skipped
end

function ns.ImportText(text)
    local plan, err, skipped = ns.ParsePlanText(text)
    if not plan then
        ns.Print(err)
        return nil, err
    end
    local id = ns.NextId("p")
    -- Ein importierter Plan fängt von vorn an: alte Häkchen an denselben Zielen gelten nicht mehr
    for _, raw in ipairs(plan.steps) do
        local st = ns.NormalizeStep(raw)
        if st then ns.C.done[st.key] = nil end
    end
    ns.C.plans[id] = { id = id, title = plan.title, mode = plan.mode, note = plan.note, steps = plan.steps,
                       created = time(), origin = ns.CopySteps(plan.steps) }
    ns.C.selectedPlan = "e:" .. id
    ns.Print((L["Plan “%s” imported: %d steps%s."]):format(plan.title, #plan.steps,
        skipped > 0 and (L[", %d line(s) not understood"]):format(skipped) or ""))
    ns.Log("I", "plan", "Plan %s imported: %d steps, %d lines skipped.", id, #plan.steps, skipped)
    ns.Refresh()
    return ns.GetPlan("e:" .. id)
end

---------------------------------------------------------------------------
-- Import-Fenster
---------------------------------------------------------------------------
function ns.ShowImport()
    local f = ns.importFrame
    if not f then
        f = CreateFrame("Frame", "RoadbookImportFrame", UIParent, "BackdropTemplate")
        f:SetBackdrop(BACKDROP_DIALOG_32_32)
        f:SetSize(520, 320)
        f:SetPoint("CENTER", 0, 60)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        local title = ns.FontString(f, "GameFontNormal", "CENTER")
        title:SetPoint("TOP", 0, -18)
        title:SetText(L["Import a plan"])
        local hint = ns.FontString(f, "GameFontDisableSmall")
        hint:SetPoint("BOTTOMLEFT", 20, 22)
        hint:SetPoint("RIGHT", -130, 0)
        hint:SetText(L["Paste a Roadbook export or /way lines (Ctrl+V)."])
        local area = ns.CreateTextArea(f)
        area:SetPoint("TOPLEFT", 18, -38)
        area:SetPoint("BOTTOMRIGHT", -18, 46)
        f.edit = area.edit
        f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
        local ok = ns.CreateButton(f, L["Import"], 100, function()
            if ns.ImportText(f.edit:GetText()) then
                f:Hide()
                ns.ShowFrame("plans")
            end
        end)
        ok:SetPoint("BOTTOMRIGHT", -18, 16)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
        tinsert(UISpecialFrames, "RoadbookImportFrame")
        ns.importFrame = f
    end
    f.edit:SetText("")
    f:Show()
    f.edit:SetFocus()
end

---------------------------------------------------------------------------
-- Reiter „Optionen“
---------------------------------------------------------------------------
function ns.PickupText()
    local v = ns.PickupMax()
    return v > 0 and ns.FmtTime(v) or L["off"]
end

function ns.Build_options(panel, tab)
    local head = ns.FontString(panel, "GameFontNormal")
    head:SetPoint("TOPLEFT", 4, 0)
    head:SetText(L["Options"])

    local y = -26
    local function check(text, tip, get, set)
        local cb = ns.AutoWrap(CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate"), "option")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", 2, y)
        local label = ns.FontString(panel, "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        label:SetText(text)
        cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); ns.UpdateUI() end)
        ns.SetTooltip(cb, text, tip)
        cb.get = get
        y = y - 28
        return cb
    end

    local checks = {
        check(L["Show the step tracker"], L["The small window below the minimap with your next step. Also: /rb tracker"],
            function() return not (ns.DB.tracker and ns.DB.tracker.hidden) end,
            function(v) ns.DB.tracker = ns.DB.tracker or {}; ns.DB.tracker.hidden = not v end),
        check(L["Show the minimap button"], L["Also: /rb minimap. The addon menu at the minimap always has a Roadbook entry."],
            function() return not ns.DB.minimap.hidden end,
            function(v) ns.DB.minimap.hidden = not v; ns.UpdateMinimapButton() end),
        check(L["Detailed log"], L["Writes more into the log and shows warnings in chat. Useful for bug reports. Also: /rb debug"],
            function() return ns.DB.debug and true or false end,
            function(v) ns.DB.debug = v end),
    }

    y = y - 12
    local title = ns.FontString(panel, "GameFontNormal")
    title:SetPoint("TOPLEFT", 4, y)
    title:SetText(L["Undiscovered flight masters"])
    y = y - 20
    local info = ns.FontString(panel, "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 4, y)
    info:SetPoint("RIGHT", -4, 0)
    info:SetJustifyV("TOP")
    info:SetText(L["If an undiscovered flight master is almost on your way, Roadbook adds it as a stop. Knowing it saves time later. Set how much detour that is worth to you."])
    y = y - 34
    local minus = ns.CreateButton(panel, "-", 28, function() ns.SetPickupMax(ns.PickupMax() - ns.PICKUP_STEP) end)
    minus:SetPoint("TOPLEFT", 4, y)
    local value = ns.FontString(panel, "GameFontHighlight", "CENTER")
    value:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    value:SetWidth(210)
    local plus = ns.CreateButton(panel, "+", 28, function() ns.SetPickupMax(ns.PickupMax() + ns.PICKUP_STEP) end)
    plus:SetPoint("LEFT", value, "RIGHT", 6, 0)

    tab.update = function()
        for _, cb in ipairs(checks) do cb:SetChecked(cb.get()) end
        value:SetText((L["Detour up to: %s"]):format(ns.PickupText()))
        minus:SetEnabled(ns.PickupMax() > 0)
        plus:SetEnabled(ns.PickupMax() < ns.PICKUP_LIMIT)
    end
end

---------------------------------------------------------------------------
-- /rb shots: die Fenster der Reihe nach mit Beispieldaten zeigen und von jedem
-- einen Screenshot machen (für die Addon-Seite). Alles ist gestellt: eine
-- Abgaberunde über zwei Kontinente mit Zeppelin, Beispiel-Notizen und -Makros.
-- Deine eigenen Pläne, Notizen und Makros sind dabei nicht zu sehen und werden
-- nicht angefasst (ns.staging lenkt nur die Anzeige um).
-- Zu jedem Bild merkt sich Roadbook, wo das Fenster lag (RoadbookDB.shots,
-- Anteile 0–1), damit media/crop_shots.py passend zuschneiden kann.
---------------------------------------------------------------------------
local function screenRect(frame, padBottom)
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local s, us = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    local w, h = UIParent:GetWidth() * us, UIParent:GetHeight() * us
    if not (l and r and t and b and w > 0 and h > 0) then return nil end
    return { l = l * s / w, r = r * s / w, t = 1 - t * s / h, b = 1 - (b - (padBottom or 0)) * s / h }
end

local function demoData()
    local function own(raw, created)
        local plan = ns.NormalizePlan(raw, "eigen")
        plan.rawId, plan.created = raw.id, created
        return plan
    end
    local zep = (L["Zeppelin %s – %s"]):format("Orgrimmar", "Undercity")
    local round = own({ id = "demo-round", auto = true, mode = "route", title = L["Turn-in round (automatic)"],
        note = (L["Created %s from %d quests ready to turn in – sorted by travel time from your position (flight points and zones included). Click again to refresh the round."])
            :format(date(L["%m/%d %H:%M"]), 5),
        steps = {
            { type = "turnin", quest = 990001, map = 1413, x = 48.1, y = 5.4, title = "Kadrak", text = L["Report to Kadrak"] },
            { type = "turnin", quest = 990002, map = 1454, x = 34.3, y = 36.4, title = "Thrall", text = L["Hidden Enemies"] },
            { type = "turnin", quest = 990003, map = 1421, x = 44.2, y = 42.7, title = L["Yuriv's Tombstone"], text = L["Until Death Do Us Part"] },
            { type = "turnin", quest = 990004, map = 1421, x = 43.4, y = 40.9, title = "Mura Runetotem", text = L["A Lost Satchel"] },
            { type = "turnin", quest = 990005, map = 1458, x = 48.8, y = 69.3, title = L["Apothecary Zinge"], text = L["Arugal's Folly"] },
        } }, 3)
    local stonetalon = own({ id = "demo-stonetalon", mode = "route", title = L["Stonetalon turn-ins"], steps = {
        { type = "turnin", quest = 990011, map = 1442, x = 47.5, y = 58.4, title = "Tammra Windfield", text = L["Cycle of Rebirth"] },
        { type = "turnin", quest = 990012, map = 1442, x = 47.2, y = 61.1, title = "Mor'rogal", text = L["Boulderslide Ravine"] },
        { type = "goto", map = 1442, x = 59.0, y = 62.6, title = "Ziz Fizziks" },
    } }, 2)
    local spots = own({ id = "demo-spots", mode = "alle", title = L["My spots"], steps = {
        { type = "goto", map = 1413, x = 62.0, y = 39.0, title = "Ratchet" },
        { type = "goto", map = 1411, x = 51.5, y = 41.6, title = "Razor Hill" },
    } }, 1)
    local ready = L["ready to turn in"]
    local staging = {
        plans = { round, stonetalon, spots },
        states = {
            ["q990001:turnin"] = { "done" }, ["q990002:turnin"] = { "done" },
            ["q990003:turnin"] = { "ready", ready }, ["q990004:turnin"] = { "ready", ready }, ["q990005:turnin"] = { "ready", ready },
            ["q990011:turnin"] = { "done" }, ["q990012:turnin"] = { "ready", ready },
        },
        ready = { { quest = 990021, title = L["Deepmoss Spider Eggs"] }, { quest = 990022, title = L["Trouble in the Deeps"] } },
        macros = {
            { group = "Roadbook", name = "Roadbook", scope = "account", icon = 134400, body = "/rb",
              note = L["Opens Roadbook. Put it on an action bar."] },
            { group = "Roadbook", name = L["Turn-in round"], scope = "account", icon = 134400, body = "/rb turnin" },
            { group = "Roadbook", name = L["Skip step"], scope = "account", icon = 134400, body = "/rb skip" },
            { group = L["Travel"], name = L["Remember here"], scope = "char", icon = 134400, body = "/rb here" },
            { group = L["Travel"], name = "Route", scope = "char", icon = 134400, body = "/rb route" },
        },
        notes = {
            { header = "Roadbook", items = ns.BUILTIN_NOTES },
            { header = L["For plans"], items = { { id = "demo:n1", title = "Plan: " .. L["Stonetalon turn-ins"] } } },
            { header = L["My notes"], items = { { id = "demo:n2", title = L["Shopping list"] }, { id = "demo:n3", title = L["Profession trainers"] } } },
            { header = L["For all characters"], items = { { id = "demo:n4", title = L["Bank and auction house"] } } },
        },
    }
    local cur = round.steps[3]
    staging.travel = { stepKey = cur.key, stepTitle = ns.StepTitle(cur), hop = { kind = "schiff", name = zep }, sig = "shots",
        text = (L["First to the dock: %s"]):format(zep), waypoint = { title = L["Dock"], text = zep } }
    local leg = L["  →  %s, about %s"]
    staging.route = table.concat({
        (L["Route description: %s"]):format(round.title), "",
        ("1. %s (%s %.1f %.1f)%s"):format(ns.StepTitle(cur), ns.ZoneName(cur), cur.x, cur.y, leg:format(zep, ns.FmtTime(560))),
        ("2. %s (%s %.1f %.1f)%s"):format(ns.StepTitle(round.steps[4]), ns.ZoneName(round.steps[4]), 43.4, 40.9, leg:format(L["on foot"], ns.FmtTime(35))),
        ("3. %s (%s %.1f %.1f)%s"):format(ns.StepTitle(round.steps[5]), ns.ZoneName(round.steps[5]), 48.8, 69.3,
            leg:format((L["Flight %s → %s"]):format("The Sepulcher", "Undercity"), ns.FmtTime(140))),
        "",
        (L["Estimated total: %s · flight points: %d known, %d of them found on this continent · speed %.1f yards/s"]):format(ns.FmtTime(735), 12, 3, 7),
        L["Estimate: straight line × 1.3 on foot, flights from known flight points, +45 s per zone change."],
    }, "\n")
    return staging
end

function ns.PhotoTour()
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    if ns.staging then return end
    ns.DB.tracker = ns.DB.tracker or {}
    local saved = { travel = ns.travel, expanded = ns.DB.tracker.expanded, hidden = ns.DB.tracker.hidden,
                    active = ns.C.activePlan, selected = ns.C.selectedPlan, note = ns.selectedNoteId }
    local staging = demoData()
    local round = staging.plans[1]
    local done = false
    local function finish()
        if done then return end
        done = true
        for _, f in ipairs({ ns.copyFrame, ns.trashFrame, ns.importFrame }) do if f then f:Hide() end end
        ns.staging = nil
        ns.travel, ns.C.activePlan, ns.C.selectedPlan, ns.selectedNoteId = saved.travel, saved.active, saved.selected, saved.note
        ns.DB.tracker.expanded, ns.DB.tracker.hidden = saved.expanded, saved.hidden
        ns.planEditId = nil
        ns.Refresh()
    end
    ns.staging = staging
    ns.travel = staging.travel
    ns.C.activePlan, ns.C.selectedPlan = round.id, round.id
    ns.DB.tracker.hidden, ns.DB.tracker.expanded = false, true

    local TABS = 34   -- die Reiter hängen unter dem Fenster
    local scenes = {
        { "plans", function() ns.ShowFrame("plans"); return ns.frame, TABS end },
        { "tracker", function() ns.frame:Hide(); ns.UpdateUI(); return ns.tracker, 0 end },
        { "route", function()
            ns.ShowCopy(L["Route description"], ns.RouteText(round))
            ns.copyFrame.edit:HighlightText(0, 0)
            ns.copyFrame.edit:ClearFocus()
            return ns.copyFrame, 0
        end },
        { "notes", function()
            ns.copyFrame:Hide()
            ns.ShowFrame("notes")
            ns.SelectNote("w:anleitung")
            return ns.frame, TABS
        end },
        { "macros", function() ns.ShowFrame("macros"); return ns.frame, TABS end },
        { "options", function() ns.ShowFrame("options"); return ns.frame, TABS end },
        { "import", function()
            ns.frame:Hide()
            ns.ShowImport()
            ns.importFrame.edit:SetText(ns.ExportPlan(round))
            ns.importFrame.edit:ClearFocus()
            return ns.importFrame, 0
        end },
    }
    ns.DB.shots = { at = time(), list = {} }
    local i = 0
    local step
    -- Bricht eine Szene mit einem Fehler ab, wird trotzdem aufgeräumt
    local function guarded(fn)
        return function()
            local ok, err = pcall(fn)
            if not ok then
                ns.Log("E", "shots", "%s", tostring(err))
                finish()
            end
        end
    end
    step = guarded(function()
        i = i + 1
        local scene = scenes[i]
        if not scene then
            finish()
            ns.ShowFrame("plans")
            return ns.Print((L["%d screenshots saved in the Screenshots folder of your game. Type /reload so the cropping data is saved too."]):format(#ns.DB.shots.list))
        end
        local frame, pad = scene[2]()
        C_Timer.After(1.2, guarded(function()
            -- ohne Position das ganze Bild: so passt die Liste immer zur Reihenfolge der Screenshots
            local rect = (frame and screenRect(frame, pad)) or { l = 0, r = 1, t = 0, b = 1 }
            rect.name = scene[1]
            table.insert(ns.DB.shots.list, rect)
            if Screenshot then Screenshot() end
            C_Timer.After(0.8, step)
        end))
    end)
    step()
end

---------------------------------------------------------------------------
-- Layout-Prüfer (/rb layout): meldet abgeschnittene, überstehende und
-- überlappende Texte/Knöpfe als Warnung „layout“ im Protokoll. Dient auch
-- den Tests (tests/layout.lua) für alle Sprachen.
---------------------------------------------------------------------------
local TOL = 1
local logged, loggedN = {}, 0

local function rect(r)
    local l, rt, t, b = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
    if l and rt and t and b then return l, rt, t, b end
end

-- Fläche, die der Text wirklich belegt (bei fester Breite/Höhe kleiner als der Rahmen)
local function textRect(fs)
    local l, r, t, b = rect(fs)
    if not l then return end
    local sw, sh = fs:GetStringWidth() or 0, fs:GetStringHeight() or 0
    if sw < r - l then
        local j = fs:GetJustifyH()
        if j == "LEFT" then r = l + sw
        elseif j == "RIGHT" then l = r - sw
        else local c = (l + r) / 2; l, r = c - sw / 2, c + sw / 2 end
    end
    if sh < t - b then
        local j = fs:GetJustifyV()
        if j == "TOP" then b = t - sh
        elseif j == "BOTTOM" then t = b + sh
        else local c = (t + b) / 2; t, b = c + sh / 2, c - sh / 2 end
    end
    return l, r, t, b
end

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function label(obj)
    local s = obj.GetText and obj:GetText()
    if s and s ~= "" then return '"' .. plain(s):gsub("\n", " / "):sub(1, 50) .. '"' end
    return obj.GetDebugName and obj:GetDebugName() or obj:GetObjectType()
end

function ns.LayoutCheck(roots)
    local found, seen = {}, {}
    local function report(msg)
        if not seen[msg] then seen[msg] = true; found[#found + 1] = msg end
    end
    -- inScroll: in Scrollbereichen darf Text oben/unten aus dem Bild laufen
    local function walk(frame, inScroll)
        local fl, fr, ft, fb = rect(frame)
        local items = {}
        for _, reg in ipairs({ frame:GetRegions() }) do
            if reg:GetObjectType() == "FontString" and reg:IsVisible() and (reg:GetText() or "") ~= "" then
                -- einzeilige Listentexte dürfen mit „…“ enden; alles andere muss ganz zu lesen sein
                if reg.IsTruncated and reg:IsTruncated() and not inScroll then report("truncated: " .. label(reg)) end
                local l, r, t, b = textRect(reg)
                if l then
                    items[#items + 1] = { reg, l, r, t, b }
                    -- Häkchen: Beschriftung steht absichtlich neben dem Kästchen
                    if fl and frame:GetObjectType() ~= "CheckButton" and (l < fl - TOL or r > fr + TOL or (not inScroll and (t > ft + TOL or b < fb - TOL))) then
                        report(("sticks out of %s: %s"):format(label(frame), label(reg)))
                    end
                end
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do
            if child:IsVisible() then
                local ot = child:GetObjectType()
                if (ot == "Button" or ot == "CheckButton") and ((child.GetText and child:GetText()) or "") ~= "" then
                    local l, r, t, b = rect(child)
                    if l then items[#items + 1] = { child, l, r, t, b } end
                end
                walk(child, inScroll or ot == "ScrollFrame")
            end
        end
        for i = 1, #items do
            local a = items[i]
            for j = i + 1, #items do
                local c = items[j]
                if math.min(a[3], c[3]) - math.max(a[2], c[2]) > TOL and math.min(a[4], c[4]) - math.max(a[5], c[5]) > TOL then
                    report(("overlap: %s / %s"):format(label(a[1]), label(c[1])))
                end
            end
        end
    end
    for _, root in ipairs(roots or { ns.frame, ns.tracker, ns.copyFrame, ns.trashFrame, ns.importFrame }) do
        if root and root:IsVisible() then walk(root, false) end
    end
    -- jeder Fund nur einmal pro Sitzung ins Protokoll
    for _, msg in ipairs(found) do
        if not logged[msg] and loggedN < 100 then
            logged[msg], loggedN = true, loggedN + 1
            ns.Log("W", "layout", "%s", msg)
        end
    end
    return found
end
