local _, Guide = ...
local L = Guide.Locale
local Sources = {}
Guide.Sources = Sources

local kinds = { Quest = "quests", Npc = "npcs", Object = "objects", Item = "items" }

local function keys(records)
    local ids = {}
    for id in pairs(records or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function givers(group)
    if group then return { group.npcs, group.objects, group.items } end
end

local function norgannonFields(db, kind, id)
    local record = db:Peek(kinds[kind], id)
    if not record then return nil end
    if kind == "Item" then
        local drops = record.drops or {}
        local npcDrops, objectDrops, itemDrops = keys(drops.npcs), keys(drops.objects), keys(drops.items)
        local seenNpc, seenObject = {}, {}
        for _, npc in ipairs(npcDrops) do seenNpc[npc] = true end
        for _, object in ipairs(objectDrops) do seenObject[object] = true end
        for _, tableID in ipairs(keys(drops.lootTables)) do
            local reference = db.lootTables and db.lootTables[tableID]
            if reference then
                for _, npc in ipairs(reference.npcs or {}) do
                    if not seenNpc[npc] then npcDrops[#npcDrops + 1] = npc; seenNpc[npc] = true end
                end
                for _, object in ipairs(reference.objects or {}) do
                    if not seenObject[object] then objectDrops[#objectDrops + 1] = object; seenObject[object] = true end
                end
            end
        end
        return { questRewards = record.rewardOf, startQuest = record.startQuest,
            npcDrops = npcDrops, objectDrops = objectDrops, itemDrops = itemDrops, vendors = keys(record.vendors) }
    end
    if record.hidden == true then return nil end
    local goals, prerequisites = record.objectives or {}, record.prerequisites or {}
    local localized = db.PeekLocale and db:PeekLocale("quests", id)
    local objectiveText = localized and localized.objectives or (record.text and record.text.objectives)
    local extra, killCredits = {}, {}
    for _, goal in ipairs(goals.extra or {}) do extra[#extra + 1] = goal end
    for _, triggerID in ipairs(goals.areaTriggers or {}) do
        local trigger = db.areaTriggers and db.areaTriggers[triggerID]
        if trigger then extra[#extra + 1] = { trigger.spawns, nil, L.EXPLORE } end
    end
    for _, goal in ipairs(goals.killCredit or {}) do
        for _, npc in ipairs(goal.npcs or {}) do killCredits[#killCredits + 1] = { npc } end
        if not goal.npcs and goal.credit then killCredits[#killCredits + 1] = { goal.credit } end
    end
    return {
        name = localized and localized.name or record.name,
        startedBy = givers(record.starters), finishedBy = givers(record.finishers),
        requiredLevel = record.minLevel, questLevel = record.level,
        requiredRaces = record.races, requiredClasses = record.classes,
        objectivesText = objectiveText,
        triggerEnd = goals.explore and { goals.explore.text, goals.explore.spawns },
        objectives = { goals.npcs, goals.objects, goals.items, goals.reputation, killCredits },
        extraObjectives = extra, preQuestGroup = prerequisites.all, preQuestSingle = prerequisites.any,
        childQuests = record.childQuests, zoneOrSort = record.zoneOrSort, nextQuestInChain = record.nextQuestInChain,
        requiredMaxLevel = record.maxLevel, parentQuest = record.parentQuest,
        availableUntilCompleted = record.availableUntilCompleted, availableStartingWith = record.availableStartingWith,
        disabledByQuest = record.disabledByQuest, exclusiveTo = record.exclusiveTo,
        requiredSkill = record.requiredSkill, requiredMinRep = record.requiredMinRep,
        requiredMaxRep = record.requiredMaxRep, requiredSpell = record.requiredSpell,
        requiredSpecialization = record.requiredSpecialization, breadcrumbForQuestId = record.breadcrumbForQuestId,
        breadcrumbs = record.breadcrumbs, requiredRanks = record.requiredRanks,
    }
end

function Sources.Catalog()
    local db = LibQuestieDB
    if db and db.RequireContract and db.RequireContract(3) then
        return db, "QuestieDB"
    end

    db = NorgannonDB
    if not (db and db.RequireSchema and db.Peek and db:RequireSchema(1, 2)) then return nil end

    local catalog = {
        Enum = db.enums or {},
        Support = { Get = function()
            return { private = { areaIdToUiMapId = db.maps and db.maps.areaToUiMap } }
        end },
        RewardInfo = function(id)
            local record = db:Peek("quests", id)
            return record and record.rewards
        end,
    }
    for kind, name in pairs(kinds) do
        local entityKind, records = kind, db[name] or {}
        catalog[kind] = {
            Exists = function(id) return records[id] ~= nil end,
            GetAllIds = function() return keys(records) end,
            Get = function(id, field)
                if field == "name" and db.L then return db:L(kinds[entityKind], id, "name") end
                local record = db:Peek(kinds[entityKind], id)
                return record and record[field]
            end,
            GetAll = function(id, fields)
                local record = norgannonFields(db, entityKind, id)
                if not record then return nil end
                local result = {}
                for i, field in ipairs(fields) do result[i] = record[field] end
                return result
            end,
        }
    end
    return catalog, "NorgannonDB"
end
