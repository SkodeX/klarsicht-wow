-- A human priest without talents loads the class suggestions.
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

M.class = "PRIEST"
for _, data in pairs(M.SPELLS) do data.known = false end
local learned = {
    { 17, "Machtwort: Schild" }, { 8092, "Gedankenschlag" }, { 8122, "Psychischer Schrei" },
    { 586, "Verblassen" }, { 13908, "Verzweifeltes Gebet" }, { 13896, "Rueckkopplung" },
    { 20600, "Wachsamkeit" },
}
for _, spell in ipairs(learned) do
    M.SPELLS[spell[1]] = { name = spell[2], icon = 135900 + spell[1] % 100, known = true }
end
-- In the client, but not learned by this character (other race, talent, racial)
M.SPELLS[6346] = { name = "Furchtzauberschutz", icon = 135902, known = false }
M.SPELLS[14751] = { name = "Innerer Fokus", icon = 135863, known = false }
M.SPELLS[7744] = { name = "Wille der Verlassenen", icon = 136187, known = false }

M.Fire("ADDON_LOADED", "Klarsicht")
M.Fire("PLAYER_LOGIN")
M.Tick(0.2)
SlashCmdList.KLARSICHT("")
M.FireScript(buttonWithText(L.PRESET), "OnClick")

check(#spells() == #learned, "preset adds every learned priest spell, got " .. #spells())
for i, spell in ipairs(learned) do
    check(spells()[i].id == spell[1], "preset order: " .. spell[2] .. " at " .. i)
end
check(spells()[1].x == -spells()[#learned].x, "row is centered")
check(M.lastMessage:find(tostring(#learned)), "chat reports the count")

-- Psychic Scream: 30 s cooldown shows up as 30
local scream = ns.icons[3]
M.cooldowns[8122] = { M.time, 30 }
M.Fire("SPELL_UPDATE_COOLDOWN")
M.Tick(0.2)
check(scream.Timer.__text == "30", "Psychic Scream timer, got " .. tostring(scream.Timer.__text))

-- /ks status works on every client
local messages = {}
DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) messages[#messages + 1] = msg end
SlashCmdList.KLARSICHT("status")
local expected = M.forever and "1.60.1 (70450)" or "1.15.9 (70003)"
check(#messages == 5 and messages[1]:find("0.2.0", 1, true) and messages[1]:find(expected, 1, true),
    "status names addon and client version: " .. tostring(messages[1]))
check(messages[5]:find(L.STATUS_LAYOUT:format(7, L.YES, 16), 1, true), "status layout line: " .. tostring(messages[5]))

print(("%s %s/%s: %d checks passed"):format(M.scenario, M.forever and "forever" or "classic", M.locale, M.passed))
