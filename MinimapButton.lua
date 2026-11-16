local _, Guide = ...
local Launcher, L = {}, Guide.Locale
Guide.MinimapButton = Launcher

local icon = "Interface\\Icons\\INV_Misc_Map_01"

function Launcher.Create(toggle)
    if not Minimap then return end
    local broker = LibStub and LibStub("LibDataBroker-1.1", true)
    local iconLib = LibStub and LibStub("LibDBIcon-1.0", true)
    local function tooltip(tip)
        tip:AddLine("Forever Quest Guide")
        tip:AddLine(L.MINIMAP_MENU, 1, .85, .55)
    end
    if broker and iconLib then
        local settings = Guide.Character.Settings()
        settings.minimapButton = settings.minimapButton or { minimapPos = 225 }
        local object = broker:NewDataObject("ForeverQuestGuide", {
            type = "launcher", icon = icon, OnClick = toggle, OnTooltipShow = tooltip,
        })
        iconLib:Register("ForeverQuestGuide", object, settings.minimapButton)
        return
    end

    local button = CreateFrame("Button", "ForeverQuestGuideMinimapButton", Minimap)
    button:SetSize(26, 26)
    button:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 8, 7)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:SetNormalTexture(icon)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetPoint("CENTER", 1, -1)
    border:SetSize(42, 42)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", toggle)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        tooltip(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end
