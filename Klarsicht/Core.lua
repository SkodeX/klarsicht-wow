local ADDON, ns = ...
local C, L = ns.C, ns.L

local UPDATE_INTERVAL = 0.1

ns.DEFAULTS = {
    size = 40, x = 0, y = -160,
    range = true, usable = true, swipe = true, timer = true, dimCD = false, grayCD = false,
    glowProc = true, glowReady = false, glowAuraOn = false, glowAura = "",
    show = "always", when = "any",
    -- What the icon follows: a spell's cooldown, or a buff/debuff (see TRACK_MODES)
    track = "spell", mine = true, auraShow = "active", glowMissing = false, glowExpiring = false,
}
ns.TRACK_MODES = { "spell", "playerBuff", "playerDebuff", "targetDebuff", "targetBuff" }
ns.AURA_SHOW_MODES = { "active", "missing", "always" }
-- Cooldown number look, shared by all icons
ns.STYLE_DEFAULTS = { color = "white", outline = "thin", scale = 100 }
ns.SHOW_MODES = { "always", "combat", "target", "combatOrTarget" }
ns.WHEN_MODES = { "any", "ready", "cooldown" }

ns.icons = {}
ns.procs = {}       -- spell ID and spell name -> true while Blizzard shows a proc alert

local UNDO_STEPS = 3
local UNDO_MERGE_SECONDS = 1.5

local db
local cooldownChanged = true
local state = {}
local undoStack, lastUndoTag, lastUndoTime = {}, nil, 0

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
    db.style = db.style or {}
    for key, value in pairs(ns.STYLE_DEFAULTS) do
        if db.style[key] == nil then db.style[key] = value end
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
    ns.OnStateTick()
end

---------------------------------------------------------------------------
-- Undo: the last few versions of the spell list (not grid or number style)
---------------------------------------------------------------------------

local function CopySpells()
    local copy = {}
    for i, entry in ipairs(db.spells) do
        local entryCopy = {}
        for key, value in pairs(entry) do entryCopy[key] = value end
        copy[i] = entryCopy
    end
    return copy
end

-- Call before changing the spell list. Changes with the same tag in quick
-- succession (one slider drag, typing a number) become one undo step.
function ns.PushUndo(tag)
    local now = GetTime()
    if tag and tag == lastUndoTag and now - lastUndoTime < UNDO_MERGE_SECONDS then
        lastUndoTime = now
        return
    end
    lastUndoTag, lastUndoTime = tag, now
    tinsert(undoStack, CopySpells())
    if #undoStack > UNDO_STEPS then tremove(undoStack, 1) end
    ns.OnUndoChanged()
end

function ns.UndoCount()
    return #undoStack
end

function ns.Undo()
    local snapshot = tremove(undoStack)
    if not snapshot then
        ns.Print(L.UNDO_EMPTY)
        return false
    end
    lastUndoTag = nil
    db.spells = snapshot
    ns.RebuildIcons()
    ns.OnUndoChanged()
    return true
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

-- After a change to db.style
function ns.ApplyStyle()
    for i = 1, #db.spells do ns.icons[i]:ApplyLayout() end
    ns.UpdateAll()
end

-- All icons as one centered row below the character, sizes unchanged.
function ns.ResetPositions()
    if #db.spells == 0 then return end
    ns.PushUndo()
    ns.ArrangeRow(db.spells, ns.ROW_Y)
    for i = 1, #db.spells do ns.icons[i]:ApplyPosition() end
    ns.RefreshConfig()
end

-- Back to the default options; the icon keeps its place.
function ns.ResetSpell(index)
    local entry = db.spells[index]
    if not entry then return end
    ns.PushUndo()
    local keep = { id = entry.id, name = entry.name, icon = entry.icon, x = entry.x, y = entry.y,
        track = entry.track, mine = entry.mine }
    for key in pairs(entry) do entry[key] = nil end
    for key, value in pairs(ns.DEFAULTS) do entry[key] = value end
    for key, value in pairs(keep) do entry[key] = value end
    ns.ApplyEntry(index)
    ns.RefreshConfig()
end

-- The same spell may be tracked twice: once for its cooldown, once as a buff.
function ns.FindSpell(spellID, name, track)
    track = track or "spell"
    for i, entry in ipairs(db.spells) do
        if entry.track == track and ((spellID and entry.id == spellID) or (name and entry.name == name)) then
            return i
        end
    end
end

local function PlaceAfterLast(entry)
    local last = db.spells[#db.spells]
    if last then
        entry.size = last.size
        entry.x = last.x + last.size + db.grid.gap
        entry.y = last.y
    end
end

-- A buff or debuff, by name; spellID and icon are optional (the aura picker
-- knows them, a typed name does not).
function ns.AddAura(name, track, spellID, icon)
    local existing = ns.FindSpell(spellID, name, track)
    if existing then
        ns.Print(format(L.ALREADY, name))
        return existing
    end
    ns.PushUndo()
    local entry = ns.NewEntry()
    PlaceAfterLast(entry)
    entry.id, entry.name, entry.icon, entry.track = spellID, name, icon, track
    entry.mine = track == "targetDebuff" or track == "targetBuff"
    tinsert(db.spells, entry)
    ns.RebuildIcons()
    ns.Print(format(L.ADDED, name))
    return #db.spells
end

-- Text from the add box: a spell if the spellbook knows it, otherwise a buff.
function ns.AddFromText(text)
    local _, _, spellID = C.GetSpellInfo(text)
    if spellID or tonumber(text) then return ns.AddSpell(text) end
    ns.Print(format(L.NOT_A_SPELL, text))
    return ns.AddAura(text, "playerBuff")
end

-- input: spell ID, numeric string or name. Returns the new (or existing) index.
-- skipUndo: the caller already saved an undo step (class suggestions).
function ns.AddSpell(input, fields, skipUndo)
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

    if not skipUndo then ns.PushUndo() end
    local entry = ns.NewEntry()
    entry.id, entry.name = spellID, name
    PlaceAfterLast(entry)
    if fields then
        for key, value in pairs(fields) do entry[key] = value end
    end
    tinsert(db.spells, entry)
    ns.RebuildIcons()
    if not fields then ns.Print(format(L.ADDED, name)) end
    return #db.spells
end

function ns.RemoveSpell(index)
    ns.PushUndo()
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
        ns.RefreshConfig()
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
    elseif msg == "undo" then
        ns.Undo()
    elseif msg == "help" or msg == "?" then
        ns.Print(L.HELP)
    else
        ns.ToggleConfig()
    end
end

function Klarsicht_OnAddonCompartmentClick()
    ns.ToggleConfig()
end
