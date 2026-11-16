-- Roadbook: Hauptfenster im Classic-Stil, Reiter, gemeinsame Bausteine
local ADDON, ns = ...
local L = ns.L

local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
ns.TEX = {
    checkOff = "Interface\\Buttons\\UI-CheckBox-Up",
    checkOn  = "Interface\\Buttons\\UI-CheckBox-Check",
    ready    = "Interface\\GossipFrame\\ActiveQuestIcon",
    avail    = "Interface\\GossipFrame\\AvailableQuestIcon",
    done     = "Interface\\RaidFrame\\ReadyCheck-Ready",
    note     = "Interface\\Icons\\INV_Misc_Note_01",
}

---------------------------------------------------------------------------
-- Bausteine
---------------------------------------------------------------------------
local INSET_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

function ns.CreateInset(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(INSET_BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.55)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    return f
end

function ns.CreateButton(parent, text, width, onClick)
    local b = ns.AutoWrap(CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"), "button:" .. tostring(text))
    b:SetSize(width or 100, 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function ns.SetTooltip(widget, title, ...)
    local lines = { ... }
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(type(title) == "function" and title(self) or title, 1, 0.82, 0)
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns.FontString(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- Scrollbare Liste mit festen Zeilenhöhen
function ns.CreateScrollList(parent, rowHeight, createRow)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
    local obj = { scroll = sf, child = child, rows = {}, rowHeight = rowHeight }
    function obj:SetData(items, bind)
        child:SetWidth(sf:GetWidth())
        for i, item in ipairs(items) do
            local row = self.rows[i]
            if not row then
                row = createRow(child)
                row:SetHeight(rowHeight)
                row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * rowHeight)
                row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
                self.rows[i] = row
            end
            row:Show()
            bind(row, item, i)
        end
        for i = #items + 1, #self.rows do self.rows[i]:Hide() end
        child:SetHeight(math.max(1, #items * rowHeight))
    end
    return obj
end

-- Zeile mit Quest-Log-Hervorhebung (Classic)
function ns.CreateRow(parent)
    local row = ns.AutoWrap(CreateFrame("Button", nil, parent), "row")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture(HIGHLIGHT, "ADD")
    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetTexture(HIGHLIGHT)
    sel:SetBlendMode("ADD")
    sel:SetAllPoints()
    sel:Hide()
    row.selected = sel
    return row
end

-- Mehrzeiliges Textfeld in einem Rahmen
function ns.CreateTextArea(parent, readOnly)
    local inset = ns.CreateInset(parent)
    local sf = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local edit = ns.AutoWrap(CreateFrame("EditBox", nil, sf), "textarea")
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal or GameFontHighlight)
    edit:SetWidth(200)
    edit:SetTextInsets(2, 2, 2, 2)
    edit.cursorOffset, edit.cursorHeight = 0, 0   -- sonst rechnet ScrollingEdit_OnUpdate mit nil
    sf:SetScrollChild(edit)
    sf:SetScript("OnSizeChanged", function(_, w) edit:SetWidth(w) end)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() edit:SetFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if ScrollingEdit_OnCursorChanged then ScrollingEdit_OnCursorChanged(self, x, y, w, h) end
    end)
    edit:SetScript("OnUpdate", function(self, elapsed)
        if ScrollingEdit_OnUpdate then ScrollingEdit_OnUpdate(self, elapsed, sf) end
    end)
    inset.scroll, inset.edit, inset.readOnly = sf, edit, readOnly
    return inset
end

---------------------------------------------------------------------------
-- Kopierfenster (WoW kennt keine Zwischenablage: Text markieren, Strg+C)
---------------------------------------------------------------------------
function ns.ShowCopy(title, text)
    local f = ns.copyFrame
    if not f then
        f = CreateFrame("Frame", "RoadbookCopyFrame", UIParent, "BackdropTemplate")
        f:SetBackdrop(BACKDROP_DIALOG_32_32 or INSET_BACKDROP)
        f:SetSize(520, 300)
        f:SetPoint("CENTER", 0, 60)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f.title = ns.FontString(f, "GameFontNormal", "CENTER")
        f.title:SetPoint("TOP", 0, -18)
        f.hint = ns.FontString(f, "GameFontDisableSmall", "CENTER")
        f.hint:SetPoint("BOTTOM", 0, 20)
        f.hint:SetText(L["The text is selected: |cffffffffCtrl+C|r copies, |cffffffffEsc|r closes."])
        local area = ns.CreateTextArea(f, true)
        area:SetPoint("TOPLEFT", 18, -38)
        area:SetPoint("BOTTOMRIGHT", -18, 40)
        f.edit = area.edit
        f.edit:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(f.text or ""); self:HighlightText() end
        end)
        f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
        tinsert(UISpecialFrames, "RoadbookCopyFrame")
        ns.copyFrame = f
    end
    f.text = text or ""
    f.title:SetText(title or L["Copy"])
    f.edit:SetText(f.text)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

---------------------------------------------------------------------------
-- Papierkorb-Fenster
---------------------------------------------------------------------------
function ns.ShowTrash()
    local f = ns.trashFrame
    if not f then
        f = CreateFrame("Frame", "RoadbookTrashFrame", UIParent, "BackdropTemplate")
        f:SetBackdrop(BACKDROP_DIALOG_32_32 or INSET_BACKDROP)
        f:SetSize(440, 320)
        f:SetPoint("CENTER", 0, 40)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local title = ns.FontString(f, "GameFontNormal", "CENTER")
        title:SetPoint("TOP", 0, -18)
        title:SetText(L["Trash"])
        local hint = ns.FontString(f, "GameFontDisableSmall", "CENTER")
        hint:SetPoint("BOTTOM", 0, 18)
        hint:SetText((L["Deleted items stay here for %d minutes, then they are gone for good."]):format(ns.TrashSeconds() / 60))
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)

        local inset = ns.CreateInset(f)
        inset:SetPoint("TOPLEFT", 18, -40)
        inset:SetPoint("BOTTOMRIGHT", -18, 36)
        f.list = ns.CreateScrollList(inset, 34, function(parent)
            local row = ns.CreateRow(parent)
            row.text = ns.FontString(row, "GameFontHighlight")
            row.text:SetPoint("TOPLEFT", 6, -3)
            row.text:SetPoint("TOPRIGHT", -120, -3)
            row.text:SetWordWrap(false)
            row.info = ns.FontString(row, "GameFontDisableSmall")
            row.info:SetPoint("BOTTOMLEFT", 6, 3)
            row.restore = ns.CreateButton(row, L["Restore"], 112, function(self)
                local r = self:GetParent()
                if r.index then ns.RestoreTrash(r.index) end
            end)
            row.restore:SetPoint("RIGHT", -2, 0)
            return row
        end)
        f.list.scroll:SetPoint("TOPLEFT", 6, -6)
        f.list.scroll:SetPoint("BOTTOMRIGHT", -26, 6)
        f.empty = ns.FontString(inset, "GameFontDisable", "CENTER")
        f.empty:SetPoint("CENTER")
        f.empty:SetText(L["The trash is empty."])

        local acc = 0
        f:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            if acc >= 1 then acc = 0; ns.Safe("trash", ns.UpdateTrash) end
        end)
        tinsert(UISpecialFrames, "RoadbookTrashFrame")
        ns.trashFrame = f
    end
    f:Show()
    ns.UpdateTrash()
