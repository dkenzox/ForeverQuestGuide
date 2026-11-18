local _, Guide = ...
local L, Data, Native = Guide.Locale, Guide.Data, Guide.Native
local View, ZoneMap, Entries, Pins = Guide.View, Guide.ZoneMap, Guide.Entries, Guide.QuestPins

BINDING_HEADER_FOREVERQUESTGUIDE = "Forever Quest Guide"
BINDING_NAME_FOREVERQUESTGUIDE_TOGGLE = L.BINDING_TOGGLE

local tabs = {
    { key = "quests", label = L.TAB_QUESTS },
    { key = "gear", label = L.TAB_EQUIPMENT },
    { key = "ore", label = L.TAB_ORE },
    { key = "herb", label = L.TAB_HERBS },
    { key = "fish", label = L.TAB_FISH },
}
local ui, launcher, zone, detail, message
local markedHere
local currentZone, pinnedZone
local Picker = Guide.ZonePicker
local openMinimapQuest
local tab, index, entries = 1, 1, {}
local routeSection, routeIndex, rewardIndex = "start", 1, 1
local returnTo, dockData
local chooseSection, focusPoint
local refreshPending, refreshPins, elapsed, dataPrimed
local render, draw, openQuest
local activeOnly = false
local collapsedByZone, questCount = {}, nil
local searchText, searchGroups = "", {}
local filterFocus

local function playerZone()
    return Data.ZoneForMap(C_Map.GetBestMapForUnit("player"))
end

local function nearest(entry)
    local points = entry and entry.points
    if not points or #points == 0 then return end
    local pos = zone and zone == currentZone and C_Map.GetPlayerMapPosition
        and C_Map.GetPlayerMapPosition(zone, "player")
    if not pos then return points[1] end
    local x, y = pos:GetXY()
    if not x or not y or (x == 0 and y == 0) then return points[1] end
    local best, distance
    for _, point in ipairs(points) do
        if point.mapID == zone then
            local d = (point.x - x * 100)^2 + (point.y - y * 100)^2
            if not distance or d < distance then best, distance = point, d end
        end
    end
    return best or points[1]
end

local function mark(point)
    if not point then return end
    if InCombatLockdown() then
        message = L.WAYPOINT_COMBAT
    elseif not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(point.mapID)
        and UiMapPoint and C_Map.SetUserWaypoint) then
        message = L.WAYPOINT_UNSUPPORTED
    else
        local waypoint = UiMapPoint.CreateFromCoordinates(point.mapID, point.x / 100, point.y / 100)
        local result = C_Map.SetUserWaypoint(waypoint)
        if result ~= false then markedHere = true end
        message = result == false and L.WAYPOINT_FAILED or L.WAYPOINT_SET:format(Data.ZoneName(point.mapID))
    end
    draw()
end

local function hasWaypoint()
    if C_Map.HasUserWaypoint then return C_Map.HasUserWaypoint() end
    if C_Map.GetUserWaypoint then return C_Map.GetUserWaypoint() ~= nil end
    return markedHere
end

local function clearWaypoint()
    local status
    if InCombatLockdown() then
        status = L.WAYPOINT_COMBAT
    elseif not C_Map.ClearUserWaypoint then
        status = L.CLEAR_MARK_UNAVAILABLE
    elseif not hasWaypoint() then
        status = L.NO_WAYPOINT
    else
        C_Map.ClearUserWaypoint()
        markedHere, status = nil, L.WAYPOINT_CLEARED
    end
    if ui and ui:IsShown() then
        message = status
        draw()
    else
        print(status)
    end
end

local function queueRefresh(itemsOnly)
    if not itemsOnly then refreshPins = true end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(.08, function()
        refreshPending = nil
        local questStateChanged = refreshPins
        refreshPins = nil
        if questStateChanged then
            local settings = Guide.Character.Settings()
            if Data.ready and currentZone and not settings.hideMinimap then
                local quests = Data.ZoneQuests(currentZone, Data.Player(), not settings.showTrivial, "both", settings.hideDungeonQuests, nil, settings.showEventQuests)
                Pins.RefreshMinimap(currentZone, quests, openMinimapQuest)
            else
                Pins.RefreshMinimap()
            end
        end
        if ui and ui:IsShown() then
            render(true)
            Picker.Refresh(ui.zonePicker, questStateChanged, currentZone)
        end
    end)
