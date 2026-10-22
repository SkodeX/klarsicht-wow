local ADDON, ns = ...
local C, L = ns.C, ns.L

-- Rank-1 spell IDs with a cooldown worth watching. Only spells the character
-- knows get added; IDs a client does not have (TBC/Wrath spells on Era) are
-- skipped, and two IDs with the same name are added once.
ns.PRESETS = {
    MAGE = {
        2139,   -- Counterspell
        122,    -- Frost Nova
        1953,   -- Blink
        2136,   -- Fire Blast
        120,    -- Cone of Cold
        12051,  -- Evocation
        66,     -- Invisibility (TBC)
        11958,  -- Ice Block (Era talent) / Cold Snap (TBC)
        12472,  -- Cold Snap (Era) / Icy Veins (TBC)
        45438,  -- Ice Block (TBC)
        11426,  -- Ice Barrier
        12043,  -- Presence of Mind
        12042,  -- Arcane Power
        11129,  -- Combustion
        11113,  -- Blast Wave
        31661,  -- Dragon's Breath (TBC)
        31687,  -- Summon Water Elemental (TBC)
    },
    PRIEST = {
        17,     -- Power Word: Shield
        8092,   -- Mind Blast
        14914,  -- Holy Fire (Era talent)
        8122,   -- Psychic Scream
        586,    -- Fade
        13908,  -- Desperate Prayer (Human, Dwarf)
        6346,   -- Fear Ward (Dwarf)
        13896,  -- Feedback (Human)
        2651,   -- Elune's Grace (Night Elf)
        10797,  -- Starshards (Night Elf)
        2944,   -- Devouring Plague (Undead)
        14751,  -- Inner Focus
        10060,  -- Power Infusion
        15487,  -- Silence
        724,    -- Lightwell
    },
}

-- Racial cooldowns, offered to every class after its own spells.
ns.RACIAL_PRESETS = {
    7744,   -- Will of the Forsaken
    20594,  -- Stoneform
    20580,  -- Shadowmeld
    20600,  -- Perception
    20554,  -- Berserking (mana)
    26296,  -- Berserking (rage)
    26297,  -- Berserking (energy)
    20589,  -- Escape Artist
    20549,  -- War Stomp
    20572,  -- Blood Fury
}

local SIZE, ROW_SPACING = 40, 8

function ns.LoadPreset()
    local _, class = UnitClass("player")
    local new, seen = {}, {}
    for _, list in ipairs({ ns.PRESETS[class] or {}, ns.RACIAL_PRESETS }) do
        for _, spellID in ipairs(list) do
            local name = C.GetSpellName(spellID)
            if name and not seen[name] and C.IsKnown(spellID) and not ns.FindSpell(spellID, name) then
                seen[name] = true
                tinsert(new, spellID)
            end
        end
    end
    if #new == 0 then
        ns.Print(L.PRESET_NONE)
        return
    end

    -- One centered row (one undo step); below the existing icons if there are any.
    ns.PushUndo()
    local y = ns.ROW_Y
    for _, entry in ipairs(ns.db.spells) do
        y = min(y, entry.y - entry.size - ROW_SPACING)
    end
    local added, firstIndex = {}, nil
    for _, spellID in ipairs(new) do
        local index = ns.AddSpell(spellID, { size = SIZE }, true)
        firstIndex = firstIndex or index
        added[#added + 1] = ns.db.spells[index]
    end
    ns.ArrangeRow(added, y)
    ns.RebuildIcons()
    ns.Print(format(L.PRESET_ADDED, #new))
    return firstIndex
end
