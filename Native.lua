local _, Guide = ...
local L = Guide.Locale
local Native = {}
Guide.Native = Native

local entries, snapshots, requested = {}, {}, {}
local empty = {}

function Native.Invalidate()
    snapshots = {}
end

function Native.DataLoaded(id)
    if requested[id] ~= true then return false end
    requested[id] = "loaded"
    Native.Invalidate()
    return true
end

local function quest(id, title, level)
    local data = C_QuestLog
    title = title or (data.GetTitleForQuestID and data.GetTitleForQuestID(id))
    level = level or (data.GetQuestDifficultyLevel and data.GetQuestDifficultyLevel(id))
    if type(title) ~= "string" or title == "" then
        title = L.UNKNOWN_QUEST:format(id)
        if data.RequestLoadQuestByID and not requested[id] then
            requested[id] = true
            C_Timer.After(0, function() data.RequestLoadQuestByID(id) end)
        end
    end
    if type(level) ~= "number" or level == 0 then level = nil end
    local result = {
        id = id, name = title, level = level, native = true,
        areas = {}, lines = {}, starterItems = {}, givers = {}, objectives = {}, finishers = {},
        allBefore = {}, anyBefore = {}, after = {}, excludes = {},
    }
    for _, objective in ipairs(data.GetQuestObjectives and data.GetQuestObjectives(id) or empty) do
        if type(objective.text) == "string" and objective.text ~= "" then
            result.lines[#result.lines + 1] = objective.text
        end
    end
    entries[id] = result
    return result
end

local function inMap(result, zone, relation, map, x, y)
    local locations = { start = "givers", objective = "objectives", finish = "finishers" }
    local labels = { start = L.NATIVE_START, objective = L.NATIVE_OBJECTIVE, finish = L.NATIVE_FINISH }
    local area = result.areas[zone] or {}
    area[relation] = true
    result.areas[zone] = area
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or y < 0 or x > 1 or y > 1 or (x == 0 and y == 0) then return end
    local list = result[locations[relation]]
    for _, source in ipairs(list) do
        local point = source.points[1]
        if point.mapID == map and point.x == x * 100 and point.y == y * 100 then return end
    end
    list[#list + 1] = { name = labels[relation], points = { { mapID = map, zone = zone, x = x * 100, y = y * 100 } } }
end

function Native.Map(zone)
    if not zone then return empty end
    if snapshots[zone] then return snapshots[zone] end
    local result, byID = {}, {}
    local function get(id, title, level)
        if not byID[id] then
            byID[id] = quest(id, title, level)
            result[#result + 1] = byID[id]
        end
        return byID[id]
    end

    local data = C_QuestLog
    for _, pin in ipairs(data.GetQuestsOnMap and data.GetQuestsOnMap(zone) or empty) do
        local id, pinMap = pin.questID, pin.mapID or zone
        if type(id) == "number" and id > 0 and Guide.Data.ZoneForMap(pinMap) == zone then
            local relation = pin.isQuestStart and "start" or "objective"
            inMap(get(id), zone, relation, pinMap, pin.x, pin.y)
        end
    end

    if data.GetNumQuestLogEntries and data.GetInfo and data.GetNextWaypoint then
        local count = data.GetNumQuestLogEntries() or 0
        for index = 1, count do
            local info = data.GetInfo(index)
            if info and not info.isHeader and type(info.questID) == "number" and info.questID > 0 then
                local map, x, y = data.GetNextWaypoint(info.questID)
                if map and Guide.Data.ZoneForMap(map) == zone then
                    inMap(get(info.questID, info.title, info.level), zone, "objective", map, x, y)
                elseif data.GetQuestUiMapID and Guide.Data.ZoneForMap(data.GetQuestUiMapID(info.questID)) == zone then
                    inMap(get(info.questID, info.title, info.level), zone, "objective", zone)
                end
            end
        end
    end

    snapshots[zone] = result
    return result
end

function Native.Quest(id)
    return entries[id]
end
