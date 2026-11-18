local _, Guide = ...
local Data, Gear, L, Pins = Guide.Data, Guide.Gear, Guide.Locale, Guide.QuestPins
local Rewards = Guide.Rewards
local Entries = {}
Guide.Entries = Entries

function Entries.QuestTitle(quest, level)
    return quest.level and ("[%d] %s"):format(level, quest.name) or quest.name
end

local function questRow(result, zone, player, startZone)
    local depth = startZone and 2 or 0
    local quest = result.quest
    local active = result.status == "active"
    local points = Pins.Points(quest, zone, (active or startZone) and "objective" or "start")
    if (active or startZone) and #points == 0 then points = Pins.Points(quest, zone, "finish") end
    local lines = table.concat(quest.lines, "\n")
    local subtitle = active and L.STATUS_ACTIVE or (#quest.starterItems > 0 and L.RELATION_ITEM or L.RELATION_START)
    if startZone then
        subtitle = L.STARTS_IN_ZONE:format(Data.ZoneName(startZone))
    elseif points[1] and points[1].name then
        local point = points[1]
        if not active and point.labelKey == "START_AND_OBJECTIVE" then subtitle = L[point.labelKey] end
        subtitle = subtitle .. " · " .. point.name
    end
    local title = Entries.QuestTitle(quest, result.level)
    if Data.HasChain(quest, player) then
        title = ("[|TInterface\\AddOns\\ForeverQuestGuide\\Art\\ChainLink.tga:13:13|t %s %d] %s")
            :format(L.CHAIN_TAG, result.level, quest.name)
    end
    local description = lines ~= "" and lines or subtitle
    if not active and not quest.native and (not quest.min or quest.min <= 0) and result.level > player.level then
        subtitle = L.MIN_LEVEL_UNVERIFIED .. " · " .. subtitle
        description = description .. "\n" .. L.MIN_LEVEL_UNVERIFIED
    end
    return {
        key = startZone and (startZone .. ":" .. quest.id) or quest.id,
        title = title, quest = quest, points = points, depth = depth,
        startZone = startZone,
        subtitle = subtitle, summary = Rewards.Summary(quest), description = description,
        icon = Guide.View.icons.quests, tint = {r = result.r, g = result.g, b = result.b},
    }
end

function Entries.Quests(quests, zone)
    local entries, player = {}, Data.Player()
    for _, result in ipairs(quests) do
        entries[#entries + 1] = questRow(result, zone, player)
    end
    return entries
end

local function liveObjectives(quest)
    if Data.OnQuest(quest.id) and C_QuestLog.GetQuestObjectives then
        return C_QuestLog.GetQuestObjectives(quest.id)
    end
end

function Entries.SearchQuests(quests, query)
    local lower = strlower or string.lower
    local function matches(text)
        return type(text) == "string" and lower(text):find(query, 1, true) ~= nil
    end
    local function matchesQuest(quest)
        if matches(quest.name) then return true end
        for _, line in ipairs(quest.lines) do
            if matches(line) then return true end
        end
        for _, objective in ipairs(liveObjectives(quest) or {}) do
            if matches(objective.text) then return true end
        end
        for _, sources in ipairs({quest.givers, quest.objectives, quest.finishers}) do
            for _, source in ipairs(sources) do
                if matches(source.name) then return true end
            end
        end
    end
    local result = {}
    for _, item in ipairs(quests) do
        if matchesQuest(item.quest) then result[#result + 1] = item end
    end
    return result
end

function Entries.AvailableQuests(quests, zone, collapsed, searching)
    local entries, localQuests, elsewhere, startZones = {}, {}, {}, {}
    local player, remoteCount = Data.Player(), 0
    for _, result in ipairs(quests) do
        if result.startZones then
            remoteCount = remoteCount + 1
            for _, id in ipairs(result.startZones) do
                if not elsewhere[id] then
                    elsewhere[id] = {}
                    startZones[#startZones + 1] = { id = id, name = Data.ZoneName(id) }
                end
                local group = elsewhere[id]
                group[#group + 1] = result
            end
        else
            localQuests[#localQuests + 1] = result
        end
    end
    table.sort(startZones, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    local function addHeader(key, title, count, depth)
        entries[#entries + 1] = {
            key = key, title = title, count = count, depth = depth,
            header = true, collapsed = collapsed[key],
        }
        return not collapsed[key]
    end
    if (not searching or #localQuests > 0) and addHeader("local", L.START_IN_THIS_ZONE, #localQuests, 0) then
        for _, result in ipairs(localQuests) do
            local row = questRow(result, zone, player)
            row.depth = 1
            entries[#entries + 1] = row
        end
    end
    if (not searching or remoteCount > 0) and addHeader("elsewhere", L.START_SOMEWHERE_ELSE, remoteCount, 0) then
        for _, start in ipairs(startZones) do
            local group = elsewhere[start.id]
            if addHeader("zone:" .. start.id, start.name, #group, 1) then
                for _, result in ipairs(group) do
                    entries[#entries + 1] = questRow(result, zone, player, start.id)
                end
            end
        end
    end
    return entries
end

local function chainRoute(quest)
    local function firstLocation(sources)
        for _, source in ipairs(sources) do
            if source.points[1] then return source.name, Data.ZoneName(source.points[1].zone) end
        end
    end
    local giver, start = firstLocation(quest.givers)
    local finisher, finish = firstLocation(quest.finishers)
    if start and finish and start ~= finish then return start .. " → " .. finish end
    local zone, contact = start or finish, giver or finisher
    return zone and contact and (contact .. " · " .. zone) or zone
end

local function chainStep(quest, player)
    local status, label = Data.Status(quest, player)
    if status == "hidden" then return end
    if status == "possible" or status == "starter" then label = L.CHAIN_AVAILABLE end
    local level, r, g, b = Data.Difficulty(quest, player)
    return {
        quest = quest, title = Entries.QuestTitle(quest, level), tint = { r = r, g = g, b = b },
        status = status, subtitle = label or L.CHAIN_UNKNOWN,
        route = chainRoute(quest), description = quest.lines[1],
    }
end

function Entries.Chain(quest, player)
    local anchor, ancestors = quest, { [quest.id] = true }
    while anchor.parent and not ancestors[anchor.parent] do
        local parent = Data.Quest(anchor.parent)
        if not parent or not chainStep(parent, player) then break end
        anchor, ancestors[parent.id] = parent, true
    end

    local function walk(preceding)
        local rows, seen = {}, { [anchor.id] = true }
        local queue, cursor = { { id = anchor.id, distance = 0 } }, 1
        while cursor <= #queue do
            local source = queue[cursor]
            local links = Data.ChainLinks(source.id, preceding)
            local ids = {}
            for id, relation in pairs(links) do
                if not seen[id] and relation ~= "on_accept" then ids[#ids + 1] = id end
            end
            table.sort(ids)
            for _, id in ipairs(ids) do
                seen[id] = true
                local linked = Data.Quest(id)
                local row = linked and chainStep(linked, player)
                if row then
                    row.distance, row.relation, row.linkedTo = source.distance + 1, links[id], source.id
                    rows[#rows + 1] = row
                    queue[#queue + 1] = { id = id, distance = row.distance }
                end
            end
            cursor = cursor + 1
        end
        return rows
    end

    local before, after = walk(true), walk(false)
    table.sort(before, function(a, b)
        if a.distance ~= b.distance then return a.distance > b.distance end
        return a.quest.id < b.quest.id
    end)
    local rows, seen, alternatives = {}, {}, {}
    local anchorRow = chainStep(anchor, player) or { quest = anchor, title = anchor.name, subtitle = L.CHAIN_UNKNOWN }
    local anchorNumber = (before[1] and before[1].distance or 0) + 1
    local current
    local function append(row, number)
        local id = row.quest.id
        if seen[id] then return end
        seen[id] = true
        row.number = number
        rows[#rows + 1] = row
        if id == quest.id then current = #rows end
    end

    for _, row in ipairs(before) do
        local number = anchorNumber - row.distance
        if row.relation == "alternative" or row.relation == "leads" then
            local key = row.linkedTo .. ":" .. number .. ":" .. row.title
            local position = alternatives[key]
            if position then
                local previous = rows[position]
                if row.status == "done" and previous.status ~= "done" then
                    row.number = number
                    rows[position] = row
                    previous = row
                end
                previous.alternate = true
                seen[row.quest.id] = true
            else
                append(row, number)
                alternatives[key] = #rows
            end
        else
            append(row, number)
        end
    end
    append(anchorRow, anchorNumber)
    for _, row in ipairs(after) do append(row, anchorNumber + row.distance) end

    local lastSeries = #rows
    local i = 1
    while i <= #rows do
        local source = rows[i].quest
        local ids = {}
        for id, relation in pairs(Data.ChainLinks(source.id, false)) do
            if relation == "on_accept" and not seen[id] then ids[#ids + 1] = id end
        end
        table.sort(ids, function(a, b)
            local first, second = Data.Quest(a), Data.Quest(b)
            local aLevel = first and first.level or math.huge
            local bLevel = second and second.level or math.huge
            if aLevel ~= bLevel then return aLevel < bLevel end
            return a < b
        end)
        for _, id in ipairs(ids) do
            local linked = Data.Quest(id)
            local row = linked and chainStep(linked, player)
            if row then
                if source.id ~= anchor.id then row.unlocksDuring = source.name end
                append(row)
            end
        end
        i = i + 1
    end
    return rows, current or lastSeries, anchor.name
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
            group[#group + 1] = Pins.Point(point, stage, source.labelKey)
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

local function localLocationsFirst(entries, zone)
    -- Stable partition keeps catalogue order within local and remote locations.
    local nextLocal = 1
    for i, row in ipairs(entries) do
        if row.mapZone == zone then
            if i ~= nextLocal then
                table.remove(entries, i)
                table.insert(entries, nextLocal, row)
            end
            nextLocal = nextLocal + 1
        end
    end
end

function Entries.Quest(quest, zone, section)
    local entries = {}
    if section == "start" then
        addLocations(entries, quest.givers, section, zone)
        localLocationsFirst(entries, zone)
        for _, id in ipairs(quest.starterItems) do
            entries[#entries + 1] = { title = Data.ItemName(id), subtitle = L.QUEST_STARTING_ITEM, itemID = id }
        end
    elseif section == "objective" then
        local live = liveObjectives(quest)
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
            itemStats = item.reward.kind .. " · " .. L.REQUIRED_ITEM_LEVEL:format(item.level)
                .. (stats and stats ~= "" and (" · " .. stats) or ""),
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
