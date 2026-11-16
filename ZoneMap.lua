local _, Guide = ...
local ZoneMap = {}
Guide.ZoneMap = ZoneMap

local L, Pins = Guide.Locale, Guide.QuestPins
local colors = {
    quests = {1, .81, .24}, gear = {.65, .63, 1}, ore = {.95, .67, .35},
    herb = {.42, .93, .44}, fish = {.37, .78, 1},
}
local function place(region, canvas, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
end

function ZoneMap.Translate(point, zone)
    local x, y = point.x / 100, point.y / 100
    if point.mapID == zone then return x, y end
    if not C_Map.GetMapRectOnMap then return end
    local left, right, top, bottom = C_Map.GetMapRectOnMap(point.mapID, zone)
    if left and right and top and bottom and right > left and bottom > top then
        return left + (right - left) * x, top + (bottom - top) * y
    end
end

local function tileFileSize(pixels, maximum)
    local size = math.min(16, maximum)
    while size < pixels do size = size * 2 end
    return math.min(size, maximum)
end

local function overlayTexture(map, i, file, x, y, width, height, scale, texCoords, front)
    local texture = map.overlays[i]
    if not texture then
        texture = map.canvas:CreateTexture(nil, "ARTWORK")
        map.overlays[i] = texture
    end
    texture:SetDrawLayer("ARTWORK", front and 2 or 1)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", map.canvas, "TOPLEFT", x * scale, -y * scale)
    texture:SetSize(width * scale, height * scale)
    texture:SetTexCoord(unpack(texCoords))
    texture:SetTexture(file)
    texture:Show()
end

local function loadOverlays(map, zone, layer, scale)
    local seen, index = {}, 0
    local function add(file, x, y, w, h, coords, front)
        if not (file and x and y and w and h and w > 0 and h > 0) then return end
        local key = ("%s:%.0f:%.0f"):format(file, x, y)
        if seen[key] then return end
        seen[key] = true
        index = index + 1
        overlayTexture(map, index, file, x, y, w, h, scale, coords, front)
    end
    local tw, th = layer.tileWidth, layer.tileHeight
    local explored = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
        and C_MapExplorationInfo.GetExploredMapTextures(zone)
    for _, area in ipairs(explored or {}) do
        if not area.isShownByMouseOver then
            local cols = math.ceil(area.textureWidth / tw)
            for i, file in ipairs(area.fileDataIDs or {}) do
                local x, y = (i - 1) % cols * tw, math.floor((i - 1) / cols) * th
                local w, h = math.min(tw, area.textureWidth - x), math.min(th, area.textureHeight - y)
                if w > 0 and h > 0 then
                    add(file, area.offsetX + x, area.offsetY + y, w, h,
                        {0, w / tileFileSize(w, tw), 0, h / tileFileSize(h, th)}, area.isDrawOnTopLayer)
                end
            end
        end
    end

    -- Reuse the same map's already-rendered exploration art, including reveals from map addons.
    local world = WorldMapFrame
    if world and world.EnumeratePinsByTemplate and world:GetMapID() == zone then
        for pin in world:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
            if pin.layerIndex == 1 then
                for _, texture in ipairs({pin:GetRegions()}) do
                    if texture:GetObjectType() == "Texture" and texture:IsShown() then
                        local anchor, _, relative, x, y = texture:GetPoint()
                        if anchor == "TOPLEFT" and relative == "TOPLEFT" and x and y then
                            add(texture:GetTexture(), x, -y, texture:GetWidth(), texture:GetHeight(),
                                {texture:GetTexCoord()})
                        end
                    end
                end
            end
        end
    end
end

local function loadArt(map, zone)
    map.zone = zone
    local canvas = map.canvas
    for _, tile in ipairs(map.tiles) do tile:Hide() end
    for _, overlay in ipairs(map.overlays) do overlay:Hide() end
    local layer = zone and C_Map.GetMapArtLayers and (C_Map.GetMapArtLayers(zone) or {})[1]
    local files = layer and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(zone, 1)
    map.fallback:SetShown(not files or #files == 0)
    if not files or #files == 0 then return end
    local w, h = layer.layerWidth, layer.layerHeight
    local tw, th = layer.tileWidth, layer.tileHeight
    if not (w and h and tw and th and w > 0 and h > 0 and tw > 0 and th > 0) then
        map.fallback:Show()
        return
    end
    local columns = math.ceil(w / tw)
    local scale = math.min(map:GetWidth() / w, map:GetHeight() / h)
    canvas:SetSize(w * scale, h * scale)
    for i, file in ipairs(files) do
        local x, y = ((i - 1) % columns) * tw, math.floor((i - 1) / columns) * th
        local width, height = math.min(tw, w - x), math.min(th, h - y)
        if width > 0 and height > 0 then
            local tile = map.tiles[i]
            if not tile then
                tile = canvas:CreateTexture(nil, "ARTWORK")
                map.tiles[i] = tile
            end
            tile:SetTexture(file)
            tile:SetSize(width * scale, height * scale)
            tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", x * scale, -y * scale)
            tile:SetTexCoord(0, width / tileFileSize(width, tw), 0, height / tileFileSize(height, th))
            tile:Show()
        end
    end
    loadOverlays(map, zone, layer, scale)
end

local function pinFor(map, index)
    local pin = map.pins[index]
    if pin then return pin end
    pin = CreateFrame("Button", nil, map.canvas)
    Pins.Decorate(pin)
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.entry.title)
        local role = Pins.Label(self.point.stage)
        if role then GameTooltip:AddLine(role .. (self.point.name and (" · " .. self.point.name) or ""), .95, .83, .54) end
        GameTooltip:AddLine(("%.1f, %.1f"):format(self.point.x, self.point.y), 1, 1, 1)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    pin:SetScript("OnClick", function(self, button)
        map.onPin(self.index, self.point, button)
    end)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    map.pins[index] = pin
    return pin
end

function ZoneMap.UpdatePlayer(map, zone)
    local position = zone and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(zone, "player")
    local x, y
    if position then x, y = position:GetXY() end
    map.player:SetShown(x ~= nil and y ~= nil and x >= 0 and y >= 0 and x <= 1 and y <= 1 and (x ~= 0 or y ~= 0))
    if map.player:IsShown() then place(map.player, map.canvas, x, y) end
end

function ZoneMap.Draw(map, zone, entries, focused, tab, highlighted)
    if map.zone ~= zone then loadArt(map, zone) end
    local count, cells = 0, {}
    local color = colors[tab]
    map.legend:SetShown(tab == "quests" or tab == "gear")
    map.caption:SetText(zone and Guide.Data.ZoneName(zone) or "")
    local function add(entry, index, selected, points)
        for _, point in ipairs(points or entry.points or {}) do
            local x, y = ZoneMap.Translate(point, zone)
            if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                -- Keep the selected entry in front of adjacent markers.
                local key = ("%d:%d"):format(math.floor(x * 38), math.floor(y * 22))
                local cell = cells[key]
                if not cell then cell = {}; cells[key] = cell end
                local role = selected and point.stage or "background"
                if not cell[role] and (selected or not next(cell)) and count < 205 then
                    cell[role] = true
                    count = count + 1
                    local pin = pinFor(map, count)
                    local size = selected and 17 or (point.stage and 13 or 10)
                    pin:SetSize(size, size)
                    local priority = point.stage == "start" and 3 or (point.stage == "finish" and 2 or 1)
                    pin:SetFrameLevel(map.canvas:GetFrameLevel() + (selected and 5 or 1) + priority)
                    Pins.Style(pin, point.stage, color, selected)
                    pin.entry, pin.index, pin.point = entry, index, point
                    if selected and point.stage == "objective" and cell.start then x = math.min(.985, x + .032) end
                    if selected and point.stage == "finish" then
                        if cell.start then x = math.max(.015, x - .032) end
                        if cell.objective and not cell.start then x = math.max(.015, x - .032) end
                    end
                    place(pin, map.canvas, x, y)
                    pin:Show()
                end
            end
        end
    end
    if zone then
        if entries[focused] then add(entries[focused], focused, true, highlighted) end
        for i, entry in ipairs(entries) do
            if i ~= focused then add(entry, i, false) end
            if count >= 205 then break end
        end
    end
    for i = count + 1, #map.pins do
        local pin = map.pins[i]
        if GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
        pin:Hide()
    end
    ZoneMap.UpdatePlayer(map, zone)
end

function ZoneMap.Create(parent, onPin)
    local map = CreateFrame("Frame", nil, parent)
    map:SetSize(388, 258)
    map:SetPoint("TOPLEFT", 5, -5)
    local canvas = CreateFrame("Frame", nil, map)
    canvas:SetPoint("CENTER")
    canvas:SetSize(388, 258)
    map.canvas, map.onPin = canvas, onPin
    map.tiles, map.overlays, map.pins, map.zone = {}, {}, {}, false
    local legend = CreateFrame("Frame", nil, map)
    legend:SetSize(360, 19)
    legend:SetPoint("BOTTOM", 0, 4)
    legend:SetFrameLevel(canvas:GetFrameLevel() + 12)
    local background = legend:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(.06, .045, .027, .92)
    local legendText = legend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    legendText:SetPoint("CENTER")
    legendText:SetText(L.MAP_LEGEND)
    map.legend = legend
    local caption = CreateFrame("Frame", nil, map)
    caption:SetSize(372, 19)
    caption:SetPoint("TOP", 0, -4)
    caption:SetFrameLevel(canvas:GetFrameLevel() + 12)
    map.caption = caption:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    map.caption:SetPoint("CENTER")
    map.fallback = map:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    map.fallback:SetPoint("CENTER")
    map.fallback:SetText(L.MAP_UNAVAILABLE)
    local player = CreateFrame("Frame", nil, canvas)
    player:SetSize(21, 21)
    player:SetFrameLevel(canvas:GetFrameLevel() + 10)
    local arrow = player:CreateTexture(nil, "OVERLAY")
    arrow:SetAllPoints()
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    map.player = player
    player:Hide()
    return map
end
