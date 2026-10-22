local ADDON, ns = ...

-- Screen grid shown while the icons are unlocked, plus the snapping rules for
-- dragging. Lines run through the screen center, which is also the origin of
-- the icon positions.
--   magnet: how close (px) an icon must come before it snaps
--   dock:   snap right next to other icons, gap px apart
ns.GRID_DEFAULTS = { show = true, snap = true, size = 8, magnet = 4, dock = true, gap = 2 }
ns.GRID_SIZES = { 4, 8, 16, 32, 64 }
ns.ROW_Y = -180

local LINE_COLOR = { 1, 1, 1, 0.08 }
local MAJOR_COLOR = { 1, 1, 1, 0.2 }
local CENTER_COLOR = { 1, 0.82, 0.25, 0.6 }
local MAJOR_EVERY = 4

local overlay

-- Snaps a dragged icon's center. Docking next to another icon wins over the
-- grid; the grid snaps each axis separately and only within the magnet range.
-- exclude: icons moving together with this one (Alt drag).
function ns.SnapPosition(icon, x, y, exclude)
    local layout = ns.db.grid
    local magnet = layout.magnet

    if layout.dock then
        local best, bestX, bestY = magnet + 0.5
        local half = icon.entry.size / 2
        local function Try(spotX, spotY)
            local distance = max(abs(x - spotX), abs(y - spotY))
            if distance < best then best, bestX, bestY = distance, spotX, spotY end
        end
        for i = 1, #ns.db.spells do
            local other = ns.icons[i]
            if other ~= icon and not (exclude and exclude[other]) then
                local o = other.entry
                local reach = o.size / 2 + layout.gap + half
                Try(o.x + reach, o.y)
                Try(o.x - reach, o.y)
                Try(o.x, o.y + reach)
                Try(o.x, o.y - reach)
            end
        end
        if bestX then return floor(bestX + 0.5), floor(bestY + 0.5) end
    end

    if layout.snap then
        local size = layout.size
        local gridX, gridY = floor(x / size + 0.5) * size, floor(y / size + 0.5) * size
        if abs(gridX - x) <= magnet then x = gridX end
        if abs(gridY - y) <= magnet then y = gridY end
    end
    return x, y
end

-- Lays entries out as one centered row at height y, gap px apart.
function ns.ArrangeRow(entries, y)
    local gap = ns.db.grid.gap
    local width = -gap
    for _, entry in ipairs(entries) do width = width + entry.size + gap end
    local left = -width / 2
    for _, entry in ipairs(entries) do
        entry.x = floor(left + entry.size / 2 + 0.5)
        entry.y = y
        left = left + entry.size + gap
    end
end

local function SetLine(index, vertical, offset, color)
    local line = overlay.lines[index]
    if not line then
        line = overlay:CreateTexture(nil, "BACKGROUND")
        overlay.lines[index] = line
    end
    line:ClearAllPoints()
    line:SetColorTexture(color[1], color[2], color[3], color[4])
    if vertical then
        line:SetPoint("TOP", overlay, "TOP", offset, 0)
        line:SetPoint("BOTTOM", overlay, "BOTTOM", offset, 0)
        line:SetWidth(1)
    else
        line:SetPoint("LEFT", overlay, "LEFT", 0, offset)
        line:SetPoint("RIGHT", overlay, "RIGHT", 0, offset)
        line:SetHeight(1)
    end
    line:Show()
end

function ns.UpdateGrid()
    local db = ns.db
    if not (ns.ready and db.grid.show and not db.locked) then
        if overlay then overlay:Hide() end
        return
    end
    if not overlay then
        overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("BACKGROUND")
        overlay.lines = {}
    end

    local size, count = db.grid.size, 0
    for _, vertical in ipairs({ true, false }) do
        local half = (vertical and UIParent:GetWidth() or UIParent:GetHeight()) / 2
        for step = 0, floor(half / size) do
            local color = LINE_COLOR
            if step == 0 then
                color = CENTER_COLOR
            elseif step % MAJOR_EVERY == 0 then
                color = MAJOR_COLOR
            end
            count = count + 1
            SetLine(count, vertical, step * size, color)
            if step > 0 then
                count = count + 1
                SetLine(count, vertical, -step * size, color)
            end
        end
    end
    for i = count + 1, #overlay.lines do
        overlay.lines[i]:Hide()
    end
    overlay:Show()
end
