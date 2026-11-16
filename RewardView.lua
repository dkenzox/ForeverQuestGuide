local _, Guide = ...
local L = Guide.Locale
local RewardView = {}
Guide.RewardView = RewardView

local tileWidth, tileHeight, rowStep = 172, 33, 38
local itemTop, metricTop, metricRow = 34, 47, 86
local unknownIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
local xpIcon = "Interface\\Icons\\XP_Icon"
local moneyIcon = "Interface\\Icons\\INV_Misc_Coin_01"
local plateAtlas = "QuestItemBorder"

local function text(parent, template, anchor, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    label:SetPoint(anchor, x, y)
    return label
end

local function darkGradient(parent, layer, bottom, top)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetGradient("VERTICAL", CreateColor(unpack(bottom)), CreateColor(unpack(top)))
    return texture
end

local function line(parent, point, dy, r, g, b)
    local texture = parent:CreateTexture(nil, "BORDER")
    texture:SetPoint(point .. "LEFT", 0, dy)
    texture:SetPoint(point .. "RIGHT", 0, dy)
    texture:SetHeight(1)
    texture:SetColorTexture(r, g, b)
end

local function hideTooltip(tile)
    if GameTooltip:IsOwned(tile) then GameTooltip:Hide() end
end

local function createTile(sheet, isItem)
    local tile = CreateFrame(isItem and "Button" or "Frame", nil, sheet)
    tile:SetSize(tileWidth, tileHeight)

    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetSize(33, 33)
    icon:SetPoint("LEFT", 0, 0)
    tile.icon = icon
    local iconFrame = tile:CreateTexture(nil, "OVERLAY")
    iconFrame:SetAllPoints(icon)
    iconFrame:SetTexture("Interface\\Common\\WhiteIconFrame")
    tile.iconFrame = iconFrame

    local plate = CreateFrame("Frame", nil, tile)
    plate:SetPoint("TOPLEFT", 36, -2)
    plate:SetPoint("BOTTOMRIGHT", 0, 2)
    local skin
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(plateAtlas) then
        skin = plate:CreateTexture(nil, "BACKGROUND")
        skin:SetAllPoints()
        skin:SetAtlas(plateAtlas)
    else
        skin = darkGradient(plate, "BACKGROUND", {.125, .083, .049}, {.23, .147, .081})
        line(plate, "TOP", 0, .38, .24, .117)
        line(plate, "BOTTOM", 0, .38, .24, .117)
    end
    tile.skin = skin

    local label = text(plate, isItem and "GameFontHighlight" or "GameFontHighlightLarge", "LEFT", 7, 0)
    label:SetWidth(tileWidth - 49)
    label:SetMaxLines(2)
    label:SetWordWrap(true)
    label:SetJustifyH("LEFT")
    tile.title = label

    if isItem then
        tile:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
        tile.quantity = text(tile, "GameFontHighlightSmall", "BOTTOMLEFT", 22, 3)
        tile.quantity:SetJustifyH("RIGHT")
        local focus = plate:CreateTexture(nil, "OVERLAY")
        focus:SetPoint("BOTTOMLEFT", 1, 0)
        focus:SetPoint("BOTTOMRIGHT", -1, 0)
        focus:SetHeight(2)
        focus:SetColorTexture(1, .81, .38)
        tile.focus = focus
        tile:SetScript("OnClick", function(self) sheet.onSelect(self.index) end)
        tile:SetScript("OnEnter", function(self) RewardView.Tooltip(self) end)
        tile:SetScript("OnLeave", hideTooltip)
        tile:SetScript("OnHide", hideTooltip)
    end
    return tile
end

function RewardView.Tooltip(tile)
    if not (tile and tile.itemID) then return end
    GameTooltip:SetOwner(tile, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink("item:" .. tile.itemID)
    GameTooltip:Show()
end

function RewardView.Create(parent, onSelect, x, y, height)
    local sheet = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    sheet:SetPoint("TOPLEFT", x, y)
    sheet:SetSize(374, height)
    sheet:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    sheet:SetBackdropColor(.26, .17, .105, 1)
    sheet:SetBackdropBorderColor(.51, .33, .17, 1)
    sheet.maxHeight, sheet.onSelect, sheet.tiles, sheet.headings = height, onSelect, {}, {}

    local banner = CreateFrame("Frame", nil, sheet)
    banner:SetPoint("TOPLEFT", 3, -3)
    banner:SetPoint("TOPRIGHT", -3, -3)
    banner:SetHeight(25)
    darkGradient(banner, "BACKGROUND", {.21, .12, .07}, {.36, .23, .13})
    line(banner, "BOTTOM", 0, .52, .33, .17)
    local title = text(banner, QuestTitleFont and "QuestTitleFont" or "GameFontNormalLarge", "CENTER", 0, 0)
    title:SetText(L.QUEST_REWARDS)
    title:SetTextColor(1, .89, .69)

    sheet.receive = text(sheet, "GameFontHighlightSmall", "TOPLEFT", 11, -34)
    sheet.receive:SetText(L.REWARD_ALSO_RECEIVE)
    sheet.receive:SetTextColor(.97, .86, .68)
    sheet.empty = text(sheet, "GameFontHighlight", "TOPLEFT", 11, -34)
    sheet.empty:SetText(L.NO_REWARDS_LISTED)
    sheet.xp = createTile(sheet)
    sheet.xp.icon:SetTexture(xpIcon)
    sheet.xp.iconFrame:SetVertexColor(.88, .68, 1)
    sheet.money = createTile(sheet)
    sheet.money.icon:SetTexture(moneyIcon)
    sheet.money.iconFrame:SetVertexColor(1, .82, .42)
    sheet:Hide()
    return sheet
end

local function layout(entries, top, bottom, metric)
    local pages, page, y, column, group = {}, nil, nil, nil, nil
    for i, entry in ipairs(entries) do
        local newGroup = entry.subtitle ~= group
        local heading = newGroup
        if i == 1 and metric and entry.subtitle == L.REWARD_GUARANTEED then heading = false end
        local needsRow = newGroup or column == 0
        if not page or (needsRow and y + (heading and 15 or 0) + tileHeight > bottom) then
            page = { first = i, blocks = {}, tiles = {} }
            pages[#pages + 1] = page
            y, column = top, 0
            if i > 1 then heading = true end
        end
        if heading then
            page.blocks[#page.blocks + 1] = { y = y, title = entry.heading }
            y = y + 15
        end
        if newGroup then column, group = 0, entry.subtitle end
        if column == 0 then y = y + rowStep end
        local tileY = y - rowStep
        page.tiles[#page.tiles + 1] = { index = i, y = tileY, column = column }
        page.used = tileY + tileHeight
        column = 1 - column
    end
    return pages
end

local function position(tile, column, y)
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", 11 + column * 179, -y)
end

local function setMetric(tile, value, column)
    tile:SetShown(value ~= nil)
    if value then
        position(tile, column, metricTop)
        tile.title:SetText(value)
    end
end

function RewardView.Draw(sheet, entries, index)
    local metric = entries.xp or entries.money
    local pages = layout(entries, metric and metricRow or itemTop, sheet.maxHeight - 23, metric)
    local pageIndex = #pages
    while pageIndex > 1 and pages[pageIndex].first > index do pageIndex = pageIndex - 1 end
    local page = pages[pageIndex]
    sheet.previous = pages[pageIndex - 1] and pages[pageIndex - 1].first
    sheet.next = pages[pageIndex + 1] and pages[pageIndex + 1].first
    sheet.focused = nil
    sheet.receive:SetShown(metric ~= nil)
    sheet.empty:SetShown(not page and not metric)
    setMetric(sheet.xp, entries.xp, 0)
    setMetric(sheet.money, entries.money, entries.xp and 1 or 0)
    local used = page and page.used or (metric and metricTop + tileHeight or 48)
    sheet:SetHeight(used + (#pages > 1 and 22 or 9))

    local blocks, tiles = {}, {}
    if page then blocks, tiles = page.blocks, page.tiles end
    for i, block in ipairs(blocks) do
        local label = sheet.headings[i]
        if not label then
            label = text(sheet, "GameFontHighlightSmall", "TOPLEFT", 11, -block.y)
            label:SetTextColor(.97, .86, .68)
            sheet.headings[i] = label
        end
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", 11, -block.y)
        label:SetText(block.title)
        label:Show()
    end
    for i = #blocks + 1, #sheet.headings do sheet.headings[i]:Hide() end

    for i, cell in ipairs(tiles) do
        local tile, entry = sheet.tiles[i], entries[cell.index]
        if not tile then tile = createTile(sheet, true); sheet.tiles[i] = tile end
        if tile.itemID ~= entry.itemID then hideTooltip(tile) end
        tile.itemID, tile.index = entry.itemID, cell.index
        position(tile, cell.column, cell.y)
        tile.icon:SetTexture(entry.icon or unknownIcon)
        local color
        if entry.quality ~= nil then
            if ColorManager and ColorManager.GetColorDataForBagItemQuality then
                color = ColorManager.GetColorDataForBagItemQuality(entry.quality)
            else
                color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality]
            end
        end
        tile.iconFrame:SetVertexColor(color and color.r or .53, color and color.g or .36, color and color.b or .20)
        local usable = entry.usable ~= false
        local r, gb = usable and 1 or .9, usable and 1 or 0
        tile.icon:SetVertexColor(r, gb, gb)
        tile.skin:SetVertexColor(r, gb, gb)
        tile.title:SetText(entry.title)
        tile.quantity:SetText(entry.quantity > 1 and entry.quantity or "")
        tile.focus:SetShown(index == cell.index)
        if index == cell.index then sheet.focused = tile end
        tile:Show()
    end
    for i = #tiles + 1, #sheet.tiles do sheet.tiles[i]:Hide() end
    return math.max(1, pageIndex), math.max(1, #pages)
end
