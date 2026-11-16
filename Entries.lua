local _, Guide = ...
local Data, Gear, L, Pins = Guide.Data, Guide.Gear, Guide.Locale, Guide.QuestPins
local Rewards = Guide.Rewards
local Entries = {}
Guide.Entries = Entries

function Entries.QuestTitle(quest, level)
    return quest.level and ("[%d] %s"):format(level, quest.name) or quest.name
end

function Entries.Quests(quests, zone)
    local entries = {}
    local playerLevel = UnitLevel("player")
    for _, result in ipairs(quests) do
        local quest = result.quest
        local active = result.status == "active"
        local points = Pins.Points(quest, zone, active and "objective" or "start")
        if active and #points == 0 then points = Pins.Points(quest, zone, "finish") end
        local lines = table.concat(quest.lines, "\n")
        local subtitle = active and L.STATUS_ACTIVE or (#quest.starterItems > 0 and L.RELATION_ITEM or L.RELATION_START)
        if points[1] and points[1].name then subtitle = subtitle .. " · " .. points[1].name end
        local description = lines ~= "" and lines or subtitle
        if not active and not quest.native and (not quest.min or quest.min <= 0) and result.level > playerLevel then
            subtitle = L.MIN_LEVEL_UNVERIFIED .. " · " .. subtitle
            description = description .. "\n" .. L.MIN_LEVEL_UNVERIFIED
        end
        entries[#entries + 1] = {
            key = quest.id, title = Entries.QuestTitle(quest, result.level), quest = quest, points = points,
            subtitle = subtitle, summary = Rewards.Summary(quest), description = description,
            icon = Guide.View.icons.quests, tint = {r = result.r, g = result.g, b = result.b},
        }
    end
    return entries
end

local function addLocations(entries, sources, stage, localZone)
    for _, source in ipairs(sources) do
        local kind = source.labelKey and L[source.labelKey]
        local byZone, zoneIDs = {}, {}
        for _, point in ipairs(source.points) do
            local group = byZone[point.zone]
            if not group then
                group = {}
                byZone[point.zone] = group
                zoneIDs[#zoneIDs + 1] = point.zone
            end
            group[#group + 1] = Pins.Point(point, stage)
        end
        table.sort(zoneIDs, function(a, b)
            if (a == localZone) ~= (b == localZone) then return a == localZone end
            return a < b
        end)
        if #zoneIDs == 0 then
            entries[#entries + 1] = { title = source.name, subtitle = L.NO_COORDINATES }
        end
        for _, zone in ipairs(zoneIDs) do
            local points = byZone[zone]
            local area = Data.ZoneName(zone)
            entries[#entries + 1] = {
                title = source.name, subtitle = kind and (kind .. " · " .. area) or area,
                points = points, mapZone = zone,
            }
        end
    end
end

function Entries.Quest(quest, zone, section)
    local entries = {}
    if section == "start" then
        addLocations(entries, quest.givers, section, zone)
        for _, id in ipairs(quest.starterItems) do
            entries[#entries + 1] = { title = Data.ItemName(id), subtitle = L.QUEST_STARTING_ITEM, itemID = id }
        end
    elseif section == "objective" then
        local live = Data.OnQuest(quest.id) and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(quest.id)
        local lines = {}
        for _, goal in ipairs(live or {}) do
            if goal.text and goal.text ~= "" then lines[#lines + 1] = goal.text end
        end
        if #lines == 0 then lines = quest.lines end
        for _, line in ipairs(lines) do
            entries[#entries + 1] = { title = line, subtitle = L.QUEST_OBJECTIVE, description = line }
        end
        addLocations(entries, quest.objectives, section, zone)
    elseif section == "finish" then
        addLocations(entries, quest.finishers, section, zone)
    else
        local _, xp, money, items = Rewards.Summary(quest)
        entries.xp, entries.money = xp, money
        entries.totals = xp and money and (money .. "  ·  " .. xp) or (money or xp)
        local groups = {
            { L.REWARD_CHOICE, L.REWARD_CHOOSE_ONE },
            { L.REWARD_GUARANTEED, L.REWARD_ALSO_RECEIVE },
            { L.REWARD_RECORDED, L.REWARD_KNOWN_ITEMS },
        }
        for _, group in ipairs(groups) do
            for _, reward in ipairs(items) do
                if reward.kind == group[1] then
                    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(reward.id)
                    local quality = reward.quality or (C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(reward.id))
                    entries[#entries + 1] = {
                        key = reward.id, title = reward.name, subtitle = reward.kind, heading = group[2],
                        icon = icon, itemID = reward.id, quantity = reward.count, usable = reward.usable,
                        quality = quality,
                    }
                end
            end
        end
    end
    return entries
end

function Entries.Gear(zone, player, quests)
    local items, waiting = Gear.Zone(player, quests)
    local entries = {}
    for _, item in ipairs(items) do
        local level = Data.Difficulty(item.quest, player)
        local itemType = item.typeName .. " · " .. L.ITEM_LEVEL:format(item.itemLevel)
        local stats = Gear.Stats(item.link)
        entries[#entries + 1] = {
            key = item.quest.id .. ":" .. item.id,
            title = item.name, quest = item.quest, points = Pins.Points(item.quest, zone, "start"),
            itemID = item.id, icon = item.icon, tint = item.tint,
            subtitle = Entries.QuestTitle(item.quest, level),
            summary = itemType,
            description = itemType .. "\n" .. item.reward.kind .. " · " .. L.REQUIRED_ITEM_LEVEL:format(item.level)
                .. (stats and stats ~= "" and ("\n" .. stats) or ""),
        }
    end
    return entries, waiting
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
