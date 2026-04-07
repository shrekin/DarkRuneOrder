-- minimap.lua
-- Lightweight minimap button without external library dependencies (C5)
DarkRuneOrder = DarkRuneOrder or {}

local BUTTON_SIZE = 32
local ICON_TEXTURE = "Interface\\AddOns\\DarkRuneOrder\\texture\\tank.tga"
local DEFAULT_ANGLE = 220  -- degrees, default position around minimap

-- Create the minimap button
local btn = CreateFrame("Button", "DarkRuneOrderMinimapButton", Minimap)
btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:SetMovable(true)
btn:SetClampedToScreen(true)

-- Circular overlay border (mimics standard minimap buttons)
local overlay = btn:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetPoint("TOPLEFT")
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Icon
local icon = btn:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", btn, "CENTER", 0, 1)
icon:SetTexture(ICON_TEXTURE)

-- Highlight on hover
local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
highlight:SetSize(24, 24)
highlight:SetPoint("CENTER", btn, "CENTER", 0, 1)
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetBlendMode("ADD")

-- Position the button around the minimap edge
local function UpdatePosition(angleDeg)
    local angle = math.rad(angleDeg)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Dragging logic: track angle around minimap center
local isDragging = false

btn:RegisterForDrag("LeftButton")
btn:SetScript("OnDragStart", function(self)
    isDragging = true
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        DarkRuneOrderDB = DarkRuneOrderDB or {}
        DarkRuneOrderDB.minimapAngle = angle
        UpdatePosition(angle)
    end)
end)

btn:SetScript("OnDragStop", function(self)
    isDragging = false
    self:SetScript("OnUpdate", nil)
end)

-- Left click: toggle picker
-- Right click: toggle test mode picker
btn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if DarkRuneOrder.testMode or DarkRuneOrder.forceMode then
            DarkRuneOrder.ShowPicker()
        elseif UnitIsGroupLeader("player") then
            DarkRuneOrder.testMode = false
            DarkRuneOrder.forceMode = false
            DarkRuneOrder.ShowPicker()
        else
            print("|cff00ff00DarkRuneOrder|r: Only the raid leader can open the picker. Right-click for test mode.")
        end
    elseif button == "RightButton" then
        DarkRuneOrder.testMode = true
        DarkRuneOrder.forceMode = false
        DarkRuneOrder.testDifficulty = DarkRuneOrder.testDifficulty or 3
        DarkRuneOrder.ShowPicker()
    end
end)

-- Tooltip
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("|cff6839a6DarkRuneOrder|r", 1, 1, 1)
    GameTooltip:AddLine("|cffccccccLeft-click:|r Open picker", 1, 1, 1)
    GameTooltip:AddLine("|cffccccccRight-click:|r Test mode", 1, 1, 1)
    GameTooltip:AddLine("|cffccccccDrag:|r Move button", 1, 1, 1)
    GameTooltip:Show()
end)

btn:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Restore position from SavedVariables
local restoreFrame = CreateFrame("Frame")
restoreFrame:RegisterEvent("ADDON_LOADED")
restoreFrame:SetScript("OnEvent", function(self, event, name)
    if name == "DarkRuneOrder" then
        DarkRuneOrderDB = DarkRuneOrderDB or {}
        local angle = DarkRuneOrderDB.minimapAngle or DEFAULT_ANGLE
        UpdatePosition(angle)

        -- Respect hide setting
        if DarkRuneOrderDB.minimapHide then
            btn:Hide()
        end

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Default position
UpdatePosition(DEFAULT_ANGLE)

-- Public toggle for minimap button visibility
function DarkRuneOrder.ToggleMinimapButton()
    DarkRuneOrderDB = DarkRuneOrderDB or {}
    if btn:IsShown() then
        btn:Hide()
        DarkRuneOrderDB.minimapHide = true
        print("|cff00ff00DarkRuneOrder|r: Minimap button hidden. /dr minimap to show again.")
    else
        btn:Show()
        DarkRuneOrderDB.minimapHide = false
        print("|cff00ff00DarkRuneOrder|r: Minimap button shown.")
    end
end
