local ADDON, ns = ...
local C, L = ns.C, ns.L

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local QUESTION_MARK = 134400
local GLOW_R, GLOW_G, GLOW_B = 1, 0.82, 0.25
local DIM_ALPHA = 0.45
local GHOST_ALPHA = 0.25   -- icons a visibility rule hides, while the settings are open
ns.MIN_SIZE, ns.MAX_SIZE = 16, 96

-- Cooldown number styles (shared by all icons, see db.style)
ns.TIMER_COLOR_ORDER = { "white", "yellow", "orange", "red", "green", "cyan", "blue", "purple" }
ns.TIMER_COLORS = {
    white = { 1, 1, 1 }, yellow = { 1, 0.85, 0.1 }, orange = { 1, 0.55, 0.1 }, red = { 1, 0.3, 0.25 },
    green = { 0.4, 1, 0.3 }, cyan = { 0.3, 0.9, 1 }, blue = { 0.4, 0.55, 1 }, purple = { 0.8, 0.45, 1 },
}
ns.OUTLINE_ORDER = { "none", "thin", "thick" }
ns.OUTLINES = { none = "", thin = "OUTLINE", thick = "THICKOUTLINE" }

-- Buff/debuff tracking: which unit and aura filter each track mode reads
local AURA_UNITS = { playerBuff = "player", playerDebuff = "player", targetBuff = "target", targetDebuff = "target" }
local AURA_FILTERS = { playerBuff = "HELPFUL", playerDebuff = "HARMFUL", targetBuff = "HELPFUL", targetDebuff = "HARMFUL" }
local EXPIRING_SECONDS = 3

local Icon = {}

local function FormatTime(seconds)
    if seconds <= 0 then return "" end
    if seconds < 3 then return format("%.1f", seconds) end
    if seconds < 60 then return format("%d", ceil(seconds)) end
    if seconds < 3600 then return format("%dm", ceil(seconds / 60)) end
    return format("%dh", ceil(seconds / 3600))
end

