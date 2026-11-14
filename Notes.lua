-- Roadbook: Notizbuch (Titel + Inhalt; pro Charakter, optional für alle Charaktere)
local ADDON, ns = ...
local L = ns.L

-- Eingebaute Kurzanleitung (Teil des Addons, wird mit jeder Version aktualisiert)
ns.BUILTIN_NOTES = {
    {
        id = "w:anleitung", title = L["Quick guide"], builtin = true, account = true,
        body = table.concat({
            L["Open: /rb, the minimap button or a key (Key Bindings → Roadbook)."],
            "",
            L["PLANS"],
            L["- Choose a plan on the left and click “Load”: the TomTom arrow points to the next step."],
            L["- Route mode: one step after the other. All mode: all points, arrow to the one you reach fastest."],
            L["- Click a step: arrow there. Shift+click: tick off. Right-click: skip."],
            L["- Quests tick themselves off when you turn them in – in every plan."],
            L["- “Create turn-in round”: all quests ready to turn in as a route from where you stand."],
            L["- “Reset”: skipped and ticked-off steps are open again, your own plans get their"],
            L["  original steps back (previous state 10 min in the trash). Turned-in quests stay done."],
            L["- “Reset waypoints”: sets the TomTom waypoints and the arrow again if TomTom lost them."],
            L["- “Route description”: every leg with flight/zeppelin and the estimated time."],
            L["- “Import” reads a plan from text (a Roadbook export or /way lines), “Export” shows it to share."],
            L["- “Edit”: rename, change the order, remove steps, “Remember here”,"],
            L["  “Sort” (by travel time). Plans from the post become your own plan when edited."],
            "",
            L["ORDER AND FLIGHTS"],
            L["- By travel time, not straight-line distance: on foot, flights from flight points you know,"],
            L["  zeppelin/boat between continents; one zone at a time where possible."],
            L["- If a flight pays off, the arrow first points to the flight master (“Flight to …”), after"],
            L["  landing to your destination. At the flight master Roadbook tells you in chat where to fly."],
            L["- Remove the travel waypoint in TomTom = walk for this step. “Reset waypoints” brings it back."],
            L["- Roadbook remembers your flight points when you visit a flight master."],
            L["- Undiscovered flight master nearby? Roadbook tells you once; /rb fm sets a waypoint."],
            "",
            L["TRACKER (below the minimap)"],
            L["- Shows the next step with its distance and – if faster – the flight master before it."],
            L["- “Skip” skips it. A left-click on the tracker sets waypoints and arrow again."],
            L["- The way to a flight master or dock shows as its own line in the plan; “Skip” or a right-click skips it first."],
            L["- Plus/minus expands it: next steps and quests ready to turn in that the plan lacks."],
            L["- Move: drag with the left mouse button. Show/hide: /rb tracker"],
            "",
            L["NOTES"],
            L["- They belong to the character. The “For all characters” box shares them."],
            L["- Delete: goes to the trash for 10 minutes. Notes from the post are hidden instead."],
            "",
            L["MACROS"],
            L["- Suggestions from the post: Apply, Copy, Undo."],
            L["- “Pick up” puts the macro on your cursor – then click an action bar slot."],
            "",
            L["COMMANDS"],
            L["/rb · /rb turnin · /rb here [name] · /rb skip · /rb off · /rb plan <name>"],
            L["/rb reset · /rb waypoints · /rb sort · /rb route"],
            L["/rb tracker · /rb trash · /rb note <title> · /rb log · /rb debug · /rb minimap"],
            "/rb import · /rb export · /rb fm · /rb layout",
        }, "\n"),
    },
}

local function byTitle(a, b)
    return (a.title or ""):lower() < (b.title or ""):lower()
end

function ns.FindNote(id)
    if not id then return nil end
    for _, n in ipairs(ns.BUILTIN_NOTES) do if n.id == id then return n, "post" end end
    if ns.post then
        for _, n in ipairs(ns.post.notes) do if n.id == id then return n, "post" end end
    end
    if ns.C.notes[id] then return ns.C.notes[id], "char" end
    if ns.DB.notes[id] then return ns.DB.notes[id], "account" end
end

