local _, Guide = ...
local L = Guide.Locale
local Data, database = {}, nil
local Native, Character = Guide.Native, Guide.Character
Guide.Data = Data

local ipairs, pairs = ipairs, pairs
local empty = {}
local mapByArea = { [17] = 1413, [331] = 1440, [406] = 1442 }
local quests, zones, itemsByQuest, startersByQuest = {}, {}, {}, {}
local names, positions, itemSources, mapInfo = {}, {}, {}, {}
local zoneCache = {}
local questFields = {
    "name", "startedBy", "finishedBy", "requiredLevel", "questLevel", "requiredRaces", "requiredClasses",
    "objectivesText", "triggerEnd", "objectives", "preQuestGroup", "preQuestSingle", "childQuests",
    "zoneOrSort", "nextQuestInChain", "extraObjectives", "requiredMaxLevel", "parentQuest",
    "availableUntilCompleted", "availableStartingWith", "disabledByQuest", "exclusiveTo",
    "requiredSkill", "requiredMinRep", "requiredMaxRep", "requiredSpell", "requiredSpecialization",
    "breadcrumbForQuestId", "breadcrumbs", "requiredRanks",
}
local itemFields = { "questRewards", "startQuest" }
local sourceFields = { "npcDrops", "objectDrops", "itemDrops", "vendors" }
local types = { [1] = "Npc", [2] = "Object", [3] = "Item" }
local entityLabels = { Npc = L.ENTITY_NPC, Object = L.ENTITY_OBJECT, Item = L.ENTITY_ITEM }

function Data.MapInfo(mapID)
    if not mapID or not C_Map then return nil end
    local info = mapInfo[mapID]
    if not info then
        info = C_Map.GetMapInfo(mapID)
        mapInfo[mapID] = info
    end
    return info
end

function Data.ZoneName(mapID)
    local info = Data.MapInfo(mapID)
    return info and info.name or L.UNKNOWN_ZONE
end

local function zoneForMap(mapID)
    if not mapID then return end
    local cached = zoneCache[mapID]
    if cached ~= nil then return cached or nil end
    local start, seen = mapID, {}
    while mapID and mapID > 0 and not seen[mapID] do
        seen[mapID] = true
        local info = Data.MapInfo(mapID)
        if not info then break end
        if info.mapType == 3 then
            zoneCache[start] = mapID
            return mapID
        end
        mapID = info.parentMapID
    end
    zoneCache[start] = false
end

Data.ZoneForMap = zoneForMap

