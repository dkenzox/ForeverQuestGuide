local _, Guide = ...
local L = Guide.Locale
local QuestPins = {}
Guide.QuestPins = QuestPins

local stages = {
    { key = "start", field = "givers", glyph = 0, r = 1, g = .81, b = .23 },
    { key = "objective", field = "objectives", glyph = 1, r = .34, g = .88, b = 1 },
    { key = "finish", field = "finishers", glyph = 2, r = .48, g = 1, b = .50 },
}
local stageByKey = {}
for _, stage in ipairs(stages) do stageByKey[stage.key] = stage end
QuestPins.stages = stages

function QuestPins.Label(stage, labelKey)
    if labelKey == "START_AND_OBJECTIVE" then return L[labelKey] end
    if stage == "start" then return L.PIN_START end
    if stage == "objective" then return L.PIN_OBJECTIVE end
    if stage == "finish" then return L.PIN_FINISH end
end

function QuestPins.Point(point, stage, labelKey)
    return {
        mapID = point.mapID, zone = point.zone, x = point.x, y = point.y,
        name = point.name, stage = stage, labelKey = labelKey,
    }
end

function QuestPins.Points(quest, zone, only)
    local result, seen = {}, {}
    for _, stage in ipairs(stages) do
        if not only or only == stage.key then
            for _, source in ipairs(quest[stage.field]) do
                for _, point in ipairs(source.points) do
                    if not zone or point.zone == zone then
                        local key = ("%s:%d:%.2f:%.2f"):format(stage.key, point.mapID, point.x, point.y)
                        if not seen[key] then
                            seen[key] = true
                            result[#result + 1] = QuestPins.Point(point, stage.key, source.labelKey)
                        end
                    end
                end
            end
        end
    end
    return result
end

local function roundTexture(pin, layer, inset)
    local texture = pin:CreateTexture(nil, layer)
    texture:SetPoint("TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", -inset, inset)
    local mask = pin:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    texture:AddMaskTexture(mask)
    return texture
end

function QuestPins.Decorate(pin)
    pin.border = roundTexture(pin, "BACKGROUND", 0)
    pin.fill = roundTexture(pin, "BORDER", 1)
    pin.fill:SetColorTexture(.075, .057, .033, .96)
    pin.picture = roundTexture(pin, "ARTWORK", 1)
    pin.glyph = pin:CreateTexture(nil, "OVERLAY")
    pin.glyph:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.glyph:SetTexture("Interface\\AddOns\\ForeverQuestGuide\\Art\\QuestGlyphs.tga")
end

function QuestPins.Style(pin, stage, color, selected, icon)
    local style = stageByKey[stage]
    local r, g, b
    if style then r, g, b = style.r, style.g, style.b else r, g, b = unpack(color) end
    pin.border:SetColorTexture(r, g, b, selected and 1 or .8)
    local glyph = style and style.glyph or 3
    local size = selected and 10 or 7
    pin.glyph:SetSize(size, size)
    pin.glyph:SetTexCoord(glyph / 4, (glyph + 1) / 4, 0, 1)
    pin.glyph:SetVertexColor(r, g, b)
    pin.glyph:SetShown(not icon)
    pin.picture:SetTexture(icon)
    pin.picture:SetShown(icon ~= nil)
end

local frames, library = {}, nil
local function getLibrary()
    return LibStub and LibStub("HereBeDragons-Pins-2.0", true)
        or C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie") and QuestieLoader and QuestieLoader.ImportModule
            and QuestieLoader:ImportModule("HBDPins")
end

function QuestPins.RefreshMinimap(zone, quests, onClick)
    local nextLibrary = getLibrary()
    if library then library:RemoveAllMinimapIcons(QuestPins) end
    library = nextLibrary
    if not (library and library.AddMinimapIconMap and library.RemoveAllMinimapIcons and Minimap and zone and quests) then
        library = nil
        return
    end

    local used, cells = 0, {}
    for _, row in ipairs(quests) do
        local quest = row.quest
        local active = row.status == "active"
        local ready = active and C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(quest.id)
        for _, point in ipairs(QuestPins.Points(quest, zone, ready and "finish" or (not active and "start" or nil))) do
            if not (active and point.stage == "start") then
                local cell = ("%s:%d:%.0f:%.0f"):format(point.stage, point.mapID, point.x, point.y)
                if not cells[cell] and used < 400 then
                    cells[cell] = true
                    used = used + 1
                    local pin = frames[used]
                    if not pin then
                        pin = CreateFrame("Button", nil, Minimap)
                        pin:SetSize(11, 11)
                        QuestPins.Decorate(pin)
                        pin:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                            GameTooltip:SetText(self.quest.name)
                            GameTooltip:AddLine(QuestPins.Label(self.point.stage, self.point.labelKey), .95, .85, .65)
                            GameTooltip:Show()
                        end)
                        pin:SetScript("OnLeave", function(self)
                            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                        end)
                        pin:SetScript("OnClick", function(self)
                            if not InCombatLockdown() then self.open(self.quest, self.point) end
                        end)
                        pin:SetScript("OnHide", pin:GetScript("OnLeave"))
                        pin:Hide()
                        frames[used] = pin
                    end
                    pin.point, pin.quest, pin.open = point, quest, onClick
                    QuestPins.Style(pin, point.stage)
                    library:AddMinimapIconMap(QuestPins, pin, point.mapID, point.x / 100, point.y / 100, true, false)
                end
            end
        end
        if used >= 400 then break end
    end
end
