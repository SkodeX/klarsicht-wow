local ADDON, ns = ...
local C, L = ns.C, ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local QUESTION_MARK = 134400
local ROWS, ROW_HEIGHT = 12, 22
local COLUMN_2 = 210
local PANEL_X, PANEL_Y = 236, -66   -- where the right-hand panels start

local frame, detail, general, emptyText, hintText, lockButton, undoButton, dialog
local tabs = {}
local rows = {}
local controls = {}          -- per-entry controls, refreshed with the selected entry
local generalControls = {}   -- grid and number style controls (shared by all icons)
local selected
local activeTab = "spells"
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

-- Changes options of the selected spell; one undo step per option and burst.
local function SetValues(values, tag)
    local entry = SelectedEntry()
    if not entry then return end
    local changed = false
    for key, value in pairs(values) do
        if entry[key] ~= value then changed = true end
    end
    if not changed then return end
    ns.PushUndo("set:" .. selected .. ":" .. tag)
    for key, value in pairs(values) do entry[key] = value end
    ns.ApplyEntry(selected)
    ns.RefreshConfig()
end

local function SetValue(key, value)
    SetValues({ [key] = value }, key)
end

local function CreateCheckBox(parent, text, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.label = CreateLabel(check, text)
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    check:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return check
end

local function CreateCheck(parent, key, text)
    local check = CreateCheckBox(parent, text, function(checked) SetValue(key, checked) end)
    check.Refresh = function(self, entry) self:SetChecked(entry[key]) end
    controls[#controls + 1] = check
    return check
end

local function CreateGridCheck(parent, key, text)
    local check = CreateCheckBox(parent, text, function(checked)
        ns.db.grid[key] = checked
        ns.UpdateGrid()
    end)
    check.Refresh = function(self) self:SetChecked(ns.db.grid[key]) end
    generalControls[#generalControls + 1] = check
    return check
end

-- A button that steps through a list of values on click.
local function CreateCycleButton(parent, width, getValue, setValue, values, labelFor)
    local button = CreateButton(parent, "", width)
    button:SetScript("OnClick", function()
        local index = 1
        for i, value in ipairs(values) do
            if value == getValue() then index = i end
        end
        setValue(values[index % #values + 1])
    end)
    button.Refresh = function(self) self:SetText(labelFor(getValue())) end
    return button
end

local function CreateCycle(parent, key, modes, prefix, width)
    local button = CreateCycleButton(parent, width,
        function() return SelectedEntry()[key] end,
        function(value) SetValue(key, value) end,
        modes, function(value) return L[prefix .. value] end)
    controls[#controls + 1] = button
    return button
end

local function CreateSlider(parent, minValue, maxValue, step, width, valueFormat, onChange)
    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width, 16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
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
        self:SetValue(self:GetValue() + delta * step)
    end)
    slider:SetScript("OnValueChanged", function(self, value)
        value = floor(value / step + 0.5) * step
        self.value:SetText(format(valueFormat, value))
        if not self.refreshing then onChange(value) end
    end)
    slider.SetValueQuietly = function(self, value)
        self.refreshing = true
        self:SetValue(value)
        self.value:SetText(format(valueFormat, value))
        self.refreshing = nil
    end
    return slider
end

-- Applies while typing; Enter or leaving the box just tidies the text.
local function CreateNumberBox(parent, key)
    local box = CreateEditBox(parent, 46)
    box:SetScript("OnTextChanged", function(self, userInput)
        local value = userInput and tonumber(self:GetText())
        if value then SetValue(key, floor(value + 0.5)) end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function() ns.RefreshConfig() end)
    box.Refresh = function(self, entry)
        if not self:HasFocus() then self:SetText(tostring(entry[key])) end
    end
    controls[#controls + 1] = box
    return box
end

local function CreateSection(parent, text, x, y)
    local label = CreateLabel(parent, text, "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    return label
end

---------------------------------------------------------------------------
-- Selection and tabs
---------------------------------------------------------------------------

local function ShowTab(name)
    activeTab = name
    ns.RefreshConfig()
end

local function Select(index)
    selected = index
    activeTab = "spells"
    ns.RefreshConfig()
    ns.RefreshMovers()
end

local function AddAndSelect(input)
    local index = type(input) == "number" and ns.AddSpell(input) or ns.AddFromText(input)
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
-- Window parts
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

-- Right panel, tab "Spells": options of the selected spell.
local function CreateDetail(parent)
    detail = CreateFrame("Frame", nil, parent)
    detail:SetSize(400, 380)

    -- Header: icon, name, spell ID, reset and remove
    detail.icon = detail:CreateTexture(nil, "ARTWORK")
    detail.icon:SetSize(36, 36)
    detail.icon:SetPoint("TOPLEFT", 0, 0)
    detail.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    detail.name = CreateLabel(detail, "", "GameFontNormalLarge")
    detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, -2)
    detail.name:SetWidth(150)
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
    local reset = CreateButton(detail, L.RESET_SPELL, 96)
    reset:SetPoint("RIGHT", remove, "LEFT", -6, 0)
    reset:SetScript("OnClick", function()
        if selected then ns.ResetSpell(selected) end
    end)

    -- Size and position
    CreateLabel(detail, L.SIZE, "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -52)
    local size = CreateSlider(detail, ns.MIN_SIZE, ns.MAX_SIZE, 1, 150, "%d", function(value) SetValue("size", value) end)
    size:SetPoint("TOPLEFT", 0, -68)
    size.Refresh = function(self, entry) self:SetValueQuietly(entry.size) end
    controls[#controls + 1] = size
    CreateLabel(detail, L.POSITION, "GameFontNormalSmall"):SetPoint("TOPLEFT", COLUMN_2, -52)
    local x = CreateNumberBox(detail, "x")
    x:SetPoint("TOPLEFT", COLUMN_2 + 6, -66)
    local y = CreateNumberBox(detail, "y")
    y:SetPoint("LEFT", x, "RIGHT", 10, 0)
    local center = CreateButton(detail, L.CENTER, 70)
    center:SetPoint("LEFT", y, "RIGHT", 8, 0)
    center:SetScript("OnClick", function() SetValue("x", 0) end)

    -- What to track: a spell's cooldown or a buff/debuff
    CreateLabel(detail, L.TRACK_LABEL, "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -108)
    local track = CreateCycleButton(detail, 140,
        function() return SelectedEntry().track end,
        function(value)
            -- Own debuffs on a target matter; buffs on you may come from others.
            SetValues({ track = value, mine = value == "targetDebuff" or value == "targetBuff" }, "track")
        end,
        ns.TRACK_MODES, function(value) return L["TRACK_" .. value] end)
    track:SetPoint("TOPLEFT", 66, -103)
    controls[#controls + 1] = track
    detail.mine = CreateCheck(detail, "mine", L.MINE)
    detail.mine:SetPoint("TOPLEFT", COLUMN_2 + 6, -102)

    -- Options for spells
    local spellOptions = CreateFrame("Frame", nil, detail)
    spellOptions:SetSize(400, 220)
    spellOptions:SetPoint("TOPLEFT", 0, -136)
    detail.spellOptions = spellOptions
    CreateSection(spellOptions, L.SEC_LOOK, 0, 0)
    local looks = {
        { "range", L.RANGE }, { "usable", L.USABLE }, { "swipe", L.SWIPE },
        { "timer", L.TIMER }, { "dimCD", L.DIM_CD }, { "grayCD", L.GRAY_CD },
    }
    for i, look in ipairs(looks) do
        local check = CreateCheck(spellOptions, look[1], look[2])
        check:SetPoint("TOPLEFT", -4, -16 - (i - 1) * 24)
        check.label:SetWidth(COLUMN_2 - 30)
    end

    CreateSection(spellOptions, L.SEC_GLOW, COLUMN_2, 0)
    local glows = { { "glowProc", L.GLOW_PROC }, { "glowReady", L.GLOW_READY }, { "glowAuraOn", L.GLOW_AURA } }
    for i, glow in ipairs(glows) do
        local check = CreateCheck(spellOptions, glow[1], glow[2])
        check:SetPoint("TOPLEFT", COLUMN_2 - 4, -16 - (i - 1) * 24)
        check.label:SetWidth(400 - COLUMN_2 - 26)
    end
    local aura = CreateEditBox(spellOptions, 160)
    aura:SetPoint("TOPLEFT", COLUMN_2 + 26, -90)
    aura:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local text = strtrim(self:GetText() or "")
        SetValues({ glowAura = text, glowAuraOn = text ~= "" }, "glowAura")
    end)
    aura:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    aura:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
    aura:SetScript("OnEditFocusLost", function() ns.RefreshConfig() end)
    aura.hint = CreateLabel(aura, L.AURA_HINT, "GameFontDisableSmall")
    aura.hint:SetPoint("LEFT", 2, 0)
    aura.Refresh = function(self, entry)
        if not self:HasFocus() then self:SetText(entry.glowAura or "") end
        self.hint:SetShown(not self:HasFocus() and (entry.glowAura or "") == "")
    end
    controls[#controls + 1] = aura

    CreateSection(spellOptions, L.SEC_SHOW, 0, -172)
    CreateCycle(spellOptions, "show", ns.SHOW_MODES, "SHOW_", 196):SetPoint("TOPLEFT", 0, -190)
    CreateCycle(spellOptions, "when", ns.WHEN_MODES, "WHEN_", 186):SetPoint("TOPLEFT", COLUMN_2, -190)

    -- Options for buffs/debuffs
    local auraOptions = CreateFrame("Frame", nil, detail)
    auraOptions:SetSize(400, 220)
    auraOptions:SetPoint("TOPLEFT", 0, -136)
    detail.auraOptions = auraOptions
    CreateSection(auraOptions, L.SEC_LOOK, 0, 0)
    CreateCheck(auraOptions, "swipe", L.AURA_SWIPE):SetPoint("TOPLEFT", -4, -16)
    CreateCheck(auraOptions, "timer", L.AURA_TIMER):SetPoint("TOPLEFT", -4, -40)
    CreateSection(auraOptions, L.SEC_GLOW, COLUMN_2, 0)
    CreateCheck(auraOptions, "glowMissing", L.GLOW_MISSING):SetPoint("TOPLEFT", COLUMN_2 - 4, -16)
    CreateCheck(auraOptions, "glowExpiring", L.GLOW_EXPIRING):SetPoint("TOPLEFT", COLUMN_2 - 4, -40)
    CreateSection(auraOptions, L.SEC_SHOW, 0, -172)
    CreateCycle(auraOptions, "show", ns.SHOW_MODES, "SHOW_", 196):SetPoint("TOPLEFT", 0, -190)
    CreateCycle(auraOptions, "auraShow", ns.AURA_SHOW_MODES, "AURASHOW_", 186):SetPoint("TOPLEFT", COLUMN_2, -190)

    -- Live state below everything
    detail.state = CreateLabel(detail, "")
    detail.state:SetPoint("TOPLEFT", 2, -358)
    detail.state:SetWidth(396)
    return detail
end

local function CreateSwatch(parent, colorKey)
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(18, 18)
    swatch:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
    local color = ns.TIMER_COLORS[colorKey]
    swatch:SetBackdropColor(color[1], color[2], color[3], 1)
    swatch:SetScript("OnClick", function()
        ns.db.style.color = colorKey
        ns.ApplyStyle()
        ns.RefreshConfig()
    end)
    swatch.Refresh = function(self)
        local chosen = ns.db.style.color == colorKey
        self:SetBackdropBorderColor(chosen and 1 or 0, chosen and 1 or 0, chosen and 1 or 0, 1)
    end
    generalControls[#generalControls + 1] = swatch
    return swatch
end

-- Right panel, tab "General": grid, snapping, number style, reset.
local function CreateGeneral(parent)
    general = CreateFrame("Frame", nil, parent)
    general:SetSize(400, 350)
    local grid, style = function() return ns.db.grid end, function() return ns.db.style end

    CreateSection(general, L.SEC_MOVE, 0, 0)
    CreateGridCheck(general, "show", L.GRID_SHOW):SetPoint("TOPLEFT", -4, -18)
    CreateLabel(general, L.GRID_SIZE):SetPoint("TOPLEFT", COLUMN_2, -24)
    local gridSize = CreateCycleButton(general, 70,
        function() return grid().size end,
        function(value)
            grid().size = value
            ns.UpdateGrid()
            ns.RefreshConfig()
        end,
        ns.GRID_SIZES, function(value) return format(L.GRID_SIZE_VALUE, value) end)
    gridSize:SetPoint("TOPLEFT", COLUMN_2 + 50, -19)
    generalControls[#generalControls + 1] = gridSize
    CreateGridCheck(general, "snap", L.GRID_SNAP):SetPoint("TOPLEFT", -4, -44)
    CreateGridCheck(general, "dock", L.GRID_DOCK):SetPoint("TOPLEFT", COLUMN_2 - 4, -44)

    CreateLabel(general, L.GRID_MAGNET, "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -78)
    local magnet = CreateSlider(general, 1, 16, 1, 150, L.PX_VALUE, function(value) grid().magnet = value end)
    magnet:SetPoint("TOPLEFT", 0, -94)
    magnet.Refresh = function(self) self:SetValueQuietly(grid().magnet) end
    generalControls[#generalControls + 1] = magnet
    CreateLabel(general, L.GRID_GAP, "GameFontNormalSmall"):SetPoint("TOPLEFT", COLUMN_2, -78)
    local gap = CreateSlider(general, 0, 20, 1, 130, L.PX_VALUE, function(value) grid().gap = value end)
    gap:SetPoint("TOPLEFT", COLUMN_2, -94)
    gap.Refresh = function(self) self:SetValueQuietly(grid().gap) end
    generalControls[#generalControls + 1] = gap
    CreateLabel(general, L.MOVE_KEYS, "GameFontDisableSmall"):SetPoint("TOPLEFT", 0, -120)

    CreateSection(general, L.SEC_NUMBER, 0, -150)
    CreateLabel(general, L.NUMBER_COLOR):SetPoint("TOPLEFT", 0, -176)
    for i, colorKey in ipairs(ns.TIMER_COLOR_ORDER) do
        CreateSwatch(general, colorKey):SetPoint("TOPLEFT", 50 + (i - 1) * 22, -172)
    end
    CreateLabel(general, L.NUMBER_OUTLINE):SetPoint("TOPLEFT", 0, -208)
    local outline = CreateCycleButton(general, 120,
        function() return style().outline end,
        function(value)
            style().outline = value
            ns.ApplyStyle()
            ns.RefreshConfig()
        end,
        ns.OUTLINE_ORDER, function(value) return L["OUTLINE_" .. value] end)
    outline:SetPoint("TOPLEFT", 50, -203)
    generalControls[#generalControls + 1] = outline
    CreateLabel(general, L.NUMBER_SIZE, "GameFontNormalSmall"):SetPoint("TOPLEFT", COLUMN_2, -192)
    local scale = CreateSlider(general, 50, 200, 10, 130, L.PERCENT_VALUE, function(value)
        style().scale = value
        ns.ApplyStyle()
    end)
    scale:SetPoint("TOPLEFT", COLUMN_2, -208)
    scale.Refresh = function(self) self:SetValueQuietly(style().scale) end
    generalControls[#generalControls + 1] = scale

    CreateSection(general, L.SEC_RESET, 0, -246)
    local resetAll = CreateButton(general, L.RESET_POSITIONS, 220)
    resetAll:SetPoint("TOPLEFT", 0, -264)
    resetAll:SetScript("OnClick", function() ns.ResetPositions() end)
    local resetHint = CreateLabel(general, L.RESET_POSITIONS_HINT, "GameFontDisableSmall")
    resetHint:SetPoint("TOPLEFT", 2, -292)
    resetHint:SetWidth(396)
    return general
end

local function CreateConfigFrame()
    frame = CreateFrame("Frame", "KlarsichtConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(660, 500)
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
    drop:SetSize(114, 30)
    drop:SetPoint("TOPLEFT", 14, -62)
    drop:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    drop:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
    drop:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.6)
    local dropText = CreateLabel(drop, L.DROP_HINT, "GameFontDisableSmall")
    dropText:SetPoint("CENTER")
    dropText:SetWidth(106)
    dropText:SetJustifyH("CENTER")
    drop:SetScript("OnReceiveDrag", TakeCursorSpell)
    drop:SetScript("OnClick", TakeCursorSpell)
    local pickAura = CreateButton(frame, L.PICK_AURA, 78)
    pickAura:SetHeight(30)
    pickAura:SetPoint("LEFT", drop, "RIGHT", 4, 0)
    pickAura:SetScript("OnClick", function() ns.OpenAuraPicker() end)

    local list = CreateList(frame)
    list:SetPoint("TOPLEFT", 14, -100)

    -- Right column: tabs, then the spell options or the general options
    tabs.spells = CreateButton(frame, L.TAB_SPELLS, 110)
    tabs.spells:SetPoint("TOPLEFT", PANEL_X, -34)
    tabs.spells:SetScript("OnClick", function() ShowTab("spells") end)
    tabs.general = CreateButton(frame, L.TAB_GENERAL, 110)
    tabs.general:SetPoint("LEFT", tabs.spells, "RIGHT", 6, 0)
    tabs.general:SetScript("OnClick", function() ShowTab("general") end)
    CreateDetail(frame):SetPoint("TOPLEFT", PANEL_X, PANEL_Y)
    CreateGeneral(frame):SetPoint("TOPLEFT", PANEL_X, PANEL_Y)
    hintText = CreateLabel(frame, L.SELECT_HINT, "GameFontDisable")
    hintText:SetPoint("TOPLEFT", PANEL_X, PANEL_Y - 4)

    -- Button row
    lockButton = CreateButton(frame, "", 136)
    lockButton:SetPoint("BOTTOMLEFT", 14, 12)
    lockButton:SetScript("OnClick", function() ns.SetLocked(not ns.db.locked) end)
    undoButton = CreateButton(frame, L.UNDO, 110)
    undoButton:SetPoint("LEFT", lockButton, "RIGHT", 8, 0)
    undoButton:SetScript("OnClick", function() ns.Undo() end)
    local preset = CreateButton(frame, L.PRESET, 136)
    preset:SetPoint("LEFT", undoButton, "RIGHT", 8, 0)
    preset:SetScript("OnClick", function()
        local index = ns.LoadPreset()
        if index then Select(index) end
    end)
    local export = CreateButton(frame, L.EXPORT_SHORT, 104)
    export:SetPoint("LEFT", preset, "RIGHT", 8, 0)
    export:SetScript("OnClick", function() ns.OpenProfileDialog("export") end)
    local import = CreateButton(frame, L.IMPORT_SHORT, 104)
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)
    import:SetScript("OnClick", function() ns.OpenProfileDialog("import") end)

    frame:Hide()
end

---------------------------------------------------------------------------
-- Refresh: everything in the window follows the current data
---------------------------------------------------------------------------

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
    local undoCount = ns.UndoCount()
    undoButton:SetText(undoCount > 0 and format(L.UNDO_COUNT, undoCount) or L.UNDO)

    for name, tab in pairs(tabs) do
        if name == activeTab then tab:LockHighlight() else tab:UnlockHighlight() end
    end
    general:SetShown(activeTab == "general")
    for _, control in ipairs(generalControls) do
        control:Refresh()
    end

    local entry = SelectedEntry()
    detail:SetShown(activeTab == "spells" and entry ~= nil)
    hintText:SetShown(activeTab == "spells" and entry == nil and count > 0)
    if not entry then return end
    local icon = ns.icons[selected]
    local isSpell = entry.track == "spell"
    detail.spellOptions:SetShown(isSpell)
    detail.auraOptions:SetShown(not isSpell)
    detail.mine:SetShown(not isSpell)
    detail.icon:SetTexture(icon and icon.iconTexture or QUESTION_MARK)
    detail.name:SetText(icon and icon.spellName or entry.name or "?")
    local spellID = icon and icon.spellID or entry.id
    detail.spellID:SetText(spellID and ("ID " .. spellID) or "")
    for _, control in pairs(controls) do
        control:Refresh(entry)
    end
    ns.OnStateTick()
end

-- Called after every icon update: the live "visible / hidden because" line.
function ns.OnStateTick()
    if not (frame and frame:IsShown() and detail:IsShown()) then return end
    local icon = selected and ns.icons[selected]
    if not icon then return end
    local reason = icon.hiddenReason
    if reason then
        detail.state:SetText(format(L.HIDDEN_NOW, L["REASON_" .. reason]))
        detail.state:SetTextColor(0.65, 0.65, 0.65)
    else
        detail.state:SetText(L.VISIBLE_NOW)
        detail.state:SetTextColor(0.4, 1, 0.4)
    end
end

function ns.OnEntryChanged(index)
    if index == selected then ns.RefreshConfig() end
end

function ns.OnLockChanged()
    ns.RefreshConfig()
end

function ns.OnUndoChanged()
    if selected and selected > #ns.db.spells then
        selected = #ns.db.spells > 0 and #ns.db.spells or nil
    end
    ns.RefreshConfig()
    if ns.ready then ns.RefreshMovers() end
end

function ns.OpenConfig(index)
    if not frame then CreateConfigFrame() end
    if index then
        selected = index
        activeTab = "spells"
    end
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
-- Aura picker: the buffs and debuffs on you and your target, one click to track
---------------------------------------------------------------------------

local PICKER_ROWS = 14
local PICKER_SOURCES = {
    { track = "playerBuff", unit = "player", filter = "HELPFUL" },
    { track = "playerDebuff", unit = "player", filter = "HARMFUL" },
    { track = "targetDebuff", unit = "target", filter = "HARMFUL" },
    { track = "targetBuff", unit = "target", filter = "HELPFUL" },
}
local picker

-- Second value: true when the client hid some auras (Forever combat)
local function CollectAuras()
    local found, seen, hidden = {}, {}, false
    for _, source in ipairs(PICKER_SOURCES) do
        local auras, partial = C.GetAuras(source.unit, source.filter)
        hidden = hidden or partial
        for _, aura in ipairs(auras) do
            local key = source.track .. ":" .. aura.name
            if not seen[key] then
                seen[key] = true
                found[#found + 1] = { name = aura.name, icon = aura.icon, spellID = aura.spellId, track = source.track }
            end
        end
    end
    return found, hidden
end

local function RefreshPicker()
    local auras, hidden = CollectAuras()
    picker.offset = max(0, min(picker.offset, #auras - PICKER_ROWS))
    for i, row in ipairs(picker.rows) do
        local aura = auras[i + picker.offset]
        if aura then
            row.aura = aura
            row.icon:SetTexture(aura.icon or QUESTION_MARK)
            row.text:SetText(aura.name)
            row.kind:SetText(L["TRACK_" .. aura.track])
            row:Show()
        else
            row:Hide()
        end
    end
    picker.empty:SetText(hidden and L.PICKER_BLOCKED or L.PICKER_EMPTY)
    picker.empty:SetShown(#auras == 0)
end

local function CreateAuraPicker()
    picker = CreateFrame("Frame", "KlarsichtAuraPicker", UIParent, "BasicFrameTemplateWithInset")
    picker:SetSize(300, 72 + PICKER_ROWS * ROW_HEIGHT)
    picker:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
    picker:SetFrameStrata("DIALOG")
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:EnableMouseWheel(true)
    picker.offset = 0
    picker:SetScript("OnMouseWheel", function(_, delta)
        picker.offset = picker.offset - delta
        RefreshPicker()
    end)
    tinsert(UISpecialFrames, "KlarsichtAuraPicker")

    CreateLabel(picker, L.PICKER_TITLE, "GameFontHighlight"):SetPoint("TOP", 0, -5)
    local help = CreateLabel(picker, L.PICKER_HELP)
    help:SetPoint("TOPLEFT", 12, -30)
    help:SetWidth(276)
    picker.rows = {}
    for i = 1, PICKER_ROWS do
        local row = CreateFrame("Button", nil, picker)
        row:SetSize(276, ROW_HEIGHT - 2)
        row:SetPoint("TOPLEFT", 12, -62 - (i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture(WHITE)
        row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 2, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.text = CreateLabel(row, "")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetWidth(150)
        row.text:SetWordWrap(false)
        row.kind = CreateLabel(row, "", "GameFontDisableSmall")
        row.kind:SetPoint("RIGHT", -4, 0)
        row.kind:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function(self)
            local aura = self.aura
            local index = ns.AddAura(aura.name, aura.track, aura.spellID, aura.icon)
            if index then
                listOffset = max(0, index - ROWS)
                Select(index)
            end
        end)
        picker.rows[i] = row
    end
    picker.empty = CreateLabel(picker, "")
    picker.empty:SetPoint("TOPLEFT", 14, -66)
    picker.empty:SetWidth(272)

    -- Live while open: buffs come and go.
    local sinceRefresh = 0
    picker:SetScript("OnUpdate", function(_, elapsed)
        sinceRefresh = sinceRefresh + elapsed
        if sinceRefresh < 0.5 then return end
        sinceRefresh = 0
        RefreshPicker()
    end)
    picker:SetScript("OnShow", RefreshPicker)
    picker:Hide()
end

function ns.OpenAuraPicker()
    if not picker then CreateAuraPicker() end
    if picker:IsShown() then
        picker:Hide()
    else
        picker:Show()
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
