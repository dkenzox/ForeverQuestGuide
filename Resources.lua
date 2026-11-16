local _, Guide = ...
local L, Character = Guide.Locale, Guide.Character
local Resources = {}
Guide.Resources = Resources

local icons = {
    ore = "Interface\\Icons\\Spell_Fire_FlameBlades",
    herb = "Interface\\Icons\\Spell_Nature_NatureTouchGrow",
    fish = "Interface\\Icons\\Trade_Fishing",
}
local skills = { ore = 186, herb = 182, fish = 356 }
local tracking = { ore = "mining", herb = "herbalism", fish = "fishing" }

local function addPoint(row, zone, x, y)
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or x > 1 or y < 0 or y > 1 then return end
    local key = ("%d:%d"):format(math.floor(x * 1000 + .5), math.floor(y * 1000 + .5))
    if row.seen[key] then return end
    row.seen[key] = true
    row.points[#row.points + 1] = { mapID = zone, zone = zone, x = x * 100, y = y * 100 }
end

local function getRow(rows, key, name, icon, required, id)
    local row = rows[key]
    if not row then
        row = { key = key, name = name, icon = icon, required = required, itemID = id, points = {}, seen = {} }
        rows[key] = row
    end
    return row
end

local function gatherLiteRows(rows, zone, kind)
    local gl = GatherLite
    if not (gl and gl.db and gl.GetNodesForMap and gl.GetNodeObject and gl.translate) then return end
    local objects = {}
    for _, node in ipairs(gl:GetNodesForMap(tracking[kind], zone) or {}) do
        if objects[node.object] == nil then objects[node.object] = gl:GetNodeObject(node.object) or false end
        local object = objects[node.object]
        if object then
            local name = gl:translate("node." .. object.name)
            local row = getRow(rows, object.name, name, object.icon or icons[kind], object.levels and object.levels[1])
            addPoint(row, zone, node.posX, node.posY)
        end
    end
end

local function referenceNodes(rows, zone, kind)
    for id, packed in pairs(Guide.ResourceSpots[zone] or {}) do
        local def = Guide.ResourceNodes[id]
        if def and def[2] == kind then
            local localized = Guide.ResourceNames[def[1]]
            local name = localized or def[4]
            local row = getRow(rows, def[1], name, icons[kind], def[3])
            for i = 1, #packed, 4 do
                local x, y = tonumber(packed:sub(i, i + 1), 32), tonumber(packed:sub(i + 2, i + 3), 32)
                if x and y then addPoint(row, zone, x / 1000, y / 1000) end
            end
        end
    end
end

local function catchRows(rows, zone)
    for _, fish in ipairs(Guide.FishData) do
        local coords = fish.maps[zone]
        if coords then
            local id = fish.itemID
            local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
            local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
            local row = getRow(rows, id, name or fish.name, icon or icons.fish, nil, id)
            row.catch = true
            for i = 1, #coords, 2 do addPoint(row, zone, coords[i], coords[i + 1]) end
        end
    end
end

function Resources.Zone(zone, kind)
    local rows, result = {}, {}
    gatherLiteRows(rows, zone, kind)
    if kind == "fish" then
        catchRows(rows, zone)
    else
        referenceNodes(rows, zone, kind)
    end
    local rank, bonus = Character.Skill(skills[kind])
    local skill = rank + bonus
    for _, row in pairs(rows) do
        if row.required then
            row.usable = skill >= row.required
            row.subtitle = L.RESOURCE_SKILL:format(skill, row.required)
        elseif kind == "fish" then
            row.usable = rank > 0
            row.subtitle = row.catch and L.FISH_REPORT or L.FISH_POOL
        end
        result[#result + 1] = row
    end
    table.sort(result, function(a,b)
        if a.usable ~= b.usable then return a.usable == true end
        if (a.required or 0) ~= (b.required or 0) then return (a.required or 0) < (b.required or 0) end
        if a.name ~= b.name then return a.name < b.name end
        return tostring(a.key) < tostring(b.key)
    end)
    return result, skill
end
