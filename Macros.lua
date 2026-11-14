-- Roadbook: Makro-Bibliothek (Vorschläge aus der Post, Übernehmen/Kopieren/Rückgängig)
local ADDON, ns = ...
local L = ns.L

local MC = Constants and Constants.MacroConsts
local MAX_ACCOUNT = (MC and MC.MAX_ACCOUNT_MACROS) or 120
local MAX_CHAR = (MC and MC.MAX_CHARACTER_MACROS) or 30
local MAX_BODY = 255
local MAX_NAME = 16

local function norm(s)
    return ((s or ""):gsub("\r", ""):gsub("[ \t]+\n", "\n"):gsub("%s+$", ""))
end

function ns.FindMacro(name, scope)
    local from, to = 1, MAX_ACCOUNT
    if scope == "char" then from, to = MAX_ACCOUNT + 1, MAX_ACCOUNT + MAX_CHAR end
    for i = from, to do
        local n, icon, body = GetMacroInfo(i)
        if n == name then return i, icon, body end
    end
end

local function ulen(s)
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end
ns.ulen = ulen

-- Rückgabe: status ("new" | "changed" | "same" | "invalid"), index, altesIcon, alterText
function ns.MacroStatus(m)
    -- Vorsichtig in Bytes zählen: Umlaute und Sonderzeichen belegen im Spiel zwei oder drei
    if ulen(m.name) > MAX_NAME or #m.body > MAX_BODY then return "invalid" end
    local idx, icon, body = ns.FindMacro(m.name, m.scope)
    if not idx then return "new" end
    if norm(body) ~= norm(m.body) then return "changed", idx, icon, body end
    return "same", idx, icon, body
end

function ns.CountPendingMacros()
    local n = 0
    if not ns.post then return 0 end
    for _, m in ipairs(ns.post.macros) do
        local st = ns.MacroStatus(m)
        if st == "new" or st == "changed" then n = n + 1 end
    end
    return n
end

local function backupStore(m)
    return (m.scope == "char") and ns.C.macroBackups or ns.DB.macroBackups
end

function ns.MacroBackup(m)
    return backupStore(m)[m.name]
end

function ns.ApplyMacro(m)
    if InCombatLockdown() then
        ns.Print(L["Macros cannot be changed in combat."])
        ns.Log("W", "macro", "Applying %s refused in combat.", m.name)
        return
    end
    local status, idx, oldIcon, oldBody = ns.MacroStatus(m)
    if status == "same" then return end
    if status == "invalid" then
        ns.Print(L["Macro too long (max. 255 characters; umlauts count double) – please copy it instead."])
        ns.Log("W", "macro", "%s: name >16 or text >255 bytes (%d) – not applied.", m.name, #m.body)
        return
    end
    local store = backupStore(m)
    local ok, res
    if status == "new" then
        local nAccount, nChar = GetNumMacros()
        if (m.scope == "char" and nChar >= MAX_CHAR) or (m.scope ~= "char" and nAccount >= MAX_ACCOUNT) then
            ns.Print(L["No free macro slot left."])
            ns.Log("W", "macro", "No free slot for %s (%s: %d account, %d character used).", m.name, m.scope, nAccount, nChar)
            return
        end
        ok, res = pcall(CreateMacro, m.name, m.icon or 134400, m.body, m.scope == "char")
        if ok and res then store[m.name] = { created = true, time = time() } end
    else
        store[m.name] = { body = oldBody, icon = oldIcon, time = time() }
        ok, res = pcall(EditMacro, idx, nil, m.icon, m.body)
    end
    if ok and res then
        ns.Print((L["Macro “%s” %s."]):format(m.name, status == "new" and L["created"] or L["updated"]))
        ns.Log("I", "macro", "%s %s (index %s, %s).", m.name, status == "new" and "created" or "updated", tostring(res), m.scope)
        local after = ns.MacroStatus(m)
        if after ~= "same" then
            ns.Log("W", "macro", "%s is not up to date after saving (status %s) – the text differs in game.", m.name, after)
        end
    else
        ns.Print(L["The macro could not be saved: "] .. tostring(res))
        ns.Log("E", "macro", "%s could not be saved (%s): %s", m.name, status, tostring(res))
    end
    if ns.UpdateUI then ns.UpdateUI() end
end

function ns.UndoMacro(m)
    if InCombatLockdown() then ns.Print(L["Macros cannot be changed in combat."]) return end
    local store = backupStore(m)
    local b = store[m.name]
    if not b or b.created then return end
    local idx = ns.FindMacro(m.name, m.scope)
    if not idx then
        ns.Print(L["Macro not found."])
        ns.Log("W", "macro", "Undo: %s not found (renamed/deleted?).", m.name)
        return
    end
    local ok, res = pcall(EditMacro, idx, nil, b.icon, b.body)
    if ok and res then
        store[m.name] = nil
        ns.Print((L["Macro “%s” restored to the old version."]):format(m.name))
        ns.Log("I", "macro", "%s restored.", m.name)
    else
        ns.Print(L["Restore failed: "] .. tostring(res))
        ns.Log("E", "macro", "Restoring %s failed: %s", m.name, tostring(res))
    end
    if ns.UpdateUI then ns.UpdateUI() end
end

-- Gruppierte Liste für die Anzeige
function ns.MacroGroups()
    local groups, order = {}, {}
    if not ns.post then return order, groups end
    for _, m in ipairs(ns.post.macros) do
        if not groups[m.group] then groups[m.group] = {}; table.insert(order, m.group) end
        table.insert(groups[m.group], m)
    end
    return order, groups
end

-- Makro an den Mauszeiger hängen (wie beim Ziehen aus dem Makrofenster)
function ns.PickupMacroFor(m)
    if InCombatLockdown() then
        ns.Print(L["Not possible in combat."])
        return
    end
    local idx = ns.FindMacro(m.name, m.scope)
    if not idx then
        ns.Print((L["Macro “%s” does not exist in game yet – click “Create” first."]):format(m.name))
        return
    end
    if ClearCursor then ClearCursor() end
    local ok, err = pcall(PickupMacro, idx)
    if ok then
        ns.Print((L["“%s” is on your cursor – now click a slot on an action bar."]):format(m.name))
        ns.Log("D", "macro", "%s picked up (index %d).", m.name, idx)
    else
        ns.Log("E", "macro", "Picking up %s failed: %s", m.name, tostring(err))
    end
end
