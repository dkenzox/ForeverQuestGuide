local _, Guide = ...
local L = Guide.Locale
local RewardView = {}
Guide.RewardView = RewardView

local tileWidth, tileHeight, rowStep = 174, 43, 47
local firstRow = 31
local parchmentFont = QuestFont and "QuestFont" or "GameFontHighlight"
local nameplateArt = "Interface\\QuestFrame\\UI-QuestItemNameFrame"
local unknownIcon = "Interface\\Icons\\INV_Misc_QuestionMark"

local function text(parent, template, anchor, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    label:SetPoint(anchor, x, y)
    label:SetJustifyH("LEFT")
    return label
end

local function ink(label, heading)
    local body, title
    if GetMaterialTextColors then body, title = GetMaterialTextColors("Parchment") end
    local color = heading and title or body
    if color then label:SetTextColor(color[1], color[2], color[3])
    else label:SetTextColor(.16, .095, .045) end
    label:SetShadowColor(0, 0, 0, 0)
end

local function background(frame, layer, r, g, b)
    local texture = frame:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, 1)
    return texture
end

local function hideTooltip(tile)
    if GameTooltip:IsOwned(tile) then GameTooltip:Hide() end
end

local function tileFor(sheet, slot)
    local tile = sheet.tiles[slot]
    if tile then return tile end

    tile = CreateFrame("Button", nil, sheet)
    tile:SetSize(tileWidth, tileHeight)
    tile.nameplate = {}
    local strips = {
        { 44, 4, .078125, .1171875 },
        { 48, tileWidth - 58, .1171875, .828125 },
        { tileWidth - 10, 10, .828125, .9140625 },
    }
    for i, strip in ipairs(strips) do
        local texture = tile:CreateTexture(nil, "BACKGROUND")
        texture:SetPoint("LEFT", strip[1], 0)
        texture:SetSize(strip[2], 40)
        texture:SetTexture(nameplateArt)
        texture:SetTexCoord(strip[3], strip[4], .15625, .828125)
        tile.nameplate[i] = texture
    end
    tile:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestItemHighlight", "ADD")

    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetSize(37, 37)
    icon:SetPoint("LEFT", 4, 0)
    tile.icon = icon
    local quality = tile:CreateTexture(nil, "OVERLAY")
    quality:SetAllPoints(icon)
    quality:SetTexture("Interface\\Common\\WhiteIconFrame")
    tile.quality = quality

    tile.quantity = text(tile, "GameFontHighlightSmall", "BOTTOMLEFT", 25, 6)
    tile.quantity:SetJustifyH("RIGHT")
    tile.title = text(tile, "GameFontHighlight", "LEFT", 49, 0)
    tile.title:SetWidth(tileWidth - 55)
    tile.title:SetMaxLines(2)
    tile.title:SetWordWrap(true)

    local focus = tile:CreateTexture(nil, "OVERLAY")
    focus:SetPoint("BOTTOMLEFT", 1, 1)
    focus:SetPoint("BOTTOMRIGHT", -1, 1)
    focus:SetHeight(2)
    focus:SetColorTexture(1, .81, .38)
    tile.focus = focus

    tile:SetScript("OnClick", function(self) sheet.onSelect(self.index) end)
    tile:SetScript("OnEnter", function(self) RewardView.Tooltip(self) end)
    tile:SetScript("OnLeave", hideTooltip)
    tile:SetScript("OnHide", hideTooltip)
    sheet.tiles[slot] = tile
    return tile
end

function RewardView.Tooltip(tile)
    if not (tile and tile.itemID) then return end
    GameTooltip:SetOwner(tile, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. tile.itemID)
    GameTooltip:Show()
end

