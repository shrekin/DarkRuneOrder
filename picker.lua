-- picker.lua
DarkRuneOrder = DarkRuneOrder or {}

local EXPRESSWAY_FONT = "Interface\\AddOns\\DarkRuneOrder\\fonts\\Expressway.ttf"

-- Pentagon math: 5 points evenly spaced starting from the top
local RADIUS = 58
local function PentagonPositions()
    local pos = {}
    for i = 1, 5 do
        local angle = math.pi / 2 - (i - 1) * (2 * math.pi / 5)
        pos[i] = { x = RADIUS * math.cos(angle), y = -RADIUS * math.sin(angle) }
    end
    return pos
end

-- Main picker frame
local pickerFrame = CreateFrame("Frame", "DarkRuneOrderPicker", UIParent, "BackdropTemplate")
pickerFrame:SetSize(210, 330)
pickerFrame:SetPoint("CENTER")
pickerFrame:SetMovable(true)
pickerFrame:EnableMouse(true)
pickerFrame:RegisterForDrag("LeftButton")
pickerFrame:SetScript("OnDragStart", pickerFrame.StartMoving)
pickerFrame:SetScript("OnDragStop", pickerFrame.StopMovingOrSizing)
pickerFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 32, edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
pickerFrame:SetBackdropBorderColor(0.408, 0.227, 0.651, 1)
pickerFrame:SetScript("OnHide", function()
    DarkRuneOrder.HideDisplay()
end)
pickerFrame:Hide()

-- Close button (top-right corner)
local closeBtn = CreateFrame("Button", nil, pickerFrame, "UIPanelCloseButton")
closeBtn:SetSize(24, 24)
closeBtn:SetPoint("TOPRIGHT", pickerFrame, "TOPRIGHT", -8, -8)

-- Gear button (test mode only, left of close button)
local gearBtn = CreateFrame("Button", nil, pickerFrame)
gearBtn:SetSize(22, 22)
gearBtn:SetPoint("TOPRIGHT", pickerFrame, "TOPRIGHT", -34, -9)
gearBtn:SetNormalTexture("Interface\\Icons\\Trade_Engineering")
gearBtn:SetHighlightTexture("Interface\\Icons\\Trade_Engineering", "ADD")
gearBtn:SetScript("OnClick", function()
    DarkRuneOrder.ShowRoster()
end)
gearBtn:Hide()

-- Central decorative circle
local centerDot = pickerFrame:CreateTexture(nil, "ARTWORK")
centerDot:SetSize(28, 28)
centerDot:SetPoint("CENTER", pickerFrame, "CENTER", 0, 14)
centerDot:SetTexture("Interface\\AddOns\\DarkRuneOrder\\texture\\tank.tga")

-- "ITV DR" title label (always visible at top)
local titleLabel = pickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleLabel:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
titleLabel:SetPoint("TOP", pickerFrame, "TOP", 0, -20)
titleLabel:SetText("Dark Rune Helper")
titleLabel:SetTextColor(0.408, 0.227, 0.651, 1)

-- "TEST MODE" label (shown only in test mode, below title)
local testLabel = pickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
testLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
testLabel:SetPoint("TOP", titleLabel, "BOTTOM", 0, -4)
testLabel:SetText("TEST MODE (/dr t)")
testLabel:SetTextColor(1, 0.5, 0, 1)
testLabel:Hide()

-- Custom button factory
-- stroke/hover: {r,g,b} tables.
-- Default stroke: #76787B → hover: #FFFFFF.
-- Custom stroke with no hover → hover auto-computed as 40% brighter (clamped).
local HOVER_DURATION = 0.15  -- seconds

local function lerp(a, b, t) return a + (b - a) * t end

