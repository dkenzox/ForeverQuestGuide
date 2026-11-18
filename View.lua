local _, Guide = ...
local L, ZoneMap = Guide.Locale, Guide.ZoneMap
local View = { width = 1120, height = 850, pageSize = 12, detailPageSize = 3, chainPageSize = 6 }
Guide.View = View

local icons = {
    quests = "Interface\\GossipFrame\\AvailableQuestIcon",
    gear = "Interface\\Icons\\INV_Chest_Chain_03",
    ore = "Interface\\Icons\\Trade_Mining",
    herb = "Interface\\Icons\\Spell_Nature_NatureTouchGrow",
    fish = "Interface\\Icons\\Trade_Fishing",
}
View.icons = icons
View.sections = { "start", "objective", "finish" }

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
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 13,
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
    control:SetPoint("TOPLEFT", 17 + (index - 1) * 218, -79)
    control:SetSize(214, 36)
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
    control.title = font(control, "GameFontNormal", "LEFT", 40, 0, 169)
    control.title:SetText(tab.label)
    control:SetScript("OnClick", function() selectTab(index) end)
    return control
end

local function rowButton(parent, i, click, openQuest, compact)
    local row = CreateFrame("Button", nil, parent)
    local width, height = compact and 360 or 278, compact and 37 or 47
    row:SetSize(width, height)
    row:SetPoint("TOPLEFT", compact and 0 or 8, (compact and 0 or -40) - (i - 1) * (height + 2))
    local selected = image(row, "BACKGROUND", "Interface\\Buttons\\WHITE8X8")
    selected:SetAllPoints()
    selected:SetGradient("HORIZONTAL", CreateColor(.46, .30, .14), CreateColor(.26, .19, .11))
    row.selected = selected
    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    local iconOffset = compact and 9 or 47
    row.title = font(row, "GameFontHighlight", "TOPLEFT", iconOffset, -5, width - iconOffset - 6)
    row.subtitle = font(row, "GameFontHighlightSmall", "TOPLEFT", iconOffset, -19, width - iconOffset - 6)
    row.subtitle:SetTextColor(.82, .76, .64)
    if not compact then
        row.icon = image(row, "ARTWORK", nil)
        row.icon:SetPoint("LEFT", 8, 0)
        row.icon:SetSize(30, 30)
        row.icon:SetTexCoord(.07, .93, .07, .93)
        row.summary = font(row, "GameFontHighlightSmall", "BOTTOMLEFT", iconOffset, 4, width - iconOffset - 6)
        row.summary:SetTextColor(.9, .83, .64)
        row.questLink = CreateFrame("Button", nil, row)
        row.questLink:SetSize(width - iconOffset - 6, 14)
        row.questLink:SetPoint("BOTTOMLEFT", iconOffset, 2)
        row.questLink.label = font(row.questLink, "GameFontHighlightSmall", "LEFT", 0, 0, width - iconOffset - 6)
        row.questLink.label:SetTextColor(.98, .79, .36)
        row.questLink:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
        row.questLink:SetScript("OnClick", function() openQuest(row.index) end)
    end
    row:SetScript("OnClick", function(self) click(self.index) end)
    return row
end

local function stageButton(parent, i, section, label, click)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(248, 44)
    button:SetPoint("TOPLEFT", 11 + (i - 1) * 253, -46)
    local fill = image(button, "BACKGROUND", nil)
    fill:SetAllPoints()
    button.fill = fill
    button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    button.title = font(button, "GameFontNormal", "TOPLEFT", 9, -5, 228)
    button.title:SetText(label)
    button.caption = font(button, "GameFontHighlightSmall", "TOPLEFT", 9, -24, 228)
    button.caption:SetTextColor(.89, .82, .69)
    button:SetScript("OnClick", function() click(section) end)
    return button
end

