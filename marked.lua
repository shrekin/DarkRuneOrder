-- marked.lua
-- Tracks players marked by Dark Rune (1249609) via combat log
DarkRuneOrder = DarkRuneOrder or {}

local DARK_RUNE_ID  = 1249609
local MAX_MARKED    = 5
local ROW_H         = 20
local ROUND_TIMEOUT = 15  -- seconds between rounds

local markedPlayers = {}
local lastMarkTime  = 0

-- ── UI ───────────────────────────────────────────────────────────────────────

local markedFrame = CreateFrame("Frame", "DarkRuneOrderMarked", UIParent, "BackdropTemplate")
markedFrame:SetSize(160, 36)
markedFrame:SetPoint("LEFT", "DarkRuneOrderPicker", "RIGHT", 8, 0)
markedFrame:SetMovable(true)
markedFrame:EnableMouse(true)
markedFrame:RegisterForDrag("LeftButton")
markedFrame:SetScript("OnDragStart", markedFrame.StartMoving)
markedFrame:SetScript("OnDragStop", markedFrame.StopMovingOrSizing)
markedFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 32, edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
markedFrame:SetBackdropBorderColor(0.408, 0.227, 0.651, 1)
markedFrame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then markedFrame:Hide() end
end)
markedFrame:Hide()

-- Border line at top
local markedBorder = markedFrame:CreateTexture(nil, "BORDER")
markedBorder:SetHeight(2)
markedBorder:SetPoint("TOPLEFT",  markedFrame, "TOPLEFT")
markedBorder:SetPoint("TOPRIGHT", markedFrame, "TOPRIGHT")
markedBorder:SetColorTexture(0.5, 0.4, 0.8, 1)

-- Title
local markedTitle = markedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
markedTitle:SetFont("Fonts\\FORCED_NARROWS.TTF", 12, "OUTLINE")
markedTitle:SetPoint("TOP", markedFrame, "TOP", 0, -10)
markedTitle:SetText("Dark Rune")
markedTitle:SetTextColor(0.8, 0.55, 1, 1)

-- Pre-build player rows
local rows = {}
for i = 1, MAX_MARKED do
    local row = CreateFrame("Frame", nil, markedFrame)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT",  markedFrame, "TOPLEFT",  6, -(26 + (i - 1) * ROW_H))
    row:SetPoint("TOPRIGHT", markedFrame, "TOPRIGHT", -6, -(26 + (i - 1) * ROW_H))

    -- Alternating background
    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints()
    rowBg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)

    local numLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numLabel:SetPoint("LEFT", row, "LEFT", 2, 0)
    numLabel:SetWidth(18)
    numLabel:SetJustifyH("LEFT")
    numLabel:SetTextColor(0.6, 0.6, 0.6, 1)
    row.numLabel = numLabel

    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("LEFT", row, "LEFT", 20, 0)
    nameLabel:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetTextColor(1, 1, 1, 1)
    row.nameLabel = nameLabel

    row:Hide()
    rows[i] = row
end

local function RefreshMarked()
    local count = #markedPlayers

    for i = 1, MAX_MARKED do rows[i]:Hide() end

    for i, name in ipairs(markedPlayers) do
        rows[i].numLabel:SetText(i .. ".")
        rows[i].nameLabel:SetText(name)
        rows[i]:Show()
    end

    if count > 0 then
        markedFrame:SetHeight(28 + count * ROW_H + 6)
        markedFrame:Show()
    else
        markedFrame:Hide()
    end
end

local function ClearMarked()
    markedPlayers = {}
    lastMarkTime  = 0
    markedFrame:Hide()
end

-- ── Callbacks called from core.lua's single event frame ──────────────────────

local function UnitHasDarkRune(unitID)
    for i = 1, 40 do
        local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex(unitID, i, "HARMFUL")
        if aura == nil then
            -- Fallback: legacy UnitDebuff
            local n, _, _, _, _, _, _, _, _, sid = UnitDebuff(unitID, i)
            if not n then break end
            if sid == DARK_RUNE_ID then return true end
        else
            if not aura then break end
            if aura.spellId == DARK_RUNE_ID then return true end
        end
    end
    return false
end

function DarkRuneOrder.OnEncounterReset()
    ClearMarked()
end

function DarkRuneOrder.OnUnitAura(unitID)
    if not unitID then return end
    if unitID ~= "player"
        and not unitID:match("^raid%d")
        and not unitID:match("^party%d") then return end

    local name = UnitName(unitID)
    if not name then return end
    local shortName = name:match("^([^%-]+)") or name

    if not UnitHasDarkRune(unitID) then return end

    -- Already in list?
    for _, n in ipairs(markedPlayers) do
        if n == shortName then return end
    end

    -- New round if enough time has passed
    local now = GetTime()
    if now - lastMarkTime > ROUND_TIMEOUT then
        markedPlayers = {}
    end
    lastMarkTime = now

    table.insert(markedPlayers, shortName)
    RefreshMarked()
end