function ns.CreateNote(title, planId)
    local id = ns.NextId("n")
    local note = { id = id, title = title or L["New note"], body = "", created = time(), updated = time(), plan = planId }
    ns.C.notes[id] = note
    ns.Log("D", "note", "Note created: %s%s", note.title, planId and (" (plan " .. planId .. ")") or "")
    if ns.UpdateUI then ns.UpdateUI() end
    return note
end

-- Notiz zu einem Plan (gehört immer zum Charakter)
function ns.GetPlanNote(plan, create)
    for _, n in pairs(ns.C.notes) do
        if n.plan == plan.id then return n end
    end
    if create then return ns.CreateNote("Plan: " .. plan.title, plan.id) end
end

function ns.SetNoteAccount(note, allChars)
    local _, store = ns.FindNote(note.id)
    if store == "post" or note.plan then return end
    ns.Log("D", "note", "%s → %s", note.title or "?", allChars and "all characters" or "this character only")
    if allChars and store == "char" then
        ns.C.notes[note.id] = nil
        ns.DB.notes[note.id] = note
    elseif not allChars and store == "account" then
        ns.DB.notes[note.id] = nil
        ns.C.notes[note.id] = note
    end
    if ns.UpdateUI then ns.UpdateUI() end
end

function ns.CopyPostNote(id)
    local src, store = ns.FindNote(id)
    if not src or store ~= "post" then return end
    local note = ns.CreateNote(src.title)
    note.body = src.body
    return note
end

-- Abschnitte für die Liste
function ns.GetNoteSections()
    local builtin, post, plans, mine, account = {}, {}, {}, {}, {}
    for _, n in ipairs(ns.BUILTIN_NOTES) do
        if not ns.IsPostNoteHidden(n) then table.insert(builtin, n) end
    end
    if ns.post then
        for _, n in ipairs(ns.post.notes) do
            if not ns.IsPostNoteHidden(n) then table.insert(post, n) end
        end
    end
    for _, n in pairs(ns.C.notes) do
        if n.plan then table.insert(plans, n) else table.insert(mine, n) end
    end
    for _, n in pairs(ns.DB.notes) do table.insert(account, n) end
    table.sort(plans, byTitle); table.sort(mine, byTitle); table.sort(account, byTitle)
    local sections = {}
    local function add(header, items) if #items > 0 then table.insert(sections, { header = header, items = items }) end end
    add("Roadbook", builtin)
    add(L["From the post"], post)
    add(L["For plans"], plans)
    add(L["My notes"], mine)
    add(L["For all characters"], account)
    return sections
end

---------------------------------------------------------------------------
-- Ausblenden von Post-Inhalten und Papierkorb
-- Notizen/Pläne aus der Post lassen sich nicht wirklich löschen (sie kommen aus Post.lua),
-- sondern werden ausgeblendet. Bringt die Post eine geänderte Fassung, erscheinen sie wieder.
---------------------------------------------------------------------------
ns.TRASH_SECONDS = 10 * 60

function ns.PostNoteHash(n) return ns.Hash((n.title or "") .. "\n" .. (n.body or "")) end
function ns.PostPlanHash(p)
    local keys = {}
    for _, st in ipairs(p.steps) do table.insert(keys, st.key) end
    return ns.Hash((p.title or "") .. "|" .. table.concat(keys, ","))
end

local function hiddenStore(account) return account and ns.DB.hidden or ns.C.hidden end

function ns.IsPostNoteHidden(n)
    return hiddenStore(n.account)[n.id] == ns.PostNoteHash(n)
end
function ns.IsPostPlanHidden(p)
    return ns.C.hidden[p.id] == ns.PostPlanHash(p)
end

local function remaining(entry)
    return (entry.deletedAt or 0) + ns.TRASH_SECONDS - time()
end

function ns.PurgeTrash()
    local trash = ns.C and ns.C.trash
    if not trash then return end
    for i = #trash, 1, -1 do
        if remaining(trash[i]) <= 0 then
            ns.Log("D", "trash", "Removed for good: %s", tostring(trash[i].title))
            table.remove(trash, i)
        end
    end
end

function ns.TrashList()
    ns.PurgeTrash()
    local out = {}
    for i = #ns.C.trash, 1, -1 do
        local e = ns.C.trash[i]
        table.insert(out, { index = i, entry = e, left = remaining(e) })
    end
    return out
