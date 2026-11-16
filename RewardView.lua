local _, Guide = ...
local L = Guide.Locale
local RewardView = {}
Guide.RewardView = RewardView

local tileWidth, tileHeight, rowStep = 174, 43, 47
local firstRow, bottom = 32, 268
local white = "Interface\\Buttons\\WHITE8X8"
local unknownIcon = "Interface\\Icons\\INV_Misc_QuestionMark"

local function text(parent, template, anchor, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    label:SetPoint(anchor, x, y)
    label:SetJustifyH("LEFT")
    return label
end

local function ink(label)
    label:SetTextColor(.17, .095, .04)
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
    background(tile, "BACKGROUND", .27, .155, .075)
    local fill = tile:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetTexture(white)
    fill:SetGradient("VERTICAL", CreateColor(.36, .24, .13), CreateColor(.62, .46, .255))
    tile:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")

    local iconBorder = tile:CreateTexture(nil, "ARTWORK")
    iconBorder:SetSize(37, 37)
    iconBorder:SetPoint("LEFT", 4, 0)
    tile.iconBorder = iconBorder

    local icon = tile:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetSize(33, 33)
    icon:SetPoint("CENTER", iconBorder)
    tile.icon = icon

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

function RewardView.Create(parent, onSelect)
    local sheet = CreateFrame("Frame", nil, parent)
    sheet:SetPoint("TOPLEFT", 9, -54)
    sheet:SetSize(374, 333)
    sheet.onSelect, sheet.tiles, sheet.headings = onSelect, {}, {}
    background(sheet, "BACKGROUND", .87, .72, .46)
    local paper = sheet:CreateTexture(nil, "BACKGROUND", nil, 1)
    paper:SetAllPoints()
    paper:SetTexture("Interface\\QuestFrame\\QuestBG")
    paper:SetTexCoord(.08, .63, .07, .65)
    paper:SetAlpha(.42)

    local title = text(sheet, "GameFontNormalLarge", "TOPLEFT", 12, -9)
    title:SetText(L.QUEST_REWARDS)
    ink(title)
    sheet.empty = text(sheet, "GameFontHighlight", "TOPLEFT", 12, -41)
    sheet.empty:SetText(L.NO_ITEM_REWARDS)
    ink(sheet.empty)

    local line = sheet:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 12, 53)
    line:SetPoint("BOTTOMRIGHT", -12, 53)
    line:SetHeight(1)
    line:SetColorTexture(.45, .30, .16)
    local totalsTitle = text(sheet, "GameFontHighlight", "BOTTOMLEFT", 12, 34)
    totalsTitle:SetText(L.REWARD_MONEY_XP)
    ink(totalsTitle)
    sheet.totals = text(sheet, "GameFontHighlightLarge", "BOTTOMLEFT", 12, 11)
    ink(sheet.totals)
    sheet:Hide()
    return sheet
end

-- Pack two items per row, carrying the section heading over to the next page.
local function layout(entries)
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
    local pages = layout(entries)
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
            label = text(sheet, "GameFontHighlight", "TOPLEFT", 12, -block.y)
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
        local color = entry.tint
        tile.iconBorder:SetColorTexture(color and color.r or .72, color and color.g or .59, color and color.b or .37)
        tile.title:SetText(entry.title)
        tile.quantity:SetText(entry.quantity > 1 and entry.quantity or "")
        tile.focus:SetShown(index == position.index)
        if index == position.index then sheet.focused = tile end
        tile:Show()
    end
    for i = #tiles + 1, #sheet.tiles do sheet.tiles[i]:Hide() end
    return math.max(1, pageIndex), math.max(1, #pages)
end
