-- Grid, magnet and docking, resizing, undo, resets, number style, talent
-- procs, and profile export/import.
local M, ns = MOCK, NS
local L = ns.L

local function check(condition, message)
    if not condition then error("CHECK FAILED: " .. message, 2) end
    M.passed = M.passed + 1
end

local function spells() return KlarsichtCharDB.spells end
local function click(widget, ...) M.FireScript(widget, "OnClick", ...) end
local function buttonWithText(text)
    return M.Find("Button", function(w) return w.__text == text end)
end
local function snap(value, size) return math.floor(value / size + 0.5) * size end
local function gridOverlay()
    return M.Find("Frame", function(w) return rawget(w, "lines") ~= nil end)
end
local function shownLines(overlay)
    local count = 0
    for _, line in ipairs(overlay.lines) do
        if line:IsShown() then count = count + 1 end
    end
    return count
end
-- Presses the mouse on a widget at (0, 0), moves to each point in turn, releases.
local function drag(widget, ...)
    M.cursorX, M.cursorY = 0, 0
    M.FireScript(widget, "OnMouseDown", "LeftButton")
    local points = { ... }
    for _, point in ipairs(points) do
        M.cursorX, M.cursorY = point[1], point[2]
        M.Tick(0.02)
        if point.check then point.check() end
    end
    M.FireScript(widget, "OnMouseUp", "LeftButton")
end

M.SPELLS[5143] = { name = "Arkane Geschosse", icon = 136096, known = true, cost = 85, cast = 0 }
M.SPELLS[11366] = { name = "Pyroschlag", icon = 135808, known = true, cost = 125, cast = 6000 }

