local ADDON, ns = ...
local C, L = ns.C, ns.L

local UPDATE_INTERVAL = 0.1

ns.DEFAULTS = {
    size = 40, x = 0, y = -160,
    range = true, usable = true, swipe = true, timer = true, dimCD = false,
    glowProc = true, glowReady = false, glowAuraOn = false, glowAura = "",
    show = "always", when = "any",
}
ns.SHOW_MODES = { "always", "combat", "target", "combatOrTarget" }
ns.WHEN_MODES = { "any", "ready", "cooldown" }

ns.icons = {}
ns.procs = {}       -- spell ID and spell name -> true while Blizzard shows a proc alert

local db
local cooldownChanged = true
local state = {}

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffKlarsicht|r: " .. msg)
end

function ns.NewEntry()
    local entry = {}
    for key, value in pairs(ns.DEFAULTS) do entry[key] = value end
    return entry
end

local function InitDB()
    KlarsichtCharDB = KlarsichtCharDB or {}
    db = KlarsichtCharDB
    db.version = db.version or 1
    db.spells = db.spells or {}
    if db.locked == nil then db.locked = true end
    db.grid = db.grid or {}
    for key, value in pairs(ns.GRID_DEFAULTS) do
        if db.grid[key] == nil then db.grid[key] = value end
    end
    -- Options added in later versions get their default.
    for _, entry in ipairs(db.spells) do
        for key, value in pairs(ns.DEFAULTS) do
            if entry[key] == nil then entry[key] = value end
        end
    end
    ns.db = db
end

local function HasHostileTarget()
    if not UnitExists("target") then return false end
    local hostile, dead = UnitCanAttack("player", "target"), UnitIsDead("target")
    if C.IsSecret(hostile) then hostile = true end
    if C.IsSecret(dead) then dead = false end
    return hostile and not dead
end

function ns.UpdateAll()
    if not ns.ready then return end
    state.inCombat = InCombatLockdown()
    state.hasTarget = HasHostileTarget()
    state.preview = not db.locked or ns.IsConfigShown()
    state.cooldownChanged = cooldownChanged
    cooldownChanged = false
    local now = GetTime()
    for i = 1, #db.spells do
        ns.icons[i]:Update(now, state)
    end
end

function ns.RefreshMovers()
    for i = 1, #db.spells do
        ns.icons[i]:SetMoverState(not db.locked, ns.IsConfigShown() and ns.GetSelected() == i)
    end
end

function ns.RebuildIcons()
    for i, entry in ipairs(db.spells) do
        local icon = ns.icons[i] or ns.CreateIcon(i)
        ns.icons[i] = icon
        icon:SetEntry(i, entry)
    end
    for i = #db.spells + 1, #ns.icons do
        ns.icons[i]:Release()
    end
    cooldownChanged = true
    ns.RefreshMovers()
    ns.UpdateAll()
end

function ns.ResolveAll()
    for i = 1, #db.spells do ns.icons[i]:Resolve() end
end

function ns.ApplyEntry(index)
    local icon = ns.icons[index]
    if icon then icon:ApplyLayout() end
    cooldownChanged = true
    ns.UpdateAll()
end

function ns.FindSpell(spellID, name)
    for i, entry in ipairs(db.spells) do
        if entry.id == spellID or (name and entry.name == name) then return i end
    end
end

-- input: spell ID, numeric string or name. Returns the new (or existing) index.
function ns.AddSpell(input, fields)
    local name, _, spellID = C.GetSpellInfo(input)
    if not spellID then
        ns.Print(format(L.NOT_FOUND, tostring(input)))
        return nil
    end
    local existing = ns.FindSpell(spellID, name)
    if existing then
        ns.Print(format(L.ALREADY, name))
        return existing
    end

    local entry = ns.NewEntry()
    entry.id, entry.name = spellID, name
    local last = db.spells[#db.spells]
    if last then
        entry.size = last.size
        entry.x = last.x + last.size + 4
        entry.y = last.y
    end
    if fields then
        for key, value in pairs(fields) do entry[key] = value end
    end
    tinsert(db.spells, entry)
    ns.RebuildIcons()
    if not fields then ns.Print(format(L.ADDED, name)) end
    return #db.spells
end

function ns.RemoveSpell(index)
    tremove(db.spells, index)
    ns.RebuildIcons()
end

function ns.SetLocked(locked)
    db.locked = locked
    if not locked then ns.Print(L.MOVE_HINT) end
    ns.UpdateGrid()
    ns.RefreshMovers()
    ns.UpdateAll()
    ns.OnLockChanged()
end

local function SetProc(spellID, value)
    if spellID == nil or C.IsSecret(spellID) then return end
    ns.diag.procEvents = ns.diag.procEvents + 1
    ns.procs[spellID] = value
    local name = C.GetSpellName(spellID)
    if name then ns.procs[name] = value end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
}) do
    C.RegisterEventSafe(driver, event)
end

driver:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then InitDB() end
    elseif event == "PLAYER_LOGIN" then
        ns.ready = true
        ns.RebuildIcons()
        ns.UpdateGrid()
    elseif not ns.ready then
        return
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        ns.UpdateGrid()
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        ns.ResolveAll()
        cooldownChanged = true
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        SetProc(arg1, true)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        SetProc(arg1, nil)
    else
        cooldownChanged = true
    end
end)

local elapsedSinceUpdate = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < UPDATE_INTERVAL then return end
    elapsedSinceUpdate = 0
    ns.UpdateAll()
end)

-- Everything a remote tester needs to report back, in a few chat lines.
local function PrintStatus()
    local d = ns.diag
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local gameVersion, build, _, interface = GetBuildInfo()
    local function YesNo(value) return value and L.YES or L.NO end
    ns.Print(format(L.STATUS_VERSION, getMetadata(ADDON, "Version") or "?", gameVersion, build, interface))
    ns.Print(format(L.STATUS_SECRETS, YesNo(issecretvalue ~= nil), YesNo(C.IsAddOnRestricted())))
    ns.Print(format(L.STATUS_COOLDOWNS, d.secretReads, d.durationOk, d.durationFailed))
    if d.lastError then ns.Print(format(L.STATUS_ERROR, d.lastError)) end
    ns.Print(format(L.STATUS_AURAS, d.auraBlocked, d.procEvents))
    ns.Print(format(L.STATUS_LAYOUT, #db.spells, YesNo(db.locked), db.grid.size))
end

SLASH_KLARSICHT1 = "/klarsicht"
SLASH_KLARSICHT2 = "/ks"
SlashCmdList.KLARSICHT = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "lock" then
        ns.SetLocked(true)
    elseif msg == "unlock" then
        ns.SetLocked(false)
    elseif msg == "export" or msg == "import" then
        ns.OpenProfileDialog(msg)
    elseif msg == "status" then
        PrintStatus()
    elseif msg == "help" or msg == "?" then
        ns.Print(L.HELP)
    else
        ns.ToggleConfig()
    end
end

function Klarsicht_OnAddonCompartmentClick()
    ns.ToggleConfig()
end