function View.Create(tabs, actions)
    local ui = frame(UIParent, View.width, View.height, "CENTER", 0, 0, .15, .105, .073)
    ui:SetFrameStrata("DIALOG")
    ui:SetFrameLevel(90)
    ui:SetToplevel(true)
    ui:EnableMouse(true)
    ui:SetClampedToScreen(true)
    ui:SetMovable(true)
    ui:Hide()

    local header = CreateFrame("Frame", nil, ui)
    header:SetPoint("TOPLEFT", 7, -7)
    header:SetSize(View.width - 14, 67)
    header:EnableMouse(true)
    header:SetScript("OnMouseDown", function(_, key) if key == "LeftButton" then ui:StartMoving() end end)
    header:SetScript("OnMouseUp", function() ui:StopMovingOrSizing() end)
    local headerFill = image(header, "BACKGROUND", "Interface\\Buttons\\WHITE8X8")
    headerFill:SetAllPoints()
    headerFill:SetGradient("VERTICAL", CreateColor(.105, .07, .043), CreateColor(.26, .17, .09))
    rule(header, "BOTTOMLEFT", 4, 0, View.width - 22)

    ui.portrait = image(header, "ARTWORK", nil)
    ui.portrait:SetSize(53, 53)
    ui.portrait:SetPoint("LEFT", 15, 1)
    local brand = font(header, "GameFontNormalSmall", "TOPLEFT", 83, -9)
    brand:SetText("Forever Quest Guide")
    ui.zone = font(header, "GameFontNormalHuge", "TOPLEFT", 81, -22, 565)
    ui.context = font(header, "GameFontHighlightSmall", "BOTTOMLEFT", 83, 6, 560)
    ui.source = font(header, "GameFontDisableSmall", "BOTTOMRIGHT", -15, 7, 180)
    ui.source:SetJustifyH("RIGHT")
    ui.changeZone = View.Button(header, L.CHANGE_ZONE, 141, 23, "TOPRIGHT", -45, -17, actions.changeZone)
    ui.browsingZone = font(header, "GameFontHighlightSmall", "RIGHT", -203, 0, 225)
    ui.browsingZone:SetJustifyH("RIGHT")
    ui.browsingZone:SetTextColor(.89, .76, .53)
    ui.close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    ui.close:SetPoint("TOPRIGHT", 0, 2)
    ui.close:SetScript("OnClick", actions.close)
    ui.tabs = {}
    for i, tab in ipairs(tabs) do ui.tabs[i] = tabButton(ui, tab, i, actions.tab) end

    local list = frame(ui, 294, 674, "TOPLEFT", 16, -125, .11, .081, .059)
    ui.listTitle = font(list, "GameFontNormalLarge", "TOPLEFT", 11, -11, 225)
    ui.count = font(list, "GameFontHighlightSmall", "TOPRIGHT", -12, -14)
    local search = CreateFrame("EditBox", nil, list, "InputBoxTemplate")
    search:SetSize(117, 22)
    search:SetPoint("TOPLEFT", 110, -8)
    search:SetFontObject(GameFontHighlightSmall)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    local placeholder = font(search, "GameFontDisableSmall", "LEFT", 7, 0, 107)
    placeholder:SetText(L.SEARCH_QUESTS)
    local clearSearch = View.Button(list, "×", 22, 20, "TOPLEFT", 234, -9, function()
        search:SetText("")
        search:ClearFocus()
    end)
    clearSearch:Hide()
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        placeholder:SetShown(text == "" and not self:HasFocus())
        clearSearch:SetShown(text ~= "" and self:IsShown())
        actions.search(text)
    end)
    search:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) placeholder:SetShown(self:GetText() == "") end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    ui.search, ui.clearSearch = search, clearSearch
    ui.rows = {}
    for i = 1, View.pageSize do ui.rows[i] = rowButton(list, i, actions.row, actions.questLink) end
    ui.prev = View.Button(list, "<", 25, 21, "BOTTOM", -50, 10, function() actions.listPage(-1) end)
    ui.next = View.Button(list, ">", 25, 21, "BOTTOM", 50, 10, function() actions.listPage(1) end)
    ui.page = font(list, "GameFontHighlightSmall", "BOTTOM", 0, 15)
    ui.back = View.Button(list, L.BACK, 67, 21, "BOTTOMLEFT", 9, 10, actions.back)

    local mapPanel = frame(ui, 778, 354, "TOPRIGHT", -16, -125, .10, .075, .05)
    ui.map = ZoneMap.Create(mapPanel, actions.pin, 768, 344)

    local dock = frame(ui, 778, 311, "TOPRIGHT", -16, -488, .13, .094, .063)
    ui.detailTitle = font(dock, "GameFontNormalLarge", "TOPLEFT", 12, -9, 525)
    ui.detail = font(dock, "GameFontHighlight", "TOPLEFT", 13, -29, 510)
    ui.detail:SetWordWrap(true)
    ui.detail:SetMaxLines(5)
    ui.coords = font(dock, "GameFontHighlightSmall", "BOTTOMLEFT", 13, 11, 510)
    ui.coords:SetTextColor(.92, .80, .53)
    ui.waypoint = View.Button(dock, L.MARK, 108, 23, "TOPRIGHT", -11, -10, actions.mark)
    ui.clearWaypoint = View.Button(dock, L.CLEAR_MARK, 104, 23, "TOPRIGHT", -124, -10, actions.clear)
    ui.chain = View.Button(dock, L.QUEST_CHAIN, 94, 23, "TOPRIGHT", -233, -10, actions.chain)
    ui.chain:Hide()

    local labels = { L.SECTION_START, L.SECTION_GOALS, L.SECTION_FINISH }
    ui.sections = {}
    for i, key in ipairs(View.sections) do ui.sections[key] = stageButton(dock, i, key, labels[i], actions.section) end
    local route = CreateFrame("Frame", nil, dock)
    route:SetSize(360, 200)
    route:SetPoint("TOPLEFT", 11, -96)
    ui.route = route
    ui.routeRows = {}
    for i = 1, View.detailPageSize do ui.routeRows[i] = rowButton(route, i, actions.route, nil, true) end
    ui.routeEmpty = font(route, "GameFontHighlight", "TOPLEFT", 6, -6, 347)
    ui.routeEmpty:SetWordWrap(true)
    ui.routeEmpty:SetMaxLines(5)
    ui.routeNote = font(route, "GameFontHighlightSmall", "TOPLEFT", 6, -121, 347)
    ui.routeNote:SetTextColor(.86, .79, .68)
    ui.routeNote:SetWordWrap(true)
    ui.routeNote:SetMaxLines(2)
    ui.routePage = font(route, "GameFontHighlightSmall", "BOTTOM", 0, 31)
    ui.routePrev = View.Button(route, "<", 24, 20, "BOTTOM", -48, 26, function() actions.routePage(-1) end)
    ui.routeNext = View.Button(route, ">", 24, 20, "BOTTOM", 48, 26, function() actions.routePage(1) end)
    local chain = CreateFrame("Frame", nil, dock)
    chain:SetSize(360, 251)
    chain:SetPoint("TOPLEFT", 11, -46)
    ui.chainPanel = chain
    ui.chainRows = {}
    for i = 1, View.chainPageSize do
        local row = rowButton(chain, i, actions.route, nil, true)
        row:SetHeight(28)
        row.subtitle:ClearAllPoints()
        row.subtitle:SetPoint("TOPLEFT", 9, -15)
        ui.chainRows[i] = row
    end
    ui.chainSeries = font(chain, "GameFontNormal", "TOPLEFT", 6, -2, 344)
    ui.chainSeries:SetText(L.CHAIN_SERIES)
    ui.chainUnlocks = font(chain, "GameFontNormal", "TOPLEFT", 6, -2, 344)
    ui.chainUnlocks:SetText(L.CHAIN_ON_ACCEPT)
    ui.chainPage = font(chain, "GameFontHighlightSmall", "BOTTOM", 0, 7)
    ui.chainPrev = View.Button(chain, "<", 24, 20, "BOTTOM", -48, 3, function() actions.routePage(-1) end)
    ui.chainNext = View.Button(chain, ">", 24, 20, "BOTTOM", 48, 3, function() actions.routePage(1) end)
    local preview = CreateFrame("Frame", nil, dock)
    preview:SetSize(374, 73)
    preview:SetPoint("TOPLEFT", 391, -44)
    ui.chainPreview = preview
    ui.chainStepTitle = font(preview, "GameFontNormal", "TOPLEFT", 6, -3, 360)
    ui.chainStepRoute = font(preview, "GameFontHighlightSmall", "TOPLEFT", 6, -19, 360)
    ui.chainStepNote = font(preview, "GameFontHighlightSmall", "TOPLEFT", 6, -35, 361)
    ui.chainStepNote:SetWordWrap(true)
    ui.chainStepNote:SetMaxLines(3)
    chain:Hide()
    preview:Hide()
    ui.rewardSheet = Guide.RewardView.Create(dock, actions.reward, 391, -96, 212)
    ui.rewardPrev = View.Button(ui.rewardSheet, "<", 21, 18, "TOPRIGHT", -31, -6, function() actions.rewardPage(-1) end)
    ui.rewardNext = View.Button(ui.rewardSheet, ">", 21, 18, "TOPRIGHT", -6, -6, function() actions.rewardPage(1) end)
    ui.rewardPrev:SetFrameLevel(ui.rewardSheet:GetFrameLevel() + 2)
    ui.rewardNext:SetFrameLevel(ui.rewardSheet:GetFrameLevel() + 2)

    ui.filter = View.Button(ui, "", 174, 24, "BOTTOMRIGHT", -16, 22, actions.filter)
    ui.dungeons = View.Button(ui, "", 161, 24, "BOTTOMRIGHT", -196, 22, actions.dungeons)
    ui.eventFilter = View.Button(ui, "", 154, 24, "BOTTOMRIGHT", -363, 22, actions.events)
    ui.questMode = View.Button(ui, "", 130, 24, "BOTTOMRIGHT", -523, 22, actions.questMode)
    ui.status = font(ui, "GameFontHighlightSmall", "BOTTOMLEFT", 18, 36, 435)
    ui.status:SetTextColor(.86, .79, .64)
    ui.hint = font(ui, "GameFontHighlightSmall", "BOTTOMLEFT", 18, 9, 1084)
    ui.hint:SetJustifyH("CENTER")
    return ui