M.Fire("ADDON_LOADED", "Klarsicht")
M.Fire("PLAYER_LOGIN")
M.Tick(0.2)
SlashCmdList.KLARSICHT("")
click(buttonWithText(L.PRESET))
check(#spells() == 5, "five spells to arrange")
check(spells()[1].x == -84 and spells()[2].x == -42 and spells()[5].x == 84, "suggestions sit 2 px apart, centered")
local sliders = M.FindAll("Slider")
local sizeSlider, magnetSlider, gapSlider, scaleSlider = sliders[1], sliders[2], sliders[3], sliders[4]

-- Grid: only while unlocked; 1920x1080 at 8 px = 241 vertical + 135 horizontal lines
check(gridOverlay() == nil, "no grid while locked")
SlashCmdList.KLARSICHT("unlock")
local overlay = gridOverlay()
check(overlay and overlay:IsShown() and shownLines(overlay) == 376, "8 px grid by default")
local sizeButton = buttonWithText("8 px")
click(sizeButton)
check(KlarsichtCharDB.grid.size == 16 and shownLines(overlay) == 188, "grid size cycles to 16")
local showGrid = M.Find("CheckButton", function(w) return w.label.__text == L.GRID_SHOW end)
showGrid:SetChecked(false)
click(showGrid)
check(not overlay:IsShown(), "grid can be hidden")
showGrid:SetChecked(true)
click(showGrid)
check(overlay:IsShown(), "grid comes back")

-- Magnet: within 4 px of a 16 px line it snaps, farther away it moves freely
local first = spells()[1]
drag(ns.icons[1],
    { 40, 100, check = function()
        check(first.x == -48 and first.y == -80, "snaps within the magnet range, got " .. first.x .. "," .. first.y)
    end },
    { 47, 100, check = function()
        check(first.x == -37 and first.y == -80, "moves freely outside the magnet range, got " .. first.x)
        magnetSlider:SetValue(8)
    end },
    { 47, 100.5, check = function()
        check(first.x == -32, "a stronger magnet pulls it onto the line")
    end })
check(KlarsichtCharDB.grid.magnet == 8, "magnet setting stored")

-- Docking: close to a spot next to another icon it locks in, gap px apart
local last = spells()[5]
drag(ns.icons[1], { 126 - first.x + 3, -180 - first.y + 2 })
check(first.x == 126 and first.y == -180, "docks right next to the last icon, got " .. first.x .. "," .. first.y)
gapSlider:SetValue(10)
drag(ns.icons[1], { 2, -1 })
check(first.x == 134 and first.y == -180, "gap setting widens the docking spot, got " .. first.x)
M.shift = true
drag(ns.icons[1], { 2.4, -1 })
M.shift = false
check(first.x == 136 and first.y == -181, "Shift moves freely")

-- Alt drags the whole group, keeping the gaps
local before = {}
for i, e in ipairs(spells()) do before[i] = { e.x, e.y } end
M.alt = true
M.cursorX, M.cursorY = 0, 0
M.FireScript(ns.icons[3], "OnMouseDown", "LeftButton")
M.alt = false
M.cursorX, M.cursorY = 40, -21
M.Tick(0.02)
M.FireScript(ns.icons[3], "OnMouseUp", "LeftButton")
local grabbed = spells()[3]
check(grabbed.x == snap(before[3][1] + 40, 16) and grabbed.y == snap(before[3][2] - 21, 16), "grabbed icon snaps")
local dx, dy = grabbed.x - before[3][1], grabbed.y - before[3][2]
for i, e in ipairs(spells()) do
    check(e.x - before[i][1] == dx and e.y - before[i][2] == dy, "Alt moves icon " .. i .. " along")
end

-- Resize at the corner: top-left stays, size follows the mouse
local second, icon2 = spells()[2], ns.icons[2]
local left, top = second.x - 20, second.y + 20
check(icon2.Grip:IsShown(), "resize corner shows while unlocked")
local undoBefore = ns.UndoCount()
drag(icon2.Grip,
    { 10, -3, check = function()
        check(second.size == 50 and icon2.__w == 50, "corner drag resizes to 50")
        check(second.x == math.floor(left + 25 + 0.5) and second.y == math.floor(top - 25 + 0.5), "top-left corner stays")
        check(icon2.Label.__text == "50 px", "label shows the size")
    end },
    { 300, 0, check = function() check(second.size == 96, "size stops at 96") end })
check(icon2.Label.__text == icon2.spellName, "label back to the name")
check(ns.UndoCount() == math.min(3, undoBefore + 1), "one resize is one undo step")

-- Undo: the resize comes back, at most 3 steps, then a message
click(buttonWithText(L.UNDO_COUNT:format(ns.UndoCount())))
check(spells()[2].size == 40, "undo restores the size")
while ns.UndoCount() > 0 do ns.Undo() end
check(not ns.Undo() and M.lastMessage:find(L.UNDO_EMPTY, 1, true), "empty undo says so")
check(buttonWithText(L.UNDO), "undo button without a count")
ns.OpenConfig(1)
local size0 = spells()[1].size
sizeSlider:SetValue(size0 + 1)
sizeSlider:SetValue(size0 + 2)
sizeSlider:SetValue(size0 + 3)
check(ns.UndoCount() == 1, "one slider drag is one undo step")
ns.Undo()
check(spells()[1].size == size0, "undo restores the size before the drag")
for step = 1, 5 do
    M.Tick(2)
    ns.OpenConfig(step)
    sizeSlider:SetValue(30 + step)
end
check(ns.UndoCount() == 3, "undo keeps the last 3 steps")
SlashCmdList.KLARSICHT("lock")

-- Reset one spell: options back to default, place stays
ns.OpenConfig(4)
local fourth = spells()[4]
fourth.size, fourth.range, fourth.show, fourth.x, fourth.y = 70, false, "combat", 300, 200
click(buttonWithText(L.RESET_SPELL))
check(fourth.size == 40 and fourth.range == true and fourth.show == "always", "reset restores the defaults")
check(fourth.x == 300 and fourth.y == 200 and fourth.id == 2136, "reset keeps place and spell")

-- Reset all positions on the General tab
click(buttonWithText(L.TAB_GENERAL))
click(buttonWithText(L.RESET_POSITIONS))
local gap = KlarsichtCharDB.grid.gap
for i = 2, #spells() do
    local a, b = spells()[i - 1], spells()[i]
    -- Centers are whole numbers, so odd sizes can be off by one pixel.
    check(math.abs((b.x - a.x) - (a.size / 2 + gap + b.size / 2)) <= 1, "row spacing " .. i)
    check(b.y == ns.ROW_Y, "row height " .. i)
end
check(math.abs(spells()[1].x + spells()[#spells()].x) <= 1 + math.abs(spells()[1].size - spells()[#spells()].size), "row is centered")

-- Gray while on cooldown
local nova, novaEntry = ns.icons[2], spells()[2]
novaEntry.grayCD = true
M.cooldowns[122] = { M.time, 25 }
M.Fire("SPELL_UPDATE_COOLDOWN")
M.Tick(0.2)
check(nova.Texture.__desaturated == true, "gray while on cooldown")

-- Number style (General tab): color, outline, size
local swatches = M.FindAll("Button")
local colorButtons = {}
for _, w in ipairs(swatches) do
    if w.__backdrop and w.__w == 18 then colorButtons[#colorButtons + 1] = w end
end
check(#colorButtons == 8, "eight color swatches")
click(colorButtons[4])
check(KlarsichtCharDB.style.color == "red", "color stored")
M.Tick(0.2)
local red = ns.TIMER_COLORS.red
check(nova.Timer.__textColor[1] == red[1] and nova.Timer.__textColor[2] == red[2], "timer uses the chosen color")
click(buttonWithText(L.OUTLINE_thin))
check(KlarsichtCharDB.style.outline == "thick" and nova.Timer.__font[3] == "THICKOUTLINE", "thick outline")
scaleSlider:SetValue(150)
check(KlarsichtCharDB.style.scale == 150 and nova.Timer.__font[2] == math.floor(nova.entry.size * 0.36 * 1.5 + 0.5),
    "number size follows the slider")
M.cooldowns[122] = nil
M.Tick(30)
check(nova.Texture.__desaturated == false, "color comes back when ready")

-- Talent procs without a Blizzard alert: spell turns free or instant
local missiles = spells()[ns.AddSpell(5143)]
local pyro = spells()[ns.AddSpell(11366)]
local missilesIcon, pyroIcon = ns.icons[#spells() - 1], ns.icons[#spells()]
M.Tick(0.2)
check(not missilesIcon.Glow:IsShown() and not pyroIcon.Glow:IsShown(), "no glow without proc")
M.cost[5143] = 0
M.castTime[11366] = 0
M.Tick(0.2)
check(missilesIcon.Glow:IsShown(), "glows while the spell is free (Missile Barrage, Clearcasting)")
check(pyroIcon.Glow:IsShown(), "glows while the spell is instant (Hot Streak)")
pyro.glowProc = false
M.Tick(0.2)
check(not pyroIcon.Glow:IsShown(), "proc glow can be switched off")
M.cost[5143], M.castTime[11366] = nil, nil
M.Tick(0.2)
check(not missilesIcon.Glow:IsShown(), "glow ends with the proc")
ns.RemoveSpell(#spells())
ns.RemoveSpell(#spells())

-- Export and import back
spells()[2].glowAuraOn = true
spells()[2].glowAura = "Freizaubern | 50% ,;:="
spells()[3].show = "combat"
local text = ns.ExportProfile()
check(text:match("^KS1:") and not text:find("[%s|]"), "export is one line without | or spaces: " .. text)
local keys = { "id" }
for key in pairs(ns.DEFAULTS) do keys[#keys + 1] = key end
local snapshot = {}
for i, e in ipairs(spells()) do
    snapshot[i] = {}
    for _, key in ipairs(keys) do snapshot[i][key] = e[key] end
end
spells()[1].size = 77
table.remove(spells(), 4)
local added, skipped = ns.ImportProfile(text, true)
check(added == 5 and skipped == 0, "replace imports all five, got " .. tostring(added) .. "/" .. tostring(skipped))
for i, e in ipairs(spells()) do
    for _, key in ipairs(keys) do
        check(e[key] == snapshot[i][key], ("spell %d %s survives the round trip"):format(i, key))
    end
end
check(spells()[1].name == M.SPELLS[spells()[1].id].name, "name comes from the importing client")
ns.Undo()
check(#spells() == 4 and spells()[1].size == 77, "an import can be undone")
ns.ImportProfile(text, true)

added, skipped = ns.ImportProfile(text, false)
check(added == 0 and skipped == 5, "adding the same profile adds nothing")
added = ns.ImportProfile(text:sub(1, 20) .. "\n   " .. text:sub(21), true)
check(added == 5, "line breaks and spaces from chat programs are ignored")

local result, err = ns.ImportProfile((text:gsub(",x=", ",x=1", 1)), true)
check(result == nil and err == L.IMPORT_DAMAGED, "changed text is rejected")
result, err = ns.ImportProfile("hallo", true)
check(result == nil and err == L.IMPORT_INVALID and #spells() == 5, "non-profile text is rejected, list untouched")
result, err = ns.ImportProfile("KS9:id=1:0000", true)
check(result == nil and err == L.IMPORT_NEWER, "newer format is rejected")

spells()[1].size, spells()[1].x, spells()[1].show = 9999, 1e9, "evil"
ns.ImportProfile(ns.ExportProfile(), true)
check(spells()[1].size == 96 and spells()[1].x == 4000 and spells()[1].show == "always", "values are clamped")

spells()[2].id = 999999
added, skipped = ns.ImportProfile(ns.ExportProfile(), true)
check(added == 4 and skipped == 1, "spells unknown to this client are skipped")

-- The dialog
SlashCmdList.KLARSICHT("export")
local dialog = KlarsichtProfileDialog
check(dialog:IsShown() and dialog.box:GetText() == ns.ExportProfile(), "export dialog shows the profile")
check(not dialog.replace:IsShown() and dialog.close.__text == L.CLOSE, "export dialog only closes")
dialog.box:SetText("kaputt")
M.FireScript(dialog.box, "OnTextChanged", true)
check(dialog.box:GetText() == dialog.exportText, "export box is read-only")
local good = dialog.exportText

SlashCmdList.KLARSICHT("import")
check(dialog.box:GetText() == "" and dialog.replace:IsShown() and dialog.merge:IsShown(), "import dialog is empty")
dialog.box:SetText("quatsch")
click(dialog.replace)
check(dialog:IsShown() and dialog.status.__text == L.IMPORT_INVALID, "bad text shows an error")
dialog.box:SetText(good)
M.FireScript(dialog.box, "OnTextChanged", true)
check(dialog.status.__text == "", "editing clears the error")
click(dialog.replace)
check(not dialog:IsShown() and #spells() == 4, "import closes the dialog")
check(KlarsichtConfigFrame:IsShown() and ns.GetSelected() == 1, "settings open on the first spell")
check(M.lastMessage:find(L.IMPORT_DONE:format(4, 0), 1, true), "chat reports the import")

print(("%s %s/%s: %d checks passed"):format(M.scenario, M.forever and "forever" or "classic", M.locale, M.passed))
