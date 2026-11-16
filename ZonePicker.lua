local _, Guide = ...
local L, View = Guide.Locale, Guide.View
local Picker = {}
Guide.ZonePicker = Picker

local pageSize = 10

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
            row.region:SetText(entry.region or "")
            row.highlight:SetShown(index == picker.index)
        end
    end
    picker.page:SetText(("%d / %d"):format(page, pages))
    picker.prev:SetEnabled(page > 1)
    picker.next:SetEnabled(page < pages)
end

local function move(picker, offset)
    picker.index = picker.index + offset
    draw(picker)
end

local function selectZone(picker)
    local entry = picker.options[picker.index]
    if not entry then return end
    picker:Hide()
    picker.onPick(entry.mapID)
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
    panel:SetSize(420, 411)
    panel:SetPoint("CENTER")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(.11, .08, .055, 1)
    panel:SetBackdropBorderColor(.70, .51, .25, 1)

    local title = label(panel, "GameFontNormalLarge", "TOPLEFT", 16, -14, 345)
    title:SetText(L.ZONE_PICKER)
    View.Button(panel, "×", 25, 20, "TOPRIGHT", -10, -10, function() picker:Hide() end)
    local hint = label(panel, "GameFontHighlightSmall", "BOTTOMLEFT", 12, 8, 396)
    hint:SetJustifyH("CENTER")
    hint:SetText(L.ZONE_PICKER_PAD)
    picker.page = label(panel, "GameFontHighlightSmall", "BOTTOM", 0, 35, 90)
    picker.page:SetJustifyH("CENTER")
    picker.prev = View.Button(panel, "<", 25, 21, "BOTTOM", -58, 30, function() move(picker, -pageSize) end)
    picker.next = View.Button(panel, ">", 25, 21, "BOTTOM", 58, 30, function() move(picker, pageSize) end)

    picker.rows, picker.onPick = {}, onPick
    for i = 1, pageSize do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(392, 29)
        row:SetPoint("TOPLEFT", 14, -40 - (i - 1) * 31)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(.43, .29, .125, .95)
        row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
        row.title = label(row, "GameFontHighlight", "LEFT", 9, 0, 222)
        row.region = label(row, "GameFontHighlightSmall", "RIGHT", -9, 0, 148)
        row.region:SetJustifyH("RIGHT")
        row.region:SetTextColor(.83, .75, .60)
        row:SetScript("OnClick", function(self) picker.index = self.index; selectZone(picker) end)
        picker.rows[i] = row
    end
    picker:Hide()
    return picker
end

function Picker.Open(picker, currentZone, pinnedZone)
    picker.options = { { name = L.CURRENT_ZONE, region = currentZone and Guide.Data.ZoneName(currentZone) } }
    picker.index = 1
    for _, entry in ipairs(Guide.Data.KnownZones(currentZone)) do
        picker.options[#picker.options + 1] = entry
        if entry.mapID == pinnedZone then picker.index = #picker.options end
    end
    picker:Show()
    draw(picker)
end

function Picker.OnPad(picker, key)
    if key == "PADDUP" then move(picker, -1)
    elseif key == "PADDDOWN" then move(picker, 1)
    elseif key == "PADLTRIGGER" then move(picker, -pageSize)
    elseif key == "PADRTRIGGER" then move(picker, pageSize)
    elseif key == "PAD1" then selectZone(picker)
    elseif key == "PAD2" or key == "PADFORWARD" then picker:Hide() end
end
