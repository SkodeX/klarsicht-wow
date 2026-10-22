-- Buff and debuff tracking, played through as a priest.
local M, ns = MOCK, NS
local L = ns.L

local function check(condition, message)
    if not condition then error("CHECK FAILED: " .. message, 2) end
    M.passed = M.passed + 1
end

local function spells() return KlarsichtCharDB.spells end
local function click(widget, ...) M.FireScript(widget, "OnClick", ...) end
local function buttonWithText(text)
    return M.Find("Button", function(w) return w.__text == text and w:IsVisible() end)
end
local function checkWithLabel(text)
    return M.Find("CheckButton", function(w) return w.label.__text == text and w:IsVisible() end)
end
local function textShown(text)
    return M.Find("FontString", function(w) return w.__text == text end) ~= nil
end

M.class = "PRIEST"
for _, data in pairs(M.SPELLS) do data.known = false end
M.SPELLS[17] = { name = "Machtwort: Schild", icon = 135940, known = true }
M.SPELLS[589] = { name = "Schattenwort: Schmerz", icon = 136207, known = true }
M.SPELLS[588] = { name = "Inneres Feuer", icon = 135926, known = true }

M.Fire("ADDON_LOADED", "Klarsicht")
M.Fire("PLAYER_LOGIN")
M.Tick(0.2)
SlashCmdList.KLARSICHT("")
local window = KlarsichtConfigFrame
local addBox = M.FindAll("EditBox")[1]

-- Shadow Word: Pain as a debuff on the target
addBox:SetText("Schattenwort: Schmerz")
M.FireScript(addBox, "OnEnterPressed")
local pain, painIcon = spells()[1], ns.icons[1]
check(pain.track == "spell", "added as a spell first")
click(buttonWithText(L.TRACK_spell))
click(buttonWithText(L.TRACK_playerBuff))
click(buttonWithText(L.TRACK_playerDebuff))
check(pain.track == "targetDebuff" and pain.mine == true, "switched to debuff on target, own only")
check(checkWithLabel(L.GLOW_EXPIRING) and not checkWithLabel(L.RANGE), "buff options replace the spell options")
check(checkWithLabel(L.MINE) and checkWithLabel(L.MINE):GetChecked(), "'only my own' is on for target debuffs")
check(painIcon.Cooldown.__reverse == true, "remaining-time swipe runs the other way")

M.Tick(0.2)
check(painIcon.__alpha == 0.25 and textShown(L.HIDDEN_NOW:format(L.REASON_inactive)), "no target: faint while the window is open")
window:Hide()
M.Tick(0.2)
check(not painIcon:IsShown(), "no target: hidden")

M.target = { hostile = true }
M.auras.target = { { name = "Schattenwort: Schmerz", spellId = 10894, icon = 136207, helpful = false, mine = true,
    duration = 18, expires = M.time + 12 } }
M.Tick(0.2)
check(painIcon:IsShown() and painIcon.Texture.__desaturated == false, "debuff on target: shown in color")
check(painIcon.Timer.__text == "12", "remaining time, got " .. tostring(painIcon.Timer.__text))
check(painIcon.Cooldown.__cooldown[2] == 18, "swipe over the full duration")
M.auras.target[1].mine = false
M.Tick(0.2)
check(not painIcon:IsShown(), "someone else's Shadow Word: Pain does not count")
M.auras.target[1].mine = true
pain.glowExpiring = true
M.Tick(10)
check(painIcon.Glow:IsShown() and painIcon.Timer.__text == "1.6", "glows shortly before it runs out")

-- The picker lists what is on you and your target
SlashCmdList.KLARSICHT("")
M.auras.player = {
    { name = "Inneres Feuer", spellId = 10952, icon = 135926, helpful = true, mine = true, stacks = 20, duration = 600, expires = M.time + 500 },
    { name = "Geschw\195\164chte Seele", spellId = 6788, icon = 135871, helpful = false, mine = true, duration = 15, expires = M.time + 9 },
}
ns.OpenAuraPicker()
local picker = KlarsichtAuraPicker
M.Tick(0.6)
local fireRow = M.Find("Button", function(w) return w.aura and w.aura.name == "Inneres Feuer" and w:IsShown() end)
local soulRow = M.Find("Button", function(w) return w.aura and w.aura.name == "Geschw\195\164chte Seele" and w:IsShown() end)
local painRow = M.Find("Button", function(w) return w.aura and w.aura.name == "Schattenwort: Schmerz" and w:IsShown() end)
check(fireRow and soulRow and painRow, "picker lists buffs, debuffs and target debuffs")
check(fireRow.kind.__text == L.TRACK_playerBuff and soulRow.kind.__text == L.TRACK_playerDebuff
    and painRow.kind.__text == L.TRACK_targetDebuff, "picker says where each one is")