end

function ns.UpdateTrash()
    local f = ns.trashFrame
    if not (f and f:IsShown()) then return end
    local items = ns.TrashList()
    f.empty:SetShown(#items == 0)
    f.list:SetData(items, function(row, it)
        row.index = it.index
        row.text:SetText(it.entry.title or "?")
        local mins = math.ceil(it.left / 60)
        row.info:SetText((L["%s · %d min left"]):format(ns.TRASH_KIND_LABEL[it.entry.kind] or "", mins))
        row.selected:Hide()
    end)
end

---------------------------------------------------------------------------
-- Hauptfenster
---------------------------------------------------------------------------
local TAB_ORDER = { "plans", "notes", "macros", "search", "options" }
local TAB_TITLE = { plans = L["Plans"], notes = L["Notes"], macros = L["Macros"], search = L["NPC search"], options = L["Options"] }
ns.tabs = {}

local function SavePosition(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    ns.DB.frame = { point = point, relPoint = relPoint, x = x, y = y }
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "RoadbookFrame", UIParent, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_DIALOG_32_32 or INSET_BACKDROP)
    f:SetSize(840, 480)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self) end)
    local pos = ns.DB.frame
    if type(pos) == "table" and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", 0, 40)
    end
    f:Hide()

    -- Titelbanner wie bei klassischen Dialogen
    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(300, 64)
    header:SetPoint("TOP", 0, 12)
    local title = ns.FontString(f, "GameFontNormal", "CENTER")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("Roadbook")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    f.status = ns.FontString(f, "GameFontDisableSmall", "RIGHT")
    f.status:SetPoint("BOTTOMRIGHT", -20, 16)

    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", 18, -30)
    f.content:SetPoint("BOTTOMRIGHT", -18, 32)

    -- Reiter unten (wie im Charakterfenster)
    f.tabButtons = {}
    for i, key in ipairs(TAB_ORDER) do
        local tab = CreateFrame("Button", "RoadbookFrameTab" .. i, f, "PanelTabButtonTemplate")
        if i == 1 then tab:SetPoint("BOTTOMLEFT", 12, -30)
        else tab:SetPoint("LEFT", f.tabButtons[i - 1], "RIGHT", 4, 0) end
        tab:SetID(i)
        tab.key = key
        if tab.Text then tab.Text:SetText(TAB_TITLE[key]) else tab:SetText(TAB_TITLE[key]) end
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
        tab:SetScript("OnClick", ns.Wrap("tab", function(self) ns.ShowTab(self.key) end))
        f.tabButtons[i] = tab
    end

    f:SetScript("OnShow", function()
        ns.MarkPostSeen()
        ns.UpdateUI()
    end)
    tinsert(UISpecialFrames, "RoadbookFrame")

    ns.frame = f
    for _, key in ipairs(TAB_ORDER) do
        local builder = ns["Build_" .. key]
        local panel = CreateFrame("Frame", nil, f.content)
        panel:SetAllPoints()
        panel:Hide()
        ns.tabs[key] = { panel = panel }
        if builder then builder(panel, ns.tabs[key]) end
    end
    ns.ShowTab(ns.currentTab or "plans")
    return f