end

local function fillRows(rows, entries, index, size, showQuestLinks, compact)
    local page = math.floor((math.max(1, index) - 1) / size) + 1
    local pages = math.max(1, math.ceil(#entries / size))
    local first = (page - 1) * size + 1
    for i, row in ipairs(rows) do
        local position = first + i - 1
        local entry = entries[position]
        row.index, row.item = position, entry
        row:SetShown(entry ~= nil)
        if entry then
            row.selected:SetShown(index == position)
            local title = entry.title
            if entry.header then
                title = ("%s  %s (%d)"):format(entry.collapsed and "+" or "-", title, entry.count)
            end
            row.title:SetText(title)
            local color = entry.tint
            row.title:SetTextColor(color and color.r or 1, color and color.g or .89,
                color and color.b or (entry.header and .35 or .69))
            local questLink = showQuestLinks and entry.quest
            row.subtitle:SetShown(not questLink)
            row.subtitle:SetText(entry.subtitle or "")
            if not compact then
                local indent = (entry.depth or 0) * 10
                local offset = (entry.header and 10 or 47) + indent
                local width = row:GetWidth() - offset - 6
                row.title:ClearAllPoints()
                row.title:SetPoint(entry.header and "LEFT" or "TOPLEFT", offset, entry.header and 0 or -5)
                row.title:SetWidth(width)
                row.subtitle:ClearAllPoints()
                row.subtitle:SetPoint("TOPLEFT", offset, -19)
                row.subtitle:SetWidth(width)
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", 8 + indent, 0)
                row.icon:SetTexture(entry.icon)
                row.summary:SetText(entry.summary or "")
                row.summary:ClearAllPoints()
                row.summary:SetPoint(questLink and "TOPLEFT" or "BOTTOMLEFT", offset, questLink and -19 or 4)
                row.summary:SetWidth(width)
                row.questLink:SetShown(not not questLink)
                if questLink then row.questLink.label:SetText(entry.subtitle) end
            end
        end
    end
    return page, pages
end

function View.Rows(ui, entries, index, showQuestLinks, total)
    local page, pages = fillRows(ui.rows, entries, index, View.pageSize, showQuestLinks)
    ui.count:SetText(total or (#entries > 0 and #entries or ""))
    ui.page:SetText(("%d / %d"):format(page, pages))
    ui.prev:SetEnabled(page > 1)
    ui.next:SetEnabled(page < pages)
end

local function drawChain(ui, steps, index)
    local page, pages = fillRows(ui.chainRows, steps, index, View.chainPageSize, false, true)
    local y, sawSeries, sawUnlocks = 0, false, false
    for _, row in ipairs(ui.chainRows) do
        if row:IsShown() then
            local step = row.item
            if step.number and not sawSeries then
                sawSeries = true
                y = y + 19
            elseif not step.number and not sawUnlocks then
                sawUnlocks = true
                ui.chainUnlocks:ClearAllPoints()
                ui.chainUnlocks:SetPoint("TOPLEFT", 6, -y - 2)
                y = y + 22
            end
            local marker = step.number and ("%d."):format(step.number) or "+"
            row.title:SetText(marker .. "  " .. step.title)
            local subtitle = step.subtitle
            if step.alternate then subtitle = L.CHAIN_ALTERNATE_STARTS .. " · " .. subtitle end
            if step.unlocksDuring then subtitle = subtitle .. " · " .. step.unlocksDuring end
            row.subtitle:SetText(subtitle)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            y = y + 29
        end
    end
    ui.chainSeries:SetShown(sawSeries)
    ui.chainUnlocks:SetShown(sawUnlocks)
    ui.chainPage:SetText(pages > 1 and ("%d / %d"):format(page, pages) or "")
    ui.chainPrev:SetShown(pages > 1)
    ui.chainNext:SetShown(pages > 1)
    ui.chainPrev:SetEnabled(page > 1)
    ui.chainNext:SetEnabled(page < pages)
    local selected = steps[index]
    ui.chainStepTitle:SetText(selected.title)
    ui.chainStepRoute:SetText(selected.route or "")
    ui.chainStepNote:SetText(selected.description or "")
end

function View.Dock(ui, section, captions, locations, routeIndex, rewards, rewardIndex, note, focus)
    local hasQuest, showChain = section ~= nil, focus == "chain"
    ui.chainPanel:SetShown(showChain)
    ui.chainPreview:SetShown(showChain)
    ui.chain:SetText(showChain and L.CHAIN_BACK_TO_ROUTE or L.QUEST_CHAIN)
    ui.clearWaypoint:SetShown(not showChain)
    ui.waypoint:SetShown(not showChain)
    for key, button in pairs(ui.sections) do
        button:SetShown(hasQuest and not showChain)
        button.caption:SetText(captions and captions[key] or "")
        local selected = key == section
        if selected then button.fill:SetColorTexture(.49, .33, .15)
        else button.fill:SetColorTexture(.24, .18, .115) end
    end
    ui.route:SetShown(hasQuest and not showChain)
    ui.rewardSheet:SetShown(hasQuest)
    ui.rewardPrev:SetShown(hasQuest)
    ui.rewardNext:SetShown(hasQuest)
    local hint = L.PAD_GUIDE_V3
    if focus == "chain" then
        hint = L.PAD_CHAIN
    elseif focus then
        hint = focus == "rewards" and L.PAD_REWARDS or L.PAD_DETAIL
        if ui.chain:IsShown() then hint = hint .. "     " .. L.PAD_OPEN_CHAIN end
    end
    ui.hint:SetText(hint)
    if not hasQuest then return end

    ui.rewardSheet:ClearAllPoints()
    ui.rewardSheet:SetPoint("TOPLEFT", 391, showChain and -119 or -96)
    ui.rewardSheet.maxHeight = showChain and 181 or 212
    if showChain then
        drawChain(ui, locations, routeIndex)
    else
        local page, pages = fillRows(ui.routeRows, locations, routeIndex, View.detailPageSize, false, true)
        ui.routeEmpty:SetShown(#locations == 0)
        ui.routeEmpty:SetText(L.QUEST_NO_DETAILS)
        local row = ui.routeRows[(math.max(1, routeIndex) - 1) % View.detailPageSize + 1]
        if row.title.IsTruncated and not row.title:IsTruncated() then note = nil end
        ui.routeNote:SetText(note or "")
        ui.routePage:SetText(pages > 1 and ("%d / %d"):format(page, pages) or "")
        ui.routePrev:SetShown(pages > 1)
        ui.routeNext:SetShown(pages > 1)
        ui.routePrev:SetEnabled(page > 1)
        ui.routeNext:SetEnabled(page < pages)
    end
    local _, rewardPages = Guide.RewardView.Draw(ui.rewardSheet, rewards, rewardIndex)
    ui.rewardPrev:SetShown(rewardPages > 1)
    ui.rewardNext:SetShown(rewardPages > 1)
    ui.rewardPrev:SetEnabled(ui.rewardSheet.previous ~= nil)
    ui.rewardNext:SetEnabled(ui.rewardSheet.next ~= nil)
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
