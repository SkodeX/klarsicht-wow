local ADDON, ns = ...
local C, L = ns.C, ns.L

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local QUESTION_MARK = 134400
local GLOW_R, GLOW_G, GLOW_B = 1, 0.82, 0.25

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

    f:SetScript("OnMouseDown", f.OnMouseDown)
    f:SetScript("OnMouseUp", f.OnMouseUp)
    f:SetScript("OnHide", f.StopDrag)
    return f
end

function Icon:SetEntry(index, entry)
    self.index, self.entry = index, entry
    self.secretMode, self.cdStart, self.cdDuration, self.cdEnd = nil, nil, nil, nil
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
    self.iconTexture = texture or QUESTION_MARK
    self.Texture:SetTexture(self.iconTexture)
    self.Label:SetText(self.spellName or "?")
end

function Icon:ApplyLayout()
    local e = self.entry
    self:SetSize(e.size, e.size)
    self:ApplyPosition()
    self.Timer:SetFont(FONT, max(10, floor(e.size * 0.36)), "OUTLINE")
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

    if onCooldown and e.timer then
        local remaining = self.cdEnd - now
        self.Timer:SetText(FormatTime(remaining))
        if remaining < 3 then
            self.Timer:SetTextColor(1, 0.35, 0.3)
        else
            self.Timer:SetTextColor(1, 1, 1)
        end
        self.Timer:Show()
    else
        self.Timer:Hide()
    end
    return onCooldown
end

-- state: inCombat, hasTarget, preview, cooldownChanged
function Icon:Update(now, state)
    local e, spellID = self.entry, self.spellID
    if not spellID then
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
    self:SetAlpha((e.dimCD and onCooldown) and 0.45 or 1)

    local glow = false
    if e.glowProc and (ns.procs[spellID] or ns.procs[self.spellName] or C.IsOverlayed(spellID)) then
        glow = true
    elseif e.glowReady and state.inCombat and not onCooldown and usable then
        glow = true
    elseif e.glowAuraOn and C.HasPlayerBuff(e.glowAura) then
        glow = true
    end
    self:SetGlow(glow)

    local show = true
    if not state.preview then
        if e.show == "combat" then
            show = state.inCombat
        elseif e.show == "target" then
            show = state.hasTarget
        elseif e.show == "combatOrTarget" then
            show = state.inCombat or state.hasTarget
        end
        if show and e.when == "ready" then
            show = not onCooldown
        elseif show and e.when == "cooldown" then
            show = onCooldown
        end
    end
    self:SetShown(show)
end

-- Dragging is done by hand instead of StartMoving so icons snap to the grid
-- while they move. Alt drags every icon, Shift skips snapping.
local DRAG_THRESHOLD = 3

local function CursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

function Icon:OnMouseDown(button)
    if button ~= "LeftButton" or ns.db.locked then return end
    local moveAll = IsAltKeyDown()
    local group = {}
    for i = 1, #ns.db.spells do
        local icon = ns.icons[i]
        if moveAll or icon == self then
            group[#group + 1] = { icon = icon, x = icon.entry.x, y = icon.entry.y }
        end
    end
    local x, y = CursorPosition()
    self.drag = { cursorX = x, cursorY = y, originX = self.entry.x, originY = self.entry.y, group = group }
    self:SetScript("OnUpdate", self.OnDragUpdate)
end

function Icon:OnDragUpdate()
    local drag = self.drag
    local x, y = CursorPosition()
    local dx, dy = x - drag.cursorX, y - drag.cursorY
    if not drag.moving then
        if abs(dx) + abs(dy) < DRAG_THRESHOLD then return end
        drag.moving = true
    end
    -- The grabbed icon snaps; the rest of an Alt group keeps its offsets.
    local newX, newY = drag.originX + dx, drag.originY + dy
    if not IsShiftKeyDown() then newX, newY = ns.SnapToGrid(newX, newY) end
    local shiftX = floor(newX - drag.originX + 0.5)
    local shiftY = floor(newY - drag.originY + 0.5)
    for _, member in ipairs(drag.group) do
        member.icon.entry.x = member.x + shiftX
        member.icon.entry.y = member.y + shiftY
        member.icon:ApplyPosition()
    end
    self.Label:SetText(format("%d, %d", self.entry.x, self.entry.y))
end

function Icon:StopDrag()
    local drag = self.drag
    if not drag then return end
    self.drag = nil
    self:SetScript("OnUpdate", nil)
    self.Label:SetText(self.spellName or "?")
    if drag.moving then
        for _, member in ipairs(drag.group) do
            ns.OnEntryChanged(member.icon.index)
        end
    end
end

function Icon:OnMouseUp(button)
    self:StopDrag()
    if button == "RightButton" then ns.OpenConfig(self.index) end
end