end

function ns.ShowTab(key)
    if not ns.tabs[key] then key = "plans" end
    ns.currentTab = key
    if not ns.frame then return end
    for i, k in ipairs(TAB_ORDER) do
        local tab = ns.frame.tabButtons[i]
        ns.tabs[k].panel:SetShown(k == key)
        if PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
            if k == key then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
        end
    end
    ns.UpdateUI()
end

function ns.ShowFrame(tab)
    if not ns.frame then CreateMainFrame() end
    if tab then ns.currentTab = tab end
    ns.frame:Show()
    ns.ShowTab(ns.currentTab or "plans")
end

function ns.ToggleFrame()
    if ns.frame and ns.frame:IsShown() then ns.frame:Hide() else ns.ShowFrame() end
end

function ns.UpdateUI()
    ns.Safe("ui", ns.UpdateUIInner)
end

function ns.UpdateUIInner()
    if ns.UpdateMinimapBadge then ns.UpdateMinimapBadge() end
    if ns.UpdateTracker then ns.Safe("tracker", ns.UpdateTracker) end
    if ns.trashFrame and ns.trashFrame:IsShown() then ns.UpdateTrash() end
    local f = ns.frame
    if not (f and f:IsShown()) then return end
    -- Reitertexte
    local pending = ns.CountPendingMacros()
    for i, key in ipairs(TAB_ORDER) do
        local tab = f.tabButtons[i]
        local text = TAB_TITLE[key]
        if key == "macros" and pending > 0 then text = text .. " |cff80ff80(" .. pending .. ")|r" end
        if tab.Text then tab.Text:SetText(text) else tab:SetText(text) end
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    end
    -- Statuszeile
    local status
    if ns.postError then
        status = L["|cffff6060Post is broken – see chat|r"]
    elseif ns.post and ns.post.version and not ns.staging then
        status = L["Post: version "] .. ns.post.version
    else
        status = "Roadbook " .. ((ns.staging and ns.VERSION == "dev") and "" or ns.VERSION)   -- Fotos ohne „dev“
    end
    if not _G.TomTom then status = L["|cffff6060TomTom missing|r · "] .. status end
    local errs = ns.SessionErrors()
    if errs > 0 then status = (L["|cffff6060%d error(s) – /rb log|r · "]):format(errs) .. status end
    if ns.DebugOn() then status = "|cffffb040Debug|r · " .. status end
    f.status:SetText(status)
    local tab = ns.tabs[ns.currentTab]
    if tab and tab.update then tab.update() end
