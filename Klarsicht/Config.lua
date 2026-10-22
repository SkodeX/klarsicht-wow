local ADDON, ns = ...
local C, L = ns.C, ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local QUESTION_MARK = 134400
local ROWS, ROW_HEIGHT = 12, 22
local COLUMN_2 = 210

local frame, detail, emptyText, hintText, lockButton, dialog
local rows = {}
local controls = {}       -- per-spell controls, refreshed with the selected entry
local gridControls = {}   -- controls for the shared grid settings
local selected
local listOffset = 0

function ns.IsConfigShown()
    return frame ~= nil and frame:IsShown()
end

function ns.GetSelected()
    return selected
end

local function SelectedEntry()
    if selected then return ns.db.spells[selected] end
end

---------------------------------------------------------------------------
-- Small widget helpers (plain templates that exist in every client)
---------------------------------------------------------------------------

local function CreateLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
    label:SetText(text or "")
    label:SetJustifyH("LEFT")
    return label
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 22)
    button:SetText(text)
    return button
end

local function CreateEditBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        ns.RefreshConfig()
    end)
    return box
end

local function SetValue(key, value)
    local entry = SelectedEntry()
    if not entry then return end
    entry[key] = value
    ns.ApplyEntry(selected)
    ns.RefreshConfig()
end

local function CreateCheckBox(parent, text, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.label = CreateLabel(check, text)
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    check:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return check
end

local function CreateGridCheck(parent, key, text)
    local check = CreateCheckBox(parent, text, function(checked)
        ns.db.grid[key] = checked
        ns.UpdateGrid()
    end)
    check.Refresh = function(self) self:SetChecked(ns.db.grid[key]) end
    gridControls[#gridControls + 1] = check
    return check
end

local function CreateCheck(parent, key, text)
    local check = CreateCheckBox(parent, text, function(checked) SetValue(key, checked) end)
    check.Refresh = function(self, entry)
        self:SetChecked(entry[key])
    end
    controls[key] = check
    return check
end

-- A button that steps through a list of modes on click.
local function CreateCycle(parent, key, modes, prefix, width)
    local button = CreateButton(parent, "", width)
    button:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if not entry then return end
        local index = 1
        for i, mode in ipairs(modes) do
            if mode == entry[key] then index = i end
        end
        SetValue(key, modes[index % #modes + 1])
    end)
    button.Refresh = function(self, entry)
        self:SetText(L[prefix .. entry[key]])
    end
    controls[key] = button
    return button
end

local function CreateSlider(parent, key, minValue, maxValue, width)
    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width, 16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider.value = CreateLabel(slider, "")
    slider.value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta)
    end)
    slider:SetScript("OnValueChanged", function(self, value)
        value = floor(value + 0.5)
        self.value:SetText(value)
        if not self.refreshing then SetValue(key, value) end
    end)
    slider.Refresh = function(self, entry)
        self.refreshing = true
        self:SetValue(entry[key])
        self.value:SetText(entry[key])
        self.refreshing = nil
    end
    controls[key] = slider
    return slider
end

local function CreateNumberBox(parent, key)
    local box = CreateEditBox(parent, 46)
    local function Commit(self)
        local value = tonumber(self:GetText())
        if value then SetValue(key, floor(value + 0.5)) end
    end
    box:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", Commit)
    box.Refresh = function(self, entry)
        if not self:HasFocus() then self:SetText(tostring(entry[key])) end
    end
    controls[key] = box
    return box
end

local function CreateSection(parent, text, x, y)
    local label = CreateLabel(parent, text, "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    return label
end

---------------------------------------------------------------------------
-- Adding spells
---------------------------------------------------------------------------

local function Select(index)
    selected = index
    ns.RefreshConfig()
    ns.RefreshMovers()
end

local function AddAndSelect(input)
    local index = ns.AddSpell(input)
    if index then
        -- Scroll so the new row is visible.
        listOffset = max(0, index - ROWS)
        Select(index)
    end
end

-- Spell dragged from the spellbook: GetCursorInfo() -> "spell", slot, book, spellID
local function TakeCursorSpell()
    local kind, _, _, spellID = GetCursorInfo()
    if kind ~= "spell" then return end
    ClearCursor()
    if spellID then AddAndSelect(spellID) end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function CreateList(parent)
    local list = CreateFrame("Frame", nil, parent)
    list:SetSize(196, ROWS * ROW_HEIGHT)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        listOffset = listOffset - delta
        ns.RefreshConfig()
    end)

    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(196, ROW_HEIGHT - 2)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row.selection = row:CreateTexture(nil, "BACKGROUND")
        row.selection:SetAllPoints()
        row.selection:SetColorTexture(0.25, 0.55, 1, 0.3)
        row:SetHighlightTexture(WHITE)
        row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 2, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.text = CreateLabel(row, "")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", -4, 0)
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self) Select(self.index) end)
        rows[i] = row
    end

    emptyText = CreateLabel(list, L.EMPTY)
    emptyText:SetPoint("TOPLEFT", 4, -4)
    emptyText:SetWidth(188)
    return list
