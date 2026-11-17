local _, Guide = ...
local L, View, Data, NextZone, ZoneMap = Guide.Locale, Guide.View, Guide.Data, Guide.NextZone, Guide.ZoneMap
local Picker = {}
Guide.ZonePicker = Picker

local pageSize = 8
local factionNames = { H = L.ZONE_HORDE, A = L.ZONE_ALLIANCE }
local factionIcons = {
    H = "Interface\\TargetingFrame\\UI-PVP-Horde",
    A = "Interface\\TargetingFrame\\UI-PVP-Alliance",
}

local function label(parent, font, anchor, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint(anchor, x, y)
    text:SetWidth(width)
    text:SetWordWrap(false)
    text:SetJustifyH("LEFT")
    return text
end

local function background(parent, r, g, b)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, 1)
    return texture
end

local function frame(parent, width, height, anchor, x, y)
    local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pane:SetSize(width, height)
    pane:SetPoint(anchor, x, y)
    pane:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    pane:SetBackdropColor(.085, .062, .042, 1)
    pane:SetBackdropBorderColor(.70, .52, .26, 1)
    return pane
end

local function showLevel(font, entry, player)
    if not (entry and entry.low) then font:SetText(""); return end
    local range = entry.low == entry.high and tostring(entry.low) or ("%d–%d"):format(entry.low, entry.high)
    font:SetText(L.ZONE_LEVEL:format(entry.estimated and ("~" .. range) or range))
    font:SetTextColor(Data.LevelColor(entry.colorLevel, player.level))
end

local function drawPreview(picker, entry)
    picker.preview:SetShown(entry ~= nil)
    picker.open:SetEnabled(entry ~= nil)
    if not entry then return end
    local mapID = entry.mapID or picker.currentZone
    picker.previewTitle:SetText(Data.ZoneName(mapID))
    local region = entry.region or ""
    if entry.faction then region = region .. "  ·  " .. factionNames[entry.faction] end
    picker.previewRegion:SetText(region)
    showLevel(picker.previewLevel, entry, picker.player)
    picker.starts:SetText(entry.starts or 0)
    picker.active:SetText(entry.active or 0)
    picker.cluster:SetText(entry.cluster or 0)
    ZoneMap.Draw(picker.map, mapID, {}, 0, "quests", nil, true, nil, mapID == picker.currentZone)
    picker.map.legend:Hide()
    picker.map.caption:Hide()
end

local function draw(picker)
    local total = #picker.options
    picker.title:SetText(picker.recommending and L.NEXT_ZONE or L.ZONE_PICKER)
    picker.mode:SetText(picker.recommending and L.NEXT_ZONE_BACK or L.NEXT_ZONE)
    picker.hint:SetText(picker.recommending and L.NEXT_ZONE_PAD or L.ZONE_PICKER_PAD)
    picker.empty:SetText(Data.ready and L.NEXT_ZONE_EMPTY or L.LOADING)
    picker.empty:SetShown(total == 0)
    picker.index = math.max(1, math.min(picker.index, total))
    local page = math.floor((picker.index - 1) / pageSize) + 1
    local pages = math.max(1, math.ceil(total / pageSize))
    local first = (page - 1) * pageSize + 1

    for i, row in ipairs(picker.rows) do
        local index = first + i - 1
        local entry = picker.options[index]
        row.index = index
        row:SetShown(entry ~= nil)
        if entry then
            row.title:SetText(entry.name)
            row.title:SetTextColor(entry.hostile and .88 or 1, entry.hostile and .71 or .94, entry.hostile and .54 or .80)
            row.region:SetText(entry.region or "")
            row.faction:SetTexture(factionIcons[entry.faction] or "Interface\\Icons\\INV_Misc_Map_01")
            row.count:SetText(Data.ready and L.ZONE_ROW_STARTS:format(entry.starts or 0) or "")
            row.highlight:SetShown(index == picker.index)
            showLevel(row.level, entry, picker.player)
        end
    end
    picker.page:SetText(("%d / %d"):format(page, pages))
    picker.prev:SetEnabled(page > 1)
    picker.next:SetEnabled(page < pages)
    drawPreview(picker, picker.options[picker.index])
