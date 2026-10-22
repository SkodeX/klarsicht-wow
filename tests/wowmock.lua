-- Minimal WoW API mock for smoke-testing Klarsicht outside the game.
-- Widgets accept only methods documented for every supported client
-- (methods.lua, generated from Blizzard's API docs), so a typo or a
-- method missing in one client fails the test.
local METHODS = METHODS
local M = { time = 1000, widgets = {}, eventFrames = {}, passed = 0,
    cooldowns = {}, inRange = {}, noPower = {}, overlay = {}, buffs = {}, castTime = {}, cost = {}, auras = { player = {}, target = {} } }
MOCK = M

local SECRET = setmetatable({}, {
    __tostring = function() return "<secret>" end,
    __lt = function() error("compared a secret value", 2) end,
    __le = function() error("compared a secret value", 2) end,
    __add = function() error("arithmetic on a secret value", 2) end,
    __sub = function() error("arithmetic on a secret value", 2) end,
    __concat = function() error("concatenated a secret value", 2) end,
})
M.SECRET = SECRET

local special = {}
local widgetMeta = {
    __index = function(t, key)
        local impl = special[key]
        if impl then return impl end
        if METHODS[key] then return function() end end
        if type(key) == "string" and key:match("^%u") then
            error("unknown widget method/field '" .. key .. "' on " .. tostring(rawget(t, "__kind")), 2)
        end
        return nil
    end,
}

local function NewWidget(kind, name, parent)
    local w = setmetatable({ __kind = kind, __name = name, __parent = parent, __scripts = {},
        __shown = true, __events = {} }, widgetMeta)
    M.widgets[#M.widgets + 1] = w
    return w
end
M.NewWidget = NewWidget

local function Fire(w, script, ...)
    local fn = w.__scripts[script]
    if fn then return fn(w, ...) end
end
M.FireScript = Fire

function special.SetScript(self, name, fn) self.__scripts[name] = fn end
function special.GetScript(self, name) return self.__scripts[name] end
function special.HookScript(self, name, fn)
    local old = self.__scripts[name]
    self.__scripts[name] = function(...) if old then old(...) end fn(...) end
end
function special.Show(self) if not self.__shown then self.__shown = true Fire(self, "OnShow") end end
function special.Hide(self) if self.__shown then self.__shown = false Fire(self, "OnHide") end end
function special.SetShown(self, shown) if shown then special.Show(self) else special.Hide(self) end end
function special.IsShown(self) return self.__shown end
function special.IsVisible(self)
    local w = self
    while w do
        if not w.__shown then return false end
        w = w.__parent
    end
    return true
end
for _, kind in ipairs({ "Texture", "FontString", "AnimationGroup", "MaskTexture" }) do
    special["Create" .. kind] = function(self) return NewWidget(kind, nil, self) end
end
function special.CreateAnimation(self, kind) return NewWidget(kind or "Animation", nil, self) end
function special.SetText(self, text) self.__text = text end
function special.GetText(self) return self.__text or "" end
function special.SetChecked(self, checked) self.__checked = checked and true or false end
function special.GetChecked(self) return self.__checked or false end
function special.SetMinMaxValues(self, low, high) self.__min, self.__max = low, high end
function special.SetValue(self, value)
    if self.__min then value = math.max(self.__min, math.min(self.__max, value)) end
    if value ~= self.__value then
        self.__value = value
        Fire(self, "OnValueChanged", value)
    end
end
function special.GetValue(self) return self.__value or 0 end
function special.HasFocus(self) return self.__focus or false end
function special.SetFocus(self) self.__focus = true Fire(self, "OnEditFocusGained") end
function special.ClearFocus(self)
    if self.__focus then self.__focus = false Fire(self, "OnEditFocusLost") end
end
function special.GetFrameLevel() return 1 end
function special.GetEffectiveScale() return 1 end
function special.GetName(self) return self.__name end
function special.GetCenter(self) return self.__cx or 0, self.__cy or 0 end
function special.SetSize(self, w, h) self.__w, self.__h = w, h end
function special.GetWidth(self) return self.__w or 0 end
function special.GetHeight(self) return self.__h or 0 end
function special.SetHighlightTexture(self) self.__highlight = NewWidget("Texture", nil, self) end
function special.GetHighlightTexture(self) return self.__highlight end
function special.SetTexture(self, texture) self.__texture = texture return true end
function special.SetDesaturated(self, desaturated) self.__desaturated = desaturated end
function special.SetVertexColor(self, r, g, b, a) self.__color = { r, g, b, a } end
function special.SetAlpha(self, alpha) self.__alpha = alpha end
function special.SetTextColor(self, r, g, b) self.__textColor = { r, g, b } end
function special.SetFont(self, path, size, flags) self.__font = { path, size, flags } end
function special.EnableMouse(self, enabled) self.__mouse = enabled end
function special.RegisterEvent(self, event)
    self.__events[event] = true
    M.eventFrames[self] = true
end
function special.SetCooldown(self, start, duration) self.__cooldown = { start, duration } end
function special.SetCooldownFromDurationObject(self, duration)
    if M.failDuration then error("secret argument rejected") end
    self.__durationObject = duration
end
function special.Clear(self) self.__cooldown, self.__durationObject = nil, nil end
function special.SetHideCountdownNumbers(self, hide) self.__hideNumbers = hide end
function special.SetReverse(self, reverse) self.__reverse = reverse end
function special.Play(self) self.__playing = true end
function special.Stop(self) self.__playing = false end

local backdrop = {
    SetBackdrop = function(self, info) self.__backdrop = info end,
    SetBackdropColor = function() end,
    SetBackdropBorderColor = function() end,
}

local FRAME_TYPES = { Frame = true, Button = true, CheckButton = true, EditBox = true, Slider = true, Cooldown = true }
function CreateFrame(kind, name, parent, template)
    assert(FRAME_TYPES[kind], "unexpected frame type " .. tostring(kind))
    local w = NewWidget(kind, name, parent)
    if template and template:find("BackdropTemplate") then
        for key, fn in pairs(backdrop) do rawset(w, key, fn) end
    end
    if name then _G[name] = w end
    return w
end

function Mixin(object, ...)
    for i = 1, select("#", ...) do
        for key, value in pairs((select(i, ...))) do object[key] = value end
    end
    return object
end

UIParent = NewWidget("Frame", "UIParent")
UIParent.__w, UIParent.__h = 1920, 1080
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) M.lastMessage = msg end }
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames = {}
SlashCmdList = {}
format, floor, ceil, max, min = string.format, math.floor, math.ceil, math.max, math.min
tinsert, tremove, strlower = table.insert, table.remove, string.lower
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetLocale() return M.locale end
function GetTime() return M.time end
function InCombatLockdown() return M.combat == true end
function UnitExists(unit) return unit == "target" and M.target ~= nil end
function UnitCanAttack() return M.forever and M.combat and SECRET or (M.target and M.target.hostile) end
function UnitIsDead() return M.target and M.target.dead or false end
function UnitClass() return "Klasse", M.class or "MAGE" end
function GetCursorInfo() if M.cursor then return table.unpack(M.cursor) end end
function GetCursorPosition() return M.cursorX or 0, M.cursorY or 0 end
function IsAltKeyDown() return M.alt == true end
function IsShiftKeyDown() return M.shift == true end
abs = math.abs
function ClearCursor() M.cursor = nil end

