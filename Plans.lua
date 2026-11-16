-- Roadbook: Pläne, Fortschritt und TomTom
local ADDON, ns = ...
local L = ns.L
local str = function(v) if v == nil then return nil end return tostring(v) end

local ARRIVAL = 15   -- Meter (Yards), ab dem ein Ort als erreicht gilt

---------------------------------------------------------------------------
-- Pläne normalisieren
---------------------------------------------------------------------------
local STEP_TYPES = { turnin = true, complete = true, accept = true, item = true, ["goto"] = true, manual = true }
ns.STEP_LABEL = {
    turnin = L["Turn in"], complete = L["Complete"], accept = L["Accept"],
    item = L["Collect"], ["goto"] = L["Go to"], manual = L["Task"],
}

local function coord(v)
    v = tonumber(v)
    if v and v >= 0 and v <= 100 then return v end
end

function ns.NormalizeStep(s, warn)
    warn = warn or function() end
    if type(s) ~= "table" then warn("Step is not a table"); return nil end
    local st = {
        type = s.type, quest = tonumber(s.quest), item = tonumber(s.item),
        count = tonumber(s.count) or 1, map = tonumber(s.map),
        x = coord(s.x), y = coord(s.y),
        zone = str(s.zone), title = str(s.title), text = str(s.text), note = str(s.note),
    }
    local label = st.title or st.text or "?"
    if s.x and not st.x or s.y and not st.y then warn(("“%s”: coordinates outside 0–100 – no waypoint"):format(label)) end
    if not STEP_TYPES[st.type] then
        if s.type then warn(("“%s”: unknown type %s"):format(label, tostring(s.type))) end
        st.type = (st.quest and "turnin") or (st.item and "item") or ((st.map and st.x and st.y) and "goto") or "manual"
    end
    if (s.map or s.x or s.y) and not (st.map and st.x and st.y) then
        warn(("“%s”: map/coordinates incomplete – no waypoint"):format(label))
    end
    if not (st.map and st.x and st.y) then st.map, st.x, st.y = nil, nil, nil end
    local t = st.type
    if (t == "turnin" or t == "complete" or t == "accept") and not st.quest then t = "manual"; warn(("“%s”: quest ID missing – treated as a task"):format(label)) end
    if t == "item" and not st.item then t = "manual"; warn(("“%s”: item ID missing – treated as a task"):format(label)) end
    if t == "goto" and not st.map then t = "manual" end
    st.type = t

    if t == "turnin" or t == "complete" or t == "accept" then
        st.key = ("q%d:%s"):format(st.quest, t)
    elseif t == "item" then
        st.key = ("i%d:%d"):format(st.item, st.count)
    elseif s.key then
        st.key = "k:" .. tostring(s.key)
    elseif st.map then
        st.key = ("p:%d:%.1f:%.1f"):format(st.map, st.x, st.y)
    else
        st.key = "m:" .. (st.title or "") .. "|" .. (st.text or "")
    end
    return st
end

function ns.NormalizePlan(p, source, warn)
    if type(p) ~= "table" or type(p.steps) ~= "table" then return nil end
    local plan = {
        id = str(p.id) or str(p.title) or "plan",
        title = str(p.title) or str(p.id) or "Plan",
        mode = (p.mode == "alle") and "alle" or "route",
        note = str(p.note), source = source, steps = {}, auto = p.auto and true or nil,
    }
    if source == "eigen" then plan.id = "e:" .. plan.id end
    for i, s in ipairs(p.steps) do
        local st = ns.NormalizeStep(s, warn)
        if st then st.rawIndex = i; table.insert(plan.steps, st) end
    end
    return plan
end

-- Alle Pläne dieses Charakters: zuerst die aus der Post, dann die eigenen
function ns.GetPlans()
    if ns.staging then return ns.staging.plans end   -- /rb shots: nur Beispielpläne
    local out = {}
    if ns.post then
        for _, plan in ipairs(ns.post.plans) do
            if not ns.IsPostPlanHidden(plan) then table.insert(out, plan) end
        end
    end
    local own = {}
    for id, raw in pairs(ns.C.plans) do
        local plan = ns.NormalizePlan(raw, "eigen")
        if plan then plan.created = raw.created or 0; plan.rawId = id; table.insert(own, plan) end
    end
    table.sort(own, function(a, b) return a.created < b.created end)
    for _, plan in ipairs(own) do table.insert(out, plan) end
    return out
end

function ns.GetPlan(id)
    if not id then return nil end
    for _, plan in ipairs(ns.GetPlans()) do
        if plan.id == id then return plan end
    end
end

function ns.ActivePlan() return ns.GetPlan(ns.C.activePlan) end

function ns.PlanMode(plan)
    return ns.C.modes[plan.id] or plan.mode or "route"
end

---------------------------------------------------------------------------
-- Status eines Schritts. "Erledigt" gilt für alle Pläne (hängt am Ziel,
-- nicht am Plan), "übersprungen" nur für den einen Plan.
---------------------------------------------------------------------------
local QL = C_QuestLog

-- Die eigene Marke überbrückt nur die Zeit, bis das Spiel die Abgabe selbst meldet.
-- Wiederholbare Quests sind danach wieder offen.
local TURNED_IN_KEEP = 3600
local function questDone(q)
    if QL and QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(q) then
        ns.C.turnedIn[q] = nil
        return true
    end
    local at = ns.C.turnedIn[q]
    if not at then return false end
    if (QL and QL.IsOnQuest and QL.IsOnQuest(q)) or time() - (tonumber(at) or 0) > TURNED_IN_KEEP then
        ns.C.turnedIn[q] = nil
        return false
    end
    return true
end
local function onQuest(q)
    return QL and QL.IsOnQuest and QL.IsOnQuest(q) or false
end
local function questComplete(q)
    if QL and QL.IsComplete and QL.IsComplete(q) then return true end
    if QL and QL.ReadyForTurnIn and QL.ReadyForTurnIn(q) then return true end
    return false
end
function ns.ItemCount(itemID)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID) or 0 end
    if GetItemCount then return GetItemCount(itemID) or 0 end
    return 0
end

-- Rückgabe: state ("done" | "ready" | "open" | "skipped"), detail
function ns.StepState(step, planId)
    local staged = ns.staging and ns.staging.states[step.key]
    if staged then return staged[1], staged[2] end
    local t, q = step.type, step.quest
    local state, detail = "open", nil
    if t == "turnin" then
        if questDone(q) then state = "done"
        elseif onQuest(q) then
            if questComplete(q) then state, detail = "ready", L["ready to turn in"] else detail = L["Objectives still open"] end
        else detail = L["not in the quest log"] end
    elseif t == "complete" then
        if questDone(q) or (onQuest(q) and questComplete(q)) then state = "done"
        elseif not onQuest(q) then detail = L["not in the quest log"] end
    elseif t == "accept" then
        if questDone(q) or onQuest(q) then state = "done" end
    elseif t == "item" then
        local have = ns.ItemCount(step.item)
        detail = ("%d/%d"):format(math.min(have, step.count), step.count)
        if have >= step.count then state = "done" end
    end
    if state ~= "done" and ns.C.done[step.key] then state, detail = "done", L["ticked off"] end
    if state ~= "done" and planId and ns.C.skipped[planId] and ns.C.skipped[planId][step.key] then
        state = "skipped"
    end
    return state, detail
end

local function isOpen(state) return state == "open" or state == "ready" end

function ns.PlanProgress(plan)
    local done, total = 0, #plan.steps
    for _, st in ipairs(plan.steps) do
        if ns.StepState(st, plan.id) == "done" then done = done + 1 end
    end
    return done, total
end

function ns.CurrentStep(plan)
    if not plan then return nil end
    local focus = ns.C.focus[plan.id]
    if focus then
        for _, st in ipairs(plan.steps) do
            if st.key == focus and isOpen((ns.StepState(st, plan.id))) then return st end
        end
    end
    for _, st in ipairs(plan.steps) do
        if isOpen((ns.StepState(st, plan.id))) then return st end
    end
end

function ns.StepTitle(step)
    local a, b = step.title, step.text
    if a and b then return a .. " – " .. b end
    return a or b or ns.STEP_LABEL[step.type] or L["Step"]
end

-- Gebietsname in der Sprache des Clients (aus der Karten-Nummer); der gespeicherte
-- Name ist nur Ersatz, denn geteilte Pläne können aus einer anderen Sprache stammen.
function ns.ZoneName(step)
    if step.map and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(step.map)
        if info and info.name then return info.name end
    end
    return step.zone or "?"
end

function ns.WayLine(step)
    if not step.map then return nil end
    return ("/way %s %.1f %.1f %s"):format(ns.ZoneName(step), step.x, step.y, ns.StepTitle(step))
end

---------------------------------------------------------------------------
-- Aktionen
---------------------------------------------------------------------------
ns.wp = { uids = {}, byKey = {}, suppressed = {}, arrowKey = nil, arrowUid = nil, arrowTracked = false, clearing = false }

