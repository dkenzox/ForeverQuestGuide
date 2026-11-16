local _, Guide = ...
local L, Data, Native = Guide.Locale, Guide.Data, Guide.Native
local View, ZoneMap, Entries = Guide.View, Guide.ZoneMap, Guide.Entries

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
local tab, index, entries, history = 1, 1, {}, {}
local refreshPending, elapsed, dataPrimed
local render, draw

local function playerZone()
    return Data.ZoneForMap(C_Map.GetBestMapForUnit("player"))
end

local function nearest(entry)
    local points = entry and entry.points
    if not points or #points == 0 then return end
    local pos = zone and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(zone, "player")
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
        message = result == false and L.WAYPOINT_FAILED or L.WAYPOINT_SET:format(Data.ZoneName(point.mapID))
    end
    draw()
end

local function queueRefresh()
    if refreshPending or not (ui and ui:IsShown()) then return end
    refreshPending = true
    C_Timer.After(.08, function()
        refreshPending = nil
        if ui:IsShown() then render(true) end
    end)
end

draw = function()
    index = math.max(1, math.min(index, #entries))
    View.Rows(ui, entries, index)
    local entry = entries[index]
    local point = nearest(entry)
    ui.detailTitle:SetText(entry and entry.title or tabs[tab].label)
    ui.detail:SetText(entry and (entry.description or entry.subtitle) or ui.emptyText)
    ui.coords:SetText(point and ("%s · %.1f, %.1f"):format(Data.ZoneName(point.mapID), point.x, point.y) or "")
    ui.waypoint:SetEnabled(point ~= nil)
    ui.status:SetText(message or ui.contextStatus or "")
    ZoneMap.Draw(ui.map, zone, entries, index, tabs[tab].key)
end

render = function(preserve)
    local key = preserve and entries[index] and entries[index].key
    local category = tabs[tab].key
    local player = Data.Player()
    local settings = Guide.Character.Settings()
    ui.zone:SetText(Data.ZoneName(zone))
    local className, class = UnitClass("player")
    local tint = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    ui.context:SetText(L.PLAYER_CONTEXT:format(player.level, UnitName("player"), className or ""))
    if tint then ui.context:SetTextColor(tint.r, tint.g, tint.b) end
    ui.source:SetText((category == "quests" or category == "gear") and (Data.source or "") or "GatherLite")
    ui.listTitle:SetText(detail and detail.title or tabs[tab].label)
    ui.back:SetShown(detail ~= nil)
    ui.filter:SetShown(category == "quests" and not detail)
    ui.filter:SetText(settings.showTrivial and L.SHOWING_TRIVIAL or L.HIDING_TRIVIAL)
    ui.contextStatus = nil
    ui.emptyText = L.EMPTY_CATALOG
    entries = {}

    if detail and detail.quest and Data.Completed(detail.quest.id) then
        detail, history, index = nil, {}, 1
        return render()
    end
    if not zone then
        ui.emptyText = L.NO_PLAYER_ZONE
    elseif detail then
        entries = detail.quest and Entries.Quest(detail.quest) or Entries.Item(detail.item, zone)
        ui.emptyText = L.QUEST_NO_DETAILS
    elseif category == "quests" or category == "gear" then
        if not Data.ready then
            ui.emptyText = L.LOADING
        else
            local quests = Data.ZoneQuests(zone, player, category == "quests" and not settings.showTrivial)
            if category == "quests" then
                entries = Entries.Quests(quests, zone)
                ui.emptyText = L.EMPTY_AVAILABLE
                ui.contextStatus = Data.IsNative() and L.STATUS_NATIVE_SOURCE or L.QUEST_ORDER
            else
                local waiting
                entries, waiting = Entries.Gear(zone, player, quests)
                ui.emptyText = L.EMPTY_GEAR
                if waiting or not Data.gearReady then
                    ui.contextStatus = L.LOADING_EQUIPMENT
                    if #entries == 0 then ui.emptyText = ui.contextStatus end
                else
                    ui.contextStatus = L.GEAR_ORDER
                end
            end
        end
    else
        local skill
        entries, skill = Entries.Resources(zone, category)
        ui.contextStatus = L.PROFESSION_RANK:format(tabs[tab].label, skill)
        ui.emptyText = L.EMPTY_RESOURCES
    end
    if key then
        for i, entry in ipairs(entries) do
            if entry.key == key then index = i; break end
        end
    end
    View.Tab(ui, tab)
    draw()
end

local function selectTab(destination)
    tab, index, detail, history, message = destination, 1, nil, {}, nil
    render()
end

local function close()
    ui:Hide()
end

local function back()
    local previous = table.remove(history)
    if not previous then close(); return end
    detail, index, message = previous.detail, previous.index, nil
    render()
end

local function openDetails(entry)
    if not entry then return end
    if entry.quest or entry.item then
        history[#history + 1] = { detail = detail, index = index }
        detail = { title = entry.title, quest = entry.quest, item = entry.item }
        index, message = 1, nil
        render()
    else
        mark(nearest(entry))
    end
end

local function toggleFilter()
    if tabs[tab].key ~= "quests" or detail then return end
    local settings = Guide.Character.Settings()
    settings.showTrivial = not settings.showTrivial
    message = nil
    render(true)
end

local function moveFocus(offset)
    message = nil
    index = index + offset
    draw()
end

local function onPad(_, key)
    if key == "PADDUP" then moveFocus(-1)
    elseif key == "PADDDOWN" then moveFocus(1)
    elseif key == "PADDLEFT" or key == "PADLSHOULDER" then selectTab((tab - 2) % #tabs + 1)
    elseif key == "PADDRIGHT" or key == "PADRSHOULDER" then selectTab(tab % #tabs + 1)
    elseif key == "PADLTRIGGER" then moveFocus(-View.pageSize)
    elseif key == "PADRTRIGGER" then moveFocus(View.pageSize)
    elseif key == "PAD1" then openDetails(entries[index])
    elseif key == "PAD2" then back()
    elseif key == "PAD3" then mark(nearest(entries[index]))
    elseif key == "PAD4" then toggleFilter()
    end
end

local function checkZone()
    local detected = playerZone()
    if zone ~= detected then
        zone, index, detail, history, message = detected, 1, nil, {}, nil
        Native.Invalidate()
        if ui and ui:IsShown() then render() end
    end
end

local function tooltip(row, entry)
    if not (entry and entry.itemID) then return end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink("item:" .. entry.itemID)
    GameTooltip:Show()
end

local function build()
    ui = View.Create(tabs, {
        close = close, back = back, tab = selectTab, filter = toggleFilter,
        row = function(position)
            if position == index then
                openDetails(entries[index])
            else
                index, message = position, nil
                draw()
            end
        end,
        page = function(offset) moveFocus(offset * View.pageSize) end,
        pin = function(position, point, button)
            index, message = position, nil
            if button == "RightButton" then mark(point) else draw() end
        end,
        mark = function() mark(nearest(entries[index])) end,
    })
    _G.ForeverQuestGuideWindow = ui
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverQuestGuideWindow") end
    if ui.EnableGamePadButton then ui:SetScript("OnGamePadButtonDown", onPad) end

    for _, row in ipairs(ui.rows) do
        row:SetScript("OnEnter", function(self) tooltip(self, entries[self.index]) end)
        row:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
    end
    ui:SetScript("OnMouseWheel", function(_, delta) moveFocus(-delta) end)
    ui:EnableMouseWheel(true)
    ui:SetScript("OnShow", function(self)
        self:Raise()
        if self.EnableGamePadButton then self:EnableGamePadButton(true) end
        SetPortraitTexture(self.portrait, "player")
        elapsed = 0
    end)
    ui:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        if self.EnableGamePadButton then self:EnableGamePadButton(false) end
        for _, row in ipairs(self.rows) do
            if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        end
        for _, pin in ipairs(self.map.pins) do
            if GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
        end
    end)
    ui:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < .5 then return end
        elapsed = 0
        checkZone()
        ZoneMap.UpdatePlayer(ui.map, zone)
    end)
    local function fit()
        ui:SetScale(math.min(1, (UIParent:GetWidth() - 24) / 820, (UIParent:GetHeight() - 24) / 608))
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
    zone, detail, history, index, message = playerZone(), nil, {}, 1, nil
    Native.Invalidate()
    ui:Show()
    prime()
    render()
end

SLASH_FOREVERQUESTGUIDE1 = "/fqg"
SlashCmdList.FOREVERQUESTGUIDE = ForeverQuestGuide_Toggle
Guide.Gear.OnChanged = queueRefresh

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
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_LOGIN" then
        attachLauncher()
        C_Timer.After(1, prime)
    elseif event == "ADDON_LOADED" then
        if arg == "Blizzard_WorldMap" then attachLauncher() end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0, checkZone)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if ui then close() end
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        Guide.Gear.Loaded(arg)
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        if Data.IsNative() and Native.DataLoaded(arg) then queueRefresh() end
    else
        Native.Invalidate()
        queueRefresh()
    end
end)
