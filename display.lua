-- display.lua
DarkRuneOrder = DarkRuneOrder or {}

local displayFrame = CreateFrame("Frame", "DarkRuneOrderDisplay", UIParent)
displayFrame:SetSize(300, 80)
displayFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
displayFrame:SetMovable(true)
displayFrame:EnableMouse(true)
displayFrame:RegisterForDrag("LeftButton")
displayFrame:SetScript("OnDragStart", displayFrame.StartMoving)
displayFrame:SetScript("OnDragStop", displayFrame.StopMovingOrSizing)
displayFrame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
        DarkRuneOrderDB.lastOrder = nil
        DarkRuneOrder.HideDisplay()
        DarkRuneOrder.ResetPicker()
    end
end)
displayFrame:Hide()

-- Semi-transparent dark background
local bg = displayFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.75)

-- Thin border line at top
local border = displayFrame:CreateTexture(nil, "BORDER")
border:SetHeight(2)
border:SetPoint("TOPLEFT", displayFrame, "TOPLEFT")
border:SetPoint("TOPRIGHT", displayFrame, "TOPRIGHT")
border:SetColorTexture(0.5, 0.4, 0.8, 1)

-- Pre-build 5 symbol cells (one per possible symbol slot)
local CELL_WIDTH = 58
local cells = {}

for i = 1, 5 do
    local cell = CreateFrame("Frame", nil, displayFrame)
    cell:SetSize(CELL_WIDTH, 72)

    -- Number above icon
    local numLabel = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    numLabel:SetPoint("TOP", cell, "TOP", 0, -4)
    numLabel:SetTextColor(1, 1, 1, 1)
    cell.numLabel = numLabel

    -- Symbol icon
    local symLabel = cell:CreateTexture(nil, "OVERLAY")
    symLabel:SetSize(40, 40)
    symLabel:SetPoint("CENTER", cell, "CENTER", 0, -6)
    cell.symLabel = symLabel

    cell:Hide()
    cells[i] = cell
end

-- Shows the display with an ordered list of symbol IDs
function DarkRuneOrder.ShowDisplay(symbolIDs)
    local count = #symbolIDs

    -- Resize frame to fit exactly the number of symbols
    displayFrame:SetWidth(count * CELL_WIDTH + 16)

    -- Hide all cells then populate
    for i = 1, 5 do
        cells[i]:Hide()
    end

    for i, id in ipairs(symbolIDs) do
        local sym = DarkRuneOrder.SymbolByID[id]
        if sym then
            local cell = cells[i]
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", displayFrame, "TOPLEFT", 8 + (i - 1) * CELL_WIDTH, -4)
            cell.numLabel:SetText(tostring(i))
            cell.symLabel:SetTexture(sym.texture)
            cell:Show()
        end
    end

    displayFrame:Show()
end

function DarkRuneOrder.HideDisplay()
    displayFrame:Hide()
end