-- Four thin lines around the icon; used for the glow edge.
local function CreateEdges(parent, thickness, r, g, b)
    local edges = {}
    for i = 1, 4 do
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(r, g, b, 1)
        edges[i] = t
    end
    edges[1]:SetPoint("TOPLEFT", -thickness, thickness)
    edges[1]:SetPoint("TOPRIGHT", thickness, thickness)
    edges[1]:SetHeight(thickness)
    edges[2]:SetPoint("BOTTOMLEFT", -thickness, -thickness)
    edges[2]:SetPoint("BOTTOMRIGHT", thickness, -thickness)
    edges[2]:SetHeight(thickness)
    edges[3]:SetPoint("TOPLEFT", -thickness, 0)
    edges[3]:SetPoint("BOTTOMLEFT", -thickness, 0)
    edges[3]:SetWidth(thickness)
    edges[4]:SetPoint("TOPRIGHT", thickness, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", thickness, 0)
    edges[4]:SetWidth(thickness)
    return edges
end

function ns.CreateIcon(index)
    local f = CreateFrame("Frame", "KlarsichtIcon" .. index, UIParent)
    Mixin(f, Icon)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(false)

    f.Border = f:CreateTexture(nil, "BACKGROUND")
    f.Border:SetPoint("TOPLEFT", -1, 1)
    f.Border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.Border:SetColorTexture(0, 0, 0, 1)

    f.Texture = f:CreateTexture(nil, "ARTWORK")
    f.Texture:SetAllPoints()
    f.Texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    f.Cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.Cooldown:SetAllPoints()
    f.Cooldown:SetDrawEdge(false)
    f.Cooldown:SetHideCountdownNumbers(true)

    -- Everything above the swipe lives on this frame.
    f.Overlay = CreateFrame("Frame", nil, f)
    f.Overlay:SetAllPoints()
    f.Overlay:SetFrameLevel(f.Cooldown:GetFrameLevel() + 2)

    f.Timer = f.Overlay:CreateFontString(nil, "OVERLAY")
    f.Timer:SetPoint("CENTER", 0, 0)
    f.Timer:SetFont(FONT, 14, "OUTLINE")

    -- Stack count of a tracked buff/debuff
    f.Count = f.Overlay:CreateFontString(nil, "OVERLAY")
    f.Count:SetPoint("BOTTOMRIGHT", -1, 2)
    f.Count:SetFont(FONT, 12, "OUTLINE")

    f.Glow = CreateFrame("Frame", nil, f.Overlay)
    f.Glow:SetAllPoints()
    f.Glow:Hide()
    f.Glow.Halo = f.Glow:CreateTexture(nil, "ARTWORK")
    f.Glow.Halo:SetTexture(GLOW_TEXTURE)
    f.Glow.Halo:SetBlendMode("ADD")
    f.Glow.Halo:SetVertexColor(GLOW_R, GLOW_G, GLOW_B)
    f.Glow.Halo:SetPoint("CENTER")
    CreateEdges(f.Glow, 2, GLOW_R, GLOW_G, GLOW_B)
    local pulse = f.Glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.45)
    f.Glow.Pulse = pulse

    -- Shown while unlocked (drag handle) and for the icon selected in the settings.
    f.Mover = f.Overlay:CreateTexture(nil, "OVERLAY", nil, 7)
    f.Mover:SetAllPoints()
    f.Mover:SetTexture(WHITE)
    f.Mover:Hide()
    f.Label = f.Overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.Label:SetPoint("TOP", f, "BOTTOM", 0, -2)
    f.Label:Hide()

    -- Corner handle for resizing while unlocked.
    f.Grip = CreateFrame("Button", nil, f)
    f.Grip:SetSize(12, 12)
    f.Grip:SetPoint("BOTTOMRIGHT", 2, -2)
    f.Grip:SetFrameLevel(f.Overlay:GetFrameLevel() + 2)
    f.Grip:SetNormalTexture(GRIP_TEXTURE .. "Up")
    f.Grip:SetHighlightTexture(GRIP_TEXTURE .. "Highlight")
    f.Grip:SetPushedTexture(GRIP_TEXTURE .. "Down")
    f.Grip:Hide()
    f.Grip:SetScript("OnMouseDown", function(_, button) f:StartResize(button) end)
    f.Grip:SetScript("OnMouseUp", function() f:StopResize() end)

    f:SetScript("OnMouseDown", f.OnMouseDown)
    f:SetScript("OnMouseUp", f.OnMouseUp)
    f:SetScript("OnHide", function(self)
        self:StopDrag()
        self:StopResize()
    end)
    return f
end

function Icon:SetEntry(index, entry)
    self.index, self.entry = index, entry
    self.secretMode, self.cdStart, self.cdDuration, self.cdEnd, self.lastOnCooldown = nil, nil, nil, nil, nil
    self.Cooldown:Clear()
    self:Resolve()
    self:ApplyLayout()
end

function Icon:Release()
    self.entry = nil
    self:Hide()
end

function Icon:Resolve()
    local spellID, name, texture = C.ResolveSpell(self.entry)
    self.spellID = spellID or self.entry.id
    self.spellName = name or self.entry.name
    -- A buff typed by name has no spell to look up; its icon is learned once seen.
    self.iconTexture = texture or self.entry.icon or QUESTION_MARK
    self.Texture:SetTexture(self.iconTexture)
    self.Label:SetText(self.spellName or "?")
    self.baseline = nil
end

-- Talent and rune procs (Missile Barrage, Clearcasting, Hot Streak, Presence
-- of Mind ...) often send no Blizzard proc alert. They make the spell free or
-- instant, so compare against the highest cost and cast time seen so far.
function Icon:IsFreeOrInstant()
    local castTime, cost = C.GetCastAndCost(self.spellID)
    if not castTime then return false end
    local baseline = self.baseline
    if not baseline then
        baseline = { castTime = 0, cost = 0 }
        self.baseline = baseline
    end
    if castTime > baseline.castTime then baseline.castTime = castTime end
    if cost > baseline.cost then baseline.cost = cost end
    return (baseline.cost > 0 and cost == 0) or (baseline.castTime > 0 and castTime == 0)
end