end

---------------------------------------------------------------------------
-- Minimap-Knopf
---------------------------------------------------------------------------
local function PositionMinimap()
    local b = ns.minimapButton
    if not (b and Minimap) then return end
    local angle = math.rad(ns.DB.minimap.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function ns.CreateMinimapButton()
    if ns.minimapButton or not Minimap then return end
    local b = ns.AutoWrap(CreateFrame("Button", "RoadbookMinimapButton", Minimap), "minimap")
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.TEX.note)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", -1, 1)
    local badge = b:CreateTexture(nil, "OVERLAY", nil, 2)
    badge:SetTexture(ns.TEX.avail)
    badge:SetSize(14, 14)
    badge:SetPoint("TOPRIGHT", 2, 2)
    badge:Hide()
    b.badge = badge

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            local plan = ns.ActivePlan()
            if plan then ns.DeactivatePlan() else ns.ShowFrame("plans") end
        else
            ns.ToggleFrame()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Roadbook", 1, 0.82, 0)
        local plan = ns.ActivePlan()
        if plan then
            local d, t = ns.PlanProgress(plan)
            GameTooltip:AddLine((L["Active plan: %s (%d/%d)"]):format(plan.title, d, t), 1, 1, 1)
            local cur = ns.CurrentStep(plan)
            if cur then GameTooltip:AddLine(L["Next: "] .. ns.StepTitle(cur), 0.8, 0.8, 0.8, true) end
        else
            GameTooltip:AddLine(L["No plan loaded"], 0.8, 0.8, 0.8)
        end
        if ns.HasNewPost() then GameTooltip:AddLine(L["New post!"], 0.5, 1, 0.5) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Left-click: open/close"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Right-click: unload plan"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Drag: move"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.DB.minimap.angle = math.deg(math.atan2(y / scale - my, x / scale - mx))
            PositionMinimap()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    ns.minimapButton = b
    PositionMinimap()
    ns.UpdateMinimapButton()
end

function ns.UpdateMinimapButton()
    local b = ns.minimapButton
    if not b then return end
    b:SetShown(not ns.DB.minimap.hidden)
    ns.UpdateMinimapBadge()
end

function ns.UpdateMinimapBadge()
    local b = ns.minimapButton
    if b then b.badge:SetShown(ns.HasNewPost() and true or false) end
end

---------------------------------------------------------------------------
-- Schritt-Tracker unter der Minimap
---------------------------------------------------------------------------
local TRACKER_W = 250
local MAX_NEXT, MAX_MISSING = 4, 5

local function fmtDist(yards)
    if not yards then return nil end
    return (L["%d yd"]):format(math.floor(yards + 0.5))
end

local function currentDistance(step)
    local tt = _G.TomTom
    local uid = step and ns.StepUid and ns.StepUid(step)
    -- Führt der Weg erst zum Flugmeister/Anleger, zählt die Entfernung dorthin
    local viaTravel = step and ns.travel and ns.travel.stepKey == step.key and ns.wp.travelUid
    if viaTravel then uid = viaTravel end
    if not (tt and uid and tt.GetDistanceToWaypoint) then return nil end
    local ok, d = pcall(tt.GetDistanceToWaypoint, tt, uid)
    return ok and d or nil, viaTravel and true or false
end

