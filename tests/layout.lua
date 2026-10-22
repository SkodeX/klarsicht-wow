-- Grid, drag and drop with snapping, and profile export/import.
local M, ns = MOCK, NS
local L = ns.L

local function check(condition, message)
    if not condition then error("CHECK FAILED: " .. message, 2) end
    M.passed = M.passed + 1
end

local function spells() return KlarsichtCharDB.spells end
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

M.Fire("ADDON_LOADED", "Klarsicht")
M.Fire("PLAYER_LOGIN")
M.Tick(0.2)
SlashCmdList.KLARSICHT("")
M.FireScript(buttonWithText(L.PRESET), "OnClick")
check(#spells() == 5, "five spells to arrange")

-- Grid: only while unlocked; 1920x1080 at 16 px = 121 vertical + 67 horizontal lines
check(gridOverlay() == nil, "no grid while locked")
SlashCmdList.KLARSICHT("unlock")
local overlay = gridOverlay()
check(overlay and overlay:IsShown(), "grid appears when unlocked")
check(shownLines(overlay) == 188, "16 px grid lines, got " .. shownLines(overlay))
local sizeButton = buttonWithText("16 px")
M.FireScript(sizeButton, "OnClick")
check(KlarsichtCharDB.grid.size == 32 and sizeButton.__text == "32 px", "grid size cycles to 32")
check(shownLines(overlay) == 94, "32 px grid lines, got " .. shownLines(overlay))
for _ = 1, 3 do M.FireScript(sizeButton, "OnClick") end
check(KlarsichtCharDB.grid.size == 16, "grid size cycles back to 16")

local checks = M.FindAll("CheckButton")
local showGrid = checks[9]
showGrid:SetChecked(false)
M.FireScript(showGrid, "OnClick")
check(not overlay:IsShown(), "grid can be hidden")
showGrid:SetChecked(true)
M.FireScript(showGrid, "OnClick")
check(overlay:IsShown(), "grid comes back")

-- Drag one icon: small jitter is ignored, then it snaps to the grid
local icon, entry = ns.icons[1], spells()[1]
local x0, y0 = entry.x, entry.y
M.cursorX, M.cursorY = 500, 500
M.FireScript(icon, "OnMouseDown", "LeftButton")
M.cursorX = 502
M.Tick(0.02)
check(entry.x == x0 and entry.y == y0, "jitter below 3 px does not move")
M.cursorX, M.cursorY = 523, 509
M.Tick(0.02)
check(entry.x == snap(x0 + 23, 16) and entry.y == snap(y0 + 9, 16), "snaps to the grid")
check(icon.Label.__text == ("%d, %d"):format(entry.x, entry.y), "label shows coordinates while dragging")
M.FireScript(icon, "OnMouseUp", "LeftButton")
check(icon.Label.__text == icon.spellName, "label shows the name again")
check(icon.__scripts.OnUpdate == nil, "drag ends on release")

-- Alt drags the whole group, keeping the gaps
local before = {}
for i, e in ipairs(spells()) do before[i] = { e.x, e.y } end
M.alt = true
M.cursorX, M.cursorY = 0, 0
M.FireScript(ns.icons[3], "OnMouseDown", "LeftButton")
M.alt = false
M.cursorX, M.cursorY = 40, -20
M.Tick(0.02)
M.FireScript(ns.icons[3], "OnMouseUp", "LeftButton")
local grabbed = spells()[3]
check(grabbed.x == snap(before[3][1] + 40, 16) and grabbed.y == snap(before[3][2] - 20, 16), "grabbed icon snaps")
local dx, dy = grabbed.x - before[3][1], grabbed.y - before[3][2]
for i, e in ipairs(spells()) do
    check(e.x - before[i][1] == dx and e.y - before[i][2] == dy, "Alt moves icon " .. i .. " along")
end

SlashCmdList.KLARSICHT("lock")
check(not overlay:IsShown(), "grid hides when locked")
M.FireScript(icon, "OnMouseDown", "LeftButton")
check(icon.drag == nil, "no dragging while locked")

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
M.FireScript(dialog.replace, "OnClick")
check(dialog:IsShown() and dialog.status.__text == L.IMPORT_INVALID, "bad text shows an error")
dialog.box:SetText(good)
M.FireScript(dialog.box, "OnTextChanged", true)
check(dialog.status.__text == "", "editing clears the error")
M.FireScript(dialog.replace, "OnClick")
check(not dialog:IsShown() and #spells() == 4, "import closes the dialog")
check(KlarsichtConfigFrame:IsShown() and ns.GetSelected() == 1, "settings open on the first spell")
check(M.lastMessage:find(L.IMPORT_DONE:format(4, 0), 1, true), "chat reports the import")

print(("%s %s/%s: %d checks passed"):format(M.scenario, M.forever and "forever" or "classic", M.locale, M.passed))