end

local function CreateDetail(parent)
    detail = CreateFrame("Frame", nil, parent)
    detail:SetSize(400, 330)

    -- Header: icon, name, spell ID, remove button
    detail.icon = detail:CreateTexture(nil, "ARTWORK")
    detail.icon:SetSize(36, 36)
    detail.icon:SetPoint("TOPLEFT", 0, 0)
    detail.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    detail.name = CreateLabel(detail, "", "GameFontNormalLarge")
    detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, -2)
    detail.name:SetWidth(250)
    detail.name:SetWordWrap(false)
    detail.spellID = CreateLabel(detail, "", "GameFontDisableSmall")
    detail.spellID:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -3)
    local remove = CreateButton(detail, L.REMOVE, 96)
    remove:SetPoint("TOPRIGHT", 0, -6)
    remove:SetScript("OnClick", function()
        if not selected then return end
        ns.RemoveSpell(selected)
        if selected > #ns.db.spells then selected = #ns.db.spells > 0 and #ns.db.spells or nil end
        ns.RefreshConfig()
        ns.RefreshMovers()
    end)

    -- Size and position
    CreateLabel(detail, L.SIZE, "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -52)
    CreateSlider(detail, "size", 16, 96, 150):SetPoint("TOPLEFT", 0, -68)
    CreateLabel(detail, L.POSITION, "GameFontNormalSmall"):SetPoint("TOPLEFT", COLUMN_2, -52)
    local x = CreateNumberBox(detail, "x")
    x:SetPoint("TOPLEFT", COLUMN_2 + 6, -66)
    local y = CreateNumberBox(detail, "y")
    y:SetPoint("LEFT", x, "RIGHT", 10, 0)
    local center = CreateButton(detail, L.CENTER, 70)
    center:SetPoint("LEFT", y, "RIGHT", 8, 0)
    center:SetScript("OnClick", function() SetValue("x", 0) end)

    -- Appearance (left) and glow (right)
    CreateSection(detail, L.SEC_LOOK, 0, -104)
    local looks = { { "range", L.RANGE }, { "usable", L.USABLE }, { "swipe", L.SWIPE }, { "timer", L.TIMER }, { "dimCD", L.DIM_CD } }
    for i, look in ipairs(looks) do
        local check = CreateCheck(detail, look[1], look[2])
        check:SetPoint("TOPLEFT", -4, -120 - (i - 1) * 24)
        check.label:SetWidth(COLUMN_2 - 30)
    end

    CreateSection(detail, L.SEC_GLOW, COLUMN_2, -104)
    local glows = { { "glowProc", L.GLOW_PROC }, { "glowReady", L.GLOW_READY }, { "glowAuraOn", L.GLOW_AURA } }
    for i, glow in ipairs(glows) do
        local check = CreateCheck(detail, glow[1], glow[2])
        check:SetPoint("TOPLEFT", COLUMN_2 - 4, -120 - (i - 1) * 24)
        check.label:SetWidth(400 - COLUMN_2 - 26)
    end
    local aura = CreateEditBox(detail, 160)
    aura:SetPoint("TOPLEFT", COLUMN_2 + 26, -194)
    local function CommitAura(self)
        local entry = SelectedEntry()
        local text = strtrim(self:GetText() or "")
        if entry and text ~= entry.glowAura then
            entry.glowAuraOn = text ~= ""
            SetValue("glowAura", text)
        end
    end
    aura:SetScript("OnEnterPressed", function(self)
        CommitAura(self)
        self:ClearFocus()
    end)
    aura:SetScript("OnEditFocusLost", CommitAura)
    aura.hint = CreateLabel(aura, L.AURA_HINT, "GameFontDisableSmall")
    aura.hint:SetPoint("LEFT", 2, 0)
    aura.Refresh = function(self, entry)
        if not self:HasFocus() then self:SetText(entry.glowAura or "") end
        self.hint:SetShown(not self:HasFocus() and (entry.glowAura or "") == "")
    end
    aura:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
    controls.glowAura = aura

    -- Visibility
    CreateSection(detail, L.SEC_SHOW, 0, -250)
    CreateCycle(detail, "show", ns.SHOW_MODES, "SHOW_", 196):SetPoint("TOPLEFT", 0, -268)
    CreateCycle(detail, "when", ns.WHEN_MODES, "WHEN_", 186):SetPoint("TOPLEFT", COLUMN_2, -268)
    return detail
end

local function CreateConfigFrame()
    frame = CreateFrame("Frame", "KlarsichtConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(660, 486)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", function()
        ns.RefreshConfig()
        ns.RefreshMovers()
        ns.UpdateAll()
    end)
    frame:SetScript("OnHide", function()
        ns.RefreshMovers()
        ns.UpdateAll()
    end)
    tinsert(UISpecialFrames, "KlarsichtConfigFrame")

    local title = CreateLabel(frame, L.TITLE .. "  |cff999999" .. L.SUBTITLE .. "|r", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)

    -- Left column: add box, drop zone, spell list
    local add = CreateEditBox(frame, 140)
    add:SetPoint("TOPLEFT", 20, -36)
    add.hint = CreateLabel(add, L.ADD_HINT, "GameFontDisableSmall")
    add.hint:SetPoint("LEFT", 2, 0)
    add:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
    add:SetScript("OnEditFocusLost", function(self) self.hint:SetShown(self:GetText() == "") end)
    add:SetScript("OnReceiveDrag", TakeCursorSpell)
    local function Submit()
        local text = strtrim(add:GetText() or "")
        if text == "" then return end
        add:SetText("")
        add:ClearFocus()
        AddAndSelect(text)
    end
    add:SetScript("OnEnterPressed", Submit)
    local addButton = CreateButton(frame, "+", 44)
    addButton:SetPoint("LEFT", add, "RIGHT", 6, 0)
    addButton:SetScript("OnClick", Submit)

    local drop = CreateFrame("Button", nil, frame, "BackdropTemplate")
    drop:SetSize(196, 30)
    drop:SetPoint("TOPLEFT", 14, -62)
    drop:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    drop:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
    drop:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.6)
    local dropText = CreateLabel(drop, L.DROP_HINT, "GameFontDisableSmall")
    dropText:SetPoint("CENTER")
    dropText:SetWidth(186)
    dropText:SetJustifyH("CENTER")
    drop:SetScript("OnReceiveDrag", TakeCursorSpell)
    drop:SetScript("OnClick", TakeCursorSpell)

    local list = CreateList(frame)
    list:SetPoint("TOPLEFT", 14, -100)

    -- Right column: settings for the selected spell
    CreateDetail(frame):SetPoint("TOPLEFT", 236, -36)
    hintText = CreateLabel(frame, L.SELECT_HINT, "GameFontDisable")
    hintText:SetPoint("TOPLEFT", 236, -40)

    -- Grid row (shared by all icons)
    local gridShow = CreateGridCheck(frame, "show", L.GRID_SHOW)
    gridShow:SetPoint("BOTTOMLEFT", 10, 40)
    local gridSnap = CreateGridCheck(frame, "snap", L.GRID_SNAP)
    gridSnap:SetPoint("LEFT", gridShow.label, "RIGHT", 14, -1)
    local sizeLabel = CreateLabel(frame, L.GRID_SIZE)
    sizeLabel:SetPoint("LEFT", gridSnap.label, "RIGHT", 18, 0)
    local gridSize = CreateButton(frame, "", 64)
    gridSize:SetPoint("LEFT", sizeLabel, "RIGHT", 6, 0)
    gridSize:SetScript("OnClick", function()
        local sizes, index = ns.GRID_SIZES, 1
        for i, size in ipairs(sizes) do
            if size == ns.db.grid.size then index = i end
        end
        ns.db.grid.size = sizes[index % #sizes + 1]
        ns.UpdateGrid()
        ns.RefreshConfig()
    end)
    gridSize.Refresh = function(self) self:SetText(format(L.GRID_SIZE_VALUE, ns.db.grid.size)) end
    gridControls[#gridControls + 1] = gridSize
    local moveHint = CreateLabel(frame, L.MOVE_KEYS, "GameFontDisableSmall")
    moveHint:SetPoint("LEFT", gridSize, "RIGHT", 12, 0)
    frame.moveHint = moveHint

    -- Button row
    lockButton = CreateButton(frame, "", 150)
    lockButton:SetPoint("BOTTOMLEFT", 14, 12)
    lockButton:SetScript("OnClick", function() ns.SetLocked(not ns.db.locked) end)
    local preset = CreateButton(frame, L.PRESET, 170)
    preset:SetPoint("LEFT", lockButton, "RIGHT", 8, 0)
    preset:SetScript("OnClick", function()
        local index = ns.LoadPreset()
        if index then Select(index) end
    end)
    local export = CreateButton(frame, L.EXPORT, 136)
    export:SetPoint("LEFT", preset, "RIGHT", 8, 0)
    export:SetScript("OnClick", function() ns.OpenProfileDialog("export") end)
    local import = CreateButton(frame, L.IMPORT, 136)
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)
    import:SetScript("OnClick", function() ns.OpenProfileDialog("import") end)

    frame:Hide()
end

function ns.RefreshConfig()
    if not frame then return end
    local spells = ns.db.spells
    local count = #spells
    listOffset = max(0, min(listOffset, count - ROWS))
    for i, row in ipairs(rows) do
        local index = i + listOffset
        local entry = spells[index]
        if entry then
            local icon = ns.icons[index]
            row.index = index
            row.icon:SetTexture(icon and icon.iconTexture or QUESTION_MARK)
            row.text:SetText(icon and icon.spellName or entry.name or tostring(entry.id))
            row.selection:SetShown(index == selected)
            row:Show()
        else
            row:Hide()
        end
    end
    emptyText:SetShown(count == 0)

    lockButton:SetText(ns.db.locked and L.UNLOCK or L.LOCK)
    frame.moveHint:SetShown(not ns.db.locked)
    for _, control in ipairs(gridControls) do
        control:Refresh()
    end

    local entry = SelectedEntry()
    detail:SetShown(entry ~= nil)
    hintText:SetShown(entry == nil and count > 0)
    if not entry then return end
    local icon = ns.icons[selected]
    detail.icon:SetTexture(icon and icon.iconTexture or QUESTION_MARK)
    detail.name:SetText(icon and icon.spellName or entry.name or "?")
    detail.spellID:SetText("ID " .. tostring(icon and icon.spellID or entry.id))
    for _, control in pairs(controls) do
        control:Refresh(entry)
    end
end

function ns.OnEntryChanged(index)
    if index == selected then ns.RefreshConfig() end
end

function ns.OnLockChanged()
    ns.RefreshConfig()
end

function ns.OpenConfig(index)
    if not frame then CreateConfigFrame() end
    if index then selected = index end
    if not selected and #ns.db.spells > 0 then selected = 1 end
    frame:Show()
    ns.RefreshConfig()
    ns.RefreshMovers()
end

function ns.ToggleConfig()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        ns.OpenConfig()
    end
end

---------------------------------------------------------------------------
-- Profile export / import dialog
---------------------------------------------------------------------------

local function ImportFromDialog(replace)
    local added, skippedOrError = ns.ImportProfile(dialog.box:GetText(), replace)
    if not added then
        dialog.status:SetText(skippedOrError)
        return
    end
    ns.Print(format(L.IMPORT_DONE, added, skippedOrError))
    dialog:Hide()
    if replace or (selected and selected > #ns.db.spells) then selected = nil end
    ns.OpenConfig()
end

local function CreateProfileDialog()
    dialog = CreateFrame("Frame", "KlarsichtProfileDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(520, 168)
    dialog:SetPoint("CENTER", 0, 140)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    tinsert(UISpecialFrames, "KlarsichtProfileDialog")

    dialog.title = CreateLabel(dialog, "", "GameFontHighlight")
    dialog.title:SetPoint("TOP", 0, -5)
    dialog.help = CreateLabel(dialog, "")
    dialog.help:SetPoint("TOPLEFT", 16, -34)
    dialog.help:SetWidth(488)

    -- A single-line box holds the whole profile; Ctrl+A/C/V work as usual.
    dialog.box = CreateEditBox(dialog, 476)
    dialog.box:SetPoint("TOPLEFT", 22, -72)
    dialog.box:SetMaxLetters(0)
    dialog.box:SetScript("OnEscapePressed", function() dialog:Hide() end)
    dialog.box:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        if dialog.mode == "export" then
            -- Read-only: typing restores the profile text.
            self:SetText(dialog.exportText)
            self:HighlightText()
        else
            dialog.status:SetText("")
        end
    end)

    dialog.status = CreateLabel(dialog, "")
    dialog.status:SetPoint("TOPLEFT", 16, -98)
    dialog.status:SetWidth(488)
    dialog.status:SetTextColor(1, 0.35, 0.3)

    dialog.close = CreateButton(dialog, L.CLOSE, 100)
    dialog.close:SetPoint("BOTTOMRIGHT", -14, 12)
    dialog.close:SetScript("OnClick", function() dialog:Hide() end)
    dialog.replace = CreateButton(dialog, L.REPLACE, 100)
    dialog.replace:SetPoint("RIGHT", dialog.close, "LEFT", -8, 0)
    dialog.replace:SetScript("OnClick", function() ImportFromDialog(true) end)
    dialog.merge = CreateButton(dialog, L.MERGE, 100)
    dialog.merge:SetPoint("RIGHT", dialog.replace, "LEFT", -8, 0)
    dialog.merge:SetScript("OnClick", function() ImportFromDialog(false) end)
    dialog:Hide()
end

-- mode: "export" or "import"
function ns.OpenProfileDialog(mode)
    if not dialog then CreateProfileDialog() end
    local export = mode == "export"
    dialog.mode = mode
    dialog.exportText = export and ns.ExportProfile() or nil
    dialog.title:SetText(export and L.EXPORT or L.IMPORT)
    dialog.help:SetText(export and L.EXPORT_HELP or L.IMPORT_HELP)
    dialog.status:SetText("")
    dialog.replace:SetShown(not export)
    dialog.merge:SetShown(not export)
    dialog.close:SetText(export and L.CLOSE or L.CANCEL)
    dialog:Show()
    dialog.box:SetText(dialog.exportText or "")
    dialog.box:SetFocus()
    dialog.box:HighlightText()
end

---------------------------------------------------------------------------
-- Entry in the game's AddOns options list that opens the window
---------------------------------------------------------------------------

local panel = CreateFrame("Frame")
panel.name = L.TITLE
local panelTitle = CreateLabel(panel, L.TITLE, "GameFontNormalLarge")
panelTitle:SetPoint("TOPLEFT", 16, -16)
local panelText = CreateLabel(panel, L.PANEL_TEXT, "GameFontHighlight")
panelText:SetPoint("TOPLEFT", panelTitle, "BOTTOMLEFT", 0, -8)
local panelButton = CreateButton(panel, L.OPEN_SETTINGS, 240)
panelButton:SetPoint("TOPLEFT", panelText, "BOTTOMLEFT", 0, -12)
panelButton:SetScript("OnClick", function() ns.OpenConfig() end)

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end
