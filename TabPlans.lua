-- Roadbook: Reiter "Pläne"
local ADDON, ns = ...
local L = ns.L

local LEFT_W = 210

local function selectedPlan()
    local plans = ns.GetPlans()
    local id = ns.C.selectedPlan or ns.C.activePlan
    for _, p in ipairs(plans) do if p.id == id then return p, plans end end
    return plans[1], plans
end

function ns.Build_plans(panel, tab)
    -------------------------------------------------------------------
    -- Links: Liste der Pläne
    -------------------------------------------------------------------
    local head = ns.FontString(panel, "GameFontNormal")
    head:SetPoint("TOPLEFT", 4, 0)
    head:SetText(L["Plans"])

    local listInset = ns.CreateInset(panel)
    listInset:SetPoint("TOPLEFT", 0, -16)
    listInset:SetSize(LEFT_W, 276)

    local planList = ns.CreateScrollList(listInset, 22, function(parent)
        local row = ns.CreateRow(parent)
        row.text = ns.FontString(row, "GameFontNormal")
        row.text:SetPoint("LEFT", 6, 0)
        row.text:SetPoint("RIGHT", -52, 0)
        row.text:SetWordWrap(false)
        row.count = ns.FontString(row, "GameFontHighlightSmall", "RIGHT")
        row.count:SetPoint("RIGHT", -4, 0)
        row:SetScript("OnClick", function(self)
            ns.C.selectedPlan = self.plan.id
            ns.UpdateUI()
        end)
        row:SetScript("OnDoubleClick", function(self) ns.ActivatePlan(self.plan.id) end)
        return row
    end)
    planList.scroll:SetPoint("TOPLEFT", 6, -6)
    planList.scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local autoTurnIn = ns.CreateButton(panel, L["Create turn-in round"], LEFT_W, function()
        ns.CreateTurnInPlan()
    end)
    autoTurnIn:SetPoint("TOPLEFT", listInset, "BOTTOMLEFT", 0, -6)
    ns.SetTooltip(autoTurnIn, L["Create turn-in round"],
        L["Takes all quests in your quest log that are ready to turn in, looks up the turn-in NPCs in QuestieDB and sorts them by travel time from your position – with your known flight points, zeppelins and one zone at a time where possible."],
        L["Click again to rebuild the round (without old skip marks). Quests you turn in tick themselves off as always."])

    local fromTomTom = ns.CreateButton(panel, L["Save TomTom waypoints"], LEFT_W, function()
        ns.CreatePlanFromTomTom()
    end)
    fromTomTom:SetPoint("TOPLEFT", autoTurnIn, "BOTTOMLEFT", 0, -4)

    local trashBtn = ns.CreateButton(panel, L["Trash"], LEFT_W, function() ns.ShowTrash() end)
    local importBtn = ns.CreateButton(panel, L["Import plan"], LEFT_W, function() ns.ShowImport() end)
    importBtn:SetPoint("TOPLEFT", fromTomTom, "BOTTOMLEFT", 0, -4)
    ns.SetTooltip(importBtn, L["Import a plan"],
        L["Reads a plan from text: a Roadbook export from another player, or /way lines as TomTom uses them."])
    trashBtn:SetPoint("TOPLEFT", importBtn, "BOTTOMLEFT", 0, -4)
    tab.trashBtn = trashBtn
    ns.SetTooltip(fromTomTom, L["Own plan from TomTom"],
        L["Saves all TomTom waypoints you have set yourself as a plan of your own for this character."])

    local empty = ns.FontString(panel, "GameFontDisable", "CENTER")
    empty:SetPoint("TOPLEFT", listInset, "TOPLEFT", 8, -40)
    empty:SetPoint("RIGHT", listInset, "RIGHT", -8, 0)
    empty:SetText(L["No plans yet.\n\nCreate a turn-in round, save your TomTom waypoints or import a plan."])

    -------------------------------------------------------------------
    -- Rechts: Plan im Detail
    -------------------------------------------------------------------
    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPLEFT", LEFT_W + 12, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)

    local title = ns.FontString(right, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 2, 0)
    title:SetPoint("RIGHT", -120, 0)
    title:SetWordWrap(false)
    local meta = ns.FontString(right, "GameFontHighlightSmall", "RIGHT")
    meta:SetPoint("TOPRIGHT", -4, -2)

    local titleEdit = ns.AutoWrap(CreateFrame("EditBox", nil, right, "InputBoxTemplate"), "plan-title")
    titleEdit:SetAutoFocus(false)
    titleEdit:SetHeight(20)
    titleEdit:SetPoint("TOPLEFT", 8, 0)
    titleEdit:SetPoint("RIGHT", -130, 0)
    titleEdit:SetMaxLetters(60)
    titleEdit:Hide()

    -- Normale Ansicht
    local bLoad = ns.CreateButton(right, L["Load"], 80)
    bLoad:SetPoint("TOPLEFT", 0, -22)
    local bMode = ns.CreateButton(right, "Route", 104)
    bMode:SetPoint("LEFT", bLoad, "RIGHT", 4, 0)
    local bNote = ns.CreateButton(right, L["Note"], 60)
    bNote:SetPoint("LEFT", bMode, "RIGHT", 4, 0)
    local bWay = ns.CreateButton(right, "/way", 54)
    bWay:SetPoint("LEFT", bNote, "RIGHT", 4, 0)
    local bEdit = ns.CreateButton(right, L["Edit"], 96)
    bEdit:SetPoint("LEFT", bWay, "RIGHT", 4, 0)
    -- Bearbeiten-Ansicht
    local bDone = ns.CreateButton(right, L["Done"], 80)
    bDone:SetPoint("TOPLEFT", 0, -22)
    local bHere = ns.CreateButton(right, L["Remember here"], 104)
    bHere:SetPoint("LEFT", bDone, "RIGHT", 4, 0)
    local bSort = ns.CreateButton(right, L["Sort"], 90)
    bSort:SetPoint("LEFT", bHere, "RIGHT", 4, 0)
    local bDelete = ns.CreateButton(right, L["Delete plan"], 110)
    bDelete:SetPoint("LEFT", bSort, "RIGHT", 4, 0)
    ns.SetTooltip(bSort, L["Sort by travel time"],
        L["Puts the open steps into the fastest order from your position (flight points, zones, continents). Finished steps stay on top."],
        L["A plan from the post becomes your own plan. “Reset” restores the original order."])
    ns.SetTooltip(bEdit, L["Edit"], L["Rename, change the order, remove steps, remember your current position."],
        L["A plan from the post becomes your own plan (progress is kept)."])
    ns.SetTooltip(bHere, L["Remember here"], L["Adds your current position as a “Go to” step at the end of the plan."])

    ns.SetTooltip(bMode, L["Mode"],
        L["|cffffd100Route:|r steps in order, the arrow always points to the next open step."],
        L["|cffffd100All points:|r all open steps on the map and minimap, the arrow points to the one you reach fastest (flights included)."])
    ns.SetTooltip(bNote, L["Note for the plan"], L["Opens your own note for this plan (creates it if needed)."])
    ns.SetTooltip(bWay, L["/way commands"], L["Shows all steps as /way lines with the zone, ready to copy."])

    local note = ns.FontString(right, "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 2, -52)
    note:SetPoint("RIGHT", -4, 0)
    note:SetHeight(26)
    note:SetJustifyV("TOP")
    note:SetTextColor(0.85, 0.8, 0.65)
    local noteHover = CreateFrame("Frame", nil, right)
    noteHover:SetAllPoints(note)
    noteHover:EnableMouse(true)

    local stepsInset = ns.CreateInset(right)
    stepsInset:SetPoint("TOPLEFT", 0, -80)
    stepsInset:SetPoint("BOTTOMRIGHT", 0, 40)

    -- Unten: Zurücksetzen und Wegpunkte neu setzen
    local bReset = ns.CreateButton(right, L["Reset"], 124)
    bReset:SetPoint("BOTTOMRIGHT", 0, 14)
    local bWp = ns.CreateButton(right, L["Reset waypoints"], 116)
    bWp:SetPoint("RIGHT", bReset, "LEFT", -4, 0)
    local bRoute = ns.CreateButton(right, L["Route description"], 130)
    bRoute:SetPoint("RIGHT", bWp, "LEFT", -4, 0)
    local bExport = ns.CreateButton(right, L["Export"], 62)
    bExport:SetPoint("BOTTOMLEFT", 0, 14)
    ns.SetTooltip(bExport, L["Export"], L["Shows the plan as text to copy and share. Other players read it with “Import plan”."])
    ns.SetTooltip(bReset, L["Reset plan"],
        L["All skipped and manually ticked-off steps are open again, the arrow starts at the top."],
        L["Your own plans, copies of plans from the post and the turn-in round also get their original steps back – the previous state stays in the trash for 10 minutes."],
        L["|cff999999Quests you have turned in stay done.|r"])
    ns.SetTooltip(bWp, L["Set waypoints again"],
        L["Removes Roadbook's waypoints from TomTom and sets them again for the loaded plan – including ones you removed by hand. The arrow then points at the plan again."],
        L["Also works with a left-click on the tracker or |cffffffff/rb waypoints|r."])
    ns.SetTooltip(bRoute, L["Route description"],
        L["All open steps with the way there (on foot, flight from–to, zeppelin) and the estimated time, to read and copy."])

    local hint = ns.FontString(right, "GameFontDisableSmall", "CENTER")
    hint:SetPoint("BOTTOM", 0, 0)
    local HINT_NORMAL = L["Click: arrow there · Shift+click: tick off · Right-click: skip"]
    local HINT_EDIT = L["Arrows: change order · Minus: remove step (trash)"]
    hint:SetText(HINT_NORMAL)

    local function iconButton(parent, tex, flip, tip)
        local b = ns.AutoWrap(CreateFrame("Button", nil, parent), "step-button")
        b:SetSize(18, 18)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexture(tex)
        if flip then t:SetTexCoord(0, 1, 1, 0) end
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        ns.SetTooltip(b, tip)
        return b
    end

    local stepList = ns.CreateScrollList(stepsInset, 24, function(parent)
        local row = ns.CreateRow(parent)
        row.box = row:CreateTexture(nil, "ARTWORK")
        row.box:SetSize(20, 20)
        row.box:SetPoint("LEFT", 2, 0)
        row.check = row:CreateTexture(nil, "OVERLAY")
        row.check:SetTexture(ns.TEX.checkOn)
        row.check:SetAllPoints(row.box)
        row.where = ns.FontString(row, "GameFontHighlightSmall", "RIGHT")
        row.where:SetPoint("RIGHT", -4, 0)
        row.where:SetWidth(150)
        row.where:SetWordWrap(false)
        row.text = ns.FontString(row, "GameFontHighlight")
        row.text:SetPoint("LEFT", row.box, "RIGHT", 4, 0)
        row.text:SetPoint("RIGHT", row.where, "LEFT", -6, 0)
        row.text:SetWordWrap(false)
        row.del = iconButton(row, "Interface\\Buttons\\UI-MinusButton-Up", false, L["Remove step"])
        row.del:SetPoint("RIGHT", -4, 0)
        row.down = iconButton(row, "Interface\\Buttons\\Arrow-Down-Up", false, L["Move down"])
        row.down:SetPoint("RIGHT", row.del, "LEFT", -6, 0)
        row.up = iconButton(row, "Interface\\Buttons\\Arrow-Down-Up", true, L["Move up"])
        row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
        row.del:SetScript("OnClick", function(self) local r = self:GetParent(); ns.RemoveStep(r.plan, r.step) end)
        row.down:SetScript("OnClick", function(self) local r = self:GetParent(); ns.MoveStep(r.plan, r.step, 1) end)
        row.up:SetScript("OnClick", function(self) local r = self:GetParent(); ns.MoveStep(r.plan, r.step, -1) end)
        row:SetScript("OnClick", function(self, button)
            local plan, step = self.plan, self.step
            if ns.planEditId == plan.id then return end
            if step.travel then
                if button == "RightButton" then ns.ToggleTravelSkip(step.travel.stepKey) end
                return
            end
            if button == "RightButton" then ns.ToggleSkip(plan, step)
            elseif IsShiftKeyDown() then ns.ToggleDone(step)
            else ns.FocusStep(plan, step) end
        end)
        row:SetScript("OnEnter", function(self)
            local st = self.step
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if st.travel then
                GameTooltip:AddLine(st.travel.title, 1, 0.82, 0, true)
                GameTooltip:AddLine(L["Travel leg: Roadbook sends you here first because that is faster."], 1, 1, 1, true)
                GameTooltip:AddLine(L["Right-click: skip it – the arrow then points straight to the step. Right-click again brings it back."], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
                return
            end
            GameTooltip:AddLine(ns.StepTitle(st), 1, 0.82, 0, true)
            local label = ns.STEP_LABEL[st.type] or ""
            if st.quest then label = label .. (L[" (quest %d)"]):format(st.quest) end
            if st.item then label = label .. (L[" (%dx item %d)"]):format(st.count, st.item) end
            GameTooltip:AddLine(label, 0.7, 0.7, 0.7)
            if st.map then GameTooltip:AddLine(("%s %.1f %.1f"):format(ns.ZoneName(st), st.x, st.y), 1, 1, 1) end
            if st.note then GameTooltip:AddLine(st.note, 0.9, 0.85, 0.7, true) end
            local state, detail = ns.StepState(st, self.plan.id)
            local stateText = ({ done = L["|cff80ff80done|r"], ready = L["|cffffd100ready to turn in|r"],
                                 open = L["open"], skipped = L["|cff999999skipped|r"] })[state]
            GameTooltip:AddLine("Status: " .. stateText .. (detail and state ~= "ready" and (" (" .. detail .. ")") or ""), 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return row
    end)
    stepList.scroll:SetPoint("TOPLEFT", 6, -6)
    stepList.scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local noPlan = ns.FontString(right, "GameFontDisable", "CENTER")
    noPlan:SetPoint("CENTER", stepsInset, "CENTER")

    -------------------------------------------------------------------
    -- Aktualisieren
    -------------------------------------------------------------------
    tab.update = function()
        local nTrash = #ns.TrashList()
        trashBtn:SetText(nTrash > 0 and (L["Trash (%d)"]):format(nTrash) or L["Trash"])
        local plan, plans = selectedPlan()

        empty:SetShown(#plans == 0)
        planList:SetData(plans, function(row, p)
            row.plan = p
            local d, t = ns.PlanProgress(p)
            local active = (p.id == ns.C.activePlan)
            row.text:SetText(p.title)
            if active then row.text:SetTextColor(0.5, 1, 0.5)
            elseif p.source == "eigen" then row.text:SetTextColor(0.7, 0.75, 1)
            else row.text:SetTextColor(1, 0.82, 0) end
            row.count:SetText(("%d/%d"):format(d, t))
            row.selected:SetShown(plan and p.id == plan.id or false)
        end)

        local hasPlan = plan ~= nil
        if not hasPlan or ns.planEditId ~= plan.id then ns.planEditId = nil end
        local editing = hasPlan and ns.planEditId == plan.id
        bExport:SetScript("OnClick", function() if plan then ns.ShowCopy(L["Export: "] .. plan.title, ns.ExportPlan(plan)) end end)
        for _, w in ipairs({ bLoad, bMode, bNote, bWay, bEdit, bReset, bRoute, bExport }) do w:SetShown(hasPlan and not editing) end
        for _, w in ipairs({ bDone, bHere, bSort, bDelete, titleEdit }) do w:SetShown(editing and true or false) end
        bWp:SetShown(hasPlan and not editing and plan.id == ns.C.activePlan or false)
        title:SetShown(not editing)
        hint:SetText(editing and HINT_EDIT or HINT_NORMAL)
        noPlan:SetShown(not hasPlan)
        noPlan:SetText(#plans == 0 and "" or L["Choose a plan on the left."])
        if not hasPlan then
            title:SetText(""); meta:SetText(""); note:SetText("")
            stepList:SetData({}, function() end)
            return
        end

        bEdit:SetScript("OnClick", function()
            ns.planEditId = plan.id
            titleEdit:SetText(plan.title)
            ns.UpdateUI()
        end)
        bDone:SetScript("OnClick", function()
            titleEdit:ClearFocus()
            ns.planEditId = nil
            ns.UpdateUI()
        end)
        bHere:SetScript("OnClick", function() ns.AddHereStep(plan) end)
        bSort:SetScript("OnClick", function() ns.SortPlan(plan) end)
        bReset:SetScript("OnClick", function() ns.ResetPlan(plan) end)
        bWp:SetScript("OnClick", function() ns.ResetWaypoints() end)
        bRoute:SetScript("OnClick", function() ns.ShowCopy(L["Route description"], ns.RouteText(plan)) end)
        if editing and not titleEdit:HasFocus() then titleEdit:SetText(plan.title) end
        titleEdit:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            ns.RenamePlan(plan, self:GetText())
        end)
        titleEdit:SetScript("OnEscapePressed", function(self)
            self:SetText(plan.title)
            self:ClearFocus()
        end)

        local active = (plan.id == ns.C.activePlan)
        local d, t = ns.PlanProgress(plan)
        title:SetText(plan.title)
        local origin = plan.auto and L["automatic"] or (plan.source == "eigen" and L["own plan"] or L["from the post"])
        meta:SetText((L["%s · %d/%d done"]):format(origin, d, t))
        local nSkip = ns.CountSkipped(plan)
        bReset:SetText(nSkip > 0 and (L["Reset (%d)"]):format(nSkip) or L["Reset"])

        bLoad:SetText(active and L["Unload"] or L["Load"])
        bLoad:SetScript("OnClick", function()
            if active then ns.DeactivatePlan() else ns.ActivatePlan(plan.id) end
        end)
        local mode = ns.PlanMode(plan)
        bMode:SetText(mode == "route" and L["Mode: Route"] or L["Mode: All"])
        bMode:SetScript("OnClick", function() ns.SetMode(plan, mode == "route" and "alle" or "route") end)
        bNote:SetScript("OnClick", function()
            local n = ns.GetPlanNote(plan, true)
            ns.ShowTab("notes")
            if ns.SelectNote then ns.SelectNote(n.id) end
        end)
        bWay:SetScript("OnClick", function()
            local lines = {}
            for _, st in ipairs(plan.steps) do
                local l = ns.WayLine(st)
                if l then table.insert(lines, l) end
            end
            ns.ShowCopy("/way – " .. plan.title, table.concat(lines, "\n"))
        end)
        bDelete:SetScript("OnClick", function() ns.planEditId = nil; ns.DeletePlan(plan) end)
        bDelete:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["Delete"], 1, 0.82, 0)
            if plan.source == "eigen" then
                GameTooltip:AddLine(L["Goes to the trash and can be restored from there for 10 minutes."], 1, 1, 1, true)
            else
                GameTooltip:AddLine(L["Hides the plan from the post (trash: can be restored for 10 minutes). If the post brings a changed version, it shows up again."], 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        bDelete:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Notiz: aus der Post zum Plan + Hinweis auf eigene Notiz
        local own = ns.GetPlanNote(plan, false)
        local noteText = plan.note or ""
        if own and ns.Trim(own.body) ~= "" then
            noteText = (noteText ~= "" and (noteText .. "  ") or "") .. L["|cffb0b0ff[You have a note]|r"]
        end
        note:SetText(noteText)
        noteHover:SetScript("OnEnter", function(self)
            if noteText == "" then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            if plan.note then
                GameTooltip:AddLine(L["Note from the post"], 1, 0.82, 0)
                GameTooltip:AddLine(plan.note, 1, 1, 1, true)
            end
            if own and ns.Trim(own.body) ~= "" then
                GameTooltip:AddLine(L["Your note"], 0.7, 0.7, 1)
                GameTooltip:AddLine(own.body, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        noteHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local cur = active and ns.CurrentStep(plan) or nil
        -- Reise-Abschnitt (Flugmeister/Anleger) als eigene Zeile vor seinem Schritt
        local rows, travel, number = {}, (active and not editing) and ns.TravelRow() or nil, 0
        for _, st in ipairs(plan.steps) do
            if travel and travel.stepKey == st.key then rows[#rows + 1] = { travel = travel } end
            rows[#rows + 1] = st
        end
        stepList:SetData(rows, function(row, st)
            row.plan, row.step = plan, st
            if st.travel then
                row.selected:SetShown(not st.travel.skipped)
                row.box:SetTexture(ns.TEX.avail); row.check:Hide()
                row.box:SetDesaturated(st.travel.skipped and true or false)
                row.up:Hide(); row.down:Hide(); row.del:Hide(); row.where:Show()
                row.text:ClearAllPoints()
                row.text:SetPoint("LEFT", row.box, "RIGHT", 4, 0)
                row.text:SetPoint("RIGHT", row.where, "LEFT", -6, 0)
                row.text:SetText("→ " .. st.travel.title)
                if st.travel.skipped then row.text:SetTextColor(0.4, 0.4, 0.4) else row.text:SetTextColor(0.4, 0.85, 1) end
                row.where:SetText(st.travel.skipped and L["skipped"] or L["on the way"])
                return
            end
            number = number + 1
            local i = number
            local state, detail = ns.StepState(st, plan.id)
            local isCur = cur and cur.key == st.key
            row.selected:SetShown(isCur and true or false)
            if state == "ready" then
                row.box:SetTexture(ns.TEX.ready); row.check:Hide()
            else
                row.box:SetTexture(ns.TEX.checkOff); row.check:SetShown(state == "done")
            end
            row.box:SetDesaturated(state == "skipped")
            row.up:SetShown(editing and i > 1 or false)
            row.down:SetShown(editing and i < #plan.steps or false)
            row.del:SetShown(editing and true or false)
            row.where:SetShown(not editing)
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row.box, "RIGHT", 4, 0)
            if editing then row.text:SetPoint("RIGHT", row.up, "LEFT", -6, 0)
            else row.text:SetPoint("RIGHT", row.where, "LEFT", -6, 0) end
            row.text:SetText(("%d. %s"):format(i, ns.StepTitle(st)))
            if state == "done" then row.text:SetTextColor(0.55, 0.55, 0.55)
            elseif state == "skipped" then row.text:SetTextColor(0.4, 0.4, 0.4)
            elseif isCur then row.text:SetTextColor(1, 0.82, 0)
            else row.text:SetTextColor(1, 1, 1) end
            local where = st.map and ("%s %.1f %.1f"):format(ns.ZoneName(st), st.x, st.y) or ""
            if state == "skipped" then where = L["skipped"]
            elseif state == "ready" then where = L["|cffffd100ready to turn in|r · "] .. where
            elseif detail and state ~= "done" and st.type == "item" then where = detail .. " · " .. where end
            row.where:SetText(where)
        end)
    end
end