function RewardView.Create(parent, onSelect, x, y, height)
    local sheet = CreateFrame("Frame", nil, parent)
    sheet:SetPoint("TOPLEFT", x, y)
    sheet:SetSize(374, height)
    sheet.bodyBottom = height - 51
    sheet.onSelect, sheet.tiles, sheet.headings = onSelect, {}, {}
    background(sheet, "BACKGROUND", 222 / 255, 176 / 255, 107 / 255)
    local paper = sheet:CreateTexture(nil, "BACKGROUND", nil, 1)
    paper:SetAllPoints()
    paper:SetTexture("Interface\\QuestFrame\\QuestBG")
    paper:SetTexCoord(.08, .63, .07, .65)

    local title = text(sheet, QuestTitleFont and "QuestTitleFont" or "GameFontNormalLarge", "TOPLEFT", 12, -9)
    title:SetText(L.QUEST_REWARDS)
    ink(title, true)
    sheet.empty = text(sheet, parchmentFont, "TOPLEFT", 12, -41)
    sheet.empty:SetText(L.NO_ITEM_REWARDS)
    ink(sheet.empty)

    local line = sheet:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 12, 45)
    line:SetPoint("BOTTOMRIGHT", -12, 45)
    line:SetHeight(1)
    line:SetColorTexture(.45, .30, .16)
    local totalsTitle = text(sheet, parchmentFont, "BOTTOMLEFT", 12, 29)
    totalsTitle:SetText(L.REWARD_MONEY_XP)
    ink(totalsTitle)
    sheet.totals = text(sheet, "GameFontHighlightLarge", "BOTTOMLEFT", 12, 8)
    sheet:Hide()
    return sheet
end

-- Pack two items per row, carrying the section heading over to the next page.
local function layout(entries, bottom)
    local pages, page, y, column, kind = {}, nil, nil, nil, nil
    for i, entry in ipairs(entries) do
        local heading = entry.subtitle ~= kind
        local needsRow = heading or column == 0
        if not page or (needsRow and y + (heading and 20 or 0) + tileHeight > bottom) then
            page = { first = i, blocks = {}, tiles = {} }
            pages[#pages + 1] = page
            y, column, heading = firstRow, 0, true
        end
        if heading then
            page.blocks[#page.blocks + 1] = { y = y, title = entry.heading }
            y, column, kind = y + 20, 0, entry.subtitle
        end
        if column == 0 then y = y + rowStep end
        page.tiles[#page.tiles + 1] = { index = i, y = y - rowStep, column = column }
        column = 1 - column
    end
    return pages
end

function RewardView.Draw(sheet, entries, index)
    local pages = layout(entries, sheet.bodyBottom)
    local pageIndex = #pages
    while pageIndex > 1 and pages[pageIndex].first > index do pageIndex = pageIndex - 1 end
    local page = pages[pageIndex]
    sheet.previous = pages[pageIndex - 1] and pages[pageIndex - 1].first
    sheet.next = pages[pageIndex + 1] and pages[pageIndex + 1].first
    sheet.focused = nil
    sheet.empty:SetShown(not page)
    sheet.totals:SetText(entries.totals or "")

    local blocks, tiles = {}, {}
    if page then blocks, tiles = page.blocks, page.tiles end
    for i, block in ipairs(blocks) do
        local label = sheet.headings[i]
        if not label then
            label = text(sheet, parchmentFont, "TOPLEFT", 12, -block.y)
            ink(label)
            sheet.headings[i] = label
        end
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", 12, -block.y)
        label:SetText(block.title)
        label:Show()
    end
    for i = #blocks + 1, #sheet.headings do sheet.headings[i]:Hide() end

    for i, position in ipairs(tiles) do
        local tile, entry = tileFor(sheet, i), entries[position.index]
        if tile.itemID ~= entry.itemID then hideTooltip(tile) end
        tile.itemID, tile.index = entry.itemID, position.index
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", 11 + position.column * 179, -position.y)
        tile.icon:SetTexture(entry.icon or unknownIcon)
        local color
        if entry.quality ~= nil then
            if ColorManager and ColorManager.GetColorDataForBagItemQuality then
                color = ColorManager.GetColorDataForBagItemQuality(entry.quality)
            else
                color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality]
            end
        end
        tile.quality:SetShown(color ~= nil)
        if color then tile.quality:SetVertexColor(color.r, color.g, color.b) end
        local usable = entry.usable ~= false
        local r, gb = usable and 1 or .9, usable and 1 or 0
        tile.icon:SetVertexColor(r, gb, gb)
        for _, strip in ipairs(tile.nameplate) do strip:SetVertexColor(r, gb, gb) end
        tile.title:SetText(entry.title)
        tile.quantity:SetText(entry.quantity > 1 and entry.quantity or "")
        tile.focus:SetShown(index == position.index)
        if index == position.index then sheet.focused = tile end
        tile:Show()
    end
    for i = #tiles + 1, #sheet.tiles do sheet.tiles[i]:Hide() end
    return math.max(1, pageIndex), math.max(1, #pages)
end