function Icon:ApplyLayout()
    local e, style = self.entry, ns.db.style
    self:SetSize(e.size, e.size)
    self:ApplyPosition()
    local fontSize = max(8, floor(e.size * 0.36 * style.scale / 100 + 0.5))
    local outline = ns.OUTLINES[style.outline] or "OUTLINE"
    self.timerColor = ns.TIMER_COLORS[style.color] or ns.TIMER_COLORS.white
    self.Timer:SetFont(FONT, fontSize, outline)
    self.Count:SetFont(FONT, max(8, floor(fontSize * 0.8 + 0.5)), outline)
    if self.track ~= e.track then
        -- Switching between spell and buff/debuff starts from a clean icon.
        self.track = e.track
        self.secretMode, self.cdStart, self.cdDuration, self.cdEnd, self.auraExpires = nil, nil, nil, nil, nil
        self.lastOnCooldown = nil
        self.Cooldown:Clear()
        self.Cooldown:SetReverse(e.track ~= "spell")
        self.Count:SetText("")
        self.Timer:Hide()
    end
    -- Blizzard's own countdown (Forever combat) gets the same look.
    local countdown = self.Cooldown:GetCountdownFontString()
    if countdown then
        countdown:SetFont(FONT, fontSize, outline)
        countdown:SetTextColor(self.timerColor[1], self.timerColor[2], self.timerColor[3])
    end
    self.Glow.Halo:SetSize(e.size * 1.72, e.size * 1.72)
    self.Cooldown:SetDrawSwipe(e.swipe)
    -- Tell OmniCC & co. to stay away while we draw our own numbers.
    self.Cooldown.noCooldownCount = e.timer or nil
    if self.secretMode then self.Cooldown:SetHideCountdownNumbers(not e.timer) end
end

function Icon:ApplyPosition()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", self.entry.x, self.entry.y)
end

function Icon:SetMoverState(unlocked, selected)
    self:EnableMouse(unlocked)
    self.Label:SetShown(unlocked)
    self.Grip:SetShown(unlocked)
    if unlocked or selected then
        if selected then
            self.Mover:SetVertexColor(0.25, 0.6, 1, 0.45)
        else
            self.Mover:SetVertexColor(0.2, 1, 0.3, 0.3)
        end
        self.Mover:Show()
    else
        self.Mover:Hide()
    end
end

function Icon:SetGlow(on)
    if on == self.glowing then return end
    self.glowing = on
    if on then
        self.Glow:Show()
        self.Glow.Pulse:Play()
    else
        self.Glow.Pulse:Stop()
        self.Glow:Hide()
    end
end

function Icon:UpdateCooldown(now, cooldownChanged)
    local e, spellID = self.entry, self.spellID
    local onCooldown, start, duration, secret = C.GetCooldown(spellID)
    if onCooldown == nil then
        -- Blizzard hid even "on cooldown yes/no": keep the last known state.
        onCooldown = self.lastOnCooldown or false
    end
    self.lastOnCooldown = onCooldown
    if secret then
        if cooldownChanged or not self.secretMode then
            self.secretMode = true
            self.cdStart, self.cdDuration, self.cdEnd = nil, nil, nil
            C.SetSecretCooldown(self.Cooldown, spellID)
            self.Cooldown:SetHideCountdownNumbers(not e.timer)
            self.Timer:Hide()
        end
        return onCooldown
    end

    if self.secretMode then
        self.secretMode = nil
        self.Cooldown:SetHideCountdownNumbers(true)
    end
    if onCooldown then
        if start ~= self.cdStart or duration ~= self.cdDuration then
            self.cdStart, self.cdDuration, self.cdEnd = start, duration, start + duration
            self.Cooldown:SetCooldown(start, duration)
        end
    elseif self.cdEnd then
        -- Let a finished cooldown play its flash; only clear early resets (Cold Snap & co.).
        if self.cdEnd > now + 0.1 then self.Cooldown:Clear() end
        self.cdStart, self.cdDuration, self.cdEnd = nil, nil, nil
    end

    self:ShowTimer(onCooldown and e.timer and self.cdEnd - now)
    return onCooldown
end

-- remaining: seconds to show, or nil/false to hide the number.
function Icon:ShowTimer(remaining)
    if not remaining then
        self.Timer:Hide()
        return
    end
    self.Timer:SetText(FormatTime(remaining))
    if remaining < 3 then
        self.Timer:SetTextColor(1, 0.35, 0.3)
    else
        self.Timer:SetTextColor(self.timerColor[1], self.timerColor[2], self.timerColor[3])
    end
    self.Timer:Show()