end

local KIND_LABEL = { note = L["Note"], plan = "Plan", postNote = L["Note from the post"], postPlan = L["Plan from the post"],
                     step = L["Step"], builtinNote = L["Guide"], planState = L["Plan state before the reset"] }
ns.TRASH_KIND_LABEL = KIND_LABEL

function ns.ToTrash(entry)
    entry.deletedAt = time()
    local quiet = entry.quiet
    entry.quiet = nil
    table.insert(ns.C.trash, entry)
    if not quiet then
        ns.Print((L["%s “%s” deleted – %d min in the trash (|cffffffff/rb trash|r)."]):format(
            KIND_LABEL[entry.kind] or L["Entry"], entry.title or "?", ns.TRASH_SECONDS / 60))
    end
    ns.Log("I", "trash", "%s in the trash: %s", KIND_LABEL[entry.kind] or entry.kind, tostring(entry.title))
end

-- Notiz löschen (eigene) bzw. ausblenden (Post)
function ns.DeleteNote(id)
    local note, store = ns.FindNote(id)
    if not note then return end
    if store == "post" then
        hiddenStore(note.account)[note.id] = ns.PostNoteHash(note)
        ns.ToTrash({ kind = note.builtin and "builtinNote" or "postNote", id = note.id, account = note.account, title = note.title })
    else
        if store == "char" then ns.C.notes[id] = nil else ns.DB.notes[id] = nil end
        ns.ToTrash({ kind = "note", id = id, store = store, data = note, title = note.title })
    end
    if ns.selectedNoteId == id then ns.selectedNoteId = nil end
    if ns.UpdateUI then ns.UpdateUI() end
end

-- Plan löschen (eigene) bzw. ausblenden (Post)
function ns.DeletePlan(plan)
    if not plan then return end
    if ns.C.activePlan == plan.id then ns.DeactivatePlan() end
    if plan.source == "eigen" then
        local raw = ns.C.plans[plan.rawId]
        ns.C.plans[plan.rawId] = nil
        -- Überspringen/Fokus gehören zu diesem Plan: ein neuer Plan mit derselben
        -- Kennung (z. B. die nächste Abgaberunde) fängt sauber an.
        ns.C.skipped[plan.id], ns.C.focus[plan.id], ns.C.finished[plan.id] = nil, nil, nil
        ns.ToTrash({ kind = "plan", id = plan.rawId, data = raw, title = plan.title })
    else
        ns.C.hidden[plan.id] = ns.PostPlanHash(plan)
        ns.ToTrash({ kind = "postPlan", id = plan.id, title = plan.title })
    end
    if ns.C.selectedPlan == plan.id then ns.C.selectedPlan = false end
    ns.Refresh()
end

function ns.RestoreTrash(index)
    local e = ns.C.trash[index]
    if not e then return end
    table.remove(ns.C.trash, index)
    if e.kind == "note" and e.data then
        if e.store == "account" then ns.DB.notes[e.id] = e.data else ns.C.notes[e.id] = e.data end
        ns.selectedNoteId = e.id
    elseif (e.kind == "plan" or e.kind == "planState") and e.data then
        ns.C.plans[e.id] = e.data
        ns.C.selectedPlan = "e:" .. e.id
    elseif e.kind == "step" and e.data then
        local raw = ns.C.plans[e.planRawId]
        if not raw then
            ns.Print(L["The plan for this step no longer exists."])
            table.insert(ns.C.trash, index, e)
            return
        end
        table.insert(raw.steps, math.min(e.index or (#raw.steps + 1), #raw.steps + 1), e.data)
        ns.C.selectedPlan = "e:" .. e.planRawId
    elseif e.kind == "postNote" or e.kind == "builtinNote" then
        hiddenStore(e.account)[e.id] = nil
        ns.selectedNoteId = e.id
    elseif e.kind == "postPlan" then
        ns.C.hidden[e.id] = nil
        ns.C.selectedPlan = e.id
    end
    ns.Print((L["Restored: %s “%s”."]):format(KIND_LABEL[e.kind] or "", e.title or "?"))
    ns.Log("I", "trash", "Restored: %s", tostring(e.title))
    ns.Refresh()
end