end

local function preferredStage(quest)
    if C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(quest.id) then return "finish" end
    return Data.OnQuest(quest.id) and "objective" or "start"
end

local function selectedQuest()
    if detail then return detail.quest end
    local item = entries[index]
    if item then return item.quest end
end

local function getDock(quest)
    if dockData and dockData.quest == quest then return dockData end
    local sections, captions = {}, {}
    for _, key in ipairs(View.sections) do
        local rows = Entries.Quest(quest, zone, key)
        sections[key] = rows
        captions[key] = rows[1] and rows[1].title or L.NO_COORDINATES
    end
    sections.rewards = Entries.Quest(quest, zone, "rewards")
    dockData = { quest = quest, sections = sections, captions = captions }
    return dockData
end

local function routePoint(data, stage, position)
    local locations = data.sections[stage]
    local item = locations[position]
    local point = nearest(item)
    if point then return point end
    -- An objective description can precede its NPC and object locations.
    for _, row in ipairs(locations) do
        point = nearest(row)
        if point and point.zone == zone then return point end
    end
    for _, row in ipairs(locations) do
        point = nearest(row)
        if point then return point end
    end
end

local function previewStage(quest)
    local entry = entries[index]
    if entry and entry.startZone and entry.points[1] then return entry.points[1].stage end
    return preferredStage(quest)
end

local function activePoint()
    local quest, entry = selectedQuest(), entries[index]
    if not quest or (not detail and entry.startZone) then return nearest(entry) end
    return routePoint(getDock(quest), detail and routeSection or preferredStage(quest), detail and routeIndex or 1)
end

local function eligibility(quest)
    if Data.OnQuest(quest.id) then
        return preferredStage(quest) == "finish" and L.READY_FOR_TURN_IN or L.STATUS_ACTIVE
    end
    if quest.min and quest.min > 0 then return L.ATLAS_REQUIRES:format(quest.min) end
    if not quest.native and quest.level and quest.level > UnitLevel("player") then return L.MIN_LEVEL_UNVERIFIED end
    return L.RELATION_START
end