end

-- Why the combat/target rule hides the icon right now, or nil.
local function ShowRuleReason(e, state)
    if e.show == "combat" and not state.inCombat then return "combat" end
    if e.show == "target" and not state.hasTarget then return "target" end
    if e.show == "combatOrTarget" and not (state.inCombat or state.hasTarget) then return "combatOrTarget" end
end

-- With the settings open or icons unlocked, hidden icons stay as faint
-- ghosts, so rule changes show up live and every icon can still be moved.
function Icon:ApplyVisibility(hidden, state, alpha)
    self.hiddenReason = hidden
    if hidden and not state.preview then
        self:Hide()
        return
    end
    self:SetAlpha(hidden and GHOST_ALPHA or alpha)
    self:Show()
end

-- Buff/debuff mode: remaining time, stacks, gray while missing.
function Icon:UpdateAura(now, state)
    local e = self.entry
    local filter = AURA_FILTERS[e.track] .. (e.mine and "|PLAYER" or "")
    local aura, unknown = C.FindAura(AURA_UNITS[e.track], filter, self.spellName, self.spellID)
    if unknown then return end   -- Forever combat hides it: keep the last picture

    local active = aura ~= nil
    if active and aura.icon and aura.icon ~= self.iconTexture then
        self.iconTexture, e.icon = aura.icon, aura.icon
        self.Texture:SetTexture(aura.icon)
    end
    local remaining
    if active and (aura.duration or 0) > 0 then
        local expires = aura.expirationTime
        if expires ~= self.auraExpires then
            self.auraExpires = expires
            self.Cooldown:SetCooldown(expires - aura.duration, aura.duration)
        end
        remaining = expires - now
    elseif self.auraExpires then
        self.auraExpires = nil
        self.Cooldown:Clear()
    end
    self:ShowTimer(e.timer and remaining)
    local stacks = active and aura.applications or 0
    self.Count:SetText(stacks > 1 and stacks or "")
    self.Texture:SetDesaturated(not active)
    if active then
        self.Texture:SetVertexColor(1, 1, 1)
    else
        self.Texture:SetVertexColor(0.6, 0.6, 0.6)
    end

    local glow = (e.glowMissing and not active and state.inCombat)
        or (e.glowExpiring and remaining ~= nil and remaining < EXPIRING_SECONDS)
    self:SetGlow(glow and true or false)

    local hidden = ShowRuleReason(e, state)
    if not hidden and e.auraShow == "active" and not active then hidden = "inactive" end
    if not hidden and e.auraShow == "missing" and active then hidden = "active" end
    self:ApplyVisibility(hidden, state, 1)
end

-- state: inCombat, hasTarget, preview, cooldownChanged
function Icon:Update(now, state)
    local e, spellID = self.entry, self.spellID
    if e.track ~= "spell" then
        self:UpdateAura(now, state)
        return
    end
    if not spellID then
        self.hiddenReason = nil
        self:SetShown(state.preview)
        return
    end

    local onCooldown = self:UpdateCooldown(now, state.cooldownChanged)
    local usable, noPower = C.IsUsable(spellID)
    local inRange = e.range and C.IsInRange(spellID, self.spellName, "target")

    local texture = self.Texture
    if e.range and inRange == false then
        texture:SetDesaturated(true)
        texture:SetVertexColor(0.6, 0.6, 0.6)
    elseif e.grayCD and onCooldown then
        texture:SetDesaturated(true)
        texture:SetVertexColor(0.9, 0.9, 0.9)
    elseif e.usable and noPower then
        texture:SetDesaturated(false)
        texture:SetVertexColor(0.35, 0.45, 1)
    elseif e.usable and not usable then
        texture:SetDesaturated(false)
        texture:SetVertexColor(0.4, 0.4, 0.4)
    else
        texture:SetDesaturated(false)
        texture:SetVertexColor(1, 1, 1)
    end

    local glow = false
    local freeOrInstant = self:IsFreeOrInstant()
    if e.glowProc and (ns.procs[spellID] or ns.procs[self.spellName] or C.IsOverlayed(spellID)) then
        glow = true
    elseif e.glowProc and freeOrInstant and not onCooldown then
        glow = true
    elseif e.glowReady and state.inCombat and not onCooldown and usable then
        glow = true
    elseif e.glowAuraOn and C.HasPlayerBuff(e.glowAura) then
        glow = true
    end
    self:SetGlow(glow)

    local hidden = ShowRuleReason(e, state)
    if not hidden and e.when == "ready" and onCooldown then hidden = "cooldown" end
    if not hidden and e.when == "cooldown" and not onCooldown then hidden = "ready" end
    self:ApplyVisibility(hidden, state, (e.dimCD and onCooldown) and DIM_ALPHA or 1)