local function SaveTrackerPos(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    ns.DB.tracker = ns.DB.tracker or {}
    ns.DB.tracker.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

function ns.CreateTracker()
    if ns.tracker then return ns.tracker end
    ns.DB.tracker = ns.DB.tracker or {}
    local f = ns.AutoWrap(CreateFrame("Frame", "RoadbookTracker", UIParent, "BackdropTemplate"), "tracker")
    f:SetBackdrop(INSET_BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.6)
    f:SetBackdropBorderColor(0.7, 0.6, 0.4, 0.9)
    f:SetWidth(TRACKER_W)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing(); SaveTrackerPos(self)
        self.dragEnd = GetTime and GetTime() or 0
    end)
    local pos = ns.DB.tracker.pos
    if type(pos) == "table" and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    elseif Minimap then
        f:SetPoint("TOP", Minimap, "BOTTOM", 0, -28)
    else
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -240)
    end

    f.toggle = ns.AutoWrap(CreateFrame("Button", nil, f), "tracker-toggle")
    f.toggle:SetSize(14, 14)
    f.toggle:SetPoint("TOPLEFT", 8, -8)
    f.toggleTex = f.toggle:CreateTexture(nil, "ARTWORK")
    f.toggleTex:SetAllPoints()
    f.toggle:SetScript("OnClick", function()
        ns.DB.tracker.expanded = not ns.DB.tracker.expanded
        ns.UpdateTracker()
    end)
    ns.SetTooltip(f.toggle, L["Expand"], L["Shows the next steps and quests ready to turn in that are missing from the plan."])

    f.header = ns.FontString(f, "GameFontNormalSmall")
    f.header:SetPoint("LEFT", f.toggle, "RIGHT", 4, 0)
    f.header:SetPoint("RIGHT", f, "RIGHT", -44, 0)
    f.header:SetWordWrap(false)
    f.progress = ns.FontString(f, "GameFontHighlightSmall", "RIGHT")
    f.progress:SetPoint("TOPRIGHT", -8, -9)

    f.action = ns.CreateButton(f, L["Skip"], 54)
    f.action:SetHeight(20)
    f.action:SetPoint("TOPRIGHT", -6, -26)

    f.line1 = ns.FontString(f, "GameFontHighlight")
    f.line1:SetPoint("TOPLEFT", 10, -26)
    f.line1:SetPoint("RIGHT", f.action, "LEFT", -6, 0)
    f.line1:SetWordWrap(false)
    f.line2 = ns.FontString(f, "GameFontDisableSmall")
    f.line2:SetPoint("TOPLEFT", f.line1, "BOTTOMLEFT", 0, -2)
    f.line2:SetPoint("RIGHT", f.action, "LEFT", -6, 0)
    f.line2:SetWordWrap(false)
    -- Reisehinweis (Flug/Zeppelin) oder Warnung zum Wegpunkt
    f.line3 = ns.FontString(f, "GameFontNormalSmall")
    f.line3:SetPoint("TOPLEFT", 10, -60)
    f.line3:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.line3:SetWordWrap(false)
    f.line3:Hide()
    -- EP: aktuelle Abgabe und alle offenen Abgaben des Plans
    f.xpLine = ns.FontString(f, "GameFontHighlightSmall")
    f.xpLine:SetTextColor(0.69, 0.44, 1)
    f.xpLine:SetWordWrap(false)

    -- Ausgeklappter Teil
    f.nextLines = {}
    for i = 1, MAX_NEXT do
        local fs = ns.FontString(f, "GameFontHighlightSmall")
        fs:SetWordWrap(false)
        f.nextLines[i] = fs
    end
    f.warn = ns.FontString(f, "GameFontNormalSmall")
    f.warn:SetTextColor(1, 0.6, 0.2)
    f.missLines = {}
    for i = 1, MAX_MISSING do
        local fs = ns.FontString(f, "GameFontHighlightSmall")
        fs:SetWordWrap(false)
        f.missLines[i] = fs
    end
    f.addBtn = ns.CreateButton(f, L["Add"], 96, function() ns.AddMissingTurnIns() end)
    f.addBtn:SetHeight(20)
    ns.SetTooltip(f.addBtn, L["Add missing turn-ins"],
        L["Adds the quests that are ready to turn in to the active plan. The automatic turn-in round is rebuilt instead."])

    -- Linksklick: Wegpunkte/Pfeil neu setzen · Rechtsklick: Roadbook öffnen
    f:SetScript("OnMouseUp", function(self, button)
        -- Loslassen direkt nach dem Verschieben ist kein Klick
        local now = GetTime and GetTime() or 0
        if self.dragEnd and now - self.dragEnd < 0.3 then return end
        if button == "RightButton" then ns.ShowFrame("plans")
        elseif button == "LeftButton" and ns.ActivePlan() then ns.ResetWaypoints() end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["Roadbook tracker"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Left-click: set waypoints and arrow again"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Right-click: open Roadbook · Drag: move"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Hide: /rb tracker"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local acc, slow = 0, 0
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.5 then return end
        slow = slow + acc
        acc = 0
        if f.step then
            local yards, viaTravel = currentDistance(f.step)
            local d = fmtDist(yards)
            if d and viaTravel then
                f.line2:SetText((L["%s · then %s"]):format(d, f.where or ""))
            else
                f.line2:SetText((f.where or "") .. (d and ((f.where and f.where ~= "" and " · " or "") .. d) or ""))
            end
        end
        if slow >= 3 then
            slow = 0
            ns.Safe("tracker-hint", ns.UpdateTrackerHint)
        end
    end)

    ns.tracker = f
    return f
end

-- Dritte Zeile im Tracker: Warnung zum Wegpunkt/Pfeil oder Reisehinweis (Flug, Zeppelin).
-- layout = true: nur setzen (UpdateTracker rechnet die Höhe selbst);
-- sonst bei Ein-/Ausblenden den Tracker neu anordnen.
function ns.UpdateTrackerHint(layout)
    local f = ns.tracker
    if not f then return false end
    local plan = ns.ActivePlan()
    local st = f.step
    local text, r, g, b
    if ns.staging then
        text, r, g, b = ns.travel and ns.travel.text, 0.4, 0.85, 1
    elseif plan and st and st.map then
        if not _G.TomTom then
            text, r, g, b = L["TomTom missing – no waypoints possible"], 1, 0.4, 0.3
        elseif not ns.StepUid(st) then
            text, r, g, b = L["No waypoint in TomTom – left-click sets it again"], 1, 0.6, 0.2
        elseif ns.PlanMode(plan) == "route" and ns.ArrowOnStep(st) == false then
            text, r, g, b = L["The arrow points elsewhere – left-click realigns it"], 1, 0.6, 0.2
        elseif ns.travel then
            -- „Alle Punkte“: der Pfeil kann zu einem anderen Schritt führen
            text = ns.travel.stepKey == st.key and ns.travel.text or (ns.travel.text .. L[" – for "] .. ns.travel.stepTitle)
            r, g, b = 0.4, 0.85, 1
        end
    end
    local was = f.line3:IsShown() and true or false
    if text then
        f.line3:SetText(text)
        f.line3:SetTextColor(r, g, b)
        f.line3:Show()
    else
        f.line3:Hide()
    end
    if not layout and was ~= (text ~= nil) then ns.UpdateTracker() end
    return text ~= nil
end

function ns.UpdateTracker()
    if not (ns.DB and ns.C) then return end
    ns.DB.tracker = ns.DB.tracker or {}
    local f = ns.tracker
    if ns.DB.tracker.hidden then
        if f then f:Hide() end
        return
    end
    local plan = ns.ActivePlan()
    local ready = ns.ReadyQuests and ns.ReadyQuests() or {}
    -- ohne Plan nur zeigen, wenn es etwas anzubieten gibt (die Abgaberunde braucht QuestieDB)
    if not plan and (#ready == 0 or not (_G.QuestDB and _G.NpcDB)) then
        if f then f:Hide() end
        return
    end
    f = f or ns.CreateTracker()
    f:Show()
    local expanded = ns.DB.tracker.expanded and true or false
    f.toggleTex:SetTexture(expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")

    local y = -26 - 34   -- unter Zeile 1+2
    for _, fs in ipairs(f.nextLines) do fs:Hide() end
    for _, fs in ipairs(f.missLines) do fs:Hide() end
    f.warn:Hide(); f.addBtn:Hide(); f.xpLine:Hide()

    local missing
    if plan then
        local d, t = ns.PlanProgress(plan)
        f.header:SetText(plan.title)
        f.progress:SetText(("%d/%d"):format(d, t))
        local cur = ns.CurrentStep(plan)
        f.step = cur
        if ns.UpdateTrackerHint(true) then y = y - 14 end
        -- EP der aktuellen Abgabe und der offenen Abgaben im Plan; Übersprungenes zählt nicht mit
        local xp, share = ns.PlanXP(plan)
        if xp then
            local own = cur and cur.type == "turnin" and ns.QuestXP(cur.quest)
            f.xpLine:ClearAllPoints()
            f.xpLine:SetPoint("TOPLEFT", 10, y)
            f.xpLine:SetPoint("RIGHT", f, "RIGHT", -10, 0)
            f.xpLine:SetText((own and (L["+%d XP · "]):format(own) or "")
                .. (share and L["%d XP open in the plan (%d%%)"] or L["%d XP open in the plan"]):format(xp, share))
            f.xpLine:Show()
            y = y - 14
        end
        if cur then
            local state, detail = ns.StepState(cur, plan.id)
            f.line1:SetText(ns.StepTitle(cur))
            local where = cur.map and ("%s %.1f %.1f"):format(ns.ZoneName(cur), cur.x, cur.y) or ""
            if state == "ready" then where = L["|cffffd100ready to turn in|r"] .. (where ~= "" and (" · " .. where) or "")
            elseif detail and cur.type == "item" then where = detail .. (where ~= "" and (" · " .. where) or "") end
            f.where = where
            f.line2:SetText(where)
            f.action:SetText(L["Skip"])
            f.action:SetScript("OnClick", function() ns.SkipCurrentStep() end)
            f.action:Show()
        else
            local nSkip = ns.CountSkipped(plan)
            f.line1:SetText(L["|cff80ff80Plan completed|r"])
            f.where = ""
            if nSkip > 0 then
                f.line2:SetText((L["%d skipped – “Back” brings them back"]):format(nSkip))
                f.action:SetText(L["Back"])
                f.action:SetScript("OnClick", function() ns.ResetPlan(plan) end)
            else
                f.line2:SetText(L["Right-click opens Roadbook"])
                f.action:SetText(L["Unload"])
                f.action:SetScript("OnClick", function() ns.DeactivatePlan() end)
            end
            f.action:Show()
        end
        missing = ns.MissingTurnIns(plan)

        if expanded and cur then
            local shown, after = 0, false
            for _, st in ipairs(plan.steps) do
                if after and shown < MAX_NEXT then
                    local state = ns.StepState(st, plan.id)
                    if state == "open" or state == "ready" then
                        shown = shown + 1
                        local fs = f.nextLines[shown]
                        fs:ClearAllPoints()
                        fs:SetPoint("TOPLEFT", 14, y)
                        fs:SetPoint("RIGHT", f, "RIGHT", -10, 0)
                        fs:SetText("– " .. ns.StepTitle(st))
                        fs:Show()
                        y = y - 14
                    end
                end
                if st.key == cur.key then after = true end
            end
            if shown > 0 then y = y - 4 end
        end
    else
        f.step = nil
        f.line3:Hide()
        f.header:SetText(L["No plan loaded"])
        f.progress:SetText("")
        f.line1:SetText((L["%d quest%s ready to turn in"]):format(#ready, #ready == 1 and "" or "s"))
        f.where = ""
        f.line2:SetText(L["Create a turn-in round by travel time?"])
        f.action:SetText(L["Round"])
        f.action:SetScript("OnClick", function() ns.CreateTurnInPlan() end)
        f.action:Show()
        missing = {}
    end

    -- Abgabebereite Quests, die im Plan fehlen
    if #missing > 0 then
        f.warn:ClearAllPoints()
        f.warn:SetPoint("TOPLEFT", 10, y)
        f.warn:SetPoint("RIGHT", f, "RIGHT", -10, 0)
        f.warn:SetText((L["%d ready to turn in, not in the plan%s"]):format(#missing, expanded and ":" or " (+)"))
        f.warn:Show()
        y = y - 14
        if expanded then
            for i = 1, math.min(#missing, MAX_MISSING) do
                local fs = f.missLines[i]
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", 14, y)
                fs:SetPoint("RIGHT", f, "RIGHT", -10, 0)
                fs:SetText("– " .. missing[i].title)
                fs:Show()
                y = y - 14
            end
            if #missing > MAX_MISSING then
                local fs = f.missLines[MAX_MISSING]
                fs:SetText((L["– … and %d more"]):format(#missing - MAX_MISSING + 1))
            end
            f.addBtn:ClearAllPoints()
            f.addBtn:SetPoint("TOPLEFT", 10, y - 2)
            f.addBtn:Show()
            y = y - 26
        end
    end
    f:SetHeight(-y + 8)
end
