local ADDON, ns = ...

-- One place for every game API call, so Classic Era, Anniversary, Mists and
-- Forever differences stay out of the rest of the addon. Forever is a Midnight
-- client: in combat some cooldown and aura values are "secret" and must not be
-- compared or used in arithmetic, only handed to widgets.
local C = {}
ns.C = C

-- Counters for /ks status, so a tester can tell which Forever paths ran.
ns.diag = { secretReads = 0, durationOk = 0, durationFailed = 0, auraBlocked = 0, procEvents = 0 }
local diag = ns.diag

local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras
local C_SpellBook = C_SpellBook
local C_SpellActivationOverlay = C_SpellActivationOverlay
local issecretvalue = issecretvalue

-- The global cooldown is never longer than 1.5 s, real cooldowns are.
local GCD_MAX = 1.5

function C.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Accepts a spell ID, a numeric string or a spell name.
function C.GetSpellInfo(spell)
    if spell == nil or spell == "" then return nil end
    spell = tonumber(spell) or spell
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell)
        if info then return info.name, info.iconID, info.spellID end
        return nil
    end
    local name, _, icon, _, _, _, spellID = GetSpellInfo(spell)
    return name, icon, spellID
end

function C.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return (GetSpellInfo(spellID))
end

-- Resolve by name first so ranked Classic spells follow the highest known
-- rank, then fall back to the stored ID (also works for unlearned spells).
function C.ResolveSpell(entry)
    local name, icon, spellID
    if entry.name then name, icon, spellID = C.GetSpellInfo(entry.name) end
    if not spellID and entry.id then name, icon, spellID = C.GetSpellInfo(entry.id) end
    return spellID, name, icon
end

function C.IsKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known ~= nil then return known end
    end
    if IsPlayerSpell then return IsPlayerSpell(spellID) end
    if IsSpellKnown then return IsSpellKnown(spellID) end
    return false
end

-- Returns onCooldown, startTime, duration, secret.
-- With secret values only onCooldown is known (isActive/isOnGCD are never secret).
function C.GetCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if not info then return false, 0, 0, false end
        if C.IsSecret(info.startTime) or C.IsSecret(info.duration) then
            diag.secretReads = diag.secretReads + 1
            return info.isActive == true and info.isOnGCD ~= true, nil, nil, true
        end
        local start, duration = info.startTime or 0, info.duration or 0
        local active = info.isEnabled ~= false and start > 0 and duration > GCD_MAX
        return active, start, duration, false
    end
    local start, duration, enabled = GetSpellCooldown(spellID)
    start, duration = start or 0, duration or 0
    local active = enabled ~= 0 and start > 0 and duration > GCD_MAX
    return active, start, duration, false
end

-- Feeds a secret cooldown straight into the Cooldown widget.
function C.SetSecretCooldown(cooldown, spellID)
    local ok, result = false, "C_Spell.GetSpellCooldownDuration or SetCooldownFromDurationObject missing"
    if C_Spell and C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
        ok, result = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
        if ok and result then
            ok, result = pcall(cooldown.SetCooldownFromDurationObject, cooldown, result, true)
        end
    end
    if ok then
        diag.durationOk = diag.durationOk + 1
    else
        diag.durationFailed = diag.durationFailed + 1
        diag.lastError = tostring(result)
        cooldown:Clear()
    end
end

function C.IsAddOnRestricted()
    if not (C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum and Enum.AddOnRestrictionType) then
        return false
    end
    for _, kind in pairs(Enum.AddOnRestrictionType) do
        if C_RestrictedActions.IsAddOnRestrictionActive(kind) then return true end
    end
    return false
end

-- true = in range, false = out of range, nil = no target or no range.
function C.IsInRange(spellID, spellName, unit)
    if C_Spell and C_Spell.IsSpellInRange then
        local inRange = C_Spell.IsSpellInRange(spellID, unit)
        if C.IsSecret(inRange) then return nil end
        return inRange
    end
    if IsSpellInRange and spellName then
        local inRange = IsSpellInRange(spellName, unit)
        if inRange == nil then return nil end
        return inRange == 1
    end
    return nil
end

-- Returns usable, noPower.
function C.IsUsable(spellID)
    local usable, noPower
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noPower = C_Spell.IsSpellUsable(spellID)
    elseif IsUsableSpell then
        usable, noPower = IsUsableSpell(spellID)
    else
        return true, false
    end
    if C.IsSecret(usable) or C.IsSecret(noPower) then return true, false end
    return usable and true or false, noPower and true or false
end

function C.IsOverlayed(spellID)
    local isOverlayed = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed or IsSpellOverlayed
    if not isOverlayed then return false end
    local ok, glowing = pcall(isOverlayed, spellID)
    if not ok or C.IsSecret(glowing) then return false end
    return glowing and true or false
end

-- aura is a buff name or spell ID. In Forever combat, restricted auras read as
-- absent instead of raising an error.
function C.HasPlayerBuff(aura)
    if aura == nil or aura == "" then return false end
    local auraID = tonumber(aura)
    if C_UnitAuras then
        local ok, data
        if auraID and C_UnitAuras.GetPlayerAuraBySpellID then
            ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
        elseif not auraID and C_UnitAuras.GetAuraDataBySpellName then
            ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", aura, "HELPFUL")
        end
        if ok ~= nil then
            if not ok or C.IsSecret(data) then
                diag.auraBlocked = diag.auraBlocked + 1
                return false
            end
            return data ~= nil
        end
    end
    if auraID then aura = C.GetSpellName(auraID) end
    if aura and AuraUtil and AuraUtil.FindAuraByName then
        return AuraUtil.FindAuraByName(aura, "player", "HELPFUL") ~= nil
    end
    return false
end

function C.RegisterEventSafe(frame, event)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then return end
    pcall(frame.RegisterEvent, frame, event)
end