local function addUnique(list, value)
    if not value then return end
    for _, existing in ipairs(list) do
        if existing == value then return end
    end
    list[#list + 1] = value
end

local function appendIndex(index, key, value)
    local list = index[key]
    if not list then
        list = {}
        index[key] = list
    end
    addUnique(list, value)
end

local function readMaps(db)
    local zoneData = db.Support and db.Support.Get("ZoneDB")
    local function read(raw)
        if type(raw) == "string" then
            for areaID, mapID in raw:gmatch("%[(%d+)%]%s*=%s*(%d+)") do
                mapByArea[tonumber(areaID)] = tonumber(mapID)
            end
        elseif type(raw) == "table" then
            for areaID, mapID in pairs(raw) do
                if type(areaID) == "number" and type(mapID) == "number" then mapByArea[areaID] = mapID end
            end
        end
    end
    local private = zoneData and zoneData.private
    if private then
        read(private.areaIdToUiMapId)
        read(private.areaIdToUiMapIdOverride)
    end
end

local function entityName(kind, id)
    local key = kind .. id
    if not names[key] then
        names[key] = (database and database[kind].Get(id, "name"))
            or (kind == "Item" and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
            or entityLabels[kind]:format(id)
    end
    return names[key]
end

local function addSpawns(list, spawns, label)
    for areaID, points in pairs(spawns or empty) do
        local mapID = mapByArea[areaID]
        local zone = zoneForMap(mapID)
        if zone then
            for _, point in ipairs(points) do
                local x, y = point[1], point[2]
                if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0 and x <= 100 and y <= 100 and (x ~= 0 or y ~= 0) then
                    list[#list + 1] = { mapID = mapID, zone = zone, x = x, y = y, name = label }
                end
            end
        end
    end
end

local function entityPoints(kind, id)
    local key = kind .. id
    local points = positions[key]
    if not points then
        points = {}
        addSpawns(points, database[kind].Get(id, "spawns"), entityName(kind, id))
        positions[key] = points
    end
    return points
end

local function addEntity(list, kind, id, labelKey)
    local entry = { kind = kind, id = id, name = entityName(kind, id), labelKey = labelKey, points = entityPoints(kind, id) }
    list[#list + 1] = entry
    return entry
end

local function readItemSources(id)
    local found = itemSources[id]
    if found then return found end
    found = {}
    local fields = database.Item.GetAll(id, sourceFields) or empty
    for _, npcID in ipairs(fields[1] or empty) do addEntity(found, "Npc", npcID, "ITEM_DROPPED_BY") end
    for _, objectID in ipairs(fields[2] or empty) do addEntity(found, "Object", objectID, "ITEM_LOOTED_FROM") end
    for _, itemID in ipairs(fields[3] or empty) do
        found[#found + 1] = { name = entityName("Item", itemID), labelKey = "ITEM_CONTAINED_IN", points = empty }
    end
    for _, npcID in ipairs(fields[4] or empty) do addEntity(found, "Npc", npcID, "ITEM_SOLD_BY") end
    itemSources[id] = found
    return found
end

local function sourceEntries(index, list, areaMap, label)
    for _, entry in ipairs(list) do
        for _, point in ipairs(entry.points) do
            local entryAreas = index[point.zone]
            if not entryAreas then
                entryAreas = {}
                index[point.zone] = entryAreas
            end
            entryAreas[label] = true
            areaMap[point.zone] = true
        end
    end
end

local function getGivers(groups, starterItems)
    local givers = {}
    for group, kind in ipairs(types) do
        if kind ~= "Item" then
            for _, id in ipairs(groups and groups[group] or empty) do addEntity(givers, kind, id) end
        end
    end
    for _, id in ipairs(starterItems or empty) do
        for _, source in ipairs(readItemSources(id)) do givers[#givers + 1] = source end
    end
    return givers
end

local function getObjectives(fields)
    local list = {}
    local objectives = fields[10] or empty
    for group, kind in ipairs(types) do
        for _, spec in ipairs(objectives[group] or empty) do
            if type(spec) == "table" and type(spec[1]) == "number" then
                if kind == "Item" then
                    for _, source in ipairs(readItemSources(spec[1])) do
                        if source.labelKey ~= "ITEM_SOLD_BY" then list[#list + 1] = source end
                    end
                else
                    addEntity(list, kind, spec[1])
                end
            end
        end
    end
    for _, spec in ipairs(objectives[5] or empty) do
        if type(spec) == "table" and type(spec[1]) == "number" and database.Npc.Exists(spec[1]) then
            addEntity(list, "Npc", spec[1])
        end
    end
    local function addObjectiveSpawns(spawns, title)
        local points = {}
        addSpawns(points, spawns, title)
        if #points > 0 then list[#list + 1] = { name = title, points = points } end
    end
    local trigger = fields[9]
    if trigger then addObjectiveSpawns(trigger[2], trigger[1] or L.QUEST_OBJECTIVE) end
    for _, spec in ipairs(fields[16] or empty) do
        addObjectiveSpawns(spec[1], spec[3] or L.QUEST_OBJECTIVE)
        for _, reference in ipairs(spec[5] or empty) do
            local kind, id = reference[1], reference[2]
            if kind == "monster" or kind == "npc" then
                if type(id) == "number" then addEntity(list, "Npc", id) end
            elseif kind == "object" and type(id) == "number" then
                addEntity(list, "Object", id)
            end
        end
    end
    return list
end

local function indexQuest(id)
    local fields = database.Quest.GetAll(id, questFields)
    if not fields or not fields[1] then return end
    local starterItems = {}
    for _, itemID in ipairs(fields[2] and fields[2][3] or empty) do addUnique(starterItems, itemID) end
    for _, itemID in ipairs(startersByQuest[id] or empty) do addUnique(starterItems, itemID) end
    local entry = {
        id = id, name = fields[1], min = fields[4], level = fields[5], raceMask = fields[6], classMask = fields[7],
        lines = fields[8] or empty, allBefore = fields[11] or empty, anyBefore = fields[12] or empty,
        after = {}, max = fields[17], parent = fields[18], untilQuest = fields[19],
        fromQuest = fields[20], disabledBy = fields[21], excludes = fields[22] or empty,
        skill = fields[23], minRep = fields[24], maxRep = fields[25], spell = fields[26],
        specialization = fields[27], breadcrumb = fields[28], breadcrumbs = fields[29] or empty,
        ranks = fields[30] or empty, nextQuest = fields[15], areaID = fields[14],
        starterItems = starterItems, givers = getGivers(fields[2], starterItems),
        finishers = getGivers(fields[3]), objectives = getObjectives(fields), areas = {},
    }
    for _, nextID in ipairs(fields[13] or empty) do addUnique(entry.after, nextID) end
    if fields[15] and fields[15] > 0 then addUnique(entry.after, fields[15]) end
    quests[id] = entry
    local affected = {}
    sourceEntries(entry.areas, entry.givers, affected, "start")
    sourceEntries(entry.areas, entry.objectives, affected, "objective")
    sourceEntries(entry.areas, entry.finishers, affected, "finish")
    local catalogZone = zoneForMap(mapByArea[fields[14]])
    if catalogZone and not affected[catalogZone] then
        entry.areas[catalogZone] = { catalog = true }
        affected[catalogZone] = true
    end
    for mapID in pairs(affected) do
        local list = zones[mapID]
        if not list then list = {}; zones[mapID] = list end
        list[#list + 1] = entry
    end
end

local function indexItem(id)
    local fields = database.Item.GetAll(id, itemFields)
    if not fields then return end
    for _, questID in ipairs(fields[1] or empty) do appendIndex(itemsByQuest, questID, id) end
    if fields[2] and fields[2] > 0 then appendIndex(startersByQuest, fields[2], id) end
end

-- Yield between small batches so opening the map does not block the UI.
function Data.Start(onReady)
    if Data.started then return end
    Data.started = true
    database, Data.source = Guide.Sources.Catalog()
    if not database then
        Data.source = L.SOURCE_NATIVE
        Data.ready = true
        onReady()
        return
    end
    readMaps(database)
    local itemIDs = database.Item.GetAllIds()
    local stages = {
        { itemIDs, indexItem },
        { database.Quest.GetAllIds(), indexQuest },
    }
    local stageIndex, cursor, ids = 1, 1
    local function advance()
        local stage = stages[stageIndex]
        if not stage then
            Data.ready = true
            onReady()
            return
        end
        ids = stage[1]
        local started = debugprofilestop and debugprofilestop()
        local last = math.min(#ids, cursor + 499)
        while cursor <= last do
            stage[2](ids[cursor])
            cursor = cursor + 1
            if started and debugprofilestop() - started >= 4 then break end
        end
        if cursor > #ids then
            stageIndex, cursor = stageIndex + 1, 1
        end
        C_Timer.After(0, advance)
    end
    C_Timer.After(0, advance)
end

function Data.IsNative() return Data.ready == true and database == nil end

function Data.Quest(id)
    if Data.IsNative() then return Native.Quest(id) end
    return quests[id]
end

function Data.Zone(mapID)
    if Data.IsNative() then return Native.Map(mapID) end
    return zones[mapID] or empty
end
function Data.ItemName(id) return entityName("Item", id) end

local function hasMask(mask, flag)
    return not mask or mask <= 0 or not flag or math.floor(mask / flag) % 2 == 1
end

function Data.Player()
    local _, _, race = UnitRace("player")
    local _, _, class = UnitClass("player")
    local raceMasks = database and database.Enum and database.Enum.raceMaskById
    local _, classToken = UnitClass("player")
    local armor = ({ WARRIOR = 3, PALADIN = 3, SHAMAN = 2, HUNTER = 2, ROGUE = 2, DRUID = 2 })[classToken] or 1
    local level = UnitLevel("player")
    if level >= 40 then
        if classToken == "WARRIOR" or classToken == "PALADIN" then armor = 4 end
        if classToken == "HUNTER" or classToken == "SHAMAN" then armor = 3 end
    end
    local faction = UnitFactionGroup("player")
    return {
        faction = faction == "Horde" and "H" or faction == "Alliance" and "A",
        level = level, race = (raceMasks and raceMasks[race]) or (race and 2 ^ (race - 1)),
        class = class and 2 ^ (class - 1), classToken = classToken, armor = armor,
    }
end

function Data.OnQuest(id)
    return id and id > 0 and C_QuestLog.IsOnQuest(id)
end

function Data.Completed(id)
    return id and id > 0 and C_QuestLog.IsQuestFlaggedCompleted(id)
end

local function started(id)
    return Data.Completed(id) or Data.OnQuest(id)
end

local function questRequirements(quest)
    if quest.skill and Character.Skill(quest.skill[1]) < quest.skill[2] then return false end
    if quest.minRep and (Character.Reputation(quest.minRep[1]) or -math.huge) < quest.minRep[2] then return false end
    if quest.maxRep and (Character.Reputation(quest.maxRep[1]) or math.huge) >= quest.maxRep[2] then return false end
    if quest.specialization and quest.specialization > 0 and not Character.HasSpell(quest.specialization) then return false end
    if quest.spell and quest.spell ~= 0 and (not not Character.HasSpell(math.abs(quest.spell))) ~= (quest.spell > 0) then
        return false
    end
    for _, rank in ipairs(quest.ranks or empty) do
        local id, required = rank[1], rank[2]
        if id and required then
            local skill = Character.Skill(id)
            if (required > 0 and skill < required) or (required < 0 and skill >= -required) then return false end
        end
    end
    return true
end

function Data.Status(quest, player)
    if Data.Completed(quest.id) then return "done", L.STATUS_DONE end
    if Data.OnQuest(quest.id) then return "active", L.STATUS_ACTIVE end
    if not hasMask(quest.raceMask, player.race) or not hasMask(quest.classMask, player.class) then return "hidden" end
    if quest.min and player.level < quest.min then return "level", L.STATUS_MIN_LEVEL:format(quest.min) end
    if quest.max and quest.max > 0 and player.level > quest.max then return "blocked", L.STATUS_MAX_LEVEL end
    if not questRequirements(quest) then return "blocked", L.STATUS_BLOCKED end
    if #quest.anyBefore > 0 then
        local satisfied = false
        for _, id in ipairs(quest.anyBefore) do
            if Data.Completed(id) then satisfied = true; break end
        end
        if not satisfied then return "blocked", L.STATUS_MISSING_ALTERNATIVE end
    else
        for _, id in ipairs(quest.allBefore) do
            local complete = Data.Completed(math.abs(id))
            local prerequisite = id > 0 and quests[id]
            if prerequisite and not complete then
                for _, alternative in ipairs(prerequisite.excludes) do
                    if Data.Completed(alternative) then complete = true; break end
                end
            end
            if not complete then return "blocked", L.STATUS_MISSING_PREVIOUS end
        end
    end
    if quest.parent and quest.parent > 0 and not Data.OnQuest(quest.parent) then return "blocked", L.STATUS_PARENT end
    if Data.Completed(quest.untilQuest) or Data.OnQuest(quest.disabledBy) then return "blocked", L.STATUS_BLOCKED end
    if quest.fromQuest and quest.fromQuest > 0 and not (Data.OnQuest(quest.fromQuest) or Data.Completed(quest.fromQuest)) then
        return "blocked", L.STATUS_MISSING_RELATED
    end
    for _, id in ipairs(quest.excludes) do
        if Data.Completed(id) or Data.OnQuest(id) then return "blocked", L.STATUS_EXCLUDED end
    end
    if started(quest.nextQuest) or started(quest.breadcrumb) then return "blocked", L.STATUS_BLOCKED end
    for _, id in ipairs(quest.breadcrumbs or empty) do
        if Data.OnQuest(id) then return "blocked", L.STATUS_BLOCKED end
    end
    if quest.native then
        for _, area in pairs(quest.areas) do
            if area.start then return "possible", L.STATUS_VISIBLE_START end
        end
        return "native", L.STATUS_VISIBLE
    end
    if #quest.starterItems > 0 then return "starter", L.STATUS_ITEM_START end
    return "possible", L.STATUS_REQUIREMENTS_MET
end

function Data.Difficulty(quest, player)
    local level = quest.level and quest.level > 0 and quest.level or player.level
    local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    if color and color.r then return level, color.r, color.g, color.b end
    local delta = level - player.level
    if delta >= 5 then return level, 1, .2, .2 end
    if delta >= 3 then return level, 1, .5, .25 end
    if delta >= -2 then return level, 1, .82, 0 end
    if level > player.level - math.floor(player.level / 10) - 5 then return level, .25, .85, .25 end
    return level, .6, .6, .6
end

function Data.IsDungeonQuest(quest)
    local tag
    if C_QuestLog.GetQuestTagInfo then
        local info = C_QuestLog.GetQuestTagInfo(quest.id)
        tag = info and info.tagID
    elseif GetQuestTagInfo then
        tag = GetQuestTagInfo(quest.id)
    end
    -- Dungeon and Heroic, as used by the client's quest tags.
    if tag and tag ~= 0 then return tag == 81 or tag == 85 end
    local info = quest.areaID and Data.MapInfo(mapByArea[quest.areaID])
    return info and info.mapType == (Enum and Enum.UIMapType and Enum.UIMapType.Dungeon or 4)
end

function Data.ZoneQuests(mapID, player, hideTrivial, mode, hideDungeons)
    local result = {}
    for _, quest in ipairs(Data.Zone(mapID)) do
        local area = quest.areas[mapID]
        local status, label = Data.Status(quest, player)
        local active = status == "active"
        local available = area.start and (status == "possible" or status == "starter")
        if ((active and mode ~= nil) or (available and mode ~= "active"))
            and not (hideDungeons and Data.IsDungeonQuest(quest)) then
            local level, r, g, b = Data.Difficulty(quest, player)
            local trivial = quest.level and quest.level > 0 and math.max(r,g,b) - math.min(r,g,b) < .08
            if active or not (hideTrivial and trivial) then
                result[#result + 1] = { quest = quest, status = status, label = label, level = level, r = r, g = g, b = b }
            end
        end
    end
    table.sort(result, function(a,b)
        if a.level ~= b.level then return a.level < b.level end
        if a.quest.name ~= b.quest.name then return a.quest.name < b.quest.name end
        return a.quest.id < b.quest.id
    end)
    return result
end

function Data.Rewards(questID)
    local result, seen = {}, {}
    local function add(id, kind, count, name, quality, usable)
        if type(id) ~= "number" or id <= 0 or seen[id] then return end
        seen[id] = true
        result[#result + 1] = {
            id = id, name = name or Data.ItemName(id), kind = kind, count = count or 1,
            quality = quality, usable = usable,
        }
    end
    local function fromGame(countFunc, getFunc, kind)
        if not (countFunc and getFunc) then return end
        local ok, count = pcall(countFunc, questID)
        if not ok or type(count) ~= "number" then return end
        for index = 1, count do
            local read, name, _, quantity, quality, usable, id = pcall(getFunc, index, questID)
            if read then add(id, kind, quantity, name, quality, usable) end
        end
    end
    if not HaveQuestRewardData or HaveQuestRewardData(questID) then
        fromGame(GetNumQuestLogRewards, GetQuestLogRewardInfo, L.REWARD_GUARANTEED)
        fromGame(GetNumQuestLogChoices, GetQuestLogChoiceInfo, L.REWARD_CHOICE)
    end
    local known = database and database.RewardInfo and database.RewardInfo(questID)
    if known then
        for _, id in ipairs(known.items or empty) do add(id, known.choice and L.REWARD_CHOICE or L.REWARD_RECORDED) end
    end
    for _, id in ipairs(itemsByQuest[questID] or empty) do add(id, L.REWARD_RECORDED) end
    table.sort(result, function(left, right) return left.name < right.name end)
    return result
end