local function CreateStyledButton(parent, stroke, hover)
    local sr, sg, sb, hr, hg, hb
    if stroke then
        sr, sg, sb = stroke[1], stroke[2], stroke[3]
        if hover then
            hr, hg, hb = hover[1], hover[2], hover[3]
        else
            hr = math.min(sr * 1.4, 1)
            hg = math.min(sg * 1.4, 1)
            hb = math.min(sb * 1.4, 1)
        end
    else
        sr, sg, sb = 118/255, 120/255, 123/255  -- #76787B
        hr, hg, hb = 1, 1, 1                    -- #FFFFFF
    end

    local btn = CreateFrame("Button", nil, parent)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(14/255, 19/255, 26/255, 1)  -- #0E131A

    local borders = {}
    local function makeBorder(a, b, horiz)
        local t = btn:CreateTexture(nil, "BORDER")
        if horiz then t:SetHeight(1) else t:SetWidth(1) end
        t:SetPoint(a, btn, a)
        t:SetPoint(b, btn, b)
        t:SetColorTexture(sr, sg, sb, 1)
        borders[#borders + 1] = t
    end
    makeBorder("TOPLEFT",    "TOPRIGHT",    true)
    makeBorder("BOTTOMLEFT", "BOTTOMRIGHT", true)
    makeBorder("TOPLEFT",    "BOTTOMLEFT",  false)
    makeBorder("TOPRIGHT",   "BOTTOMRIGHT", false)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetFont(EXPRESSWAY_FONT, 12)
    label:SetPoint("CENTER", btn, "CENTER")
    label:SetTextColor(sr, sg, sb, 1)

    -- Hover animation state
    local hoverT  = 0
    local animDir = 0

    local function applyColors(t)
        local r = lerp(sr, hr, t)
        local g = lerp(sg, hg, t)
        local b = lerp(sb, hb, t)
        for _, border in ipairs(borders) do
            border:SetColorTexture(r, g, b, 1)
        end
        label:SetTextColor(r, g, b, 1)
    end

    btn:SetScript("OnUpdate", function(self, dt)
        if animDir == 0 then return end
        hoverT = math.max(0, math.min(1, hoverT + animDir * dt / HOVER_DURATION))
        applyColors(hoverT)
        if hoverT == 0 or hoverT == 1 then animDir = 0 end
    end)

    btn:SetScript("OnEnter", function() animDir =  1 end)
    btn:SetScript("OnLeave", function() animDir = -1 end)

    -- Store label so SetText always hits our FontString,
    -- not WoW's native Button:SetText which has no built-in FontString here.
    btn._label = label
    rawset(btn, "SetText", function(self, str) label:SetText(str) end)
    rawset(btn, "GetText", function(self)      return label:GetText() end)

    return btn
end

-- Reset button (always visible)
local resetBtn = CreateStyledButton(pickerFrame)
resetBtn:SetSize(80, 22)
resetBtn:SetPoint("BOTTOM", pickerFrame, "BOTTOM", 0, 24)
resetBtn:SetText("Reset")

-- Test Cast button (test mode only)
local testCastBtn = CreateStyledButton(pickerFrame)
testCastBtn:SetSize(80, 22)
testCastBtn:SetPoint("LEFT", resetBtn, "RIGHT", 4, 0)
testCastBtn:SetText("Test Cast")
testCastBtn:SetScript("OnClick", function()
    DarkRuneOrder.SimulateCast(6)
end)
testCastBtn:Hide()

-- Undo button (B5) — removes last symbol pick
local undoBtn = CreateStyledButton(pickerFrame)
undoBtn:SetSize(80, 22)
undoBtn:SetPoint("LEFT", resetBtn, "RIGHT", 4, 0)
undoBtn:SetText("Undo")
undoBtn:Hide()

-- Send Last button (C3) — re-sends last order from history
local sendLastBtn = CreateStyledButton(pickerFrame)
sendLastBtn:SetSize(80, 22)
sendLastBtn:SetPoint("BOTTOM", pickerFrame, "BOTTOM", 0, 48)
sendLastBtn:SetText("Send Last")
sendLastBtn:Hide()

-- Difficulty label (always shown above buttons; clickable in test mode to cycle)
local diffLabelBtn = CreateFrame("Button", nil, pickerFrame)
diffLabelBtn:SetSize(160, 20)
diffLabelBtn:SetPoint("BOTTOM", pickerFrame, "BOTTOM", 0, 78)
local diffLabel = diffLabelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
diffLabel:SetFont(EXPRESSWAY_FONT, 14, "OUTLINE")
diffLabel:SetAllPoints()
diffLabel:SetTextColor(0.8, 0.8, 0.8, 1)
diffLabelBtn:Hide()

-- Internal state
local clickOrder  = {}   -- symbol IDs in click order
local hadBroadcast = false  -- true if we sent at least one ORDER message

local DIFF_LABELS = { [3] = "Normal (3 symbols)", [4] = "Heroic (4 symbols)", [5] = "Mythic (5 symbols)" }

local function UpdateDiffLabel()
    diffLabel:SetText(DIFF_LABELS[DarkRuneOrder.testDifficulty] or "Normal (3 symbols)")
end

local function ResetState(sendMessage)
    if sendMessage and hadBroadcast then
        DarkRuneOrder.SendReset()
    end
    clickOrder = {}
    hadBroadcast = false
end

-- Symbol buttons
local symbolButtons = {}
local positions = PentagonPositions()

for i, sym in ipairs(DarkRuneOrder.Symbols) do
    local btn = CreateFrame("Button", nil, pickerFrame)
    btn:SetSize(44, 44)
    btn:SetPoint("CENTER", pickerFrame, "CENTER", positions[i].x, positions[i].y + 24)

    -- Colored stroke (outer circle, full button size)
    -- local strokeTex = btn:CreateTexture(nil, "BACKGROUND")
    -- strokeTex:SetAllPoints()
    -- strokeTex:SetColorTexture(sym.color[1], sym.color[2], sym.color[3], 0.6)
    -- local strokeMask = btn:CreateMaskTexture()
    -- strokeMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    -- strokeMask:SetAllPoints(strokeTex)
    -- strokeTex:AddMaskTexture(strokeMask)

    -- Black inner circle (inset 2px to create stroke effect)
    local btnBg = btn:CreateTexture(nil, "BORDER")
    btnBg:SetSize(50, 50)
    btnBg:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnBg:SetColorTexture(0, 0, 0, 0.3)
    local bgMask = btn:CreateMaskTexture()
    bgMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    bgMask:SetAllPoints(btnBg)
    btnBg:AddMaskTexture(bgMask)

    -- Symbol icon
    local symIcon = btn:CreateTexture(nil, "OVERLAY")
    symIcon:SetSize(32, 32)
    symIcon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    symIcon:SetTexture(sym.texture)

    -- Number badge (top-right corner)
    local badge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 4, 4)
    badge:SetTextColor(1, 1, 0, 1)
    badge:SetText("")
    btn.badge = badge

    btn.symbolID = sym.id

    btn:SetScript("OnClick", function(self)
        local required = DarkRuneOrder.GetSymbolCount()
        if #clickOrder >= required then return end

        table.insert(clickOrder, self.symbolID)

        -- Badge shows all positions this symbol was selected (e.g. "2" or "1,4")
        local badgePositions = {}
        for pos, id in ipairs(clickOrder) do
            if id == self.symbolID then
                table.insert(badgePositions, tostring(pos))
            end
        end
        self.badge:SetText(table.concat(badgePositions, ","))
        self:SetAlpha(0.45)

        if #clickOrder == required then
            hadBroadcast = true
            DarkRuneOrder.SendOrder(clickOrder)
        end
    end)

    -- Hover highlight
    btn:SetScript("OnEnter", function(self)
        if #clickOrder < DarkRuneOrder.GetSymbolCount() then
            self:SetAlpha(0.75)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        -- Restore dim if this button was clicked at least once
        local clicked = false
        for _, id in ipairs(clickOrder) do
            if id == self.symbolID then clicked = true; break end
        end
        self:SetAlpha(clicked and 0.45 or 1)
    end)

    symbolButtons[i] = btn
