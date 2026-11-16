local _, Guide = ...
local ZoneMap = {}
Guide.ZoneMap = ZoneMap

local L = Guide.Locale
local colors = {
    quests = {1, .81, .24}, gear = {.65, .63, 1}, ore = {.95, .67, .35},
    herb = {.42, .93, .44}, fish = {.37, .78, 1},
}
local circle = "Interface\\Minimap\\UI-Minimap-WhiteIconHighlight"

local function place(region, canvas, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
end

local function translate(point, zone)
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

local function loadArt(map, zone)
    map.zone = zone
    local canvas = map.canvas
    for _, tile in ipairs(map.tiles) do tile:Hide() end
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
end

local function pinFor(map, index)
    local pin = map.pins[index]
    if pin then return pin end
    pin = CreateFrame("Button", nil, map.canvas)
    pin.dot = pin:CreateTexture(nil, "OVERLAY")
    pin.dot:SetTexture(circle)
    pin.dot:SetAllPoints()
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.entry.title)
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

function ZoneMap.Draw(map, zone, entries, focused, tab)
    if map.zone ~= zone then loadArt(map, zone) end
    local count, cells = 0, {}
    local color = colors[tab]
    local function add(entry, index, selected)
        for _, point in ipairs(entry.points or {}) do
            local x, y = translate(point, zone)
            if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                -- Keep the selected entry in front of adjacent markers.
                local key = ("%d:%d"):format(math.floor(x * 38), math.floor(y * 22))
                if not cells[key] and count < 260 then
                    cells[key] = true
                    count = count + 1
                    local pin = pinFor(map, count)
                    pin:SetSize(selected and 18 or 12, selected and 18 or 12)
                    pin:SetFrameLevel(map.canvas:GetFrameLevel() + (selected and 4 or 2))
                    pin.dot:SetVertexColor(color[1], color[2], color[3], selected and 1 or .85)
                    pin.entry, pin.index, pin.point = entry, index, point
                    place(pin, map.canvas, x, y)
                    pin:Show()
                end
            end
        end
    end
    if zone then
        if entries[focused] then add(entries[focused], focused, true) end
        for i, entry in ipairs(entries) do
            if i ~= focused then add(entry, i, false) end
            if count >= 260 then break end
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
    map.tiles, map.pins, map.zone = {}, {}, false
    map.fallback = map:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    map.fallback:SetPoint("CENTER")
    map.fallback:SetText(L.MAP_UNAVAILABLE)
    local player = CreateFrame("Frame", nil, canvas)
    player:SetSize(21, 21)
    player:SetFrameLevel(canvas:GetFrameLevel() + 5)
    local arrow = player:CreateTexture(nil, "OVERLAY")
    arrow:SetAllPoints()
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    map.player = player
    player:Hide()
    return map
end
