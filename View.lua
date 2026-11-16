local _, Guide = ...
local L, ZoneMap = Guide.Locale, Guide.ZoneMap
local View = { pageSize = 8 }
Guide.View = View

local icons = {
    quests = "Interface\\GossipFrame\\AvailableQuestIcon",
    gear = "Interface\\Icons\\INV_Chest_Chain_03",
    ore = "Interface\\Icons\\Trade_Mining",
    herb = "Interface\\Icons\\Spell_Nature_NatureTouchGrow",
    fish = "Interface\\Icons\\Trade_Fishing",
}
View.icons = icons

local function font(parent, template, anchor, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    label:SetPoint(anchor, x, y)
    label:SetJustifyH("LEFT")
    if width then label:SetWidth(width) end
    label:SetWordWrap(false)
    return label
end

local function image(parent, layer, path, sublevel)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture(path)
    return texture
end

local function frame(parent, w, h, anchor, x, y, r, g, b)
    local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pane:SetSize(w, h)
    pane:SetPoint(anchor, x, y)
    pane:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 13,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    pane:SetBackdropColor(r or .28, g or .24, b or .20, 1)
    pane:SetBackdropBorderColor(.73, .55, .29, 1)
    return pane
end

local function rule(parent, anchor, x, y, w)
    local line = image(parent, "ARTWORK", nil)
    line:SetPoint(anchor, x, y)
    line:SetSize(w, 1)
    line:SetColorTexture(.69, .48, .22, .8)
end

function View.Button(parent, text, w, h, anchor, x, y, click)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(w, h)
    control:SetPoint(anchor, x, y)
    control:SetText(text)
    control:SetScript("OnClick", click)
    return control
end

local function tabButton(parent, tab, index, selectTab)
    local control = CreateFrame("Button", nil, parent)
    control:SetPoint("TOPLEFT", 17 + (index - 1) * 158, -79)
    control:SetSize(154, 36)
    local fill = image(control, "BACKGROUND", "Interface\\Buttons\\WHITE8X8")
    fill:SetAllPoints()
    fill:SetGradient("VERTICAL", CreateColor(.13, .09, .06), CreateColor(.24, .19, .14))
    control.fill = fill
    local ribbon = image(control, "ARTWORK", "Interface\\Buttons\\WHITE8X8")
    ribbon:SetPoint("BOTTOMLEFT")
    ribbon:SetPoint("BOTTOMRIGHT")
    ribbon:SetHeight(2)
    ribbon:SetColorTexture(.96, .68, .29)
    control.ribbon = ribbon
    control:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    local icon = image(control, "ARTWORK", icons[tab.key])
    icon:SetPoint("LEFT", 11, 0)
    icon:SetSize(19, 19)
    control.title = font(control, "GameFontNormal", "LEFT", 40, 0, 109)
    control.title:SetText(tab.label)
    control:SetScript("OnClick", function() selectTab(index) end)
    return control
end

local function rowButton(parent, index, selectRow)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(378, 43)
    row:SetPoint("TOPLEFT", 7, -30 - (index - 1) * 44)
    local bg = image(row, "BACKGROUND", nil)
    bg:SetAllPoints()
    bg:SetColorTexture(.79, .61, .30, index % 2 == 0 and .065 or .09)
    local selected = image(row, "BORDER", "Interface\\Buttons\\WHITE8X8")
    selected:SetAllPoints()
    selected:SetGradient("HORIZONTAL", CreateColor(.47, .30, .125, .92), CreateColor(.22, .15, .09, .9))
    row.selected = selected
    local indicator = image(row, "ARTWORK", nil)
    indicator:SetSize(3, 34)
    indicator:SetPoint("LEFT")
    indicator:SetColorTexture(1, .79, .32)
    row.indicator = indicator
    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")

    local rim = image(row, "ARTWORK", nil)
    rim:SetSize(31, 31)
    rim:SetPoint("LEFT", 9, 0)
    rim:SetColorTexture(.55, .41, .23, 1)
    row.iconRim = rim
    row.icon = image(row, "ARTWORK", nil, 1)
    row.icon:SetPoint("CENTER", rim)
    row.icon:SetSize(27, 27)
    row.icon:SetTexCoord(.07, .93, .07, .93)
    row.title = font(row, "GameFontHighlight", "TOPLEFT", 48, -6, 321)
    row.subtitle = font(row, "GameFontDisableSmall", "BOTTOMLEFT", 48, 6, 321)
    row.subtitle:SetTextColor(.76, .72, .64)
    row:SetScript("OnClick", function(self) selectRow(self.index, true) end)
    return row
end

function View.Create(tabs, actions)
    local ui = frame(UIParent, 820, 608, "CENTER", 0, 0, .44, .35, .27)
    ui:SetFrameStrata("DIALOG")
    ui:SetFrameLevel(90)
    ui:SetToplevel(true)
    ui:EnableMouse(true)
    ui:SetClampedToScreen(true)
    ui:SetMovable(true)
    ui:Hide()

    local header = CreateFrame("Frame", nil, ui)
    header:SetPoint("TOPLEFT", 7, -7)
    header:SetSize(806, 67)
    header:EnableMouse(true)
    header:SetScript("OnMouseDown", function(_, key) if key == "LeftButton" then ui:StartMoving() end end)
    header:SetScript("OnMouseUp", function() ui:StopMovingOrSizing() end)
    local headerFill = image(header, "BACKGROUND", "Interface\\Buttons\\WHITE8X8")
    headerFill:SetAllPoints()
    headerFill:SetGradient("VERTICAL", CreateColor(.13, .085, .055), CreateColor(.26, .17, .09))
    rule(header, "BOTTOMLEFT", 4, 0, 798)

    local portrait = image(header, "ARTWORK", nil)
    portrait:SetSize(53, 53)
    portrait:SetPoint("LEFT", 15, 1)
    ui.portrait = portrait
    local ring = image(header, "OVERLAY", "Interface\\CharacterFrame\\UI-Character-Portrait-Border")
    ring:SetSize(69, 69)
    ring:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    ring:SetVertexColor(1, .86, .58)

    local title = font(header, "GameFontNormalSmall", "TOPLEFT", 83, -9)
    title:SetText("Forever Quest Guide")
    ui.zone = font(header, "GameFontNormalHuge", "TOPLEFT", 81, -22, 565)
    ui.context = font(header, "GameFontHighlightSmall", "BOTTOMLEFT", 83, 6, 560)
    ui.context:SetTextColor(.82, .77, .65)
    ui.source = font(header, "GameFontDisableSmall", "BOTTOMRIGHT", -15, 7, 169)
    ui.source:SetJustifyH("RIGHT")
    ui.close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    ui.close:SetPoint("TOPRIGHT", 0, 2)
    ui.close:SetScript("OnClick", actions.close)

    ui.tabs = {}
    for index, tab in ipairs(tabs) do ui.tabs[index] = tabButton(ui, tab, index, actions.tab) end

    local list = frame(ui, 392, 422, "TOPLEFT", 16, -124)
    ui.listTitle = font(list, "GameFontNormal", "TOPLEFT", 14, -10, 318)
    ui.count = font(list, "GameFontHighlightSmall", "TOPRIGHT", -14, -11)
    ui.rows = {}
    for i = 1, View.pageSize do ui.rows[i] = rowButton(list, i, actions.row) end
    ui.prev = View.Button(list, "<", 27, 21, "BOTTOM", -57, 10, function() actions.page(-1) end)
    ui.next = View.Button(list, ">", 27, 21, "BOTTOM", 57, 10, function() actions.page(1) end)
    ui.page = font(list, "GameFontHighlightSmall", "BOTTOM", 0, 15)
    ui.back = View.Button(list, L.BACK, 74, 21, "BOTTOMLEFT", 10, 10, actions.back)

    local mapPanel = frame(ui, 398, 268, "TOPRIGHT", -16, -124, .26, .20, .14)
    ui.map = ZoneMap.Create(mapPanel, actions.pin)
    local detail = frame(ui, 398, 147, "TOPRIGHT", -16, -399, .17, .13, .09)
    local parchment = image(detail, "BACKGROUND", "Interface\\QuestFrame\\QuestBG", 2)
    parchment:SetPoint("TOPLEFT", 4, -4)
    parchment:SetPoint("BOTTOMRIGHT", -4, 4)
    parchment:SetTexCoord(.05, .75, .04, .39)
    parchment:SetVertexColor(.57, .49, .37, .54)

    ui.detailTitle = font(detail, "GameFontNormalLarge", "TOPLEFT", 13, -12, 370)
    rule(detail, "TOPLEFT", 13, -37, 370)
    ui.detail = font(detail, "GameFontHighlight", "TOPLEFT", 13, -46, 370)
    ui.detail:SetWordWrap(true)
    ui.detail:SetMaxLines(4)
    ui.coords = font(detail, "GameFontHighlightSmall", "BOTTOMLEFT", 13, 15, 233)
    ui.coords:SetTextColor(.94, .82, .57)
    ui.waypoint = View.Button(detail, L.MARK, 110, 24, "BOTTOMRIGHT", -11, 9, actions.mark)

    ui.filter = View.Button(ui, "", 174, 24, "BOTTOMRIGHT", -16, 31, actions.filter)
    ui.status = font(ui, "GameFontHighlightSmall", "BOTTOMLEFT", 17, 37, 590)
    ui.status:SetTextColor(.81, .76, .65)
    rule(ui, "BOTTOMLEFT", 17, 27, 785)
    local hint = font(ui, "GameFontHighlightSmall", "BOTTOMLEFT", 17, 8, 786)
    hint:SetText(L.PAD_GUIDE)
    hint:SetJustifyH("CENTER")
    return ui
end

function View.Rows(ui, entries, index)
    local size, total = View.pageSize, #entries
    local page, pages = math.floor((index - 1) / size) + 1, math.max(1, math.ceil(total / size))
    local first = (page - 1) * size + 1
    for i, row in ipairs(ui.rows) do
        local position = first + i - 1
        local entry = entries[position]
        row.index = position
        row:SetShown(entry ~= nil)
        if entry then
            local focused = position == index
            row.title:SetText(entry.title)
            local color = entry.tint
            row.title:SetTextColor(color and color.r or 1, color and color.g or .88, color and color.b or .66)
            row.subtitle:SetText(entry.subtitle or "")
            row.icon:SetTexture(entry.icon)
            row.icon:SetShown(entry.icon ~= nil)
            row.iconRim:SetShown(entry.icon ~= nil)
            row.selected:SetShown(focused)
            row.indicator:SetShown(focused)
        end
    end
    ui.count:SetText(total > 0 and total or "")
    ui.page:SetText(("%d / %d"):format(page, pages))
    ui.prev:SetEnabled(page > 1)
    ui.next:SetEnabled(page < pages)
end

function View.Tab(ui, index)
    for i, button in ipairs(ui.tabs) do
        button.ribbon:SetShown(i == index)
        if i == index then
            button.fill:SetGradient("VERTICAL", CreateColor(.24, .15, .08), CreateColor(.45, .31, .15))
            button.title:SetTextColor(1, .88, .58)
        else
            button.fill:SetGradient("VERTICAL", CreateColor(.10, .078, .06), CreateColor(.22, .17, .12))
            button.title:SetTextColor(.75, .69, .56)
        end
    end
end