function GetBuildInfo()
    if M.forever then return "1.60.1", "70450", "Oct 16 2026", 16001 end
    return "1.15.9", "70003", "Oct 1 2026", 11509
end
C_AddOns = { GetAddOnMetadata = function(addon, field)
    assert(addon == "Klarsicht" and field == "Version")
    return "0.2.0"
end }
Enum = { AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 } }
C_RestrictedActions = { IsAddOnRestrictionActive = function(kind)
    return M.forever == true and M.combat == true and kind == Enum.AddOnRestrictionType.Combat
end }

Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) M.settingsPanel = panel return { name = name } end,
    RegisterAddOnCategory = function(category) M.settingsCategory = category end,
}

-- Spell data: ranks share a name; lookups by name return the highest known rank.
local SPELLS = {
    [122] = { name = "Frostnova", icon = 135848, known = true },
    [1953] = { name = "Blinzeln", icon = 135736, known = true },
    [2139] = { name = "Gegenzauber", icon = 135856, known = true },
    [2136] = { name = "Feuerschlag", icon = 135807, known = true },
    [12051] = { name = "Hervorrufung", icon = 136075, known = true },
    [12043] = { name = "Geistesgegenwart", icon = 136031, known = false },
    [10] = { name = "Blizzard", icon = 135857, known = true },
    [133] = { name = "Feuerball", icon = 135812, known = true },
    [25306] = { name = "Feuerball", icon = 135812, known = true },
    [12536] = { name = "Freizaubern", icon = 136170 },
}
M.SPELLS = SPELLS

