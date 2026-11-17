local _, Guide = ...
local L, View, Data, NextZone = Guide.Locale, Guide.View, Guide.Data, Guide.NextZone
local Picker = {}
Guide.ZonePicker = Picker

local pageSize, recommendationPageSize = 10, 8

local function label(parent, font, anchor, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint(anchor, x, y)
    text:SetWidth(width)
    text:SetWordWrap(false)
    text:SetJustifyH("LEFT")
    return text
end

local function draw(picker)
    local total = #picker.options
    local recommending = picker.recommending
    local size = recommending and recommendationPageSize or pageSize
    local pages = math.max(1, math.ceil(total / size))
    local pagination = not recommending or pages > 1
    local footerSpace = pagination and 36 or 0
    picker.panel:SetHeight(recommending and math.max(175, 126 + 42 * math.min(total, size) + footerSpace) or 411)
    picker.title:SetText(recommending and L.NEXT_ZONE or L.ZONE_PICKER)
    picker.mode:SetText(recommending and L.NEXT_ZONE_BACK or L.NEXT_ZONE)
    picker.hint:SetText(recommending and L.NEXT_ZONE_PAD or L.ZONE_PICKER_PAD)
    picker.context:SetShown(recommending and picker.currentZone ~= nil)
    local emptyReason = picker.otherContinents and L.NEXT_ZONE_OTHER_EMPTY or L.NEXT_ZONE_EMPTY
    picker.empty:SetText(Data.ready and emptyReason or L.LOADING)
    picker.empty:SetShown(total == 0)
    picker.nearby:SetShown(recommending)
    picker.overseas:SetShown(recommending)
    if picker.otherContinents then
        picker.nearby:UnlockHighlight()
        picker.overseas:LockHighlight()
    else
        picker.nearby:LockHighlight()
        picker.overseas:UnlockHighlight()
    end
    picker.index = math.max(1, math.min(picker.index, total))
    local page = math.floor((picker.index - 1) / size) + 1
    local first = (page - 1) * size + 1
    for i, row in ipairs(picker.rows) do
        local index = first + i - 1
        local entry = i <= size and picker.options[index]
        row.index = index
        row:SetShown(entry ~= nil)
        if entry then
            row:ClearAllPoints()
            local top, spacing = recommending and 89 or 40, recommending and 42 or 31
            row:SetPoint("TOPLEFT", 14, -top - (i - 1) * spacing)
            row:SetHeight(recommending and 39 or 29)
            row.title:ClearAllPoints()
            row.title:SetPoint("LEFT", 9, recommending and 6 or 0)
            row.title:SetText(entry.name)
            row.reason:SetShown(recommending)
            if recommending then
                row.reason:SetText(L.NEXT_ZONE_SUMMARY:format(entry.starts, entry.active, entry.cluster))
            end
            local minLevel, maxLevel, estimated = Data.ZoneLevels(entry.mapID or picker.currentZone)
            local range = minLevel and (minLevel == maxLevel and tostring(minLevel)
                or ("%d–%d"):format(minLevel, maxLevel))
            row.level:ClearAllPoints()
            row.level:SetPoint("LEFT", 205, recommending and 6 or 0)
            row.level:SetText(range and L.ZONE_LEVEL:format(estimated and ("~" .. range) or range) or "")
            row.region:ClearAllPoints()
            row.region:SetPoint("RIGHT", -9, recommending and 6 or 0)
            local note = entry.region or ""
            if entry.current then note = L.NEXT_ZONE_STAY
            elseif recommending and entry.hubTravel then
                note = L.NEXT_ZONE_DISTANCE:format(math.floor(entry.hubTravel / 100 + .5) * 100)
            end
            row.region:SetText(note)
            row.highlight:SetShown(index == picker.index)
        end
    end
    picker.page:SetText(("%d / %d"):format(page, pages))
    picker.page:SetShown(pagination)
    picker.prev:SetShown(pagination)
    picker.next:SetShown(pagination)
    picker.prev:SetEnabled(page > 1)
    picker.next:SetEnabled(page < pages)
end

local function move(picker, offset)
    picker.index = picker.index + offset
    draw(picker)
end

local function movePage(picker, offset)
    local size = picker.recommending and recommendationPageSize or pageSize
    move(picker, offset * size)
end

local function selectZone(picker)
    local entry = picker.options[picker.index]
    if not entry then return end
    picker:Hide()
    picker.onPick(not entry.current and entry.mapID or nil, picker.recommending)
end

local function selectScope(picker, otherContinents)
    if not picker.recommending or picker.otherContinents == otherContinents then return end
    picker.otherContinents = otherContinents
    local settings = Guide.Character.Settings()
    local player = Data.Player()
    picker.context:SetText(L.NEXT_ZONE_CONTEXT:format(player.level, Data.ZoneName(picker.currentZone)))
    picker.options = NextZone.Recommend(picker.currentZone, picker.zones, player, settings.hideDungeonQuests, otherContinents)
    picker.index = 1
    draw(picker)
end

local function toggleMode(picker)
    if picker.recommending then
        picker.options, picker.index = picker.allOptions, picker.allIndex
        picker.recommending, picker.otherContinents = false, nil
        draw(picker)
    else
        picker.allOptions, picker.allIndex = picker.options, picker.index
        picker.recommending = true
        selectScope(picker, false)
    end
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
    shade:SetColorTexture(0, 0, 0, .57)

    local panel = CreateFrame("Frame", nil, picker, "BackdropTemplate")
    panel:SetSize(470, 411)
    panel:SetPoint("CENTER")
    picker.panel = panel
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(.11, .08, .055, 1)
    panel:SetBackdropBorderColor(.70, .51, .25, 1)

    picker.title = label(panel, "GameFontNormalLarge", "TOPLEFT", 16, -14, 254)
    picker.mode = View.Button(panel, L.NEXT_ZONE, 155, 21, "TOPRIGHT", -42, -10, function()
        toggleMode(picker)
    end)
    picker.context = label(panel, "GameFontHighlightSmall", "TOPLEFT", 17, -39, 436)
    picker.nearby = View.Button(panel, L.NEXT_ZONE_NEARBY, 105, 22, "TOPLEFT", 15, -58, function()
        selectScope(picker, false)
    end)
    picker.overseas = View.Button(panel, L.NEXT_ZONE_OTHER, 144, 22, "TOPLEFT", 125, -58, function()
        selectScope(picker, true)
    end)
    picker.empty = label(panel, "GameFontHighlight", "TOPLEFT", 17, -98, 436)
    picker.empty:SetWordWrap(true)
    View.Button(panel, "×", 25, 20, "TOPRIGHT", -10, -10, function() picker:Hide() end)
    picker.hint = label(panel, "GameFontHighlightSmall", "BOTTOMLEFT", 12, 8, 446)
    picker.hint:SetJustifyH("CENTER")
    picker.page = label(panel, "GameFontHighlightSmall", "BOTTOM", 0, 35, 90)
    picker.page:SetJustifyH("CENTER")
    picker.prev = View.Button(panel, "<", 25, 21, "BOTTOM", -58, 30, function() movePage(picker, -1) end)
    picker.next = View.Button(panel, ">", 25, 21, "BOTTOM", 58, 30, function() movePage(picker, 1) end)

    picker.rows, picker.onPick = {}, onPick
    for i = 1, pageSize do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(442, 29)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(.43, .29, .125, .95)
        row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
        row.title = label(row, "GameFontHighlight", "LEFT", 9, 0, 191)
        row.reason = label(row, "GameFontHighlightSmall", "LEFT", 9, -8, 420)
        row.reason:SetTextColor(.83, .75, .60)
        row.level = label(row, "GameFontNormal", "LEFT", 205, 0, 74)
        row.level:SetJustifyH("CENTER")
        row.region = label(row, "GameFontHighlightSmall", "RIGHT", -9, 0, 154)
        row.region:SetJustifyH("RIGHT")
        row.region:SetTextColor(.83, .75, .60)
        row:SetScript("OnClick", function(self) picker.index = self.index; selectZone(picker) end)
        picker.rows[i] = row
    end
    picker:Hide()
    return picker
end

function Picker.Open(picker, currentZone, pinnedZone)
    picker.currentZone, picker.recommending, picker.otherContinents = currentZone, false, nil
    picker.zones = Data.KnownZones(currentZone)
    picker.options = { { name = L.CURRENT_ZONE, region = currentZone and Data.ZoneName(currentZone) } }
    picker.index = 1
    for _, entry in ipairs(picker.zones) do
        picker.options[#picker.options + 1] = entry
        if entry.mapID == pinnedZone then picker.index = #picker.options end
    end
    picker:Show()
    draw(picker)
end

function Picker.OnPad(picker, key)
    if key == "PADDUP" then move(picker, -1)
    elseif key == "PADDDOWN" then move(picker, 1)
    elseif key == "PADLTRIGGER" then movePage(picker, -1)
    elseif key == "PADRTRIGGER" then movePage(picker, 1)
    elseif key == "PADLSHOULDER" then selectScope(picker, false)
    elseif key == "PADRSHOULDER" then selectScope(picker, true)
    elseif key == "PAD1" then selectZone(picker)
    elseif key == "PAD4" or (key == "PAD2" and picker.recommending) then toggleMode(picker)
    elseif key == "PAD2" or key == "PADFORWARD" then picker:Hide() end
end