end

-- Reset all button visual state
local function RefreshButtons()
    for _, btn in ipairs(symbolButtons) do
        btn.badge:SetText("")
        btn:SetAlpha(1)
    end
end

-- Refresh badges for all buttons based on current clickOrder
local function RefreshBadges()
    for _, btn in ipairs(symbolButtons) do
        local badgePositions = {}
        for pos, id in ipairs(clickOrder) do
            if id == btn.symbolID then
                table.insert(badgePositions, tostring(pos))
            end
        end
        if #badgePositions > 0 then
            btn.badge:SetText(table.concat(badgePositions, ","))
            btn:SetAlpha(0.45)
        else
            btn.badge:SetText("")
            btn:SetAlpha(1)
        end
    end
end

resetBtn:SetScript("OnClick", function()
    ResetState(true)
    RefreshButtons()
end)

-- Undo: remove last symbol pick (B5)
undoBtn:SetScript("OnClick", function()
    if #clickOrder == 0 then return end
    table.remove(clickOrder)
    hadBroadcast = false
    RefreshBadges()
end)

-- Send Last: re-send previous order from history (C3)
sendLastBtn:SetScript("OnClick", function()
    DarkRuneOrder.SendLastOrder()
end)

diffLabelBtn:SetScript("OnClick", function()
    if not DarkRuneOrder.testMode then return end
    local cycle = { [3] = 4, [4] = 5, [5] = 3 }
    DarkRuneOrder.testDifficulty = cycle[DarkRuneOrder.testDifficulty] or 3
    UpdateDiffLabel()
    ResetState(false)
    RefreshButtons()
end)