local function Lookup(spell)
    if type(spell) == "number" then return SPELLS[spell] and spell end
    local best
    for id, data in pairs(SPELLS) do
        if data.name == spell and data.known and (not best or id > best) then best = id end
    end
    return best
end

C_Spell = {
    GetSpellInfo = function(spell)
        local id = Lookup(spell)
        if not id then return nil end
        return { name = SPELLS[id].name, iconID = SPELLS[id].icon, spellID = id,
            castTime = M.castTime[id] or SPELLS[id].cast or 0 }
    end,
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id].name end,
    GetSpellCooldown = function(id)
        local cd = M.cooldowns[id]
        local active = cd ~= nil and M.time < cd[1] + cd[2]
        if M.forever and M.combat then
            return { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = active, isOnGCD = false, modRate = SECRET }
        end
        if not active then return { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1 } end
        return { startTime = cd[1], duration = cd[2], isEnabled = true, isActive = true, modRate = 1 }
    end,
    GetSpellCooldownDuration = function(id, ignoreGCD)
        assert(ignoreGCD == true, "expected ignoreGCD")
        return { spellID = id }
    end,
    IsSpellInRange = function(id, unit)
        if not M.target then return nil end
        return M.inRange[id]
    end,
    GetSpellPowerCost = function(id)
        local cost = M.cost[id] or (SPELLS[id] and SPELLS[id].cost)
        if not cost then return nil end
        return { { type = 0, cost = cost, minCost = cost } }
    end,
    IsSpellUsable = function(id)
        if M.noPower[id] then return false, true end
        return true, false
    end,
}
C_SpellBook = { IsSpellKnown = function(id) return SPELLS[id] ~= nil and SPELLS[id].known == true end }
C_SpellActivationOverlay = { IsSpellOverlayed = function(id) return M.overlay[id] == true end }
C_UnitAuras = {
    GetAuraDataBySpellName = function(unit, name, filter)
        assert(unit == "player" and filter == "HELPFUL")
        if M.forever and M.combat then return nil end   -- restricted aura
        return M.buffs[name] and { name = name } or nil
    end,
    GetPlayerAuraBySpellID = function(id) return M.buffs[id] and { spellId = id } or nil end,
    -- M.auras.player / M.auras.target: { name, spellId, icon, helpful, mine, stacks, duration, expires }
    GetAuraDataByIndex = function(unit, index, filter)
        if M.forever and M.combat then return { name = SECRET, spellId = SECRET, expirationTime = SECRET } end
        if unit == "target" and not M.target then return nil end
        local helpful, mineOnly = filter:find("HELPFUL") ~= nil, filter:find("PLAYER") ~= nil
        local n = 0
        for _, aura in ipairs(M.auras[unit] or {}) do
            if aura.helpful == helpful and (aura.mine or not mineOnly) then
                n = n + 1
                if n == index then
                    return { name = aura.name, spellId = aura.spellId, icon = aura.icon, applications = aura.stacks or 0,
                        duration = aura.duration or 0, expirationTime = aura.expires or 0 }
                end
            end
        end
    end,
}
C_EventUtils = { IsEventValid = function() return true end }

function M.Fire(event, ...)
    for frame in pairs(M.eventFrames) do
        if frame.__events[event] then Fire(frame, "OnEvent", event, ...) end
    end
end

function M.Tick(seconds)
    M.time = M.time + seconds
    for _, w in ipairs(M.widgets) do
        if w.__scripts.OnUpdate and w:IsVisible() then Fire(w, "OnUpdate", seconds) end
    end
end

function M.Find(kind, predicate)
    for _, w in ipairs(M.widgets) do
        if w.__kind == kind and (not predicate or predicate(w)) then return w end
    end
end

function M.FindAll(kind)
    local found = {}
    for _, w in ipairs(M.widgets) do
        if w.__kind == kind then found[#found + 1] = w end
    end
    return found
end

function M.UseForever()
    M.forever = true
    issecretvalue = function(value) return value == SECRET end
end
