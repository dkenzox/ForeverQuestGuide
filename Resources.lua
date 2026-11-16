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

local itemByResource = {
    copper_vein = 2770, tin_vein = 2771, silver_vein = 2775, iron_deposit = 2772,
    gold_vein = 2776, mithril_deposit = 3858, truesilver_deposit = 7911, dark_iron_deposit = 11370,
    small_thorium_vein = 10620, rich_thorium_vein = 10620, heavy_thorium_vein = 10620,
    hakkari_thorium_vein = 10620, incendicite_mineral_vein = 3340, lesser_bloodstone_deposit = 4278,
    indurium_mineral_vein = 5833, small_obsidian_chunk = 22202, large_obsidian_chunk = 22203,
    cold_iron_deposit = 219401, fools_gold_vein = 2776, starsilver_vein = 219486,
    greater_moonstone_formation = 219515, chunk_of_amber = 2770, large_chunk_of_amber = 2770,
    silverleaf = 765, peacebloom = 2447, earthroot = 2449, mageroyal = 785, briarthorn = 2450,
    stranglekelp = 3820, bruiseweed = 2453, wild_steelbloom = 3355, grave_moss = 3369,
    kingsblood = 3356, liferoot = 3357, fadeleaf = 3818, goldthorn = 3821, khadgars_whisker = 3358,
    wintersbite = 3819, firebloom = 4625, purple_lotus = 8831, arthas_tears = 8836, sungrass = 8838,
    blindweed = 8839, ghost_mushroom = 8845, gromsblood = 8846, golden_sansam = 13464,
    dreamfoil = 13463, mountain_silversage = 13465, plaguebloom = 13466, icecap = 13467,
    black_lotus = 13468, nightmare_moss = 219399, dreamroot = 219444, moonroot = 219514,
    star_lotus = 219454, hyjal_silphium = 274979, tomb_weed = 286204,
    fish_pool_oily_blackmouth = 6358, fish_pool_sagefish = 21071,
}
local chestIcon = "Interface\\Icons\\INV_Misc_TreasureChest_02"

local function itemIcon(id)
    return id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
end

local function resourceIcon(key, kind, nodeIcon)
    if key == "battered_chest" or key == "fish_pool_debris" or key == "fish_pool_wreckage" then
        return chestIcon
    end
    return itemIcon(itemByResource[key]) or nodeIcon or icons[kind]
end

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
            local row = getRow(rows, object.name, name, resourceIcon(object.name, kind, object.icon), object.levels and object.levels[1])
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
            local row = getRow(rows, def[1], name, resourceIcon(def[1], kind), def[3])
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
            local icon = itemIcon(id)
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
