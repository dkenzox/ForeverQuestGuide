local _, Guide = ...
local Data, Gear, L = Guide.Data, Guide.Gear, Guide.Locale
local Entries = {}
Guide.Entries = Entries

local function collect(list, sources, zone)
    for _, source in ipairs(sources) do
        for _, point in ipairs(source.points) do
            if point.zone == zone then list[#list + 1] = point end
        end
    end
end

local function questPoints(quest, zone)
    local points = {}
    collect(points, quest.givers, zone)
    return points
end

function Entries.Quests(quests, zone)
    local entries = {}
    for _, result in ipairs(quests) do
        local quest = result.quest
        local title = quest.level and ("[%d] %s"):format(result.level, quest.name) or quest.name
        local points = questPoints(quest, zone)
        local lines = table.concat(quest.lines, "\n")
        entries[#entries + 1] = {
            key = quest.id, title = title, quest = quest, points = points,
            subtitle = #quest.starterItems > 0 and L.RELATION_ITEM or L.RELATION_START,
            description = lines ~= "" and lines or (points[1] and (L.QUEST_GIVER .. " · " .. (points[1].name or L.NATIVE_START))),
            icon = Guide.View.icons.quests, tint = {r = result.r, g = result.g, b = result.b},
        }
    end
    return entries
end

local function addLocations(entries, sources, label)
    for _, source in ipairs(sources) do
        local kind = source.labelKey and L[source.labelKey] or label
        if #source.points == 0 then
            entries[#entries + 1] = { title = source.name, subtitle = kind .. " · " .. L.NO_COORDINATES }
        else
            for _, point in ipairs(source.points) do
                entries[#entries + 1] = {
                    title = source.name, subtitle = kind .. " · " .. Data.ZoneName(point.mapID),
                    points = { point },
                }
            end
        end
    end
end

function Entries.Quest(quest)
    local entries = {}
    addLocations(entries, quest.givers, L.QUEST_GIVER)
    for _, id in ipairs(quest.starterItems) do
        entries[#entries + 1] = { title = Data.ItemName(id), subtitle = L.QUEST_STARTING_ITEM, itemID = id }
    end
    for _, line in ipairs(quest.lines) do
        entries[#entries + 1] = { title = line, subtitle = L.QUEST_OBJECTIVE, description = line }
    end
    addLocations(entries, quest.objectives, L.QUEST_OBJECTIVE)
    addLocations(entries, quest.finishers, L.QUEST_FINISHER)
    for _, reward in ipairs(Data.Rewards(quest.id)) do
        local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(reward.id)
        entries[#entries + 1] = {
            title = reward.name, subtitle = reward.kind, icon = icon, itemID = reward.id,
        }
    end
    return entries
end

function Entries.Gear(zone, player, quests)
    local items, waiting = Gear.Zone(zone, player, quests)
    local entries = {}
    for _, item in ipairs(items) do
        local points = {}
        for _, source in ipairs(item.sources) do
            if source.quest then
                collect(points, source.quest.givers, zone)
            else
                points[#points + 1] = source.point
            end
        end
        local source = item.sources[1]
        local origin = source.quest and source.quest.name or source.point.name
        entries[#entries + 1] = {
            key = item.id, title = item.name, item = item, points = points, itemID = item.id, icon = item.icon, tint = item.tint,
            subtitle = item.typeName .. " · " .. L.ITEM_LEVEL:format(item.itemLevel),
            description = origin .. "\n" .. L.REQUIRED_ITEM_LEVEL:format(item.level),
        }
    end
    return entries, waiting
end

function Entries.Item(item, zone)
    local entries = {}
    local seen = {}
    for _, source in ipairs(item.sources) do
        if source.quest then
            entries[#entries + 1] = {
                title = source.quest.name, subtitle = source.subtitle,
                quest = source.quest, points = questPoints(source.quest, zone), icon = Guide.View.icons.quests,
            }
        else
            local point = source.point
            local key = ("%s:%s:%d:%.2f:%.2f"):format(source.labelKey, point.name, point.mapID, point.x, point.y)
            if not seen[key] then
                seen[key] = true
                entries[#entries + 1] = { title = point.name, subtitle = L[source.labelKey], points = { point } }
            end
        end
    end
    return entries
end

function Entries.Resources(zone, kind)
    local rows, skill = Guide.Resources.Zone(zone, kind)
    local entries = {}
    for _, row in ipairs(rows) do
        local description = kind == "fish" and (row.catch and L.FISH_DESCRIPTION or L.POOL_DESCRIPTION) or L.NODE_DESCRIPTION
        if #row.points > 0 then description = description .. " " .. L.LOCATION_COUNT:format(#row.points) end
        entries[#entries + 1] = {
            key = row.key, title = row.name, subtitle = row.subtitle, description = description,
            icon = row.icon, points = row.points, itemID = row.itemID,
            tint = row.usable and {r = .77, g = .94, b = .69} or {r = .82, g = .77, b = .70},
        }
    end
    return entries, skill
end
