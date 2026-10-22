local ADDON, ns = ...

-- Screen grid shown while the icons are unlocked. Lines run through the
-- screen center, which is also the origin of the icon positions.
ns.GRID_DEFAULTS = { show = true, snap = true, size = 16 }
ns.GRID_SIZES = { 8, 16, 32, 64 }

local LINE_COLOR = { 1, 1, 1, 0.08 }
local MAJOR_COLOR = { 1, 1, 1, 0.2 }
local CENTER_COLOR = { 1, 0.82, 0.25, 0.6 }
local MAJOR_EVERY = 4

local overlay

-- Rounds a position to the nearest grid point when snapping is on.
function ns.SnapToGrid(x, y)
    local grid = ns.db.grid
    if not grid.snap then return x, y end
    local size = grid.size
    return floor(x / size + 0.5) * size, floor(y / size + 0.5) * size
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