end

-- Dragging is done by hand instead of StartMoving so icons snap while they
-- move. Alt drags every icon, Shift skips snapping.
local DRAG_THRESHOLD = 3

local function CursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

function Icon:OnMouseDown(button)
    if button ~= "LeftButton" or ns.db.locked then return end
    local moveAll = IsAltKeyDown()
    local group, moving = {}, {}
    for i = 1, #ns.db.spells do
        local icon = ns.icons[i]
        if moveAll or icon == self then
            group[#group + 1] = { icon = icon, x = icon.entry.x, y = icon.entry.y }
            moving[icon] = true
        end
    end
    local x, y = CursorPosition()
    self.drag = { cursorX = x, cursorY = y, originX = self.entry.x, originY = self.entry.y, group = group, moving = moving }
    self:SetScript("OnUpdate", self.OnDragUpdate)
end

function Icon:OnDragUpdate()
    local drag = self.drag
    local x, y = CursorPosition()
    local dx, dy = x - drag.cursorX, y - drag.cursorY
    if not drag.started then
        if abs(dx) + abs(dy) < DRAG_THRESHOLD then return end
        drag.started = true
        ns.PushUndo()
    end
    -- The grabbed icon snaps; the rest of an Alt group keeps its offsets.
    local newX, newY = drag.originX + dx, drag.originY + dy
    if not IsShiftKeyDown() then newX, newY = ns.SnapPosition(self, newX, newY, drag.moving) end
    local shiftX = floor(newX - drag.originX + 0.5)
    local shiftY = floor(newY - drag.originY + 0.5)
    for _, member in ipairs(drag.group) do
        member.icon.entry.x = member.x + shiftX
        member.icon.entry.y = member.y + shiftY
        member.icon:ApplyPosition()
    end
    self.Label:SetText(format("%d, %d", self.entry.x, self.entry.y))
    ns.OnEntryChanged(self.index)
end

function Icon:StopDrag()
    local drag = self.drag
    if not drag then return end
    self.drag = nil
    self:SetScript("OnUpdate", nil)
    self.Label:SetText(self.spellName or "?")
    if drag.started then
        for _, member in ipairs(drag.group) do
            ns.OnEntryChanged(member.icon.index)
        end
    end
end

-- Resizing keeps the top-left corner in place; dragging right or down grows.
function Icon:StartResize(button)
    if button ~= "LeftButton" or ns.db.locked then return end
    local e = self.entry
    local x, y = CursorPosition()
    self.resize = { cursorX = x, cursorY = y, size = e.size, left = e.x - e.size / 2, top = e.y + e.size / 2 }
    ns.PushUndo()
    self:SetScript("OnUpdate", self.OnResizeUpdate)
end

function Icon:OnResizeUpdate()
    local resize, e = self.resize, self.entry
    local x, y = CursorPosition()
    local grow = max(x - resize.cursorX, resize.cursorY - y)
    local size = min(ns.MAX_SIZE, max(ns.MIN_SIZE, floor(resize.size + grow + 0.5)))
    e.size = size
    e.x = floor(resize.left + size / 2 + 0.5)
    e.y = floor(resize.top - size / 2 + 0.5)
    self:ApplyLayout()
    self.Label:SetText(format("%d px", size))
    ns.OnEntryChanged(self.index)
end

function Icon:StopResize()
    if not self.resize then return end
    self.resize = nil
    self:SetScript("OnUpdate", nil)
    self.Label:SetText(self.spellName or "?")
    ns.OnEntryChanged(self.index)
end

function Icon:OnMouseUp(button)
    self:StopDrag()
    if button == "RightButton" then ns.OpenConfig(self.index) end
end