end

local function move(picker, offset)
    picker.index = picker.index + offset
    draw(picker)
end

local function selectZone(picker)
    local entry = picker.options[picker.index]
    if not entry then return end
    picker:Hide()
    local mapID = entry.mapID
    if picker.recommending and entry.current then mapID = nil end
    picker.onPick(mapID, picker.recommending)
end

local function buildOptions(picker, pinnedZone)
    local settings = Guide.Character.Settings()
    local ranked = NextZone.Zones(picker.currentZone, Data.KnownZones(picker.currentZone), picker.player, settings)
    picker.allOptions, picker.recommendations, picker.allIndex = {}, {}, 1
    if picker.currentZone then
        local automatic
        for _, entry in ipairs(ranked) do
            if entry.current then
                automatic = {}
                for key, value in pairs(entry) do automatic[key] = value end
                break
            end
        end
        automatic = automatic or {}
        automatic.name, automatic.mapID = L.CURRENT_ZONE, nil
        picker.allOptions[1] = automatic
    end
    for _, entry in ipairs(ranked) do
        if entry.recommended then picker.recommendations[#picker.recommendations + 1] = entry end
        picker.allOptions[#picker.allOptions + 1] = entry
        if entry.mapID == pinnedZone then picker.allIndex = #picker.allOptions end
    end
    picker.dataReady = Data.ready
end

function Picker.Refresh(picker)
    if not picker:IsShown() or picker.dataReady == Data.ready then return end
    local selected = picker.options[picker.index]
    local previous = picker.allOptions[picker.allIndex]
    buildOptions(picker, previous and previous.mapID)
    picker.options = picker.recommending and picker.recommendations or picker.allOptions
    picker.index = picker.recommending and 1 or picker.allIndex
    if selected then
        for index, entry in ipairs(picker.options) do
            if entry.mapID == selected.mapID then picker.index = index; break end
        end
    end
    draw(picker)
end

local function toggleMode(picker)
    if picker.recommending then
        picker.options, picker.index = picker.allOptions, picker.allIndex
    else
        picker.allIndex = picker.index
        picker.options, picker.index = picker.recommendations, 1
    end
    picker.recommending = not picker.recommending
    draw(picker)
end

local function stat(parent, x, caption)
    local tile = frame(parent, 136, 61, "TOPLEFT", x, -385)
    local amount = label(tile, "GameFontNormalLarge", "TOP", 0, -10, 123)
    amount:SetJustifyH("CENTER")
    local title = label(tile, "GameFontHighlightSmall", "BOTTOM", 0, 10, 124)
    title:SetJustifyH("CENTER")
    title:SetText(caption)
    return amount
end

function Picker.Create(parent, onPick)
    local picker = CreateFrame("Frame", nil, parent)
    picker:SetAllPoints()
    picker:SetFrameLevel(parent:GetFrameLevel() + 35)
    picker:EnableMouse(true)
    picker:EnableMouseWheel(true)
    picker:SetScript("OnMouseWheel", function(self, delta) move(self, -delta) end)
    local shade = picker:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, .62)

    local panel = frame(picker, 854, 585, "CENTER", 0, 0)
    local header = frame(panel, 834, 49, "TOPLEFT", 10, -9)
    local headerArt = background(header, .22, .14, .075)
    headerArt:SetGradient("VERTICAL", CreateColor(.14, .083, .045), CreateColor(.30, .19, .098))
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", 12, 0)
    picker.title = label(header, "GameFontNormalLarge", "TOPLEFT", 52, -7, 421)
    picker.context = label(header, "GameFontHighlightSmall", "BOTTOMLEFT", 52, 7, 421)
    picker.mode = View.Button(header, L.NEXT_ZONE, 155, 24, "RIGHT", -43, 0, function() toggleMode(picker) end)
    View.Button(header, "×", 27, 24, "RIGHT", -9, 0, function() picker:Hide() end)

    local list = frame(panel, 369, 426, "TOPLEFT", 11, -66)
    picker.empty = label(list, "GameFontHighlight", "TOPLEFT", 12, -16, 341)
    picker.empty:SetWordWrap(true)
    local preview = frame(panel, 452, 455, "TOPRIGHT", -11, -66)
    picker.preview = preview
    picker.previewTitle = label(preview, "GameFontNormalLarge", "TOPLEFT", 13, -12, 321)
    picker.previewRegion = label(preview, "GameFontHighlightSmall", "TOPLEFT", 14, -36, 421)
    picker.previewLevel = label(preview, "GameFontNormal", "TOPRIGHT", -14, -14, 96)
    picker.previewLevel:SetJustifyH("RIGHT")
    local mapFrame = frame(preview, 430, 320, "TOPLEFT", 11, -56)
    picker.map = ZoneMap.Create(mapFrame, nil, 420, 310)
    picker.starts = stat(preview, 12, L.ZONE_STARTS)
    picker.active = stat(preview, 158, L.ZONE_ACTIVE)
    picker.cluster = stat(preview, 304, L.ZONE_CLUSTER)

    picker.hint = label(panel, "GameFontHighlightSmall", "BOTTOM", 0, 11, 818)
    picker.hint:SetJustifyH("CENTER")
    picker.page = label(panel, "GameFontHighlightSmall", "BOTTOMLEFT", 153, 42, 83)
    picker.page:SetJustifyH("CENTER")
    picker.prev = View.Button(panel, "<", 25, 21, "BOTTOMLEFT", 119, 36, function() move(picker, -pageSize) end)
    picker.next = View.Button(panel, ">", 25, 21, "BOTTOMLEFT", 246, 36, function() move(picker, pageSize) end)
    picker.open = View.Button(panel, L.OPEN_ZONE, 126, 24, "BOTTOMRIGHT", -11, 34, function() selectZone(picker) end)

    picker.rows, picker.onPick = {}, onPick
    for i = 1, pageSize do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(353, 48)
        row:SetPoint("TOPLEFT", 8, -7 - (i - 1) * 52)
        local fill = background(row, .145, .104, .070)
        fill:SetGradient("HORIZONTAL", CreateColor(.20, .137, .079), CreateColor(.112, .078, .048))
        local highlight = row:CreateTexture(nil, "BORDER")
        highlight:SetAllPoints()
        highlight:SetColorTexture(.49, .31, .124, .91)
        row.highlight = highlight
        row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
        row.faction = row:CreateTexture(nil, "ARTWORK")
        row.faction:SetPoint("LEFT", 9, 0)
        row.faction:SetSize(23, 23)
        row.title = label(row, "GameFontHighlight", "TOPLEFT", 39, -7, 216)
        row.region = label(row, "GameFontHighlightSmall", "BOTTOMLEFT", 39, 7, 215)
        row.region:SetTextColor(.73, .66, .54)
        row.level = label(row, "GameFontNormal", "TOPRIGHT", -9, -7, 83)
        row.level:SetJustifyH("RIGHT")
        row.count = label(row, "GameFontHighlightSmall", "BOTTOMRIGHT", -9, 7, 83)
        row.count:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function(self)
            if picker.index == self.index then selectZone(picker)
            else picker.index = self.index; draw(picker) end
        end)
        picker.rows[i] = row
    end
    picker:Hide()
    return picker
end

function Picker.Open(picker, currentZone, pinnedZone)
    picker.currentZone, picker.recommending = currentZone, false
    picker.player = Data.Player()
    picker.context:SetText(L.NEXT_ZONE_CONTEXT:format(picker.player.level, Data.ZoneName(currentZone)))
    buildOptions(picker, pinnedZone)
    picker.options, picker.index = picker.allOptions, picker.allIndex
    picker:Show()
    draw(picker)
end

function Picker.OnPad(picker, key)
    if key == "PADDUP" then move(picker, -1)
    elseif key == "PADDDOWN" then move(picker, 1)
    elseif key == "PADLTRIGGER" then move(picker, -pageSize)
    elseif key == "PADRTRIGGER" then move(picker, pageSize)
    elseif key == "PAD1" then selectZone(picker)
    elseif key == "PAD4" or (key == "PAD2" and picker.recommending) then toggleMode(picker)
    elseif key == "PAD2" or key == "PADFORWARD" then picker:Hide() end
end
