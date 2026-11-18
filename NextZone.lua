local _, Guide = ...
local Data, Pins, ZoneMap = Guide.Data, Guide.QuestPins, Guide.ZoneMap
local NextZone = {}
Guide.NextZone = NextZone

local function worldPosition(mapID, position)
    local instance, vector = C_Map.GetWorldPosFromMapPos(mapID, position)
    if not vector then return end
    local x, y = vector:GetXY()
    if issecretvalue and (issecretvalue(instance) or issecretvalue(x) or issecretvalue(y)) then return end
    return { instance = instance, x = x, y = y }
end

local function worldPoint(mapID, x, y)
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, result = pcall(worldPosition, mapID, CreateVector2D(x, y))
    if ok then return result end
end

local function distance(origin, target)
    if origin and target and origin.instance == target.instance then
        return math.sqrt((origin.x - target.x)^2 + (origin.y - target.y)^2)
    end
end

local function playerPosition(mapID)
    local position = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return end
    local x, y = position:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return end
    if x and y and (x ~= 0 or y ~= 0) then return x, y end
end

local function addPoints(points, quest, mapID, stage)
    for _, pin in ipairs(Pins.Points(quest, mapID, stage)) do
        local x, y = ZoneMap.Translate(pin, mapID)
        if x and y then
            points[#points + 1] = { id = quest.id, x = x, y = y }
        end
    end
end

local function bestCluster(points, mapID, origin)
    local radius = .12
    local cells = {}
    for _, point in ipairs(points) do
        point.col, point.row = math.floor(point.x / radius), math.floor(point.y / radius)
        local key = point.col .. ":" .. point.row
        if not cells[key] then cells[key] = {} end
        cells[key][#cells[key] + 1] = point
    end
    local bestSize, bestDistance = 0, nil
    for _, anchor in ipairs(points) do
        local seen, size = {}, 0
        for col = anchor.col - 1, anchor.col + 1 do
            for row = anchor.row - 1, anchor.row + 1 do
                local cell = cells[col .. ":" .. row]
                if cell then
                    for _, point in ipairs(cell) do
                        if not seen[point.id] and (point.x - anchor.x)^2 + (point.y - anchor.y)^2 <= radius^2 then
                            seen[point.id] = true
                            size = size + 1
                        end
                    end
                end
            end
        end
        if size >= bestSize then
            local travel = origin and distance(origin, worldPoint(mapID, anchor.x, anchor.y))
            if size > bestSize or (travel and (not bestDistance or travel < bestDistance)) then
                bestSize, bestDistance = size, travel
            end
        end
    end
    return bestSize, bestDistance
end

local function zoneSummary(mapID, player, settings, origin)
    local starts, active, points, xpQuests = 0, 0, {}, {}
    for _, result in ipairs(Data.ZoneQuests(mapID, player, true, "both", settings.hideDungeonQuests, nil, settings.showEventQuests)) do
        local quest = result.quest
        if result.status == "active" then
            local ready = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(quest.id)
            local stage = ready and "finish" or "objective"
            if quest.areas[mapID][stage] then
                active = active + 1
                xpQuests[#xpQuests + 1] = result
            end
        elseif result.level >= player.level - 2 and result.level <= player.level + 3 then
            starts = starts + 1
            xpQuests[#xpQuests + 1] = result
            addPoints(points, quest, mapID, "start")
        end
    end
    local cluster, travel = bestCluster(points, mapID, origin)
    return starts, active, cluster, travel, xpQuests
end

local function continent(mapID)
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    local seen = {}
    while mapID and mapID > 0 and not seen[mapID] do
        seen[mapID] = true
        local info = Data.MapInfo(mapID)
        if not info then return end
        if info.mapType == continentType then return mapID end
        mapID = info.parentMapID
    end
end

-- Dominant questing faction. The quest catalogue still supplies character-specific counts.
local zoneFaction = {
    [1411] = "H", [1412] = "H", [1413] = "H", [1420] = "H", [1421] = "H",
    [1454] = "H", [1456] = "H", [1458] = "H",
    [1426] = "A", [1429] = "A", [1431] = "A", [1432] = "A", [1433] = "A",
    [1436] = "A", [1437] = "A", [1438] = "A", [1439] = "A",
    [1453] = "A", [1455] = "A", [1457] = "A",
}

function NextZone.Zones(currentZone, zones, player, settings)
    local hereContinent = continent(currentZone)
    local origin
    if currentZone then
        local x, y = playerPosition(currentZone)
        origin = worldPoint(currentZone, x or .5, y or .5)
    end

    local result = {}
    for _, zone in ipairs(zones) do
        local mapID = zone.mapID
        local current = mapID == currentZone
        local zoneContinent = continent(mapID)
        local sameContinent = hereContinent and hereContinent == zoneContinent
        local hubOrigin = (current or sameContinent) and origin or nil
        local starts, active, cluster, travel, xpQuests = 0, 0, 0, nil, nil
        if Data.ready then
            starts, active, cluster, travel, xpQuests = zoneSummary(mapID, player, settings, hubOrigin)
        end

        local low, high, estimated = Data.ZoneLevels(mapID)
        local gap = low and math.max(low - player.level, player.level - high, 0) or math.huge
        local colorLevel = player.level
        if low and player.level < low then colorLevel = math.max(low, player.level + 3) end
        if high and player.level > high then colorLevel = math.min(high, player.level - 3) end
        local faction = zoneFaction[mapID]
        local hostile = faction ~= nil and player.faction ~= nil and faction ~= player.faction
        local useful = starts > 0 or (active > 0 and gap <= 3)
        local recommended = current or (useful and (not low or (low <= player.level and gap <= 3)))
        result[#result + 1] = {
            mapID = mapID, name = zone.name, region = (zoneContinent and Data.ZoneName(zoneContinent)) or zone.region,
            current = current, starts = starts, active = active, cluster = cluster, travel = travel, xpQuests = xpQuests,
            low = low, high = high, estimated = estimated, gap = gap, colorLevel = colorLevel,
            faction = faction, hostile = hostile, recommended = recommended,
        }
    end
    table.sort(result, function(a, b)
        if a.hostile ~= b.hostile then return not a.hostile end
        if a.gap ~= b.gap then return a.gap < b.gap end
        if a.starts ~= b.starts then return a.starts > b.starts end
        if a.active ~= b.active then return a.active > b.active end
        if a.current ~= b.current then return a.current end
        if a.cluster ~= b.cluster then return a.cluster > b.cluster end
        local aTravel, bTravel = a.travel or math.huge, b.travel or math.huge
        if aTravel ~= bTravel then return aTravel < bTravel end
        if a.low ~= b.low and a.low and b.low then return a.low < b.low end
        if a.name ~= b.name then return a.name < b.name end
        return a.mapID < b.mapID
    end)
    return result
end
