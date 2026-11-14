-- Roadbook: Reiter "Notizen" (Notizblock: Titel + Inhalt)
local ADDON, ns = ...
local L = ns.L

local LEFT_W = 210

function ns.SelectNote(id)
    ns.selectedNoteId = id
    if ns.currentTab ~= "notes" then ns.ShowTab("notes") else ns.UpdateUI() end
end

function ns.Build_notes(panel, tab)
    -------------------------------------------------------------------
    -- Links: Liste
    -------------------------------------------------------------------
    local head = ns.FontString(panel, "GameFontNormal")
    head:SetPoint("TOPLEFT", 4, 0)
    head:SetText(L["Notes"])

    local listInset = ns.CreateInset(panel)
    listInset:SetPoint("TOPLEFT", 0, -16)
    listInset:SetSize(LEFT_W, 330)

    local noteList = ns.CreateScrollList(listInset, 20, function(parent)
        local row = ns.CreateRow(parent)
        row.text = ns.FontString(row, "GameFontHighlight")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetPoint("RIGHT", -4, 0)
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self)
            if self.note then ns.SelectNote(self.note.id) end
        end)
        return row
    end)
    noteList.scroll:SetPoint("TOPLEFT", 6, -6)
    noteList.scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local bNew = ns.CreateButton(panel, L["New note"], LEFT_W, function()
        local n = ns.CreateNote()
        ns.SelectNote(n.id)
        if tab.titleBox then tab.titleBox:SetFocus(); tab.titleBox:HighlightText() end
    end)
    bNew:SetPoint("TOPLEFT", listInset, "BOTTOMLEFT", 0, -6)

    local trashBtn = ns.CreateButton(panel, L["Trash"], LEFT_W, function() ns.ShowTrash() end)
    trashBtn:SetPoint("TOPLEFT", bNew, "BOTTOMLEFT", 0, -4)

    -------------------------------------------------------------------
    -- Rechts: Notiz
    -------------------------------------------------------------------
    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPLEFT", LEFT_W + 12, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)

    local titleLabel = ns.FontString(right, "GameFontNormalSmall")
    titleLabel:SetPoint("TOPLEFT", 2, 0)
    titleLabel:SetText(L["Title"])

    local titleBox = ns.AutoWrap(CreateFrame("EditBox", nil, right, "InputBoxTemplate"), "note-title")
    titleBox:SetAutoFocus(false)
    titleBox:SetHeight(20)
    titleBox:SetPoint("TOPLEFT", 8, -14)
    titleBox:SetPoint("RIGHT", -170, 0)
    titleBox:SetMaxLetters(80)
    tab.titleBox = titleBox

    local allChars = ns.AutoWrap(CreateFrame("CheckButton", nil, right, "UICheckButtonTemplate"), "note-all")
    allChars:SetSize(24, 24)
    allChars:SetPoint("LEFT", titleBox, "RIGHT", 10, 0)
    local allCharsText = ns.FontString(right, "GameFontHighlightSmall")
    allCharsText:SetPoint("LEFT", allChars, "RIGHT", 2, 0)
    allCharsText:SetText(L["For all characters"])
    ns.SetTooltip(allChars, L["For all characters"],
        L["Unticked, the note belongs to this character only. Ticked, all your characters see it."])

    local info = ns.FontString(right, "GameFontDisableSmall")
    info:SetPoint("TOPLEFT", 2, -40)
    info:SetPoint("RIGHT", -4, 0)

    local area = ns.CreateTextArea(right)
    area:SetPoint("TOPLEFT", 0, -54)
    area:SetPoint("BOTTOMRIGHT", 0, 30)
    local body = area.edit

    local bDelete = ns.CreateButton(right, L["Delete"], 100)
    bDelete:SetPoint("BOTTOMLEFT", 0, 2)
    local bCopyOwn = ns.CreateButton(right, L["Copy as my own note"], 200)
    bCopyOwn:SetPoint("LEFT", bDelete, "RIGHT", 4, 0)
    local bCopy = ns.CreateButton(right, L["Copy text"], 120)
    bCopy:SetPoint("BOTTOMRIGHT", 0, 2)

    local emptyText = ns.FontString(right, "GameFontDisable", "CENTER")
    emptyText:SetPoint("CENTER", area, "CENTER")
    emptyText:SetText(L["Choose a note on the left or create a new one."])

    -------------------------------------------------------------------
    -- Bearbeiten
    -------------------------------------------------------------------
    local current, currentStore, loadedId

    titleBox:SetScript("OnTextChanged", function(self, user)
        if not (user and current) then return end
        if currentStore == "post" then self:SetText(current.title) return end
        current.title = self:GetText()
        current.updated = time()
    end)
    local function titleDone(self)
        self:ClearFocus()
        ns.UpdateUI()
    end
    titleBox:SetScript("OnEnterPressed", titleDone)
    titleBox:SetScript("OnEditFocusLost", function() ns.UpdateUI() end)
    titleBox:SetScript("OnEscapePressed", titleDone)

    body:SetScript("OnTextChanged", function(self, user)
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(self, area.scroll) end
        if not (user and current) then return end
        if currentStore == "post" then self:SetText(current.body or "") return end
        current.body = self:GetText()
        current.updated = time()
    end)

    allChars:SetScript("OnClick", function(self)
        if current and currentStore ~= "post" and not current.plan then
            ns.SetNoteAccount(current, self:GetChecked() and true or false)
        end
    end)

    bDelete:SetScript("OnClick", function()
        if current then ns.DeleteNote(current.id) end
    end)
    ns.SetTooltip(bDelete, L["Delete"],
        L["Your own notes go to the trash (can be restored for 10 minutes)."],
        L["Notes from the post are hidden – a changed version shows up again."])
    bCopyOwn:SetScript("OnClick", function()
        if not current then return end
        local n = ns.CopyPostNote(current.id)
        if n then ns.SelectNote(n.id) end
    end)
    bCopy:SetScript("OnClick", function()
        if current then ns.ShowCopy(current.title, current.body or "") end
    end)

    -------------------------------------------------------------------
    -- Aktualisieren
    -------------------------------------------------------------------
    tab.update = function()
        local nTrash = #ns.TrashList()
        trashBtn:SetText(nTrash > 0 and (L["Trash (%d)"]):format(nTrash) or L["Trash"])
        local sections = ns.GetNoteSections()
        local items = {}
        for _, sec in ipairs(sections) do
            table.insert(items, { header = sec.header })
            for _, n in ipairs(sec.items) do table.insert(items, { note = n }) end
        end

        current, currentStore = ns.FindNote(ns.selectedNoteId)
        if not current then
            -- Standard: erste Notiz
            for _, it in ipairs(items) do
                if it.note then current, currentStore = ns.FindNote(it.note.id); break end
            end
            ns.selectedNoteId = current and current.id or nil
        end

        noteList:SetData(items, function(row, it)
            row.note = it.note
            if it.header then
                row:Disable()
                row.selected:Hide()
                row.text:SetFontObject(GameFontNormalSmall)
                row.text:SetText(it.header)
                row.text:SetTextColor(1, 0.82, 0)
                row.text:SetPoint("LEFT", 4, 0)
            else
                row:Enable()
                row.text:SetFontObject(GameFontHighlight)
                row.text:SetPoint("LEFT", 12, 0)
                local t = ns.Trim(it.note.title) ~= "" and it.note.title or L["(untitled)"]
                row.text:SetText(t)
                row.text:SetTextColor(1, 1, 1)
                row.selected:SetShown(current and current.id == it.note.id or false)
            end
        end)

        local has = current ~= nil
        titleBox:SetShown(has); titleLabel:SetShown(has); area:SetShown(has); info:SetShown(has)
        bCopy:SetShown(has)
        emptyText:SetShown(not has)
        local isPost = currentStore == "post"
        bDelete:SetShown(has)
        bCopyOwn:SetShown(has and isPost)
        local canShare = has and not isPost and not current.plan
        allChars:SetShown(canShare); allCharsText:SetShown(canShare)
        if not has then loadedId = nil return end

        if loadedId ~= current.id then
            loadedId = current.id
            titleBox:SetText(current.title or "")
            titleBox:SetCursorPosition(0)
            body:SetText(current.body or "")
            body:SetCursorPosition(0)
        end
        allChars:SetChecked(currentStore == "account")

        local parts = {}
        if current.builtin then table.insert(parts, L["Part of Roadbook (read-only)"])
        elseif isPost then table.insert(parts, L["From the post (read-only)"])
        elseif currentStore == "account" then table.insert(parts, L["For all characters"])
        else table.insert(parts, L["Only "] .. (ns.playerName or L["this character"])) end
        if current.plan then
            local p = ns.GetPlan(current.plan)
            table.insert(parts, "Plan: " .. (p and p.title or current.plan))
        end
        if current.updated then table.insert(parts, L["changed "] .. date(L["%m/%d %H:%M"], current.updated)) end
        info:SetText(table.concat(parts, " · "))
    end
end