draw = function()
    index = math.max(1, math.min(index, #entries))
    View.Rows(ui, entries, index, tabs[tab].key == "gear", questCount)
    local entry, quest = entries[index], selectedQuest()
    local point = activePoint()
    local mapZone = zone
    local highlighted, selectedStage
    if quest then
        local data = getDock(quest)
        local stage = detail and routeSection or previewStage(quest)
        local locations = data.sections[stage]
        routeIndex = math.max(1, math.min(routeIndex, #locations))
        local location = locations[detail and routeIndex or 1]
        if detail then
            selectedStage = stage
            mapZone = (point and point.zone) or (location and location.mapZone) or zone
        end
        ui.detailTitle:SetText(Entries.QuestTitle(quest, Data.Difficulty(quest, Data.Player())))
        local context = eligibility(quest)
        if tabs[tab].key == "gear" and entry and entry.summary then context = context .. " · " .. entry.summary end
        ui.detail:SetWordWrap(false)
        ui.detail:SetText(context)
        View.Dock(ui, stage, data.captions, locations,
            detail and detail.section ~= "rewards" and routeIndex or 0, data.sections.rewards,
            detail and detail.section == "rewards" and rewardIndex or 0,
            location and location.description, detail and detail.section)
        highlighted = Pins.Points(quest, mapZone, selectedStage)
    else
        ui.detailTitle:SetText(entry and entry.title or tabs[tab].label)
        ui.detail:SetWordWrap(true)
        ui.detail:SetText(entry and (entry.description or entry.subtitle) or ui.emptyText)
        View.Dock(ui)

    end
    local coordinates = point and ("%s · %.1f, %.1f"):format(Data.ZoneName(point.mapID), point.x, point.y)
    ui.coords:SetText(coordinates or "")
    ui.waypoint:SetEnabled(point ~= nil)
    ui.clearWaypoint:SetEnabled(not not (C_Map.ClearUserWaypoint and hasWaypoint()))
    ui.status:SetText(message or (entry and entry.itemStats) or ui.contextStatus or "")
    ui.back:SetShown(detail ~= nil)
    if filterFocus then ui.hint:SetText(L.PAD_FILTERS) end

    local mapEntries, mapIndex = entries, index
    if detail then
        mapEntries = { { title = quest.name, quest = quest } }
        mapIndex = 1
    end
    if point and highlighted then table.insert(highlighted, 1, point) end
    ZoneMap.Draw(ui.map, mapZone, mapEntries, mapIndex, tabs[tab].key, highlighted,
        tabs[tab].key == "gear" or detail ~= nil, selectedStage, mapZone == currentZone)
end

local function collapsedGroups()
    if searchText ~= "" then return searchGroups end
    if not collapsedByZone[zone] then collapsedByZone[zone] = {} end
    return collapsedByZone[zone]
end

render = function(preserve)
    local key = preserve and entries[index] and entries[index].key
    local category = tabs[tab].key
    local player = Data.Player()
    local settings = Guide.Character.Settings()
    ui.zone:SetText(Data.ZoneName(zone))
    ui.browsingZone:SetText(pinnedZone and pinnedZone ~= currentZone and L.BROWSING_ZONE or "")
    local className, class = UnitClass("player")
    local tint = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    ui.context:SetText(L.PLAYER_CONTEXT:format(player.level, UnitName("player"), className or ""))
    if tint then ui.context:SetTextColor(tint.r, tint.g, tint.b) end
    ui.source:SetText((category == "quests" or category == "gear") and (Data.source or "") or "GatherLite")
    local browsingQuests = category == "quests"
    ui.listTitle:SetText(browsingQuests and (activeOnly and L.ACTIVE_QUESTS or L.AVAILABLE_QUESTS) or tabs[tab].label)
    ui.listTitle:SetWidth(browsingQuests and 91 or 225)
    ui.search:SetShown(browsingQuests)
    ui.clearSearch:SetShown(browsingQuests and (ui.search:GetText() or "") ~= "")
    ui.questMode:SetShown(browsingQuests)
    ui.questMode:SetText(activeOnly and L.AVAILABLE_QUESTS or L.ACTIVE_QUESTS)
    local filterable = browsingQuests or category == "gear"
    ui.filter:SetShown(filterable and not (browsingQuests and activeOnly))
    ui.filter:SetText(settings.showTrivial and L.SHOWING_TRIVIAL or L.HIDING_TRIVIAL)
    ui.dungeons:SetShown(filterable)
    ui.dungeons:SetText(settings.hideDungeonQuests and L.HIDING_DUNGEONS or L.SHOWING_DUNGEONS)
    ui.eventFilter:SetShown(filterable)
    ui.eventFilter:SetText(settings.showEventQuests and L.SHOWING_EVENTS or L.HIDING_EVENTS)
    ui.contextStatus, ui.emptyText = nil, L.EMPTY_CATALOG
    entries, dockData, questCount = {}, nil, nil

    if detail and Data.Completed(detail.quest.id) then detail, returnTo = nil, nil end
    if not zone then
        ui.emptyText = L.NO_PLAYER_ZONE
    elseif category == "quests" or category == "gear" then
        if not Data.ready then
            ui.emptyText = L.LOADING
        else
            local grouped = browsingQuests and not activeOnly
            if browsingQuests then
                local quests = Data.ZoneQuestList(zone, player, settings, activeOnly and "active" or nil)
                local searching = searchText ~= ""
                if searching then quests = Entries.SearchQuests(quests, searchText) end
                if grouped then
                    entries = Entries.AvailableQuests(quests, zone, collapsedGroups(), searching)
                else
                    entries = Entries.Quests(quests, zone)
                end
                if grouped or searching then questCount = #quests end
                ui.emptyText = searching and L.NO_QUEST_MATCHES or (activeOnly and L.EMPTY_ACTIVE or L.EMPTY_AVAILABLE)
                ui.contextStatus = Data.IsNative() and L.STATUS_NATIVE_SOURCE or (activeOnly and L.ACTIVE_QUESTS or L.QUEST_ORDER)
            else
                local quests = Data.ZoneQuests(zone, player, not settings.showTrivial, "both",
                    settings.hideDungeonQuests, nil, settings.showEventQuests)
                local waiting
                entries, waiting = Entries.Gear(zone, player, quests)
                ui.emptyText = waiting and L.LOADING_EQUIPMENT or L.EMPTY_GEAR
                ui.contextStatus = waiting and L.LOADING_EQUIPMENT or L.GEAR_QUEST_ORDER
            end
        end
    else
        local skill
        entries, skill = Entries.Resources(zone, category)
        ui.contextStatus = L.PROFESSION_RANK:format(tabs[tab].label, skill)
        ui.emptyText = L.EMPTY_RESOURCES
    end
    local wanted = detail and (detail.entryKey or detail.listKey or detail.quest.id) or key
    local found
    if wanted then
        for i, entry in ipairs(entries) do
            if entry.key == wanted then found = i; break end
        end
        if found then index = found
        elseif detail and detail.entryKey then detail, returnTo = nil, nil end
    end
    if not found and index == 1 and entries[1] and entries[1].header then
        for i, entry in ipairs(entries) do
            if entry.quest then index = i; break end
        end
    end
    View.Tab(ui, tab)
    draw()
end

local function updateSearch(text)
    local lower = strlower or string.lower
    local query = lower((text or ""):match("^%s*(.-)%s*$"))
    if query == searchText then return end
    searchText, searchGroups = query, {}
    index, detail, returnTo, message = 1, nil, nil, nil
    render()
end

local function selectTab(destination)
    if filterFocus then filterFocus:UnlockHighlight(); filterFocus = nil end
    ui.search:ClearFocus()
    tab, index, detail, returnTo, message = destination, 1, nil, nil, nil
    render()
end

local function close()
    ui:Hide()
end

local function back()
    if not detail then close(); return end
    detail, message = nil, nil
    if returnTo then
        tab, index, activeOnly = returnTo.tab, returnTo.index, returnTo.activeOnly
        if returnTo.pinnedZone then
            pinnedZone, zone = returnTo.pinnedZone, returnTo.pinnedZone
        end
        returnTo = nil
    end
    render()
end

openQuest = function(quest, point, inGear)
    if Data.Completed(quest.id) then return end
    if not (ui and ui:IsShown()) then ForeverQuestGuide_Toggle() end
    if not (ui and ui:IsShown()) then return end
    local selected = entries[index]
    local entryKey = inGear and selected and selected.key or nil
    local listKey = not inGear and tab == 1 and selected and selected.quest == quest and selected.key or nil
    if not point and listKey and selected.startZone then
        point = Pins.Points(quest, selected.startZone, "start")[1]
    end
    local targetTab = inGear and tab or 1
    if not detail or detail.quest.id ~= quest.id or detail.entryKey ~= entryKey or tab ~= targetTab then
        if not inGear then
            local active = not not Data.OnQuest(quest.id)
            if tab ~= 1 or activeOnly ~= active then
                returnTo = returnTo or { tab = tab, index = index, activeOnly = activeOnly }
            end
            tab, activeOnly = 1, active
        end
        local section = point and point.stage or preferredStage(quest)
        detail = { quest = quest, section = section, entryKey = entryKey, listKey = listKey }
        routeSection, routeIndex, rewardIndex = section, 1, 1
        message = nil
        render()
    end
    if point then focusPoint(point) end
end

openMinimapQuest = function(quest, point)
    if zone and currentZone and zone ~= currentZone then
        if not (ui and ui:IsShown()) then ForeverQuestGuide_Toggle() end
        if not (ui and ui:IsShown()) then return end
        returnTo = { tab = tab, index = index, activeOnly = activeOnly, pinnedZone = pinnedZone }
        pinnedZone, zone, detail, index = nil, currentZone, nil, 1
    end
    if ui then ui.zonePicker:Hide() end
    openQuest(quest, point)
end

local function openCurrentQuest(quest, point)
    openQuest(quest, point, tabs[tab].key == "gear")
end

chooseSection = function(section)
    local quest = selectedQuest()
    if not quest then return end
    if not detail then openCurrentQuest(quest) end
    if not detail then return end
    if section ~= "rewards" and section ~= routeSection then routeSection, routeIndex = section, 1 end
    detail.section, message = section, nil
    draw()
end

focusPoint = function(point)
    if not (detail and point.stage) then return end
    if point.stage ~= routeSection then routeIndex = 1 end
    routeSection, detail.section = point.stage, point.stage
    local locations = getDock(detail.quest).sections[routeSection]
    for i, item in ipairs(locations) do
        for _, candidate in ipairs(item.points or {}) do
            if candidate.mapID == point.mapID and candidate.x == point.x and candidate.y == point.y then
                routeIndex = i
                draw()
                return
            end
        end
    end
    draw()
end

local function stepSection(offset)
    for i, section in ipairs(View.sections) do
        if routeSection == section then
            chooseSection(View.sections[(i - 1 + offset) % #View.sections + 1])
            return
        end
    end
end

local function toggleQuestMode()
    if tabs[tab].key ~= "quests" then return end
    activeOnly, index, detail, returnTo, message = not activeOnly, 1, nil, nil, nil
    render()
end

local function toggleFilter()
    local key = tabs[tab].key
    if key ~= "gear" and (key ~= "quests" or activeOnly) then return end
    local settings = Guide.Character.Settings()
    settings.showTrivial = not settings.showTrivial
    message = nil
    render(true)
    queueRefresh()
end

local function toggleQuestType(setting, matches)
    local key = tabs[tab].key
    if key ~= "quests" and key ~= "gear" then return end
    local settings = Guide.Character.Settings()
    settings[setting] = not settings[setting]
    if detail and matches(detail.quest, settings[setting]) then
        detail, returnTo = nil, nil
    end
    message = nil
    render(true)
    queueRefresh()
end

local function toggleDungeons()
    toggleQuestType("hideDungeonQuests", function(quest, hidden)
        return hidden and Data.IsDungeonQuest(quest)
    end)
end

local function toggleEvents()
    toggleQuestType("showEventQuests", function(quest, shown)
        return not shown and Data.IsEventQuest(quest)
    end)
end

local function focusFilter(button)
    if filterFocus then filterFocus:UnlockHighlight() end
    filterFocus = button
    if button then button:LockHighlight() end
    draw()
end

local function selectList(position)
    index, detail, returnTo, message = position, nil, nil, nil
    draw()
end

local function changeListPage(offset)
    selectList(index + offset * View.pageSize)
end

local function selectRoute(position)
    local quest = selectedQuest()
    if not quest then return end
    if not detail then openCurrentQuest(quest) end
    if not detail then return end
    detail.section, routeIndex, message = routeSection, position, nil
    draw()
end

local function selectReward(position)
    local quest = selectedQuest()
    if not quest then return end
    if not detail then openCurrentQuest(quest) end
    if not detail then return end
    detail.section, rewardIndex, message = "rewards", position, nil
    local items = getDock(detail.quest).sections.rewards
    rewardIndex = math.max(1, math.min(rewardIndex, #items))
    draw()
end

local function changeRoutePage(offset)
    selectRoute(routeIndex + offset * View.detailPageSize)
end

local function changeRewardPage(offset)
    local target = offset < 0 and ui.rewardSheet.previous or (offset > 0 and ui.rewardSheet.next)
    if target then selectReward(target) end
end

local function moveFocus(offset)
    if not detail then selectList(index + offset)
    elseif detail.section == "rewards" then selectReward(rewardIndex + offset)
    else selectRoute(routeIndex + offset) end
end

local function changePage(offset)
    if not detail then changeListPage(offset)
    elseif detail.section == "rewards" then changeRewardPage(offset)
    else changeRoutePage(offset) end
end

local function toggleGroup(item)
    local collapsed = collapsedGroups()
    collapsed[item.key] = not collapsed[item.key] or nil
    detail, returnTo, message = nil, nil, nil
    render(true)
end

local function activate()
    if detail then
        if detail.section == "rewards" then Guide.RewardView.Tooltip(ui.rewardSheet.focused)
        else mark(activePoint()) end
    else
        local item = entries[index]
        if item and item.header then toggleGroup(item)
        elseif item and item.quest then openCurrentQuest(item.quest)
        else mark(activePoint()) end
    end
end

local function chooseZone(mapID)
    pinnedZone, zone = mapID, mapID or currentZone
    searchGroups = {}
    index, detail, returnTo, message = 1, nil, nil, nil
    tab, activeOnly = 1, false
    searchText = ""
    ui.search:SetText("")
    render()
end

local function showZonePicker()
    ui.search:ClearFocus()
    Picker.Open(ui.zonePicker, currentZone, pinnedZone)
end

local function onPad(_, key)
    if ui.zonePicker:IsShown() then Picker.OnPad(ui.zonePicker, key); return end
    if ui.search:HasFocus() then
        if key == "PAD1" or key == "PAD2" or key == "PADDDOWN" then ui.search:ClearFocus() end
        return
    end
    if filterFocus then
        if key == "PAD2" or key == "PADBACK" then focusFilter(nil)
        elseif key == "PADDLEFT" then focusFilter(ui.eventFilter)
        elseif key == "PADDRIGHT" then focusFilter(ui.dungeons)
        elseif key == "PAD1" then
            if filterFocus == ui.eventFilter then toggleEvents() else toggleDungeons() end
        end
        return
    end
    if key == "PADFORWARD" then showZonePicker()
    elseif key == "PADDUP" and not detail and index == 1 and ui.search:IsShown() then ui.search:SetFocus()
    elseif key == "PADDUP" then moveFocus(-1)
    elseif key == "PADDDOWN" then moveFocus(1)
    elseif key == "PADDLEFT" and detail then stepSection(-1)
    elseif key == "PADDRIGHT" and detail then stepSection(1)
    elseif key == "PADDLEFT" or key == "PADLSHOULDER" then selectTab((tab - 2) % #tabs + 1)
    elseif key == "PADDRIGHT" or key == "PADRSHOULDER" then selectTab(tab % #tabs + 1)
    elseif key == "PADLTRIGGER" then changePage(-1)
    elseif key == "PADRTRIGGER" then changePage(1)
    elseif key == "PAD1" then activate()
    elseif key == "PAD2" then back()
    elseif key == "PAD3" then mark(activePoint())
    elseif key == "PADLSTICK" then clearWaypoint()
    elseif key == "PAD4" then toggleFilter()
    elseif key == "PADBACK" and ui.dungeons:IsShown() then focusFilter(ui.dungeons)
    elseif key == "PADRSTICK" then
        if not detail then toggleQuestMode()
        elseif detail.section == "rewards" then chooseSection(routeSection)
        elseif #getDock(detail.quest).sections.rewards > 0 then chooseSection("rewards") end
    end
end

local function checkZone()
    local detected = playerZone()
    if currentZone ~= detected then
        currentZone = detected
        Native.Invalidate()
        if not pinnedZone then
            searchGroups = {}
            zone, index, detail, returnTo, message = detected, 1, nil, nil, nil
        end
        queueRefresh()
    end
end

local function bindItemTooltip(row)
    local function hide(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    row:SetScript("OnEnter", function(self)
        local item = self.item
        if not (item and item.itemID) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. item.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", hide)
    row:SetScript("OnHide", hide)
end

local function build()
    ui = View.Create(tabs, {
        close = close, back = back, tab = selectTab, filter = toggleFilter, questMode = toggleQuestMode, dungeons = toggleDungeons, events = toggleEvents,
        section = chooseSection, clear = clearWaypoint, route = selectRoute, changeZone = showZonePicker,
        search = updateSearch,
        listPage = changeListPage, routePage = changeRoutePage, rewardPage = changeRewardPage,
        questLink = function(position)
            local entry = entries[position]
            if entry and entry.quest then index = position; openCurrentQuest(entry.quest) end
        end,
        row = function(position)
            local entry = entries[position]
            if entry and entry.header then
                index = position
                toggleGroup(entry)
            elseif position == index and not detail then
                activate()
            else
                selectList(position)
            end
        end,
        reward = function(position)
            selectReward(position)
            Guide.RewardView.Tooltip(ui.rewardSheet.focused)
        end,
        pin = function(position, point, button)
            if button == "RightButton" then mark(point); return end
            if detail and point.stage then
                focusPoint(point)
            elseif entries[position] and entries[position].quest then
                index = position
                openCurrentQuest(entries[position].quest, point)
            else
                selectList(position)
            end
        end,
        mark = function() mark(activePoint()) end,
    })
    ui.zonePicker = Picker.Create(ui, chooseZone)
    _G.ForeverQuestGuideWindow = ui
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverQuestGuideWindow") end
    if ui.EnableGamePadButton then ui:SetScript("OnGamePadButtonDown", onPad) end
    for _, row in ipairs(ui.rows) do bindItemTooltip(row) end
    for _, row in ipairs(ui.routeRows) do bindItemTooltip(row) end
    ui:SetScript("OnMouseWheel", function(_, delta) moveFocus(-delta) end)
    ui:EnableMouseWheel(true)
    ui:SetScript("OnShow", function(self)
        self:Raise()
        if self.EnableGamePadButton then self:EnableGamePadButton(true) end
        SetPortraitTexture(self.portrait, "player")
        elapsed = 0
    end)
    ui:SetScript("OnHide", function(self)
        if filterFocus then filterFocus:UnlockHighlight(); filterFocus = nil end
        self:StopMovingOrSizing()
        self.zonePicker:Hide()
        self.search:ClearFocus()
        if returnTo and returnTo.pinnedZone then
            tab, activeOnly, pinnedZone = returnTo.tab, returnTo.activeOnly, returnTo.pinnedZone
            zone, returnTo = pinnedZone, nil
        end
        if self.EnableGamePadButton then self:EnableGamePadButton(false) end
        for _, pin in ipairs(self.map.pins) do
            if GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
        end
    end)
    ui:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < .5 then return end
        elapsed = 0
        checkZone()
        ZoneMap.UpdatePlayer(ui.map, currentZone == ui.map.zone and currentZone or nil)
    end)
    local function fit()
        ui:SetScale(math.min(1, (UIParent:GetWidth() - 24) / View.width, (UIParent:GetHeight() - 24) / View.height))
    end
    fit()
    UIParent:HookScript("OnSizeChanged", fit)
end

local function prime()
    if dataPrimed then return end
    dataPrimed = true
    Data.Start(queueRefresh)
end

function ForeverQuestGuide_Toggle()
    if ui and ui:IsShown() then close(); return end
    if InCombatLockdown() then return end
    if not ui then build() end
    ui.map.zone = false
    currentZone = playerZone()
    zone, detail, returnTo, dockData, index, message = pinnedZone or currentZone, nil, nil, nil, 1, nil
    Native.Invalidate()
    ui:Show()
    prime()
    render()
end

SLASH_FOREVERQUESTGUIDE1 = "/fqg"
SlashCmdList.FOREVERQUESTGUIDE = function(command)
    command = (command or ""):lower():match("^%s*(.-)%s*$")
    if command == "clear" then
        clearWaypoint()
    elseif command == "minimap" then
        local settings = Guide.Character.Settings()
        settings.hideMinimap = not settings.hideMinimap
        print(settings.hideMinimap and L.MINIMAP_HIDDEN or L.MINIMAP_VISIBLE)
        queueRefresh()
    else
        ForeverQuestGuide_Toggle()
    end
end
Guide.Gear.OnChanged = function() queueRefresh(true) end

local function attachLauncher()
    if launcher or not WorldMapFrame then return end
    launcher = View.Button(WorldMapFrame, L.MAP_BUTTON, 66, 22, "TOPRIGHT", -46, -27, ForeverQuestGuide_Toggle)
    launcher:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 15)
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
    "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_DATA_LOAD_RESULT", "PLAYER_LEVEL_UP",
    "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "UPDATE_FACTION", "ITEM_DATA_LOAD_RESULT", "PLAYER_REGEN_DISABLED",
    "MAP_EXPLORATION_UPDATED", "USER_WAYPOINT_UPDATED",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, arg, success)
    if event == "PLAYER_LOGIN" then
        attachLauncher()
        Guide.MinimapButton.Create(ForeverQuestGuide_Toggle)
        checkZone()
        C_Timer.After(1, prime)
    elseif event == "ADDON_LOADED" then
        if arg == "Blizzard_WorldMap" then attachLauncher() end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0, checkZone)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if ui then close() end
    elseif event == "MAP_EXPLORATION_UPDATED" then
        if ui and ui:IsShown() then
            ui.map.zone = false
            render(true)
            Picker.RefreshMap(ui.zonePicker)
        end
    elseif event == "USER_WAYPOINT_UPDATED" then
        if ui and ui:IsShown() then draw() end
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        Guide.Gear.Loaded(arg)
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        local updated = Guide.Rewards.Loaded(arg, success)
        if Data.IsNative() and Native.DataLoaded(arg) then queueRefresh()
        elseif updated then queueRefresh(true) end
    else
        Native.Invalidate()
        queueRefresh()
    end
end)
