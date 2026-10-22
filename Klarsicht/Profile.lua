local ADDON, ns = ...
local C, L = ns.C, ns.L

-- Profile strings look like "KS1:<spells>:<checksum>".
-- <spells> is a ;-separated list of spells, each a ,-separated list of
-- key=value pairs, with only the values that differ from the defaults.
-- Spells travel by ID, so a profile works across client languages. Import
-- only parses text (nothing is ever executed) and clamps every value.
local VERSION = 1
local MAX_SPELLS = 100
local MAX_TEXT = 100
local LIMITS = { size = { 16, 96 }, x = { -4000, 4000 }, y = { -4000, 4000 } }

local function Escape(text)
    return (text:gsub("[^%w_%.%-]", function(char) return format("%%%02X", char:byte()) end))
end

local function Unescape(text)
    return (text:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function Checksum(text)
    local sum = 0
    for i = 1, #text do
        sum = (sum * 31 + text:byte(i)) % 65521
    end
    return format("%04x", sum)
end

local function SortedKeys()
    local keys = {}
    for key in pairs(ns.DEFAULTS) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function EncodeValue(value)
    if value == true then return "1" end
    if value == false then return "0" end
    if type(value) == "number" then return tostring(floor(value + 0.5)) end
    return Escape(tostring(value))
end

local function Contains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

function ns.ExportProfile()
    local keys, spells = SortedKeys(), {}
    for _, entry in ipairs(ns.db.spells) do
        -- Buffs/debuffs also travel by name: some have no ID, and IDs can
        -- differ between clients while the name matches.
        local fields = {}
        if entry.id then fields[1] = "id=" .. EncodeValue(entry.id) end
        if entry.track ~= "spell" or not entry.id then
            fields[#fields + 1] = "name=" .. Escape(entry.name or "")
        end
        for _, key in ipairs(keys) do
            if entry[key] ~= ns.DEFAULTS[key] then
                fields[#fields + 1] = key .. "=" .. EncodeValue(entry[key])
            end
        end
        spells[#spells + 1] = table.concat(fields, ",")
    end
    local payload = table.concat(spells, ";")
    return "KS" .. VERSION .. ":" .. payload .. ":" .. Checksum(payload)
end

local function ParseSpell(chunk)
    local entry = {}
    for key, value in chunk:gmatch("(%w+)=([^,]*)") do
        local default = ns.DEFAULTS[key]
        if key == "id" then default = 0 elseif key == "name" then default = "" end
        local kind = type(default)
        if kind == "number" then
            entry[key] = tonumber(value)
        elseif kind == "boolean" then
            entry[key] = value == "1"
        elseif kind == "string" then
            entry[key] = Unescape(value):sub(1, MAX_TEXT)
        end
    end
    local id = entry.id
    if id and (id < 1 or id > 9999999 or id % 1 ~= 0) then return nil end
    if entry.track and not Contains(ns.TRACK_MODES, entry.track) then return nil end
    -- Only buffs/debuffs may come without an ID.
    if not id and not (entry.name and entry.name ~= "" and entry.track and entry.track ~= "spell") then return nil end
    for key, range in pairs(LIMITS) do
        if entry[key] then entry[key] = min(range[2], max(range[1], floor(entry[key] + 0.5))) end
    end
    if entry.show and not Contains(ns.SHOW_MODES, entry.show) then entry.show = nil end
    if entry.when and not Contains(ns.WHEN_MODES, entry.when) then entry.when = nil end
    if entry.auraShow and not Contains(ns.AURA_SHOW_MODES, entry.auraShow) then entry.auraShow = nil end
    return entry
end

-- Returns a list of sanitized spell entries, or nil and an error message.
function ns.ParseProfile(text)
    text = (text or ""):gsub("%s+", "")
    local version, payload, checksum = text:match("^KS(%d+):([^:]*):(%x+)$")
    if not version then return nil, L.IMPORT_INVALID end
    if tonumber(version) > VERSION then return nil, L.IMPORT_NEWER end
    if Checksum(payload) ~= checksum:lower() then return nil, L.IMPORT_DAMAGED end
    local entries = {}
    for chunk in payload:gmatch("[^;]+") do
        local entry = ParseSpell(chunk)
        if entry then entries[#entries + 1] = entry end
        if #entries >= MAX_SPELLS then break end
    end
    return entries
end

-- replace: true drops the current list first. Returns added, skipped or nil, error.
function ns.ImportProfile(text, replace)
    local entries, err = ns.ParseProfile(text)
    if not entries then return nil, err end
    ns.PushUndo()
    if replace then ns.db.spells = {} end
    local added, skipped = 0, 0
    for _, imported in ipairs(entries) do
        local name = imported.id and C.GetSpellName(imported.id) or imported.name
        if not name or ns.FindSpell(imported.id, name, imported.track) then
            skipped = skipped + 1
        else
            local entry = ns.NewEntry()
            for key, value in pairs(imported) do entry[key] = value end
            entry.name = name
            tinsert(ns.db.spells, entry)
            added = added + 1
        end
    end
    ns.RebuildIcons()
    return added, skipped
end
