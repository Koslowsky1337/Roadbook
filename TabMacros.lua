-- Roadbook: Reiter "Makros" (Bibliothek aus der Post)
local ADDON, ns = ...
local L = ns.L

local LEFT_W = 210
local STATUS_TEXT = {
    new = L["|cff80ff80new|r"], changed = L["|cffffd100changed|r"],
    same = L["|cff999999up to date|r"], invalid = L["|cffff6060too long|r"],
}

function ns.Build_macros(panel, tab)
    local head = ns.FontString(panel, "GameFontNormal")
    head:SetPoint("TOPLEFT", 4, 0)
    head:SetText(L["Macro library"])

    local listInset = ns.CreateInset(panel)
    listInset:SetPoint("TOPLEFT", 0, -16)
    listInset:SetPoint("BOTTOMLEFT", 0, 0)
    listInset:SetWidth(LEFT_W)

    local selected
    local macroList = ns.CreateScrollList(listInset, 20, function(parent)
        local row = ns.CreateRow(parent)
        row.text = ns.FontString(row, "GameFontHighlight")
        row.text:SetPoint("LEFT", 12, 0)
        row.text:SetPoint("RIGHT", -60, 0)
        row.text:SetWordWrap(false)
        row.state = ns.FontString(row, "GameFontHighlightSmall", "RIGHT")
        row.state:SetPoint("RIGHT", -4, 0)
        row:SetScript("OnClick", function(self)
            if self.macro then selected = self.macro; ns.UpdateUI() end
        end)
        return row
    end)
    macroList.scroll:SetPoint("TOPLEFT", 6, -6)
    macroList.scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPLEFT", LEFT_W + 12, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)

    local name = ns.FontString(right, "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", 2, 0)
    local info = ns.FontString(right, "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 2, -22)
    info:SetPoint("RIGHT", -4, 0)
    local note = ns.FontString(right, "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 2, -38)
    note:SetPoint("RIGHT", -4, 0)
    note:SetTextColor(0.85, 0.8, 0.65)

    local newLabel = ns.FontString(right, "GameFontNormalSmall")
    newLabel:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -6)   -- lange Hinweise brauchen zwei Zeilen
    newLabel:SetText(L["Suggestion"])
    local newArea = ns.CreateTextArea(right, true)
    newArea:SetPoint("TOPLEFT", newLabel, "BOTTOMLEFT", -2, -2)
    newArea:SetPoint("RIGHT", 0, 0)
    newArea:SetHeight(120)

    local oldLabel = ns.FontString(right, "GameFontNormalSmall")
    oldLabel:SetPoint("TOPLEFT", newArea, "BOTTOMLEFT", 2, -6)
    oldLabel:SetText(L["In game now"])
    local oldArea = ns.CreateTextArea(right, true)
    oldArea:SetPoint("TOPLEFT", newArea, "BOTTOMLEFT", 0, -18)
    oldArea:SetPoint("RIGHT", 0, 0)
    oldArea:SetHeight(110)

    for _, a in ipairs({ newArea, oldArea }) do
        a.edit:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(self.fixed or "") end
        end)
    end

    local bApply = ns.CreateButton(right, L["Apply"], 110)
    bApply:SetPoint("BOTTOMLEFT", 0, 2)
    local bCopy = ns.CreateButton(right, L["Copy"], 90)
    bCopy:SetPoint("LEFT", bApply, "RIGHT", 4, 0)
    local bUndo = ns.CreateButton(right, L["Undo"], 100)
    bUndo:SetPoint("LEFT", bCopy, "RIGHT", 4, 0)
    local bPick = ns.CreateButton(right, L["Pick up"], 96)
    bPick:SetPoint("BOTTOMRIGHT", 0, 2)
    ns.SetTooltip(bPick, L["Pick up"], L["Puts the macro on your cursor. Then just click a slot on an action bar."])
    ns.SetTooltip(bApply, L["Apply"], L["Writes the suggestion into the game as a macro. The old version is backed up. Locked in combat."])
    ns.SetTooltip(bUndo, L["Undo"], L["Restores the version from before applying."])

    local combat = ns.FontString(right, "GameFontRedSmall", "RIGHT")
    combat:SetPoint("BOTTOMRIGHT", -4, 28)
    combat:SetText(L["Locked in combat"])

    local emptyText = ns.FontString(right, "GameFontDisable", "CENTER")
    emptyText:SetPoint("CENTER")
    emptyText:SetText(L["No macros in the post yet."])

    local function setArea(area, text)
        if area.edit.fixed == (text or "") then return end
        area.edit.fixed = text or ""
        area.edit:SetText(text or "")
        area.edit:SetCursorPosition(0)
    end

    tab.update = function()
        local order, groups = ns.MacroGroups()
        local items, first = {}, nil
        local stillThere = false
        for _, g in ipairs(order) do
            table.insert(items, { header = g })
            for _, m in ipairs(groups[g]) do
                table.insert(items, { macro = m })
                first = first or m
                if m == selected then stillThere = true end
            end
        end
        if not stillThere then selected = first end

        macroList:SetData(items, function(row, it)
            row.macro = it.macro
            if it.header then
                row:Disable()
                row.selected:Hide()
                row.text:SetFontObject(GameFontNormalSmall)
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetText(it.header)
                row.text:SetTextColor(1, 0.82, 0)
                row.state:SetText("")
            else
                row:Enable()
                row.text:SetFontObject(GameFontHighlight)
                row.text:SetPoint("LEFT", 12, 0)
                row.text:SetText(it.macro.name)
                row.text:SetTextColor(1, 1, 1)
                row.state:SetText(STATUS_TEXT[(ns.MacroStatus(it.macro))])
                row.selected:SetShown(it.macro == selected)
            end
        end)

        local has = selected ~= nil
        for _, w in ipairs({ name, info, note, newLabel, newArea, bApply, bCopy, bPick }) do w:SetShown(has) end
        emptyText:SetShown(not has)
        if not has then
            oldLabel:Hide(); oldArea:Hide(); bUndo:Hide(); combat:Hide()
            return
        end

        local m = selected
        local status, _, _, oldBody = ns.MacroStatus(m)
        name:SetText(m.name)
        info:SetText((L["%s · %s · %d/255"]):format(
            m.scope == "char" and (L["Character macro ("] .. (ns.playerName or "") .. ")") or L["Account macro (all characters)"],
            STATUS_TEXT[status], #m.body))
        note:SetText(m.note or "")
        setArea(newArea, m.body)
        local showOld = (status == "changed")
        oldLabel:SetShown(showOld); oldArea:SetShown(showOld)
        if showOld then setArea(oldArea, oldBody) end

        local inCombat = InCombatLockdown()
        combat:SetShown(inCombat)
        bApply:SetEnabled((status == "new" or status == "changed") and not inCombat)
        bApply:SetText(status == "new" and L["Create"] or L["Apply"])
        bApply:SetScript("OnClick", function() ns.ApplyMacro(m) end)
        bCopy:SetScript("OnClick", function() ns.ShowCopy(L["Macro: "] .. m.name, m.body) end)
        local backup = ns.MacroBackup(m)
        bUndo:SetShown(backup ~= nil and not backup.created)
        bUndo:SetEnabled(not inCombat)
        bUndo:SetScript("OnClick", function() ns.UndoMacro(m) end)
        bPick:SetEnabled(status ~= "new" and status ~= "invalid" and not inCombat)
        bPick:SetScript("OnClick", function() ns.PickupMacroFor(m) end)
    end
end