function ns.ActivatePlan(id)
    local plan = ns.GetPlan(id)
    if not plan then ns.Log("W", "plan", "Plan %s not found.", tostring(id)) return end
    ns.Log("I", "plan", "Plan loaded: %s (mode %s, %d steps)", plan.id, ns.PlanMode(plan), #plan.steps)
    if not _G.TomTom then
        ns.Log("W", "tomtom", "TomTom is not loaded – no waypoints possible.")
        ns.Print(L["TomTom is not loaded – without TomTom there are no waypoints."])
    end
    ns.C.activePlan = plan.id
    ns.C.selectedPlan = plan.id
    wipe(ns.wp.suppressed)
    ns.wp.arrowKey = nil
    ns.lastCurrentKey = nil
    ns.Refresh()
    local cur = ns.CurrentStep(plan)
    ns.Print((L["Plan loaded: |cffffffff%s|r%s"]):format(plan.title,
        cur and (L[" – first: "] .. ns.StepTitle(cur)) or L[" – everything done."]))
end

function ns.DeactivatePlan()
    if not ns.C.activePlan then return end
    ns.Log("I", "plan", "Plan unloaded: %s", tostring(ns.C.activePlan))
    ns.C.activePlan = false
    ns.Refresh()
    ns.Print(L["Plan unloaded, waypoints removed."])
end

function ns.SetMode(plan, mode)
    ns.C.modes[plan.id] = (mode ~= plan.mode) and mode or nil
    ns.Log("I", "plan", "Mode %s for %s", mode, plan.id)
    ns.wp.arrowKey = nil
    ns.Refresh()
end

function ns.FocusStep(plan, step)
    if ns.PlanMode(plan) == "route" then
        ns.C.focus[plan.id] = step.key
    end
    ns.Log("D", "plan", "Focus on %s (%s)", ns.StepTitle(step), step.key)
    ns.wp.suppressed[step.key] = nil
    ns.wp.arrowKey = nil
    ns.wp.targetKey = step.key   -- sonst springt der Pfeil im Modus „Alle“ beim nächsten Abgleich zurück
    if ns.C.activePlan ~= plan.id then
        ns.ActivatePlan(plan.id)
    else
        ns.Refresh()
    end
    if ns.PlanMode(plan) == "alle" then ns.PointArrow(step) end
end

function ns.ToggleSkip(plan, step)
    local s = ns.C.skipped[plan.id] or {}
    ns.C.skipped[plan.id] = s
    s[step.key] = (not s[step.key]) and true or nil
    ns.Log("I", "plan", "%s: %s", s[step.key] and "Skipped" or "Resumed", ns.StepTitle(step))
    if not next(s) then ns.C.skipped[plan.id] = nil end
    ns.Refresh()
end

function ns.ToggleDone(step)
    ns.C.done[step.key] = (not ns.C.done[step.key]) and time() or nil
    ns.Log("I", "plan", "Manually %s: %s", ns.C.done[step.key] and "ticked off" or "open again", ns.StepTitle(step))
    ns.Refresh()
end

-- Reise-Abschnitt (Flugmeister/Anleger) überspringen bzw. wieder aufnehmen: der Pfeil
-- geht dann direkt zum Schritt. Nötig, wenn der Punkt nicht genau am Anleger liegt
-- und deshalb nicht von selbst verschwindet.
function ns.ToggleTravelSkip(stepKey)
    local key = "travel:" .. tostring(stepKey)
    if ns.wp.suppressed[key] then
        ns.wp.suppressed[key] = nil
        ns.wp.skippedTravel = nil
        ns.Log("I", "route", "Travel leg resumed for %s", tostring(stepKey))
    else
        local tr = ns.travel
        if not (tr and tr.stepKey == stepKey) then return false end
        local title = tr.waypoint and ns.StepTitle(tr.waypoint) or tr.text
        ns.wp.suppressed[key] = true
        ns.wp.skippedTravel = { stepKey = stepKey, title = title }
        ns.Print((L["Travel leg skipped: %s. The arrow now points straight to the step."]):format(title))
        ns.Log("I", "route", "Travel leg skipped: %s", tr.text)
    end
    ns.wp.arrowKey = nil
    ns.Refresh()
    return true
end

-- Für die Anzeige im Plan: der Reise-Abschnitt vor einem Schritt (auch der übersprungene)
function ns.TravelRow()
    local tr = ns.travel
    if tr and tr.waypoint then return { stepKey = tr.stepKey, title = ns.StepTitle(tr.waypoint) } end
    local sk = ns.wp.skippedTravel
    if sk and ns.wp.suppressed["travel:" .. tostring(sk.stepKey)] then
        return { stepKey = sk.stepKey, title = sk.title, skipped = true }
    end
end

function ns.SkipCurrentStep()
    -- erst der Weg zum Flugmeister/Anleger, beim nächsten Mal der Schritt selbst
    if ns.travel and ns.ToggleTravelSkip(ns.travel.stepKey) then return end
    local plan = ns.ActivePlan()
    local cur = plan and ns.CurrentStep(plan)
    if not cur then ns.Print(L["No open step in the active plan."]) return end
    ns.ToggleSkip(plan, cur)
    ns.Print(L["Skipped: "] .. ns.StepTitle(cur))
end

-- Meldungen bei Fortschritt im aktiven Plan
local lastStates = {}
local function trackStates(plan)
    local stateOf = lastStates[plan.id] or {}
    lastStates[plan.id] = stateOf
    for _, st in ipairs(plan.steps) do
        local state, detail = ns.StepState(st, plan.id)
        local before = stateOf[st.key]
        if before and before ~= state then
            ns.Log(state == "done" and "I" or "D", "step", "%s: %s → %s%s", ns.StepTitle(st), before, state,
                detail and (" (" .. detail .. ")") or "")
        end
        stateOf[st.key] = state
    end
end

function ns.CheckProgress()
    local plan = ns.ActivePlan()
    if not plan then ns.lastCurrentKey = nil return end
    trackStates(plan)
    local cur = ns.CurrentStep(plan)
    local key = cur and cur.key or "ENDE"
    if ns.lastCurrentKey and ns.lastCurrentKey ~= key then
        if cur then
            ns.Print(L["Next step: |cffffffff"] .. ns.StepTitle(cur) .. "|r")
        elseif not ns.C.finished[plan.id] then
            ns.Print((L["|cff80ff80Plan “%s” completed!|r"]):format(plan.title))
            ns.Log("I", "plan", "Plan completed: %s", plan.id)
        end
    end
    ns.C.finished[plan.id] = (cur == nil) and true or nil
    ns.lastCurrentKey = key
end

---------------------------------------------------------------------------
-- Schrittlisten kopieren/vergleichen (für den Ursprung eines Plans)
---------------------------------------------------------------------------
local STEP_FIELDS = { "type", "quest", "item", "count", "map", "x", "y", "zone", "title", "text", "note", "key" }

local function copySteps(steps)
    local out = {}
    for i, s in ipairs(steps or {}) do
        local c = {}
        for _, f in ipairs(STEP_FIELDS) do c[f] = s[f] end
        out[i] = c
    end
    return out
end
ns.CopySteps = copySteps

local function stepsSig(steps)
    local parts = {}
    for _, s in ipairs(steps or {}) do
        local f = {}
        for _, k in ipairs(STEP_FIELDS) do f[#f + 1] = tostring(s[k]) end
        parts[#parts + 1] = table.concat(f, "|")
    end
    return table.concat(parts, "\n")
end

function ns.CountSkipped(plan)
    local n = 0
    for _ in pairs(plan and ns.C.skipped[plan.id] or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Plan zurücksetzen: Überspringen, Abhaken und Fokus weg, Wegpunkte neu.
-- Eigene Pläne mit gespeichertem Ursprung bekommen auch ihre ursprünglichen
-- Schritte zurück; der Stand davor liegt 10 Minuten im Papierkorb.
-- Abgegebene Quests bleiben erledigt – das ist echter Fortschritt.
---------------------------------------------------------------------------
function ns.ResetPlan(plan)
    if not plan then ns.Print(L["No plan selected."]) return end
    local skipped = ns.CountSkipped(plan)
    local ticks = 0
    ns.C.skipped[plan.id] = nil
    ns.C.focus[plan.id] = nil
    ns.C.finished[plan.id] = nil
    lastStates[plan.id] = nil
    local restored = false
    if plan.source == "eigen" then
        local raw = ns.C.plans[plan.rawId]
        if raw and type(raw.origin) == "table" and #raw.origin > 0 and stepsSig(raw.steps) ~= stepsSig(raw.origin) then
            local before = {}
            for k, v in pairs(raw) do before[k] = v end
            before.steps = copySteps(raw.steps)
            before.origin = copySteps(raw.origin)
            ns.ToTrash({ kind = "planState", id = plan.rawId, data = before, title = plan.title, quiet = true })
            raw.steps = copySteps(raw.origin)
            restored = true
            plan = ns.GetPlan(plan.id) or plan
        end
    end
    for _, st in ipairs(plan.steps) do
        if ns.C.done[st.key] then ns.C.done[st.key] = nil; ticks = ticks + 1 end
        ns.wp.suppressed[st.key] = nil
        ns.wp.suppressed["travel:" .. st.key] = nil
    end
    ns.wp.arrowKey = nil
    if ns.C.activePlan == plan.id then ns.lastCurrentKey = nil end
    ns.Log("I", "plan", "Plan reset: %s (%d skipped, %d ticked off%s)", plan.id, skipped, ticks,
        restored and ", steps as at the start" or "")
    local parts = {}
    if skipped > 0 then parts[#parts + 1] = (L["%d skipped"]):format(skipped) end
    if ticks > 0 then parts[#parts + 1] = (L["%d ticked-off"]):format(ticks) end
    local what = #parts > 0 and (table.concat(parts, L[" and "]) .. L[" steps open again"]) or L["nothing skipped or ticked off"]
    ns.Print((L["Plan “%s” reset: %s%s.%s"]):format(plan.title, what,
        restored and L["; steps as at the start (previous state in the trash)"] or "",
        ns.C.activePlan == plan.id and "" or L[" Click “Load” to show the waypoints in TomTom."]))
    ns.Refresh()
end

---------------------------------------------------------------------------
-- Eigener Plan aus den aktuellen TomTom-Wegpunkten
---------------------------------------------------------------------------
function ns.CreatePlanFromTomTom(title)
    local tt = _G.TomTom
    if not (tt and tt.waypoints) then
        ns.Print(L["TomTom is not loaded."])
        ns.Log("W", "tomtom", "Plan from TomTom: TomTom is missing or has no waypoint list.")
        return
    end
    local steps = {}
    for m, entries in pairs(tt.waypoints) do
        for _, uid in pairs(entries) do
            if type(uid) == "table" and uid.from ~= ns.FROM and uid[1] and uid[2] and uid[3] then
                table.insert(steps, {
                    type = "goto", map = uid[1],
                    x = math.floor(uid[2] * 1000 + 0.5) / 10, y = math.floor(uid[3] * 1000 + 0.5) / 10,
                    title = uid.title or L["Waypoint"],
                })
            end
        end
    end
    if #steps == 0 then ns.Print(L["No TomTom waypoints of your own found."]) return end
    ns.ForgetArrivals(steps)
    -- Reihenfolge nach Reisezeit ab deinem Standort (statt nach Karten-Nummer)
    table.sort(steps, function(a, b)
        if a.map ~= b.map then return a.map < b.map end
        return (a.title or "") < (b.title or "")
    end)
    if ns.OrderSteps then steps = ns.OrderSteps(steps) end
    local id = ns.NextId("p")
    ns.C.plans[id] = { id = id, title = title or (L["My spots "] .. date(L["%m/%d %H:%M"])), mode = "alle", steps = steps,
                       created = time(), origin = copySteps(steps) }
    ns.Print((L["Own plan created: %d waypoints."]):format(#steps))
    ns.Log("I", "plan", "Own plan %s created from %d TomTom waypoints.", id, #steps)
    ns.C.selectedPlan = "e:" .. id
    ns.ShowFrame("plans")
    ns.Refresh()
end

function ns.DeleteOwnPlan(plan) ns.DeletePlan(plan) end

---------------------------------------------------------------------------
-- Pläne bearbeiten. Pläne aus der Post werden dabei zur eigenen Kopie
-- (die Fassung aus der Post wird ausgeblendet, Fortschritt bleibt erhalten).
---------------------------------------------------------------------------
-- Neue „Hingehen“-Schritte fangen offen an, auch wenn derselbe Ort früher schon erreicht wurde
function ns.ForgetArrivals(steps)
    for _, raw in ipairs(steps) do
        local st = ns.NormalizeStep(raw)
        if st and st.type == "goto" then ns.C.done[st.key] = nil end
    end
end

local function rawFromStep(st)
    return {
        type = st.type, quest = st.quest, item = st.item, count = (st.count ~= 1) and st.count or nil,
        map = st.map, x = st.x, y = st.y, zone = st.zone, title = st.title, text = st.text, note = st.note,
        key = st.key and st.key:match("^k:(.*)") or nil,
    }
end
ns.RawFromStep = rawFromStep

function ns.EnsureEditable(plan)
    if not plan then return nil end
    if plan.source == "eigen" then return plan, ns.C.plans[plan.rawId] end
    local rawId = ns.NextId("p")
    local raw = { id = rawId, title = plan.title, mode = plan.mode, note = plan.note, created = time(), from = plan.id, steps = {} }
    for _, st in ipairs(plan.steps) do table.insert(raw.steps, rawFromStep(st)) end
    raw.origin = copySteps(raw.steps)   -- Ursprung für „Zurücksetzen“
    ns.C.plans[rawId] = raw
    ns.C.hidden[plan.id] = ns.PostPlanHash(plan)
    local newId = "e:" .. rawId
    ns.C.skipped[newId] = ns.C.skipped[plan.id]
    ns.C.modes[newId] = ns.C.modes[plan.id]
    ns.C.focus[newId] = ns.C.focus[plan.id]
    if ns.C.activePlan == plan.id then ns.C.activePlan = newId end
    if ns.C.selectedPlan == plan.id then ns.C.selectedPlan = newId end
    if ns.planEditId == plan.id then ns.planEditId = newId end
    ns.Print((L["Plan “%s” is now your own – the version from the post is hidden."]):format(plan.title))
    ns.Log("I", "plan", "Post plan %s taken over as own plan %s.", plan.id, newId)
    return ns.GetPlan(newId), raw
end

function ns.RenamePlan(plan, title)
    title = ns.Trim(title)
    if title == "" or title == plan.title then return end
    local p, raw = ns.EnsureEditable(plan)
    if not raw then return end
    raw.title = title
    ns.Log("I", "plan", "Plan renamed: %s", title)
    ns.Refresh()
end
ns.RenameOwnPlan = ns.RenamePlan

function ns.MoveStep(plan, step, dir)
    local p, raw = ns.EnsureEditable(plan)
    if not raw then return end
    local i = step.rawIndex
    local j = i and (i + dir)
    if not (i and j and raw.steps[i] and raw.steps[j]) then return end
    raw.steps[i], raw.steps[j] = raw.steps[j], raw.steps[i]
    ns.Log("D", "plan", "Step %d ↔ %d in %s", i, j, p.id)
    ns.Refresh()
end

function ns.RemoveStep(plan, step)
    local p, raw = ns.EnsureEditable(plan)
    if not (raw and step.rawIndex and raw.steps[step.rawIndex]) then return end
    local data = table.remove(raw.steps, step.rawIndex)
    ns.ToTrash({ kind = "step", planRawId = p.rawId, index = step.rawIndex, data = data,
                 title = (L["%s (from “%s”)"]):format(ns.StepTitle(step), p.title) })
    ns.Refresh()
end

local function playerSpot()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = math.floor(pos.x * 1000 + 0.5) / 10, math.floor(pos.y * 1000 + 0.5) / 10
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return map, x, y, info and info.name
end

-- Aktuelle Position als Schritt merken (im gewählten bzw. aktiven Plan, sonst neuer Plan)
function ns.AddHereStep(plan, name)
    local map, x, y, zone = playerSpot()
    if not map then
        ns.Print(L["Your position is not available here (e.g. in instances)."])
        ns.Log("W", "plan", "Remember here: no position available.")
        return
    end
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local title = (name and ns.Trim(name) ~= "" and name) or (sub ~= "" and sub) or (GetZoneText and GetZoneText()) or L["Remembered spot"]
    ns.AddSpotStep({ type = "goto", map = map, x = x, y = y, zone = zone, title = title }, plan)
end

-- Einen Ort als Schritt anhängen: an den geladenen Plan, sonst an den gewählten eigenen, sonst an einen neuen
function ns.AddSpotStep(step, plan)
    local title, zone, x, y = step.title, step.zone, step.x, step.y
    plan = plan or ns.ActivePlan()
    if not plan then
        -- ohne geladenen Plan: den gewählten eigenen Plan weiterführen statt jedes Mal einen neuen anzulegen
        local sel = ns.GetPlan(ns.C.selectedPlan)
        if sel and sel.source == "eigen" and not sel.auto then plan = sel end
    end
    ns.ForgetArrivals({ step })
    local raw
    if plan then
        plan, raw = ns.EnsureEditable(plan)
    else
        local id = ns.NextId("p")
        raw = { id = id, title = L["My spots"], mode = "alle", created = time(), steps = {} }
        ns.C.plans[id] = raw
        plan = { id = "e:" .. id, title = raw.title }
        ns.C.selectedPlan = plan.id
    end
    table.insert(raw.steps, step)
    ns.Print((L["Remembered: %s (%s %.1f %.1f) → plan “%s”."]):format(title, zone or "?", x, y, raw.title))
    ns.Log("I", "plan", "Remembered here: %s %s %.1f %.1f in %s", title, tostring(zone), x, y, plan.id)
    ns.Refresh()
end

---------------------------------------------------------------------------
-- TomTom
--
-- Roadbook merkt sich, welche TomTom-Punkte ihm gehören (uid -> Schritt).
-- Beim Abgleich wird geprüft, ob TomTom die Punkte noch hat (TomTom kann
-- sie bei einem Neuladen ohne Meldung verlieren), und alte Roadbook-Punkte,
-- die keinem Schritt mehr gehören, werden aufgeräumt.
---------------------------------------------------------------------------
local function TT() return _G.TomTom end

local function countKeys(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

function ns.InitTomTom()
    local tt = TT()
    if not (tt and tt.RegisterCallback) then
        ns.Log("W", "tomtom", "TomTom not found or without callback interface.")
        return
    end
    tt.RegisterCallback(ns, "WaypointRemoved", ns.Wrap("tomtom-removed", function(_, uid)
        if ns.wp.clearing then return end
        local key = ns.wp.uids[uid]
        if key == "travel" then
            -- Reise-Punkt (Flugmeister/Anleger) von Hand entfernt: für diesen Schritt zu Fuß
            ns.wp.uids[uid] = nil
            ns.wp.travelUid, ns.wp.travelSig = nil, nil
            if ns.wp.targetKey then
                ns.wp.suppressed["travel:" .. ns.wp.targetKey] = true
                ns.wp.skippedTravel = { stepKey = ns.wp.targetKey, title = uid.title }
            end
            ns.wp.arrowKey = nil
            ns.Log("I", "tomtom", "Travel waypoint removed by hand – the arrow goes straight to the step: %s", tostring(uid.title))
            ns.ScheduleRefresh()
        elseif key then
            -- Von Hand entfernt: bis zur nächsten Änderung nicht neu setzen
            ns.wp.uids[uid] = nil
            if ns.wp.byKey[key] == uid then ns.wp.byKey[key] = nil end
            ns.wp.suppressed[key] = true
            if ns.wp.arrowKey == key then ns.wp.arrowKey = nil end
            ns.Log("I", "tomtom", "Waypoint removed by hand (a left-click on the tracker sets it again): %s", tostring(uid.title))
            if ns.UpdateUI then ns.UpdateUI() end
        end
    end))
    tt.RegisterCallback(ns, "WaypointsReloaded", ns.Wrap("tomtom-reloaded", function()
        wipe(ns.wp.uids); wipe(ns.wp.byKey); wipe(ns.wp.suppressed)
        ns.wp.arrowKey, ns.wp.travelUid, ns.wp.travelSig = nil, nil, nil
        ns.Log("I", "tomtom", "TomTom reloaded its waypoints – Roadbook sets its own again.")
        ns.ScheduleRefresh()
    end))
    -- Wohin zeigt der Pfeil gerade? (TomTom 4.4: ArrowTargetChanged)
    local okArrow = pcall(tt.RegisterCallback, ns, "ArrowTargetChanged", ns.Wrap("tomtom-arrow", function(_, uid)
        ns.wp.arrowUid = uid or false
    end))
    ns.wp.arrowTracked = okArrow and true or false
    ns.Log("D", "tomtom", "TomTom callbacks registered (arrow target %s).", ns.wp.arrowTracked and "tracked" or "unknown")
end

-- Hat TomTom diesen Punkt noch?
local function uidAlive(tt, uid)
    if not (tt and type(tt.waypoints) == "table") then return true end
    local entries = tt.waypoints[uid[1]]
    if type(entries) ~= "table" then return false end
    for _, u in pairs(entries) do if u == uid then return true end end
    return false
end

-- Roadbook-Punkte bei TomTom, die Roadbook nicht (mehr) kennt
local function orphanUids(tt)
    local out = {}
    if not (tt and type(tt.waypoints) == "table") then return out end
    for _, entries in pairs(tt.waypoints) do
        if type(entries) == "table" then
            for _, uid in pairs(entries) do
                if type(uid) == "table" and uid.from == ns.FROM and not ns.wp.uids[uid] then table.insert(out, uid) end
            end
        end
    end
    return out
end

local function stepOfUid(uid)
    local key = ns.wp.uids[uid]
    local plan = ns.ActivePlan()
    if not (key and plan) then return nil end
    for _, st in ipairs(plan.steps) do if st.key == key then return st end end
end

function ns.OnArrive(uid)
    if UnitOnTaxi and UnitOnTaxi("player") then return end   -- im Flug über einen Punkt hinweg zählt nicht
    if ns.wp.uids[uid] == "travel" then
        local tr = ns.travel
        if tr and ns.wp.travelArrived ~= tr.sig then
            ns.wp.travelArrived = tr.sig
            ns.Print(tr.arrive or tr.text)
            ns.Log("I", "route", "Travel waypoint reached: %s", tr.text)
        end
        return
    end
    local st = stepOfUid(uid)
    if st and st.type == "goto" and not ns.C.done[st.key] then
        ns.C.done[st.key] = time()
        ns.Print(L["Arrived: "] .. ns.StepTitle(st))
        ns.Log("I", "step", "Arrived: %s", ns.StepTitle(st))
        C_Timer.After(0, ns.Refresh)
    end
end

local function userUid(step, title)
    local tt = TT()
    if not (tt and tt.waypoints and tt.GetKey) then return nil end
    local entries = tt.waypoints[step.map]
    if not entries then return nil end
    return entries[tt:GetKey({ step.map, step.x / 100, step.y / 100, title = title })]
end

-- Der TomTom-Punkt eines Schritts (eigener oder schon vorhandener Nutzerpunkt)
function ns.StepUid(step)
    if not (step and step.map) then return nil end
    return ns.wp.byKey[step.key] or userUid(step, ns.StepTitle(step))
end

local function addWaypoint(step)
    local tt = TT()
    if not (tt and step.map) then return end
    local x, y, title = step.x / 100, step.y / 100, ns.StepTitle(step)
    if tt.WaypointExists and tt:WaypointExists(step.map, x, y, title) then
        ns.Log("D", "tomtom", "Waypoint already exists (your own TomTom waypoint), not set twice: %s", title)
        return
    end
    local opts = {
        title = title, from = ns.FROM, persistent = false, minimap = true, world = true,
        crazy = false, cleardistance = 0, arrivaldistance = ARRIVAL, silent = true,
    }
    if tt.DefaultCallbacks then
        local cbs = tt:DefaultCallbacks(opts)
        cbs.distance = cbs.distance or {}
        local prev = cbs.distance[ARRIVAL]
        cbs.distance[ARRIVAL] = ns.Wrap("tomtom-arrive", function(event, uid, range, dist, lastdist)
            if prev then prev(event, uid, range, dist, lastdist) end
            if lastdist then ns.OnArrive(uid) end
        end)
        opts.callbacks = cbs
    end
    local ok, uid = pcall(tt.AddWaypoint, tt, step.map, x, y, opts)
    if ok and type(uid) == "table" then
        ns.wp.uids[uid] = step.key
        if step.key == "travel" then
            ns.wp.travelUid = uid
            return uid
        end
        ns.wp.byKey[step.key] = uid
        ns.Log("D", "tomtom", "Waypoint set: %s (%s %.1f %.1f)", title, ns.ZoneName(step), step.x, step.y)
    else
        ns.Log("E", "tomtom", "TomTom:AddWaypoint failed for %s (map %s): %s", title, tostring(step.map), tostring(uid))
    end
end

function ns.PointArrow(step, force)
    local tt = TT()
    if not (tt and tt.SetCrazyArrow and step and step.map) then return end
    local uid = ns.StepUid(step)
    if not uid then ns.Log("D", "tomtom", "Arrow: no waypoint for %s", ns.StepTitle(step)) return end
    local empty = tt.IsCrazyArrowEmpty and tt:IsCrazyArrowEmpty()
    if force or ns.wp.arrowKey ~= step.key or empty then
        tt:SetCrazyArrow(uid, ARRIVAL, ns.StepTitle(step))
        ns.wp.arrowKey = step.key
        ns.wp.arrowUid = uid
        ns.Log("D", "tomtom", "Arrow → %s", ns.StepTitle(step))
    end
end

-- Zeigt der TomTom-Pfeil auf diesen Schritt? (nil = unbekannt)
function ns.ArrowOnStep(step)
    if not (ns.wp.arrowTracked and step) then return nil end
    if ns.travel and ns.travel.stepKey == step.key and ns.wp.travelUid then
        return ns.wp.arrowUid == ns.wp.travelUid
    end
    local uid = ns.StepUid(step)
    if not uid then return false end
    return ns.wp.arrowUid == uid
end

-- „Alle Punkte“: Schritt mit der kürzesten Reisezeit
local function nearestStep(list)
    local tt = TT()
    local best, bestCost
    local from = ns.PlayerPos and ns.PlayerPos()
    for _, st in ipairs(list) do
        if ns.StepUid(st) then
            local cost
            local to = from and ns.StepPos(st)
            if to then cost = ns.LegCost(from, to) end
            if not cost and tt and tt.GetDistanceToWaypoint then
                local ok, d = pcall(tt.GetDistanceToWaypoint, tt, ns.StepUid(st))
                cost = ok and d and (d / 7) or nil
            end
            if cost and (not bestCost or cost < bestCost) then best, bestCost = st, cost end
        end
    end
    return best
end

function ns.DesiredWaypoints(plan)
    local mode = ns.PlanMode(plan)
    local out = {}
    if mode == "route" then
        local cur = ns.CurrentStep(plan)
        if cur and cur.map and not ns.wp.suppressed[cur.key] then out[1] = cur end
    else
        for _, st in ipairs(plan.steps) do
            if st.map and isOpen((ns.StepState(st, plan.id))) and not ns.wp.suppressed[st.key] then
                table.insert(out, st)
            end
        end
    end
    return out, mode
end

-- Gleicht die TomTom-Punkte mit dem aktiven Plan ab. Entfernt nur eigene Punkte.
-- Lohnt sich ein Flug (oder Zeppelin), kommt ein Reise-Punkt beim Flugmeister
-- dazu und der Pfeil zeigt zuerst dorthin.
function ns.SyncWaypoints()
    local tt = TT()
    local plan = ns.ActivePlan()
    local want, mode = {}, nil
    if plan then want, mode = ns.DesiredWaypoints(plan) end
    local wantKey = {}
    for _, st in ipairs(want) do wantKey[st.key] = true end
    local force = ns.wp.forceArrow
    ns.wp.forceArrow = nil

    -- Wohin soll der Pfeil am Ende führen?
    local target
    if mode == "route" then
        target = want[1]
    elseif plan then
        if not force and ns.wp.targetKey and wantKey[ns.wp.targetKey] then
            for _, st in ipairs(want) do if st.key == ns.wp.targetKey then target = st end end
        end
    end

    -- Punkte, die TomTom ohne Meldung verloren hat, vergessen (werden unten neu gesetzt)
    local lost = 0
    if tt then
        for uid, key in pairs(ns.wp.uids) do
            if not uidAlive(tt, uid) then
                ns.wp.uids[uid] = nil
                if ns.wp.byKey[key] == uid then ns.wp.byKey[key] = nil end
                if key == "travel" then ns.wp.travelUid, ns.wp.travelSig = nil, nil end
                if ns.wp.arrowKey == key then ns.wp.arrowKey = nil end
                lost = lost + 1
            end
        end
    end
    if lost > 0 then ns.Log("I", "tomtom", "%d waypoint(s) had vanished from TomTom – setting them again.", lost) end

    local removed, added = 0, 0
    ns.wp.clearing = true
    for uid, key in pairs(ns.wp.uids) do
        if key ~= "travel" and not wantKey[key] then
            removed = removed + 1
            if tt then pcall(tt.RemoveWaypoint, tt, uid) end
            ns.wp.uids[uid] = nil
            if ns.wp.byKey[key] == uid then ns.wp.byKey[key] = nil end
            if ns.wp.arrowKey == key then ns.wp.arrowKey = nil end
        end
    end
    -- Alte Roadbook-Punkte ohne Schritt (z. B. aus einer früheren Sitzung) aufräumen
    local orphans = orphanUids(tt)
    for _, uid in ipairs(orphans) do pcall(tt.RemoveWaypoint, tt, uid) end
    ns.wp.clearing = false
    if #orphans > 0 then ns.Log("I", "tomtom", "%d orphaned Roadbook waypoints removed from TomTom.", #orphans) end

    if tt and plan then
        for _, st in ipairs(want) do
            if not ns.wp.byKey[st.key] then addWaypoint(st); added = added + 1 end
        end
        if added > 0 or removed > 0 then
            ns.Log("D", "tomtom", "Sync %s (%s): +%d −%d waypoints", plan.id, tostring(mode), added, removed)
        end
        if not target and mode ~= "route" then target = nearestStep(want) end
    end

    -- Reise: Flugmeister oder Anleger vor dem eigentlichen Ziel
    local prevSig = ns.travel and ns.travel.sig
    if target and tt and not ns.wp.suppressed["travel:" .. target.key] and ns.ComputeTravel then
        ns.travel = ns.ComputeTravel(target)
    else
        ns.travel = nil
    end
    if (ns.travel and ns.travel.sig) ~= prevSig then
        ns.wp.travelArrived = nil
        if ns.travel then ns.Log("I", "route", "Travel route for %s: %s", ns.StepTitle(target), ns.travel.text) end
    end
    if ns.wp.travelUid and (not ns.travel or ns.wp.travelSig ~= ns.travel.sig) then
        ns.wp.clearing = true
        pcall(tt.RemoveWaypoint, tt, ns.wp.travelUid)
        ns.wp.clearing = false
        ns.wp.uids[ns.wp.travelUid] = nil
        if ns.wp.arrowKey == "travel" then ns.wp.arrowKey = nil end
        ns.wp.travelUid, ns.wp.travelSig = nil, nil
    end
    if ns.travel and tt and not ns.wp.travelUid then
        local w = ns.travel.waypoint
        if w then
            addWaypoint({ key = "travel", map = w.map, x = w.x, y = w.y, title = w.title, text = w.text })
            if ns.wp.travelUid then ns.wp.travelSig = ns.travel.sig end
        end
    end

    ns.wp.targetKey = target and target.key or nil
    if not (tt and plan and target) then return end
    if ns.travel and ns.wp.travelUid then
        local empty = tt.IsCrazyArrowEmpty and tt:IsCrazyArrowEmpty()
        if force or empty or ns.wp.arrowKey ~= "travel" then
            -- Pfeiltext wie der Kartenpunkt: wohin es geht, nicht nur der Flugmeister
            tt:SetCrazyArrow(ns.wp.travelUid, ARRIVAL, ns.StepTitle(ns.travel.waypoint))
            ns.wp.arrowKey, ns.wp.arrowUid = "travel", ns.wp.travelUid
            ns.Log("D", "tomtom", "Arrow → %s", ns.StepTitle(ns.travel.waypoint))
        end
    else
        ns.PointArrow(target, force or ns.wp.arrowKey == "travel")
    end
end

-- Alle Roadbook-Punkte bei TomTom entfernen und für den aktiven Plan neu setzen,
-- auch die von Hand entfernten. Der Pfeil zeigt danach wieder auf den Plan.
function ns.ResetWaypoints(quiet)
    local tt = TT()
    if not tt then
        ns.Print(L["TomTom is not loaded – without TomTom there are no waypoints."])
        ns.Log("W", "tomtom", "Reset waypoints: TomTom is missing.")
        return
    end
    local plan = ns.ActivePlan()
    ns.wp.clearing = true
    for uid in pairs(ns.wp.uids) do pcall(tt.RemoveWaypoint, tt, uid) end
    ns.wp.clearing = false
    local hidden = countKeys(ns.wp.suppressed)
    wipe(ns.wp.uids); wipe(ns.wp.byKey); wipe(ns.wp.suppressed)
    ns.wp.arrowKey, ns.wp.travelUid, ns.wp.travelSig, ns.wp.travelArrived = nil, nil, nil, nil
    ns.travel = nil
    ns.wp.riding = nil
    ns.wp.forceArrow = true
    ns.Refresh()
    local n = countKeys(ns.wp.uids)
    ns.Log("I", "tomtom", "Waypoints set again: %d for %s (%d had been removed by hand).", n,
        plan and plan.id or "no plan", hidden)
    if quiet then return end
    if not plan then
        ns.Print(L["No plan loaded – old Roadbook waypoints are removed."])
        return
    end
    local cur = ns.CurrentStep(plan)
    if not cur then
        ns.Print((L["“%s” has no open step left – nothing to show. “Reset” brings skipped steps back."]):format(plan.title))
    elseif not cur.map then
        ns.Print((L["The next step “%s” has no coordinates (e.g. inside an instance)."]):format(ns.StepTitle(cur)))
    elseif ns.travel and ns.travel.stepKey == cur.key then
        ns.Print((L["Waypoints set again (%d). %s – then on to: %s"]):format(n, ns.travel.text, ns.StepTitle(cur)))
    else
        ns.Print((L["Waypoints set again (%d), arrow on: %s"]):format(n, ns.StepTitle(cur)))
    end
    local prof = tt.profile
    if type(prof) == "table" and type(prof.arrow) == "table" and prof.arrow.enable == false then
        ns.Print(L["Note: the TomTom arrow is switched off in the TomTom settings (/tomtom)."])
    end
end

---------------------------------------------------------------------------
-- Routenplanung nach Reisezeit
--
-- Früher: Luftlinie in Weltkoordinaten. Die kennt keine Flugrouten, Berge,
-- Aufzüge oder Gebiete – deshalb wirkte die Reihenfolge oft wie „nach
-- Koordinaten“. Jetzt kostet jeder Weg Sekunden:
--   zu Fuß     Luftlinie × Umweg / Lauftempo
--   Flug       zum nächsten BEKANNTEN Flugpunkt laufen + Flug + weiterlaufen
--   Zeppelin/Schiff/Tiefenbahn (Haltestellen aus Leatrix Maps und QuestieDB)
--   Gebietswechsel kosten etwas extra, damit ein Gebiet am Stück dran ist.
-- Die Reihenfolge: nächster Halt zuerst, danach verbessert (2-opt + Umsetzen).
---------------------------------------------------------------------------
local RUN_SPEED = 7          -- Yards/s zu Fuß
local DETOUR = 1.3           -- echte Wege sind länger als die Luftlinie
local FLY_SPEED = 28         -- Yards/s Luftlinie (gemessen: Crossroads → Ratchet in 52 s)
local FLY_OVERHEAD = 25      -- Flugmeister, Start, Landung
local ZONE_CHANGE = 45       -- Sekunden extra je Gebietswechsel
local SHIP_TIME = 300        -- Zeppelin/Schiff inkl. Warten
local NO_LINK = 3600         -- Kontinent ohne bekannte Verbindung
local NEAR_TAXI = 2          -- so viele Flugpunkte je Halt prüfen
ns.ROUTE = { RUN_SPEED = RUN_SPEED, FLY_SPEED = FLY_SPEED, ZONE_CHANGE = ZONE_CHANGE }

local function num(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return type(v) == "number" and v or tonumber(v)
end

local function vecXY(v)
    if type(v) ~= "table" then return nil end
    local x, y = v.x, v.y
    if (x == nil or y == nil) and v.GetXY then x, y = v:GetXY() end
    return num(x), num(y)
end

local posCache = {}
-- Weltposition eines Kartenpunkts (x, y in 0–100) als { c = Kontinent, x, y, map }
function ns.WorldPos(map, x, y, nocache)
    if not (map and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local key = ("%d:%.2f:%.2f"):format(map, x, y)
    if not nocache then
        local hit = posCache[key]
        if hit ~= nil then return hit or nil end
    end
    local p = false
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
    if ok and cont then
        local wx, wy = vecXY(pos)
        cont = num(cont)
        if wx and wy and cont then p = { c = cont, x = wx, y = wy, map = map } end
    end
    if not nocache and p then posCache[key] = p end   -- Fehlschläge nicht merken (Kartendaten kommen evtl. später)
    return p or nil
end

function ns.StepPos(step)
    if not (step and step.map and step.x and step.y) then return nil end
    return ns.WorldPos(step.map, step.x, step.y)
end

function ns.PlayerPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
    map = ok and num(map) or nil
    if not map then return nil end
    local ok2, p = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not ok2 then return nil end
    local x, y = vecXY(p)
    if not (x and y) then return nil end
    local w = ns.WorldPos(map, x * 100, y * 100, true)
    if not w then return nil end
    return { c = w.c, x = w.x, y = w.y, map = map, player = true }
end

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Lauftempo: 7 Yards/s, mit Reittier das zuletzt gemessene Reittempo
local function runSpeed()
    if IsMounted and GetUnitSpeed and IsMounted() then
        local _, run = GetUnitSpeed("player")
        run = num(run)
        if run and run > RUN_SPEED and run < 30 then ns.C.mountSpeed = run end
    end
    local m = ns.C and tonumber(ns.C.mountSpeed)
    return (m and m > RUN_SPEED) and m or RUN_SPEED
end

-- Mit Geländekarte (siehe „Gelände“ weiter unten) die Weglänge um Berge herum, sonst die Luftlinie
local function walkTime(a, b)
    return (ns.GridLen and ns.GridLen(a, b) or dist(a, b)) * DETOUR / runSpeed()
end

---------------------------------------------------------------------------
-- Flugpunkte: bekannt sind die, die du beim Flugmeister gesehen hast (wird
-- unter der Flugpunkt-Nummer gemerkt). Positionen aus C_TaxiMap.
---------------------------------------------------------------------------
ns.taxiVersion = 0
local taxiCache = {}

local function shortName(name) return (tostring(name or ""):match("^([^,]+)") or tostring(name or "")) end
ns.ShortTaxiName = shortName

local function taxiKnownSet()
    ns.C.taxi = type(ns.C.taxi) == "table" and ns.C.taxi or {}
    return ns.C.taxi
end

local function continentMap(map)
    local CONT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
    for _ = 1, 8 do
        if not map then return nil end
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
        if not info then return nil end
        if info.mapType == CONT then return map end
        map = info.parentMapID
    end
end

-- Beim Flugmeister: alle erreichbaren Flugpunkte merken
function ns.RecordTaxi()
    local added, set = 0, taxiKnownSet()
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and GetTaxiMapID then
        local okId, mapID = pcall(GetTaxiMapID)
        local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, okId and mapID or 0)
        if ok and type(nodes) == "table" then
            for _, n in ipairs(nodes) do
                local st, id = num(n.state), num(n.nodeID)
                if id and (st == 0 or st == 1) and not set[id] then set[id] = true; added = added + 1 end
            end
            -- Auf diesem Kontinent ist die Liste jetzt vollständig: was fehlt, ist wirklich unbekannt
            local here = ns.PlayerPos()
            local cont = here and continentMap(here.map)
            if cont and #nodes > 0 then
                ns.C.taxiSeen = type(ns.C.taxiSeen) == "table" and ns.C.taxiSeen or {}
                ns.C.taxiSeen[cont] = true
            end
        end
    end
    ns.taxiVersion = ns.taxiVersion + 1
    if added > 0 then
        ns.Log("I", "route", "%d flight point(s) remembered as known (%d in total).", added, countKeys(ns.C.taxi))
    end
end

local function isKnownTaxi(node)
    local set = taxiKnownSet()
    local id = num(node.nodeID)
    if id and set[id] then return true end
    if next(set) then
        -- Einträge bis 0.7 standen unter dem (übersetzten) Namen: einmalig auf die Nummer umziehen
        local short = shortName(node.name)
        for key in pairs(set) do
            if type(key) == "string" and (key == node.name or shortName(key) == short) then
                if id then set[key] = nil; set[id] = true end
                return true
            end
        end
        return false
    end
    -- Noch keine Flugkarte geöffnet: nichts als bekannt werten. Das Feld isUndiscovered
    -- taugt dafür nicht – auf Forever meldet es auch nie besuchte Flugpunkte als entdeckt.
    return false
end

local function factionOk(f)
    f = num(f)
    if f == nil or f == 0 then return true end
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    return (f == 1 and mine == "Horde") or (f == 2 and mine == "Alliance")
end

-- Flugpunkte auf dem Kontinent eines Kartenpunkts: bekannte, unbekannte
local function taxiNodesFor(map)
    local cont = continentMap(map)
    if not cont then return {}, {} end
    local hit = taxiCache[cont]
    if hit and hit.ver == ns.taxiVersion then return hit.list, hit.unknown end
    local list, unknown, seen, total = {}, {}, {}, 0
    local function collect(mapID)
        if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return end
        local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
        if not (ok and type(nodes) == "table") then return end
        for _, n in ipairs(nodes) do
            local id = type(n) == "table" and (n.nodeID or n.name)
            if id and n.name and not seen[id] and factionOk(n.faction) then
                seen[id] = true
                total = total + 1
                local x, y = vecXY(n.position)
                local p = x and y and ns.WorldPos(mapID, x * 100, y * 100)
                if p then
                    table.insert(isKnownTaxi(n) and list or unknown,
                        { c = p.c, x = p.x, y = p.y, name = n.name, short = shortName(n.name), id = n.nodeID,
                          map = mapID, mx = x * 100, my = y * 100, undiscovered = n.isUndiscovered })
                end
            end
        end
    end
    collect(cont)
    -- Manche Clients zeigen Flugpunkte nur auf Gebietskarten: dann die Gebiete abfragen
    if total == 0 and C_Map and C_Map.GetMapChildrenInfo then
        local ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
        local ok, kids = pcall(C_Map.GetMapChildrenInfo, cont, ZONE, true)
        if ok and type(kids) == "table" then
            for _, k in ipairs(kids) do if k.mapID then collect(k.mapID) end end
        end
    end
    taxiCache[cont] = { ver = ns.taxiVersion, list = list, unknown = unknown }
    if not taxiCache["log" .. cont] then
        taxiCache["log" .. cont] = true
        ns.Log("I", "route", "Flight points on map %d: %d found, %d of them known.", cont, total, #list)
    end
    return list, unknown
end
ns.KnownTaxiNodes = taxiNodesFor

-- Ist die Liste der bekannten Flugpunkte auf diesem Kontinent vollständig?
function ns.TaxiListComplete(map)
    local cont = continentMap(map)
    return type(ns.C.taxiSeen) == "table" and cont and ns.C.taxiSeen[cont] and true or false
end

-- Die nächsten bekannten Flugpunkte eines Punkts (zu Fuß), zwischengespeichert
local function nearTaxi(p)
    local ver = ns.taxiVersion .. ":" .. runSpeed()
    if p._near and p._nearVer == ver then return p._near, p._nearNew end
    local all, unknown = taxiNodesFor(p.map)
    local function nearest(list, new)
        -- erst nach Luftlinie vorsortieren: die Wegsuche übers Gelände nur für die nächsten sechs
        local air = {}
        for _, n in ipairs(list) do
            if n.c == p.c then air[#air + 1] = { node = n, d = dist(p, n) } end
        end
        table.sort(air, function(a, b) return a.d < b.d end)
        local scored = {}
        for i = 1, math.min(6, #air) do scored[i] = { node = air[i].node, t = walkTime(p, air[i].node), new = new } end
        table.sort(scored, function(a, b) return a.t < b.t end)
        local out = {}
        for i = 1, math.min(NEAR_TAXI, #scored) do out[i] = scored[i] end
        return out
    end
    local out = nearest(all)
    -- Unbekannte Flugmeister taugen als Abflugpunkt: hinlaufen, kennenlernen, losfliegen.
    -- Nur wo die Liste verlässlich ist (auf dem Kontinent wurde schon eine Flugkarte geöffnet).
    local outNew = ns.TaxiListComplete(p.map) and nearest(unknown, true) or {}
    p._near, p._nearNew, p._nearVer = out, outNew, ver
    return out, outNew
end

---------------------------------------------------------------------------
-- Zeppeline, Schiffe und die Tiefenbahn. Man muss sie nicht „kennenlernen“
-- (anders als Flugpunkte): alle Linien der eigenen Fraktion zählen immer.
--
-- Quellen: Leatrix Maps (Leatrix_Maps_Icons.lua: alle Haltestellen auf Forever
-- mit Ziel, Fraktion und Fahrtrichtung) und QuestieDB (Standort der Zeppelin-
-- und Schiffsmeister in Orgrimmar, Undercity, Grom'gol, Ratchet und Booty Bay).
--
-- { Karte, x, y, Karte, x, y, Fraktion (nil = alle), Art, Ort A, Ort B, nur A → B }
-- Ein Ort als Zahl ist eine Karten-Nummer: der Name kommt dann vom Spiel.
---------------------------------------------------------------------------
local ZEP, BOAT, TRAM = L["Zeppelin %s – %s"], L["Boat %s – %s"], L["Tram %s – %s"]
local LINKS = {
    -- Horde
    { 1411, 50.82, 13.54, 1420, 60.74, 58.87, "Horde", ZEP, "Orgrimmar", "Undercity" },
    { 1411, 50.69, 12.89, 1434, 31.43, 29.91, "Horde", ZEP, "Orgrimmar", "Grom'gol" },
    { 1420, 61.78, 59.18, 1434, 31.54, 29.36, "Horde", ZEP, "Undercity", "Grom'gol" },
    { 1412, 34.3, 26.1, 2521, 57.7, 81.0, "Horde", ZEP, "Thunder Bluff", L["Zephras Isle"] },
    { 1446, 68.6, 23.0, 2548, 80.6, 54.6, "Horde", BOAT, "Tanaris", L["Riverglades"] },
    -- alle
    { 1413, 63.54, 38.61, 1434, 26.08, 73.35, nil, BOAT, "Ratchet", "Booty Bay" },
    -- Allianz
    { 1453, 21.8, 56.9, 1439, 30.5, 40.9, "Alliance", BOAT, "Stormwind", "Auberdine" },
    { 1439, 33.3, 39.8, 1438, 54.8, 97.2, "Alliance", BOAT, "Auberdine", "Rut'theran" },
    { 1437, 4.7, 63.8, 1445, 71.7, 56.7, "Alliance", BOAT, L["Menethil Harbor"], "Theramore" },
    { 2521, 65.8, 83.8, 1416, 12.8, 51.2, "Alliance", BOAT, L["Zephras Isle"], 1416 },
    { 1444, 43.1, 42.8, 1444, 31.0, 39.5, "Alliance", BOAT, 1444, "Feathermoon" },
    { 1453, 66.6, 34.7, 1455, 73.0, 50.2, "Alliance", TRAM, "Stormwind", "Ironforge" },
    -- Rundfahrt, nur in dieser Richtung: Auberdine → Menethil → Southshore → Auberdine
    { 1439, 32.3, 44.1, 1437, 4.5, 56.7, "Alliance", BOAT, "Auberdine", L["Menethil Harbor"], true },
    { 1437, 4.5, 56.7, 1424, 50.7, 70.4, "Alliance", BOAT, L["Menethil Harbor"], "Southshore", true },
    { 1424, 50.7, 70.4, 1439, 32.3, 44.1, "Alliance", BOAT, "Southshore", "Auberdine", true },
}
local function placeName(v)
    if type(v) ~= "number" then return v end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(v)
    return info and info.name or tostring(v)
end
local linkCache

-- Zwischenspeicher leeren (Karten-/Flugpunktdaten neu lesen)
function ns.ClearRouteCache()
    wipe(posCache); wipe(taxiCache)
    linkCache = nil
end

local function links()
    if linkCache then return linkCache end
    local list, complete = {}, true
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    for _, l in ipairs(LINKS) do
        if not l[7] or l[7] == mine then
            local a, b = ns.WorldPos(l[1], l[2], l[3]), ns.WorldPos(l[4], l[5], l[6])
            if not (a and b) then
                complete = false
            else
                local name = l[8]:format(placeName(l[9]), placeName(l[10]))
                local am = { map = l[1], x = l[2], y = l[3] }
                local bm = { map = l[4], x = l[5], y = l[6] }
                table.insert(list, { a = a, b = b, name = name, am = am, bm = bm })
                if not l[11] then table.insert(list, { a = b, b = a, name = name, am = bm, bm = am }) end
            end
        end
    end
    if complete then linkCache = list end   -- sonst beim nächsten Mal neu versuchen
    return list
end

---------------------------------------------------------------------------
-- Kosten eines Wegs a → b in Sekunden; dazu wie (lauf/flug/schiff) und womit
---------------------------------------------------------------------------
local function sameContinent(a, b)
    local best, how, via = walkTime(a, b), "lauf", nil
    local na, naNew = nearTaxi(a)
    local nb = nearTaxi(b)
    local function try(A)
        for _, B in ipairs(nb) do
            if A.node ~= B.node then
                local t = A.t + FLY_OVERHEAD + dist(A.node, B.node) / FLY_SPEED + B.t
                if t < best then
                    best, how, via = t, "flug", { from = A.node, to = B.node, walkTo = A.t, walkFrom = B.t, new = A.new }
                end
            end
        end
    end
    for _, A in ipairs(na) do try(A) end
    for _, A in ipairs(naNew) do try(A) end   -- Abflug bei einem Flugmeister, den du dabei kennenlernst
    return best, how, via
end

function ns.LegCost(a, b)
    if not (a and b) then return nil end
    local zone = (a.map and b.map and a.map ~= b.map) and ZONE_CHANGE or 0
    local best, how, via
    if a.c == b.c then best, how, via = sameContinent(a, b) end
    -- Zeppelin/Schiff: zwischen Kontinenten nötig, auf demselben Kontinent oft schneller
    -- als der Fußweg (z. B. Undercity – Grom'gol statt quer durch die Östlichen Königreiche)
    for _, l in ipairs(links()) do
        if l.a.c == a.c and l.b.c == b.c then
            local t = sameContinent(a, l.a) + SHIP_TIME + sameContinent(l.b, b)
            if not best or t < best then best, how, via = t, "schiff", l end
        end
    end
    if not best then return NO_LINK + zone, "fern", nil end
    return best + zone, how, via
end

local function fmtTime(sec)
    sec = math.floor((sec or 0) + 0.5)
    if sec < 60 then return ("%d s"):format(sec) end
    if sec < 3600 then return (L["%d min"]):format(math.floor(sec / 60 + 0.5)) end
    return (L["%d:%02d h"]):format(math.floor(sec / 3600), math.floor((sec % 3600) / 60 + 0.5))
end
ns.FmtTime = fmtTime

-- EP einer Abgabe, wie das Spiel sie für die Quest im Questlog nennt (nil: unbekannt, keine,
-- oder im Reiter Optionen abgeschaltet). Ob aktive EP-Boni darin stecken, entscheidet das Spiel.
function ns.QuestXP(quest)
    if ns.DB.noQuestXP or not (quest and GetQuestLogRewardXP) then return nil end
    local ok, xp = pcall(GetQuestLogRewardXP, quest)
    xp = ok and num(xp) or nil
    return xp and xp > 0 and xp or nil
end

-- Summe der EP aller offenen Abgaben eines Plans, dazu der Anteil an der aktuellen Stufe in Prozent
function ns.PlanXP(plan)
    local total = 0
    for _, st in ipairs(plan.steps) do
        if st.type == "turnin" then
            local state = ns.StepState(st, plan.id)
            if state == "open" or state == "ready" then total = total + (ns.QuestXP(st.quest) or 0) end
        end
    end
    if total == 0 then return nil end
    local max = num(UnitXPMax and UnitXPMax("player"))
    return total, (max and max > 0) and math.floor(total / max * 100 + 0.5) or nil
end

---------------------------------------------------------------------------
-- Reiseweg zum nächsten Ziel: Lohnt sich ein Flug, zeigt der Pfeil erst zum
-- Flugmeister (mit „Flug nach …“), nach der Landung zum Ziel. Zwischen
-- Kontinenten erst zum Flugmeister bzw. Anleger des Zeppelins/Schiffs.
-- Damit der Pfeil nicht hin und her springt, bleibt ein gewählter Weg, bis
-- ein anderer klar besser ist (mind. 20 s bzw. 10 %).
---------------------------------------------------------------------------
-- Zahlen-Einstellungen (Reiter Optionen): { Standard, kleinster, größter Wert, Schritt }
ns.OPTS = {
    flySaving = { 30, 0, 300, 15 },     -- Sekunden, die ein Flug mindestens sparen muss …
    searchHits = { 8, 4, 20, 2 },       -- Treffer in der NPC-Suche
    trashMinutes = { 10, 5, 60, 5 },    -- so lange bleibt Gelöschtes im Papierkorb
    hearthSaving = { 15, 5, 60, 5 },    -- Minuten, die der Ruhestein mindestens sparen muss
    groupSaving = { 10, 5, 60, 5 },     -- Minuten, ab denen ein Portal/eine Beschwörung empfohlen wird
}

function ns.Opt(key)
    local o = ns.OPTS[key]
    local v = tonumber(ns.DB and type(ns.DB.opt) == "table" and ns.DB.opt[key])
    return v and math.max(o[2], math.min(o[3], v)) or o[1]
end

function ns.SetOpt(key, value)
    local o = ns.OPTS[key]
    ns.DB.opt = type(ns.DB.opt) == "table" and ns.DB.opt or {}
    ns.DB.opt[key] = math.max(o[2], math.min(o[3], math.floor((tonumber(value) or o[1]) + 0.5)))
    ns.Log("I", "options", "%s = %d", key, ns.DB.opt[key])
    ns.Refresh()
end

local MIN_SAVING_SHARE = 0.2 -- … und mindestens diesen Anteil der Laufzeit (die Schätzung ist grob)
local KEEP_MARGIN = 20      -- Sekunden Vorsprung, bevor der Weg wechselt

-- Kartenposition eines Flugpunkts für TomTom (möglichst Gebiets-/Stadtkarte)
local function nodeMapPos(node)
    if node._wp then return node._wp end
    local w
    if C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D then
        local ok, map, pos = pcall(C_Map.GetMapPosFromWorldPos, node.c, CreateVector2D(node.x, node.y))
        local x, y = vecXY(pos)
        map = ok and num(map) or nil
        if map and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            w = { map = map, x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10 }
        end
    end
    if not w and node.map and node.mx then
        w = { map = node.map, x = math.floor(node.mx * 10 + 0.5) / 10, y = math.floor(node.my * 10 + 0.5) / 10 }
    end
    node._wp = w
    return w
end

---------------------------------------------------------------------------
-- Sprünge: eigene Teleports (Magier) und der Ruhestein als Reiseweg. Dazu als
-- Empfehlung: Portale von Magiern in der Gruppe (sie teilen ihre Portale über
-- Roadbook, siehe Share.lua) und Beschwörungen von Hexenmeistern in der Gruppe.
-- Alles einzeln abschaltbar im Reiter Optionen.
-- shortcut: Sprünge zählen nur für den Weg ab deinem Standort, nicht beim Sortieren
-- eines Plans (ns.LegCost); aufrüsten, wenn Magier-Routen dadurch spürbar schlechter sind.
---------------------------------------------------------------------------
local JUMP_TIME = 25      -- Zauberzeit 10 s + Ladebildschirm
local PORTAL_TIME = 60    -- fragen, zaubern, durchgehen
local SUMMON_TIME = 120   -- fragen, Helfer finden, Ritual
local ARRIVED = 300       -- Yards: so nah am Ankunftsort ist der Sprung erledigt
local RUNE_TELEPORT, HEARTHSTONE, HEARTH_SPELL = 17031, 6948, 8690
-- { Teleport, Portal, Karte, x, y, Fraktion }; Ankunft beim Portallehrer der Stadt (QuestieDB)
ns.CITY_SPELLS = {
    { 3567, 11417, 1454, 38.7, 85.4, "Horde" },     -- Orgrimmar
    { 3563, 11418, 1458, 84.2, 15.6, "Horde" },     -- Undercity
    { 3566, 11420, 1456, 22.5, 16.9, "Horde" },     -- Thunder Bluff
    { 3561, 10059, 1453, 50.4, 86.0, "Alliance" },  -- Stormwind
    { 3562, 11416, 1455, 25.5, 7.1, "Alliance" },   -- Ironforge
    { 3565, 11419, 1457, 40.6, 82.1, "Alliance" },  -- Darnassus
}

function ns.KnowsSpell(spell)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spell)
        if ok and known then return true end
    end
    return (IsPlayerSpell and IsPlayerSpell(spell)) or (IsSpellKnown and IsSpellKnown(spell)) or false
end

local function spellName(spell)
    local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
    return n or (GetSpellInfo and (GetSpellInfo(spell))) or nil
end

local function hearthReady()
    if ns.ItemCount(HEARTHSTONE) < 1 then return false end
    local get = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not get then return true end
    local ok, start, dur = pcall(get, HEARTHSTONE)
    start, dur = num(start), num(dur)
    return not (ok and start and dur and dur > 0 and start + dur - GetTime() > 0)
end

-- Wo der Ruhestein hinführt, sagt das Spiel nur als Namen. Den Ort merkt sich Roadbook,
-- wenn du ihn beim Gastwirt setzt oder den Stein benutzt (afterUse: nur kurz nach dem Zauber).
function ns.RecordHearth(afterUse)
    if afterUse and not (ns.hearthUsedAt and GetTime() - ns.hearthUsedAt < 120) then return end
    local here, name = ns.PlayerPos(), GetBindLocation and GetBindLocation()
    if not (here and name) then return end
    ns.hearthUsedAt = nil
    ns.C.hearth = { name = name, c = here.c, x = here.x, y = here.y, map = here.map }
    ns.Log("I", "route", "Hearthstone location remembered: %s", name)
end

function ns.OnSpellCast(spell)
    if num(spell) ~= HEARTH_SPELL then return end
    ns.hearthUsedAt = GetTime()
    C_Timer.After(3, function() ns.RecordHearth(true) end)
end

local function groupUnits()
    local out = {}
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do out[i] = "raid" .. i end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do out[i] = "party" .. i end
    end
    return out
end

local function unitPos(unit)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, map = pcall(C_Map.GetBestMapForUnit, unit)
    map = ok and num(map) or nil
    if not map then return nil end
    local ok2, p = pcall(C_Map.GetPlayerMapPosition, map, unit)
    local x, y = vecXY(ok2 and p)
    if not (x and y) then return nil end
    return ns.WorldPos(map, x * 100, y * 100, true)
end

-- Jeder Sprung: { kind, sig, name, who, pos = Ankunft, lead = Sekunden bis dort, min = Mindestersparnis }
local function jumps(from)
    local out = {}
    if not ns.DB.noTeleport and ns.ItemCount(RUNE_TELEPORT) > 0 then
        for _, s in ipairs(ns.CITY_SPELLS) do
            local pos = ns.KnowsSpell(s[1]) and ns.WorldPos(s[3], s[4], s[5])
            if pos then
                out[#out + 1] = { kind = "sprung", sig = "sprung:" .. s[1], name = spellName(s[1]) or placeName(s[3]),
                                  pos = pos, lead = JUMP_TIME, min = ns.Opt("flySaving") }
            end
        end
    end
    local h = ns.C.hearth
    if not ns.DB.noHearth and type(h) == "table" and h.name == (GetBindLocation and GetBindLocation()) and hearthReady() then
        out[#out + 1] = { kind = "sprung", sig = "sprung:hearth", name = (L["Hearthstone (%s)"]):format(h.name),
                          pos = { c = h.c, x = h.x, y = h.y, map = h.map }, lead = JUMP_TIME, min = ns.Opt("hearthSaving") * 60 }
    end
    local wantPortal, wantSummon = not ns.DB.noPortalHint, not ns.DB.noSummonHint
    if not (wantPortal or wantSummon) then return out end
    local min = ns.Opt("groupSaving") * 60
    for _, unit in ipairs(groupUnits()) do
        local name = UnitName(unit)
        local _, class = UnitClass(unit)
        if name and not (UnitIsUnit and UnitIsUnit(unit, "player")) and not (UnitIsConnected and not UnitIsConnected(unit)) then
            local known = wantPortal and ns.portals and ns.portals[name]
            local pos = (known or class == "WARLOCK") and unitPos(unit)
            if known and pos and pos.c == from.c then
                for _, s in ipairs(ns.CITY_SPELLS) do
                    local dest = known[s[2]] and ns.WorldPos(s[3], s[4], s[5])
                    if dest then
                        out[#out + 1] = { kind = "portal", sig = ("portal:%s:%d"):format(name, s[2]), who = name, name = placeName(s[3]),
                                          pos = dest, lead = walkTime(from, pos) + PORTAL_TIME, min = min }
                    end
                end
            end
            if wantSummon and class == "WARLOCK" and pos and (num(UnitLevel and UnitLevel(unit)) or 0) >= 20 then
                out[#out + 1] = { kind = "ruf", sig = "ruf:" .. name, who = name, pos = pos, lead = SUMMON_TIME, min = min }
            end
        end
    end
    return out
end

local function jumpCost(from, to, j)
    if j.pos.c == from.c and dist(from, j.pos) < ARRIVED then return nil end
    return j.lead + (ns.LegCost(j.pos, to) or NO_LINK)
end

local function hopSig(hop)
    if hop.sig then return hop.sig end
    if hop.kind == "flug" then
        return ("flug:%s>%s"):format(tostring(hop.from.id or hop.from.name), tostring(hop.to.id or hop.to.name))
    end
    if hop.kind == "neu" then return "neu:" .. tostring(hop.node.id or hop.node.name) end
    return "schiff:" .. tostring(hop.name)
end

-- Erster Reiseabschnitt von from nach to: nil = zu Fuß
local function firstHop(from, to)
    local t, how, via = ns.LegCost(from, to)
    if how == "flug" and via then
        return t, { kind = "flug", from = via.from, to = via.to, new = via.new }
    elseif how == "schiff" and via then
        local _, how2, via2 = sameContinent(from, via.a)
        if how2 == "flug" and via2 then
            return t, { kind = "flug", from = via2.from, to = via2.to, after = via.name, new = via2.new }
        end
        return t, { kind = "schiff", dock = via.a, dockMap = via.am, name = via.name }
    end
    return t, nil
end

-- Was kostet es, dem gewählten Abschnitt von hier aus weiter zu folgen?
local function hopCost(from, to, hop)
    if hop.sig then   -- Sprung: gibt es ihn noch (Rune, Abklingzeit, Gruppe)?
        for _, j in ipairs(jumps(from)) do
            if j.sig == hop.sig then return jumpCost(from, to, j) or math.huge end
        end
        return math.huge
    end
    local start = (hop.kind == "flug" and hop.from) or (hop.kind == "neu" and hop.node) or hop.dock
    if not start or start.c ~= from.c then return math.huge end
    if hop.kind == "neu" then return walkTime(from, hop.node) + (ns.LegCost(hop.node, to) or NO_LINK) end
    if hop.kind == "flug" then
        return walkTime(from, hop.from) + FLY_OVERHEAD + dist(hop.from, hop.to) / FLY_SPEED + (ns.LegCost(hop.to, to) or NO_LINK)
    end
    return walkTime(from, hop.dock) + (ns.LegCost(hop.dock, to) or NO_LINK)
end

local function travelInfo(step, hop, cost, saves)
    local tr = { stepKey = step.key, stepTitle = ns.StepTitle(step), hop = hop, sig = hopSig(hop), cost = cost }
    local spare = (saves and saves >= 60) and (L[" – saves about %s"]):format(fmtTime(saves)) or ""
    -- Sprünge haben keinen Wegpunkt: der Pfeil bleibt auf dem Ziel, der Tracker nennt den Sprung
    if hop.kind == "sprung" then
        tr.text = (L["First use |cffffffff%s|r%s"]):format(hop.name, spare)
    elseif hop.kind == "portal" then
        tr.text = (L["Tip: ask %s for a portal to %s%s"]):format(hop.who, hop.name, spare)
    elseif hop.kind == "ruf" then
        tr.text = (L["Tip: ask %s for a summon%s"]):format(hop.who, spare)
    elseif hop.kind == "flug" then
        local w = nodeMapPos(hop.from)
        if not w then return nil end
        local dest = hop.to.short .. (hop.after and (L[", then "] .. hop.after) or "")
        tr.text = (hop.new and L["First to the undiscovered flight master in %s (you learn it on the way), fly to %s%s"]
            or L["First to the flight master in %s, fly to %s%s"]):format(hop.from.short, dest, spare)
        tr.arrive = (L["Flight master %s: fly to |cffffffff%s|r%s."]):format(hop.from.short, hop.to.name,
            hop.after and (L[", then "] .. hop.after) or "")
        tr.waypoint = { map = w.map, x = w.x, y = w.y, title = L["Flight master "] .. hop.from.short, text = L["Flight to "] .. hop.to.short .. (hop.after and (L[", then "] .. hop.after) or "") }
    elseif hop.kind == "neu" then
        local w = nodeMapPos(hop.node)
        if not w then return nil end
        tr.text = (L["Undiscovered flight master %s on the way (+%s) – pick it up"]):format(hop.node.short, fmtTime(hop.extra))
        tr.arrive = (L["Flight master %s: open the flight map to learn this flight point."]):format(hop.node.short)
        tr.waypoint = { map = w.map, x = w.x, y = w.y, title = L["Flight master "] .. hop.node.short, text = L["undiscovered – pick it up"] }
    else
        local m = hop.dockMap
        if not m then return nil end
        tr.text = (L["First to the dock: %s"]):format(hop.name)
        tr.arrive = (L["Dock reached: %s."]):format(hop.name)
        tr.waypoint = { map = m.map, x = m.x, y = m.y, title = L["Dock"], text = hop.name }
    end
    return tr
end

-- Unbekannter Flugmeister, der kaum Umweg kostet: mitnehmen. Ihn zu kennen spart später
-- mehr, als der Umweg jetzt kostet.
ns.PICKUP_DEFAULT, ns.PICKUP_STEP, ns.PICKUP_LIMIT = 120, 30, 600   -- Sekunden Umweg (Reiter Optionen, /rb detour)

function ns.PickupMax()
    local v = tonumber(ns.DB and ns.DB.pickupMax)
    return v and math.max(0, math.min(ns.PICKUP_LIMIT, v)) or ns.PICKUP_DEFAULT
end

function ns.SetPickupMax(seconds)
    ns.DB.pickupMax = math.max(0, math.min(ns.PICKUP_LIMIT, math.floor((tonumber(seconds) or ns.PICKUP_DEFAULT) + 0.5)))
    ns.Log("I", "route", "Detour for undiscovered flight masters: %d s", ns.DB.pickupMax)
    ns.Refresh()
end

local function pickupNode(from, to)
    local limit = ns.PickupMax()
    if limit <= 0 or not ns.TaxiListComplete(from.map) then return nil end
    local _, unknown = taxiNodesFor(from.map)
    local direct = walkTime(from, to)
    local node, least
    for _, n in ipairs(unknown) do
        -- Luftlinie zuerst: nur was grob in Frage kommt, bekommt die Wegsuche übers Gelände
        if n.c == from.c and n.c == to.c and (dist(from, n) + dist(n, to) - dist(from, to)) * DETOUR / runSpeed() <= limit * 2 then
            local extra = walkTime(from, n) + walkTime(n, to) - direct
            if extra <= limit and (not least or extra < least) then node, least = n, extra end
        end
    end
    return node, least
end

-- Reiseweg für einen Schritt ab deinem Standort (nil = zu Fuß bzw. unbekannt)
function ns.ComputeTravel(step)
    if not (step and step.map) then return nil end
    if ns.wp.riding then return nil end   -- auf dem Zeppelin/Schiff: der Anleger ist erledigt
    local cur = ns.travel and ns.travel.stepKey == step.key and ns.travel or nil
    if UnitOnTaxi and UnitOnTaxi("player") then return cur end   -- im Flug nichts ändern
    local from, to = ns.PlayerPos(), ns.StepPos(step)
    if not (from and to) then return cur end
    local best, hop = firstHop(from, to)
    if not best then return nil end
    local walk = (from.c == to.c) and (walkTime(from, to) + ((from.map ~= to.map) and ZONE_CHANGE or 0)) or nil
    -- Flug nur empfehlen, wenn er sich wirklich lohnt
    if hop and walk and walk - best < math.max(ns.Opt("flySaving"), walk * MIN_SAVING_SHARE) then hop, best = nil, walk end
    -- Zu Fuß unterwegs: liegt ein unbekannter Flugmeister fast am Weg?
    if not hop and walk then
        local node, extra = pickupNode(from, to)
        if node then hop, best = { kind = "neu", node = node, extra = extra }, walk + extra end
    end
    -- Teleport, Ruhestein, Portal oder Beschwörung: nur, wenn es die Mindestersparnis bringt
    local saves = walk and (walk - best) or nil
    local base = best
    for _, j in ipairs(jumps(from)) do
        local t = jumpCost(from, to, j)
        if t and base - t >= j.min and t < best then hop, best, saves = j, t, base - t end
    end
    -- Gewählten Weg behalten, solange der neue nicht klar besser ist
    if cur and cur.hop.kind ~= "neu" and (not hop or hopSig(hop) ~= cur.sig) then
        local keep = hopCost(from, to, cur.hop)
        if keep <= best + math.max(KEEP_MARGIN, best * 0.1) then
            hop, best = cur.hop, keep
        end
    end
    if not hop then return nil end
    return travelInfo(step, hop, best, saves)
end

-- An Bord erkannt: du wirst bewegt, läufst aber nicht selbst. Dann ist der Anleger
-- erledigt – der Punkt verschwindet und der Pfeil zeigt zum Ziel. Sobald du wieder
-- selbst läufst (angekommen), wird der Weg neu berechnet.
local lastSpot, carried = nil, 0

function ns.CheckRiding()
    if ns.staging then return end
    local here = ns.PlayerPos()
    local speed = GetUnitSpeed and num((GetUnitSpeed("player")))
    if ns.wp.riding then
        if speed and speed > 0 then
            ns.wp.riding = nil
            ns.Log("I", "route", "Left the zeppelin or boat – travel route is calculated again.")
            ns.ScheduleRefresh()
        end
    elseif here and lastSpot and here.c == lastSpot.c and speed == 0 and ns.travel and ns.travel.hop.kind == "schiff"
           and not (UnitOnTaxi and UnitOnTaxi("player")) and dist(here, lastSpot) > 6 then
        carried = carried + 1
        if carried >= 2 then   -- zwei Messungen hintereinander: kein Rückstoß, kein Aufzug
            carried = 0
            ns.wp.riding = true
            ns.Print((L["On board (%s) – the arrow now points to your destination."]):format(ns.travel.hop.name))
            ns.Log("I", "route", "On board detected: %s", ns.travel.hop.name)
            ns.ScheduleRefresh()
        end
    else
        carried = 0
    end
    lastSpot = here
end

-- Alle 2 Sekunden: hat sich der beste Reiseweg geändert? Dann neu abgleichen.
function ns.CheckTravel()
    if ns.staging then return end
    local plan = ns.ActivePlan()
    if not (plan and ns.wp.targetKey and _G.TomTom) then return end
    if UnitOnTaxi and UnitOnTaxi("player") then return end
    local step
    for _, st in ipairs(plan.steps) do if st.key == ns.wp.targetKey then step = st break end end
    if not step or ns.wp.suppressed["travel:" .. step.key] then return end
    local tr = ns.ComputeTravel(step)
    if (tr and tr.sig) ~= (ns.travel and ns.travel.sig) then
        ns.Log("D", "route", "Travel route changes: %s → %s", ns.travel and ns.travel.sig or "on foot", tr and tr.sig or "on foot")
        ns.ScheduleRefresh()
    end
end

-- Unbekannter Flugmeister in der Nähe: einmal pro Sitzung melden – ihn jetzt
-- mitzunehmen spart später Zeit. „Unbekannt“ heißt: das Spiel meldet ihn so,
-- oder du hast auf diesem Kontinent schon eine Flugkarte geöffnet und er fehlte.
local NEW_TAXI_RANGE = 400
local taxiHinted = {}

function ns.CheckNewTaxi()
    if ns.staging then return end
    if UnitOnTaxi and UnitOnTaxi("player") then return end
    local here = ns.PlayerPos()
    if not here then return end
    local cont = continentMap(here.map)
    local _, unknown = taxiNodesFor(here.map)
    local seen = type(ns.C.taxiSeen) == "table" and cont and ns.C.taxiSeen[cont]
    for _, n in ipairs(unknown) do
        local key = n.id or n.name
        if n.c == here.c and not taxiHinted[key] and (n.undiscovered == true or seen) then
            local d = dist(here, n)
            if d < NEW_TAXI_RANGE then
                taxiHinted[key] = true
                ns.newTaxi = n
                if not ns.DB.quietTaxi then   -- Reiter Optionen; /rb fm geht trotzdem
                    ns.Print((L["Undiscovered flight master nearby: |cffffffff%s|r (%d yd). |cffffffff/rb fm|r sets a waypoint."]):format(n.name, d))
                end
                ns.Log("I", "route", "Undiscovered flight master nearby: %s (%d yd)", n.name, d)
            end
        end
    end
end

function ns.WaypointNewTaxi()
    local tt, n = _G.TomTom, ns.newTaxi
    local w = n and nodeMapPos(n)
    if not (tt and w) then ns.Print(L["No undiscovered flight master nearby."]) return end
    -- eigener Absender: der Abgleich räumt nur Punkte mit from = "Roadbook" auf
    pcall(tt.AddWaypoint, tt, w.map, w.x / 100, w.y / 100,
        { title = L["Flight master "] .. n.short, from = "Roadbook flight master", persistent = false, crazy = true })
end

do
    local ticker = CreateFrame("Frame")
    local acc = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 2 then return end
        acc = 0
        if ns.C and ns.Safe then
            ns.Safe("travel", ns.BuildGrid)
            ns.Safe("travel", ns.CheckRiding)
            ns.Safe("travel", ns.CheckTravel)
            ns.Safe("travel", ns.CheckNewTaxi)
        end
    end)
    ns.travelTicker = ticker
end

-- Am Flugmeister: sagen, wohin es geht
function ns.OnTaxiMapOpened()
    ns.RecordTaxi()
    local plan = ns.ActivePlan()
    if not (plan and ns.wp.targetKey) then return end
    local step
    for _, st in ipairs(plan.steps) do if st.key == ns.wp.targetKey then step = st break end end
    if not step then return end
    local tr = ns.ComputeTravel(step)
    local here = ns.PlayerPos()
    if tr and tr.hop.kind == "flug" and here and here.c == tr.hop.from.c and dist(here, tr.hop.from) < 250 then
        ns.Print((L["Fly to |cffffffff%s|r%s – for “%s”."]):format(tr.hop.to.name,
            tr.hop.after and (L[", then "] .. tr.hop.after) or "", ns.StepTitle(step)))
    elseif not tr then
        ns.Print((L["Walking is the fastest way to “%s”."]):format(ns.StepTitle(step)))
    end
end

-- Gesamtdauer einer Reihenfolge (Liste von Positionen) ab start
local function pathCost(start, list)
    local total, prev = 0, start
    for _, p in ipairs(list) do
        if prev then total = total + (ns.LegCost(prev, p) or 0) end
        prev = p
    end
    return total
end
ns.PathCost = pathCost

-- Reihenfolge für Positionen: nächster Halt zuerst, dann 2-opt und Umsetzen.
-- Rückgabe: Liste der Indizes in neuer Reihenfolge.
function ns.OrderPositions(start, pts)
    local n = #pts
    if n == 0 then return {} end
    local C = {}
    for i = 0, n do
        C[i] = {}
        local a = (i == 0) and start or pts[i]
        for j = 1, n do
            if i ~= j then C[i][j] = a and ns.LegCost(a, pts[j]) or 0 end
        end
    end
    -- nächster Halt zuerst
    local order, used, cur = {}, {}, 0
    for k = 1, n do
        local bj, bc
        for j = 1, n do
            if not used[j] and (not bc or C[cur][j] < bc) then bj, bc = j, C[cur][j] end
        end
        used[bj] = true
        order[k] = bj
        cur = bj
    end
    local function c(i, j) if j == nil then return 0 end return C[i][j] end
    local function prevOf(k) return (k == 1) and 0 or order[k - 1] end
    for _ = 1, (n > 60) and 0 or 50 do   -- shortcut: ab 60 Halten nur „nächster Halt“, sonst ruckelt es
        local improved = false
        -- 2-opt: Abschnitt umdrehen
        for i = 1, n - 1 do
            for j = i + 1, n do
                local a, b, d, e = prevOf(i), order[i], order[j], order[j + 1]
                local before = c(a, b) + c(d, e)
                local after = c(a, d) + c(b, e)
                if after + 0.5 < before then
                    local lo, hi = i, j
                    while lo < hi do order[lo], order[hi] = order[hi], order[lo]; lo, hi = lo + 1, hi - 1 end
                    improved = true
                end
            end
        end
        -- Umsetzen: einen Halt an eine bessere Stelle
        for i = 1, n do
            local x = order[i]
            local p, q = prevOf(i), order[i + 1]
            local gain = c(p, x) + c(x, q) - (q and c(p, q) or 0)
            local bestPos, bestAdd
            for k = 1, n + 1 do
                if k ~= i and k ~= i + 1 then
                    local u = (k == 1) and 0 or order[k - 1]
                    local v = order[k]
                    local add = c(u, x) + (v and c(x, v) or 0) - (v and c(u, v) or 0)
                    if not bestAdd or add < bestAdd then bestPos, bestAdd = k, add end
                end
            end
            if bestAdd and bestAdd + 0.5 < gain then
                table.remove(order, i)
                table.insert(order, bestPos > i and bestPos - 1 or bestPos, x)
                improved = true
                break
            end
        end
        if not improved then break end
    end
    return order
end

-- Schritte (Rohdaten mit map/x/y) nach Reisezeit ab deinem Standort ordnen.
-- Schritte ohne Position kommen ans Ende.
function ns.OrderSteps(steps, start)
    start = start or ns.PlayerPos()
    local placed, pts, rest = {}, {}, {}
    for _, st in ipairs(steps) do
        local p = st.map and st.x and st.y and ns.WorldPos(st.map, st.x, st.y)
        if p then
            placed[#placed + 1] = st
            pts[#pts + 1] = { c = p.c, x = p.x, y = p.y, map = p.map }
        else
            rest[#rest + 1] = st
        end
    end
    local order = ns.OrderPositions(start, pts)
    local out = {}
    for _, i in ipairs(order) do out[#out + 1] = placed[i] end
    for _, st in ipairs(rest) do out[#out + 1] = st end
    return out, pts, order
end


-- Kurzer Reisehinweis für einen Weg, z. B. „Flug Thunder Bluff → Sonnenfels“
function ns.LegText(a, b)
    if not (a and b) then return nil end
    local t, how, via = ns.LegCost(a, b)
    if not t then return nil end
    if how == "flug" and via then
        return (L["Flight %s → %s"]):format(via.from.short, via.to.short) .. (via.new and L[" (new flight master)"] or ""), t, how
    elseif how == "schiff" and via then
        return via.name, t, how
    elseif how == "fern" then
        return L["other continent – connection unknown"], nil, how
    end
    return L["on foot"], t, how
end

-- Reisehinweis für den Weg vom Spieler zu einem Schritt (nur wenn nicht zu Fuß)
function ns.TravelHint(step)
    local from, to = ns.PlayerPos(), ns.StepPos(step)
    if not (from and to) then return nil end
    local text, t, how = ns.LegText(from, to)
    if not text or how == "lauf" then return nil end
    if not t then return text end
    return (L["%s · about %s"]):format(text, fmtTime(t))
end

-- Offene Schritte eines Plans in neue Reihenfolge bringen
-- (erledigte bleiben vorn, übersprungene kommen ans Ende)
function ns.SortPlan(plan)
    if not plan then ns.Print(L["No plan selected."]) return end
    local start = ns.PlayerPos()
    local head, open, tail = {}, {}, {}
    for _, st in ipairs(plan.steps) do
        local state = ns.StepState(st, plan.id)
        if isOpen(state) then open[#open + 1] = st
        elseif state == "skipped" then tail[#tail + 1] = st
        else head[#head + 1] = st end
    end
    if #open < 2 then ns.Print(L["Too few open steps to sort."]) return end
    local oldPts = {}
    for _, st in ipairs(open) do local p = ns.StepPos(st); if p then oldPts[#oldPts + 1] = p end end
    local sorted, pts, order = ns.OrderSteps(open, start)
    local newPts = {}
    for _, i in ipairs(order) do newPts[#newPts + 1] = pts[i] end
    local before, after = pathCost(start, oldPts), pathCost(start, newPts)
    local p, raw = ns.EnsureEditable(plan)
    if not raw then return end
    local newRaw = {}
    for _, st in ipairs(head) do newRaw[#newRaw + 1] = raw.steps[st.rawIndex] end
    for _, st in ipairs(sorted) do newRaw[#newRaw + 1] = raw.steps[st.rawIndex] end
    for _, st in ipairs(tail) do newRaw[#newRaw + 1] = raw.steps[st.rawIndex] end
    raw.steps = newRaw
    ns.C.focus[p.id] = nil
    ns.wp.arrowKey = nil
    ns.Print((L["Order sorted by travel time%s: estimated %s instead of %s."]):format(
        start and "" or L[" (without your position)"], fmtTime(after), fmtTime(before)))
    ns.Log("I", "route", "Plan %s sorted: %d open steps, %s instead of %s.", p.id, #open, fmtTime(after), fmtTime(before))
    ns.Refresh()
end

-- Wegbeschreibung für die offenen Schritte (für /rb route)
function ns.RouteText(plan)
    if ns.staging then return ns.staging.route end
    if not plan then return L["No plan loaded or selected."] end
    local lines = { (L["Route description: %s"]):format(plan.title), "" }
    local prev = ns.PlayerPos()
    if not prev then lines[#lines + 1] = L["(Your position is unknown right now – first leg without a time.)"] end
    local total, i = 0, 0
    for _, st in ipairs(plan.steps) do
        if isOpen((ns.StepState(st, plan.id))) then
            i = i + 1
            local p = ns.StepPos(st)
            local where = st.map and ("%s %.1f %.1f"):format(ns.ZoneName(st), st.x, st.y) or L["no coordinates"]
            local how = ""
            if prev and p then
                local text, t = ns.LegText(prev, p)
                total = total + (t or 0)
                how = t and (L["  →  %s, about %s"]):format(text or "?", fmtTime(t)) or ("  →  " .. (text or "?"))
            end
            lines[#lines + 1] = ("%d. %s (%s)%s"):format(i, ns.StepTitle(st), where, how)
            if p then prev = p end
        end
    end
    if i == 0 then lines[#lines + 1] = L["No open steps."] end
    lines[#lines + 1] = ""
    local here = ns.PlayerPos()
    lines[#lines + 1] = (L["Estimated total: %s · flight points: %d known, %d of them found on this continent · speed %.1f yards/s"]):format(
        fmtTime(total), countKeys(ns.C.taxi), here and #taxiNodesFor(here.map) or 0, runSpeed())
    lines[#lines + 1] = L["Estimate: straight line × 1.3 on foot, flights from known flight points, +45 s per zone change."]
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Automatische Abgaberunde: alle abgabebereiten Quests aus dem Questlog,
-- Abgabe-NPC/-Objekt und Koordinaten aus QuestieDB, Reihenfolge nach Entfernung
---------------------------------------------------------------------------
local AUTO_ID = "auto-abgabe"
local zoneMap

local function areaToUiMap(areaID)
    if not zoneMap then
        zoneMap = {}
        local lib = _G.LibQuestieDB
        local zdb = lib and lib.Support and lib.Support.Get and lib.Support.Get("ZoneDB")
        local priv = zdb and zdb.private
        for _, key in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
            local src = priv and priv[key]
            local tbl = src
            if type(src) == "string" then
                local fn = loadstring(src)
                tbl = nil
                if fn then
                    setfenv(fn, {})
                    local ok, t = pcall(fn)
                    if ok then tbl = t end
                end
            end
            if type(tbl) == "table" then
                for area, map in pairs(tbl) do zoneMap[area] = map end
            end
        end
        if not next(zoneMap) then ns.Log("W", "auto", "Zone table from QuestieDB not readable – no coordinates.") end
    end
    return zoneMap[areaID]
end
ns.AreaToUiMap = areaToUiMap

---------------------------------------------------------------------------
-- Gelände. Das Spiel sagt Addons nicht, wo Berge stehen. Roadbook leitet es
-- aus den Daten ab, die da sind: Wo QuestieDB NPCs oder Objekte kennt, kann
-- man hin. Alle Fundorte kommen in ein Raster (80 Yards je Feld, samt den
-- Nachbarfeldern, das schließt kleine Lücken). Ein Fußweg ist dann der kürzeste
-- Weg über bekannte Felder (A*), nicht die Luftlinie quer durchs Gebirge.
-- Ohne Verbindung, außerhalb des Rasters oder abgeschaltet: Luftlinie wie bisher.
-- Feste Werte je Gebiet gibt es nicht; es gelten nur diese vier Zahlen für alles.
---------------------------------------------------------------------------
local CELL = 80            -- Yards je Rasterfeld
local GRID_NODES = 4000    -- mehr Felder untersucht die Wegsuche nicht (dann Luftlinie)
local GRID_CAP = 2.5       -- ein Umweg zählt höchstens als das 2,5-fache der Luftlinie
local GRID_SLICE = 1500    -- so viele NPCs/Objekte je Durchgang einlesen (kein Ruckeln)
local grid = { cells = {}, cache = {}, cached = 0 }

local function cellOf(p) return (math.floor(p.x / CELL) + 512) * 2048 + math.floor(p.y / CELL) + 1024 end

function ns.ResetGrid()
    grid = { cells = {}, cache = {}, cached = 0 }
end

-- Liest die Fundorte in kleinen Portionen ein; startet einmal, sobald QuestieDB da ist
function ns.BuildGrid()
    if grid.started or ns.staging or not (_G.NpcDB and NpcDB.GetAllIds and NpcDB.Get) then return end
    grid.started = true
    local my = grid
    local t0 = debugprofilestop and debugprofilestop() or 0
    local sources = { NpcDB }
    if _G.ObjectDB and ObjectDB.GetAllIds and ObjectDB.Get then sources[2] = ObjectDB end
    local maps, count, s, i, ids = {}, 0, 1, 0, nil
    -- Karte -> Welt: aus drei Eckpunkten, danach reine Rechnung
    local function mapFor(area)
        local m = maps[area]
        if m == nil then
            m = false
            local map = areaToUiMap(area)
            local o = map and ns.WorldPos(map, 0, 0, true)
            local ex, ey = map and ns.WorldPos(map, 100, 0, true), map and ns.WorldPos(map, 0, 100, true)
            if o and ex and ey and o.c == ex.c and o.c == ey.c then
                m = { c = o.c, x = o.x, y = o.y, xx = (ex.x - o.x) / 100, xy = (ex.y - o.y) / 100,
                      yx = (ey.x - o.x) / 100, yy = (ey.y - o.y) / 100 }
                my.cells[o.c] = my.cells[o.c] or {}
            end
            maps[area] = m
        end
        return m
    end
    local function slice()
        for _ = 1, GRID_SLICE do
            if not ids then
                local db = sources[s]
                if not db then
                    my.ready = true
                    ns.taxiVersion = ns.taxiVersion + 1   -- Wege zu den Flugmeistern neu rechnen
                    ns.Log("I", "route", "Terrain map ready: %d fields, %d ms", count,
                        debugprofilestop and (debugprofilestop() - t0) or 0)
                    if ns.ScheduleRefresh then ns.ScheduleRefresh() end
                    return
                end
                local ok, list = pcall(db.GetAllIds)
                ids, i = ok and type(list) == "table" and list or {}, 0
            end
            i = i + 1
            local id = ids[i]
            if not id then
                ids, s = nil, s + 1
            else
                local ok, spawns = pcall(sources[s].Get, id, "spawns")
                if ok and type(spawns) == "table" then
                    for area, pts in pairs(spawns) do
                        local m = type(pts) == "table" and mapFor(area)
                        if m then
                            local cells = my.cells[m.c]
                            for _, pt in ipairs(pts) do
                                local px, py = type(pt) == "table" and tonumber(pt[1]), type(pt) == "table" and tonumber(pt[2])
                                if px and py and px >= 0 and px <= 100 and py >= 0 and py <= 100 then
                                    local k = cellOf({ x = m.x + px * m.xx + py * m.yx, y = m.y + px * m.xy + py * m.yy })
                                    if not cells[k] then count = count + 1 end
                                    for dk = -2048, 2048, 2048 do
                                        cells[k + dk - 1], cells[k + dk], cells[k + dk + 1] = true, true, true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if my == grid then C_Timer.After(0.05, slice) end
    end
    slice()
end

-- Ein bekanntes Feld an oder direkt neben dem Punkt (nil: außerhalb des Rasters)
local function snap(cells, k)
    if cells[k] then return k end
    for r = 1, 2 do
        for dx = -r, r do
            for dy = -r, r do
                local n = k + dx * 2048 + dy
                if cells[n] then return n end
            end
        end
    end
end

local STEPS = { { 2048, 1 }, { -2048, 1 }, { 1, 1 }, { -1, 1 },
                { 2049, 1.4142 }, { 2047, 1.4142 }, { -2047, 1.4142 }, { -2049, 1.4142 } }

-- Weglänge in Yards von a nach b über bekanntes Gelände; nil = Luftlinie nehmen
function ns.GridLen(a, b)
    if not grid.ready or (ns.DB and ns.DB.noTerrain) or a.c ~= b.c then return nil end
    local cells = grid.cells[a.c]
    if not cells then return nil end
    local ka, kb = snap(cells, cellOf(a)), snap(cells, cellOf(b))
    if not (ka and kb) or ka == kb then return nil end
    local air = dist(a, b)
    local ck = a.c .. ":" .. ka .. ":" .. kb
    local hit = grid.cache[ck]
    if hit == nil then
        -- A* mit Binär-Heap; Schätzung = Weg auf dem leeren Raster (überschätzt nie)
        local bx, by = math.floor(kb / 2048), kb % 2048
        local function h(k)
            local dx, dy = math.abs(math.floor(k / 2048) - bx), math.abs(k % 2048 - by)
            return (dx > dy) and (dx + 0.4142 * dy) or (dy + 0.4142 * dx)
        end
        local g, hf, hk, n, nodes = { [ka] = 0 }, { h(ka) }, { ka }, 1, 0
        hit = false
        while n > 0 and nodes < GRID_NODES do
            local f, k = hf[1], hk[1]
            hf[1], hk[1] = hf[n], hk[n]
            hf[n], hk[n] = nil, nil
            n = n - 1
            local i = 1
            while true do
                local l, r, m = i * 2, i * 2 + 1, i
                if l <= n and hf[l] < hf[m] then m = l end
                if r <= n and hf[r] < hf[m] then m = r end
                if m == i then break end
                hf[i], hf[m], hk[i], hk[m] = hf[m], hf[i], hk[m], hk[i]
                i = m
            end
            if k == kb then hit = g[k] * CELL break end
            if f <= g[k] + h(k) + 1e-6 then   -- sonst veralteter Eintrag
                nodes = nodes + 1
                for _, st in ipairs(STEPS) do
                    local nk = k + st[1]
                    if cells[nk] then
                        local ng = g[k] + st[2]
                        if ng < (g[nk] or math.huge) then
                            g[nk] = ng
                            n = n + 1
                            hf[n], hk[n] = ng + h(nk), nk
                            local j = n
                            while j > 1 do
                                local p = math.floor(j / 2)
                                if hf[p] <= hf[j] then break end
                                hf[p], hf[j], hk[p], hk[j] = hf[j], hf[p], hk[j], hk[p]
                                j = p
                            end
                        end
                    end
                end
            end
        end
        if grid.cached > 4000 then grid.cache, grid.cached = {}, 0 end
        grid.cache[ck], grid.cached = hit, grid.cached + 1
    end
    if not hit then return nil end
    -- Rasterwege sind eckig (etwa 4 % zu lang); nie kürzer als die Luftlinie, nie über dem Deckel
    return math.max(air, math.min(hit * 0.96, air * GRID_CAP))
end

-- Alle Spawn-Punkte eines Abgabe-Ziels (NPC oder Objekt) als { map, x, y, name }
local function finisherSpots(questID, faction)
    local spots, names = {}, {}
    local finishedBy = _G.QuestDB and QuestDB.Get(questID, "finishedBy")
    if type(finishedBy) ~= "table" then return spots, names end
    local function addFrom(db, ids, isObject)
        for _, id in ipairs(type(ids) == "table" and ids or {}) do
            local friendly = (not isObject) and db.Get(id, "friendlyToFaction") or nil
            if not (type(friendly) == "string" and friendly ~= "" and not friendly:find(faction, 1, true)) then
                local name = db.Get(id, "name") or ("#" .. id)
                table.insert(names, name)
                local spawns = db.Get(id, "spawns")
                for area, list in pairs(type(spawns) == "table" and spawns or {}) do
                    local map = areaToUiMap(area)
                    for _, xy in ipairs(type(list) == "table" and list or {}) do
                        local x, y = xy[1], xy[2]
                        if map and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                            table.insert(spots, { map = map, x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10, name = name })
                        end
                    end
                end
            end
        end
    end
    if _G.NpcDB then addFrom(NpcDB, finishedBy[1], false) end
    if _G.ObjectDB then addFrom(ObjectDB, finishedBy[2], true) end
    return spots, names
end

local function questLogComplete()
    if ns.staging then return ns.staging.ready end
    local out = {}
    local QLx = C_QuestLog
    if not (QLx and QLx.GetNumQuestLogEntries and QLx.GetInfo) then return out end
    local n = QLx.GetNumQuestLogEntries() or 0
    for i = 1, n do
        local info = QLx.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            if questComplete(info.questID) then
                table.insert(out, { quest = info.questID, title = info.title or ("Quest " .. info.questID) })
            end
        end
    end
    return out
end

function ns.ReadyQuests() return questLogComplete() end

-- Abgabe-Schritte für eine Questliste bauen. Hat ein Abgabe-NPC mehrere
-- Orte, gewinnt der mit der kürzesten Reisezeit ab deinem Standort.
local function buildTurnInSteps(quests)
    local faction = (UnitFactionGroup and UnitFactionGroup("player") == "Alliance") and "A" or "H"
    local here = ns.PlayerPos()
    local placed, unplaced = {}, {}
    for _, q in ipairs(quests) do
        local spots, names = finisherSpots(q.quest, faction)
        local best, bestScore
        for _, sp in ipairs(spots) do
            local p = ns.WorldPos(sp.map, sp.x, sp.y)
            local score = (p and here and ns.LegCost(here, p)) or (p and 1e9) or 1e12
            if not bestScore or score < bestScore then best, bestScore = sp, score end
        end
        local step = { type = "turnin", quest = q.quest, text = q.title, title = names[1] or L["Turn-in"] }
        if best then
            step.map, step.x, step.y, step.title = best.map, best.x, best.y, best.name
            local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(best.map)
            step.zone = info and info.name or nil
            table.insert(placed, step)
        else
            step.note = (#names > 0) and L["No waypoint (instance or no coordinates)."] or L["Turn-in NPC unknown."]
            if #names == 0 then ns.Log("W", "auto", "Quest %d (%s): no turn-in NPC in QuestieDB.", q.quest, q.title) end
            table.insert(unplaced, step)
        end
    end
    return placed, unplaced, here
end

-- Abgabebereite Quests, die im aktiven Plan fehlen
function ns.MissingTurnIns(plan)
    local inPlan = {}
    for _, st in ipairs(plan and plan.steps or {}) do
        if st.quest then inPlan[st.quest] = true end
    end
    local out = {}
    for _, q in ipairs(questLogComplete()) do
        if not inPlan[q.quest] then table.insert(out, q) end
    end
    return out
end

-- Fehlende Abgaben dort einfügen, wo sie am wenigsten Umweg kosten
-- (zwischen den offenen Schritten), statt sie hinten anzuhängen.
function ns.AddMissingTurnIns()
    local plan = ns.ActivePlan()
    if not plan or plan.auto then return ns.CreateTurnInPlan() end
    if not (_G.QuestDB and _G.NpcDB) then
        ns.Print(L["QuestieDB is not loaded – without it Roadbook does not know the turn-in NPCs."])
        return
    end
    local missing = ns.MissingTurnIns(plan)
    if #missing == 0 then return end
    local p, raw = ns.EnsureEditable(plan)
    local placed, unplaced, here = buildTurnInSteps(missing)
    -- offene Schritte mit Position in Reihenfolge (raw-Index + Position)
    local seq = {}
    for _, st in ipairs(p.steps) do
        if isOpen((ns.StepState(st, p.id))) then
            local pos = ns.StepPos(st)
            if pos then seq[#seq + 1] = { raw = raw.steps[st.rawIndex], pos = pos } end
        end
    end
    for _, st in ipairs(placed) do
        local pos = ns.WorldPos(st.map, st.x, st.y)
        local bestK, bestAdd = #seq + 1, nil
        if pos then
            for k = 1, #seq + 1 do
                local u = (k == 1) and here or seq[k - 1].pos
                local v = seq[k] and seq[k].pos
                local add = (u and ns.LegCost(u, pos) or 0) + (v and ns.LegCost(pos, v) or 0)
                            - ((u and v) and ns.LegCost(u, v) or 0)
                if not bestAdd or add < bestAdd then bestK, bestAdd = k, add end
            end
        end
        -- Stelle in raw.steps: vor dem offenen Schritt seq[bestK], sonst ans Ende
        local at = #raw.steps + 1
        if seq[bestK] then
            for i, r in ipairs(raw.steps) do if r == seq[bestK].raw then at = i break end end
        end
        table.insert(raw.steps, at, st)
        table.insert(seq, bestK, { raw = st, pos = pos })
    end
    for _, st in ipairs(unplaced) do table.insert(raw.steps, st) end
    ns.Print((L["%d turn-in(s) added to “%s” – placed where they cost the least detour."]):format(#missing, raw.title))
    ns.Log("I", "auto", "%d missing turn-ins placed in %s.", #missing, p.id)
    ns.Refresh()
end

function ns.CreateTurnInPlan()
    if not (_G.QuestDB and _G.NpcDB) then
        ns.Print(L["QuestieDB is not loaded – without it Roadbook does not know the turn-in NPCs."])
        ns.Log("W", "auto", "Turn-in round: QuestieDB (QuestDB/NpcDB) is missing.")
        return
    end
    local quests = questLogComplete()
    if #quests == 0 then
        ns.Print(L["No quests ready to turn in."])
        ns.Log("I", "auto", "Turn-in round: no quests ready to turn in.")
        return
    end
    local placed, unplaced, here = buildTurnInSteps(quests)
    -- Reihenfolge nach Reisezeit ab deinem Standort (Flugpunkte, Gebiete, Kontinente)
    local ordered = ns.OrderSteps(placed, here)
    for _, st in ipairs(unplaced) do table.insert(ordered, st) end

    local id = "e:" .. AUTO_ID
    -- neue Runde = frischer Anfang: alte Übersprungen-/Fokus-Marken weg
    ns.C.skipped[id], ns.C.focus[id], ns.C.finished[id] = nil, nil, nil
    ns.C.plans[AUTO_ID] = {
        id = AUTO_ID, title = L["Turn-in round (automatic)"], mode = "route", created = time(), auto = true,
        note = (L["Created %s from %d quests ready to turn in – sorted by travel time from your position (flight points and zones included). Click again to refresh the round."])
            :format(date(L["%m/%d %H:%M"]), #quests),
        steps = ordered, origin = copySteps(ordered),
    }
    ns.Log("I", "auto", "Turn-in round created: %d quests, %d with waypoint, %d without%s.", #quests, #placed, #unplaced,
        here and "" or " (position unknown)")
    ns.Print((L["Turn-in round created: %d quests%s."]):format(#quests,
        #unplaced > 0 and (", " .. #unplaced .. L[" of them without a waypoint"]) or ""))
    ns.ActivatePlan(id)
    if ns.frame and ns.frame:IsShown() then ns.ShowTab("plans") end
end