-- Check if history has entries
local function HasHistory()
    DarkRuneOrderDB = DarkRuneOrderDB or {}
    DarkRuneOrderDB.history = DarkRuneOrderDB.history or {}
    return #DarkRuneOrderDB.history > 0
end

-- Public: open the picker
function DarkRuneOrder.ShowPicker()
    ResetState(false)
    RefreshButtons()

    -- Show Send Last if history exists
    if HasHistory() then
        sendLastBtn:Show()
    else
        sendLastBtn:Hide()
    end

    if DarkRuneOrder.testMode then
        testLabel:Show()
        UpdateDiffLabel()
        gearBtn:Show()
        testCastBtn:Show()
        undoBtn:Hide()
        resetBtn:ClearAllPoints()
        resetBtn:SetPoint("BOTTOM", pickerFrame, "BOTTOM", -46, 24)
    else
        testLabel:Hide()
        gearBtn:Hide()
        testCastBtn:Hide()
        undoBtn:Show()
        resetBtn:ClearAllPoints()
        resetBtn:SetPoint("BOTTOM", pickerFrame, "BOTTOM", -46, 24)
        undoBtn:ClearAllPoints()
        undoBtn:SetPoint("LEFT", resetBtn, "RIGHT", 4, 0)
        local _, _, _, difficultyName = GetInstanceInfo()
        local count = DarkRuneOrder.GetSymbolCount()
        diffLabel:SetText((difficultyName ~= "" and difficultyName or "Normal") .. " (" .. count .. " symbols)")
    end
    diffLabelBtn:Show()

    pickerFrame:Show()
end

-- Resets picker state and visuals (called externally e.g. from display right-click)
function DarkRuneOrder.ResetPicker()
    ResetState(false)
    if pickerFrame:IsShown() then
        RefreshButtons()
    end
end

-- Updates the difficulty label live (called on zone/difficulty change events)
function DarkRuneOrder.RefreshDifficultyLabel()
    if not pickerFrame:IsShown() then return end
    if DarkRuneOrder.testMode then return end
    local _, _, _, difficultyName = GetInstanceInfo()
    local count = DarkRuneOrder.GetSymbolCount()
    diffLabel:SetText((difficultyName ~= "" and difficultyName or "Normal") .. " (" .. count .. " symbols)")
end

