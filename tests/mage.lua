-- Plays through the addon like a user would and checks the results.
local M, ns = MOCK, NS
local L = ns.L

local function check(condition, message)
    if not condition then error("CHECK FAILED: " .. message, 2) end
    M.passed = M.passed + 1
end

local function click(widget, ...) M.FireScript(widget, "OnClick", ...) end
local function spells() return KlarsichtCharDB.spells end
local function iconFor(spellID)
    for i, entry in ipairs(spells()) do
        if ns.icons[i].spellID == spellID then return ns.icons[i], entry, i end
    end
end
local function buttonWithText(text)
    return M.Find("Button", function(w) return w.__text == text end)
end

-- Login
M.Fire("ADDON_LOADED", "Klarsicht")
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD")
M.Tick(0.2)
check(#spells() == 0, "starts empty")
check(KlarsichtCharDB.locked == true, "starts locked")
check(M.settingsPanel ~= nil, "registered in the AddOns options")

-- Open the window with the slash command
SlashCmdList.KLARSICHT("")
local window = KlarsichtConfigFrame
check(window and window:IsShown(), "/ks opens the window")

-- Class suggestions: 5 known mage spells exist in the mock data
click(buttonWithText(L.PRESET))
check(#spells() == 5, "preset adds the 5 known spells, got " .. #spells())
check(ns.GetSelected() == 1, "first preset spell selected")
local y = spells()[1].y
for i = 2, #spells() do check(spells()[i].y == y, "preset is one row") end
click(buttonWithText(L.PRESET))
check(#spells() == 5, "preset does not add duplicates")

-- Add by name, by ID of another rank, and nonsense
local editBoxes = M.FindAll("EditBox")
local addBox, xBox, yBox, auraBox = editBoxes[1], editBoxes[2], editBoxes[3], editBoxes[4]
addBox:SetText("Feuerball")
M.FireScript(addBox, "OnEnterPressed")
check(#spells() == 6 and spells()[6].id == 25306, "name resolves to the highest rank")
addBox:SetText("133")
M.FireScript(addBox, "OnEnterPressed")
check(#spells() == 6, "other rank of the same spell is a duplicate")
local messages = {}
local printMessage = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, msg)
    messages[#messages + 1] = msg
    printMessage(self, msg)
end
addBox:SetText("Quatsch")
M.FireScript(addBox, "OnEnterPressed")
DEFAULT_CHAT_FRAME.AddMessage = printMessage
check(#spells() == 7 and spells()[7].track == "playerBuff" and spells()[7].name == "Quatsch",
    "a name the spellbook does not know becomes a buff entry")
check(messages[1]:find(L.NOT_A_SPELL:format("Quatsch"), 1, true), "and the chat says so")
addBox:SetText("99999")
M.FireScript(addBox, "OnEnterPressed")
check(#spells() == 7, "an unknown ID is rejected")
ns.RemoveSpell(7)

-- Drag a spell from the spellbook onto the drop zone
local drop = M.Find("Button", function(w) return w.__scripts.OnReceiveDrag ~= nil end)
M.cursor = { "spell", 12, "spell", 10 }
M.FireScript(drop, "OnReceiveDrag")
check(#spells() == 7 and spells()[7].id == 10, "drag and drop adds the spell")
check(M.cursor == nil, "cursor cleared after drop")
check(ns.GetSelected() == 7, "dropped spell is selected")

-- Edit the selected spell through the controls
local slider = M.Find("Slider")
slider:SetValue(55)
check(spells()[7].size == 55 and ns.icons[7].__w == 55, "size slider resizes the icon")
xBox:SetText("-120")
M.FireScript(xBox, "OnTextChanged", true)
check(spells()[7].x == -120, "X box moves the icon while typing")
click(buttonWithText(L.CENTER))
check(spells()[7].x == 0, "center button")

local dimCheck = M.Find("CheckButton", function(w) return w.label.__text == L.DIM_CD end)
dimCheck:SetChecked(true)
click(dimCheck)
check(spells()[7].dimCD == true, "fade-on-cooldown checkbox")

local showCycle = buttonWithText(L.SHOW_always)
click(showCycle)
check(spells()[7].show == "combat", "show mode cycles to combat")
check(showCycle.__text == L.SHOW_combat, "cycle button relabels")
M.Tick(0.2)
check(ns.icons[7]:IsShown() and ns.icons[7].__alpha == 0.25, "hidden icon stays as a faint ghost while the window is open")
local stateText = L.HIDDEN_NOW:format(L.REASON_combat)
check(M.Find("FontString", function(w) return w.__text == stateText end), "window says live why it is hidden")

-- Glow while a buff is up
auraBox:SetText("Freizaubern")
M.FireScript(auraBox, "OnTextChanged", true)
check(spells()[7].glowAura == "Freizaubern" and spells()[7].glowAuraOn, "buff glow set")
M.buffs.Freizaubern = true
M.Tick(0.2)
check(ns.icons[7].Glow:IsShown(), "glows while the buff is up")
M.buffs.Freizaubern = nil
M.Tick(0.2)
check(not ns.icons[7].Glow:IsShown(), "glow ends with the buff")

-- Cooldown swipe and numbers
local counter, counterEntry = iconFor(2139)
M.cooldowns[2139] = { M.time, 24 }
M.Fire("SPELL_UPDATE_COOLDOWN")
M.Tick(0.2)
check(counter.Cooldown.__cooldown and counter.Cooldown.__cooldown[2] == 24, "cooldown swipe started")
check(counter.Timer:IsShown() and counter.Timer.__text == "24", "timer shows 24, got " .. tostring(counter.Timer.__text))
M.Tick(22.5)
check(counter.Timer.__text == "1.3", "timer shows decimals at the end, got " .. tostring(counter.Timer.__text))
M.Tick(2)
check(not counter.Timer:IsShown(), "timer hides when ready")

-- Global cooldown alone is not a cooldown
M.cooldowns[2139] = { M.time, 1.5 }
M.Tick(0.2)
check(not counter.Timer:IsShown(), "GCD is ignored")

-- Range and mana
M.target = { hostile = true }
M.inRange[2139] = false
M.Tick(0.2)
check(counter.Texture.__desaturated == true, "gray when out of range")
M.inRange[2139] = true
M.Tick(0.2)
check(counter.Texture.__desaturated == false, "colored again in range")
local fireBlast = iconFor(2136)
M.noPower[2136] = true
M.Tick(0.2)
check(fireBlast.Texture.__color[3] == 1 and fireBlast.Texture.__color[1] < 0.5, "blue without mana")
M.noPower[2136] = nil

-- Blizzard proc alert
M.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 2136)
M.Tick(0.2)
check(fireBlast.Glow:IsShown() and fireBlast.Glow.Pulse.__playing, "glows on proc")
M.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 2136)
M.Tick(0.2)
check(not fireBlast.Glow:IsShown(), "proc glow ends")

-- Visibility rules apply once the window is closed
window:Hide()
M.target = nil
M.Tick(0.2)
check(not ns.icons[7]:IsShown(), "combat-only icon hidden out of combat")
M.combat = true
M.Tick(0.2)
check(ns.icons[7]:IsShown(), "combat-only icon shown in combat")
M.combat = false

-- Unlock, drag an icon, right-click selects it
SlashCmdList.KLARSICHT("unlock")
check(KlarsichtCharDB.locked == false and ns.icons[1].__mouse == true, "unlock enables dragging")
local icon = ns.icons[2]
local x0, y0 = spells()[2].x, spells()[2].y
M.cursorX, M.cursorY = 0, 0
M.FireScript(icon, "OnMouseDown", "LeftButton")
M.shift = true
M.cursorX, M.cursorY = 100.4, -50.6
M.Tick(0.02)
M.FireScript(icon, "OnMouseUp", "LeftButton")
M.shift = false
check(spells()[2].x == x0 + 100 and spells()[2].y == y0 - 51, "free drag stores the rounded position")
M.FireScript(icon, "OnMouseUp", "RightButton")
check(window:IsShown() and ns.GetSelected() == 2, "right-click opens the window on that spell")
SlashCmdList.KLARSICHT("lock")
check(ns.icons[1].__mouse == false, "lock disables dragging")

-- Remove the selected spell
click(buttonWithText(L.REMOVE))
check(#spells() == 6, "remove deletes the spell")
check(not ns.icons[7]:IsShown(), "the spare icon frame is hidden")

-- Forever: secret cooldowns in combat must not raise errors
if M.forever then
    M.combat = true
    M.target = { hostile = true }
    M.cooldowns[2139] = { M.time, 24 }
    M.Fire("SPELL_UPDATE_COOLDOWN")
    M.Tick(0.2)
    counter = iconFor(2139)
    check(counter.Cooldown.__durationObject ~= nil, "secret cooldown goes through the duration object")
    check(counter.Cooldown.__hideNumbers == false, "native countdown numbers in secret mode")
    check(not counter.Timer:IsShown(), "own timer hidden in secret mode")
    check(ns.diag.secretReads > 0 and ns.diag.durationOk > 0, "status counters track the secret path")
    SlashCmdList.KLARSICHT("status")
    check(M.lastMessage:find("6"), "status prints the layout line")

    -- If Blizzard ever rejects the duration object, the icon stays usable
    M.failDuration = true
    M.Fire("SPELL_UPDATE_COOLDOWN")
    M.Tick(0.2)
    M.failDuration = false
    check(ns.diag.durationFailed > 0 and ns.diag.lastError:find("rejected"), "failure is counted with its message")
    check(counter.Cooldown.__durationObject == nil, "rejected swipe is cleared, not left stale")
    M.Tick(5)
    M.combat = false
    M.Tick(0.2)
    check(counter.Cooldown.__cooldown ~= nil and counter.Timer:IsShown(), "back to own timer after combat")

    -- Should Blizzard lock even "on cooldown yes/no": keep the last state, never guess
    counter.entry.dimCD = true
    M.Tick(0.2)
    check(counter.__alpha == 0.45, "faded while on cooldown before the lock")
    M.secretFlags, M.combat = true, true
    M.Fire("SPELL_UPDATE_COOLDOWN")
    M.Tick(0.2)
    check(ns.diag.secretFlags > 0, "locked yes/no values are counted")
    check(counter.__alpha == 0.45 and counter.Cooldown.__durationObject ~= nil, "icon keeps 'on cooldown', swipe still via Blizzard")
    M.cooldowns[2139] = nil
    M.Tick(0.2)
    check(counter.__alpha == 0.45, "cooldown ended while locked: still the last known state")
    local messages = {}
    local printMessage = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) messages[#messages + 1] = msg end
    SlashCmdList.KLARSICHT("status")
    DEFAULT_CHAT_FRAME.AddMessage = printMessage
    local flagLine = L.STATUS_FLAGS:format(ns.diag.secretFlags)
    local found = false
    for _, msg in ipairs(messages) do
        if msg:find(flagLine, 1, true) then found = true end
    end
    check(found, "status reports the locked yes/no values")
    M.secretFlags, M.combat = false, false
    M.Tick(0.2)
    check(counter.__alpha == 1, "real state again once Blizzard shows it")
end

print(("%s %s/%s: %d checks passed"):format(M.scenario, M.forever and "forever" or "classic", M.locale, M.passed))