click(fireRow)
local fire, fireIcon = spells()[2], ns.icons[2]
check(fire.track == "playerBuff" and fire.mine == false and fire.id == 10952, "click tracks it as a buff on me")
check(ns.GetSelected() == 2, "and selects it")
M.Tick(0.2)
check(fireIcon.Count.__text == 20, "stacks are shown")
click(soulRow)
check(spells()[3].track == "playerDebuff" and spells()[3].name == "Geschw\195\164chte Seele", "debuff on me from the picker")
picker:Hide()

-- Reminder when a buff is missing
ns.OpenConfig(2)
click(buttonWithText(L.AURASHOW_active))
check(fire.auraShow == "missing", "show only while missing")
local glowMissing = checkWithLabel(L.GLOW_MISSING)
glowMissing:SetChecked(true)
click(glowMissing)
window:Hide()
M.Tick(0.2)
check(not fireIcon:IsShown(), "buff up: reminder hidden")
table.remove(M.auras.player, 1)
M.combat = true
M.Tick(0.2)
if M.forever then
    -- Forever hides buffs in combat, so "missing" cannot be told from "hidden".
    check(not fireIcon:IsShown(), "Forever combat: reminder keeps its last state")
    M.combat = false
    M.Tick(0.2)
    check(fireIcon:IsShown() and fireIcon.Texture.__desaturated == true, "Forever: reminder appears after combat")
else
    check(fireIcon:IsShown() and fireIcon.Texture.__desaturated == true and fireIcon.Glow:IsShown(),
        "buff gone in combat: gray reminder that glows")
end
M.combat = false

-- A name the spellbook does not know, its icon is learned when seen
ns.OpenConfig()
addBox:SetText("Schwache Seele")
M.FireScript(addBox, "OnEnterPressed")
local weak, weakIcon = spells()[4], ns.icons[4]
check(weak.track == "playerBuff" and weak.id == nil and weakIcon.iconTexture == 134400, "typed name: buff entry with a question mark")
click(buttonWithText(L.TRACK_playerBuff))
M.auras.player[#M.auras.player + 1] = { name = "Schwache Seele", spellId = 77777, icon = 132090, helpful = false, mine = false, duration = 0 }
M.Tick(0.2)
check(weak.track == "playerDebuff" and weak.icon == 132090 and weakIcon.Texture.__texture == 132090, "icon learned from the debuff")

-- Spell and buff of the same name can live side by side
local shield = ns.AddSpell(17)
local shieldBuff = ns.AddAura("Machtwort: Schild", "playerBuff", 17)
check(shield and shieldBuff and shield ~= shieldBuff, "spell and buff with the same name are separate entries")
check(ns.AddAura("Machtwort: Schild", "playerBuff", 17) == shieldBuff, "the same buff twice is a duplicate")

-- Profiles carry buff/debuff entries, including ones without an ID
local text = ns.ExportProfile()
local before = {}
for i, e in ipairs(spells()) do before[i] = { e.track, e.name, e.id, e.mine, e.auraShow } end
local added, skipped = ns.ImportProfile(text, true)
check(added == #before and skipped == 0, "all entries come back, got " .. tostring(added) .. "/" .. tostring(skipped))
for i, e in ipairs(spells()) do
    check(e.track == before[i][1] and e.mine == before[i][4] and e.auraShow == before[i][5], "entry " .. i .. " options survive")
end
check(spells()[4].name == "Schwache Seele" and spells()[4].id == nil, "name-only debuff survives")

-- Forever combat: auras are blocked; icons keep their last picture without errors
if M.forever then
    M.combat = true
    local blockedBefore = ns.diag.auraBlocked
    local shownBefore = painIcon:IsShown()
    M.Tick(0.2)
    check(ns.diag.auraBlocked > blockedBefore, "blocked reads are counted")
    check(painIcon:IsShown() == shownBefore, "icon keeps its last state")
    ns.OpenAuraPicker()
    M.Tick(0.6)
    check(KlarsichtAuraPicker.empty.__text == L.PICKER_BLOCKED, "picker explains the block")
    M.combat = false
end

print(("%s %s/%s: %d checks passed"):format(M.scenario, M.forever and "forever" or "classic", M.locale, M.passed))
