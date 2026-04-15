-- marked.lua
-- Tracks players marked by Dark Rune (1249609) via combat log
DarkRuneOrder = DarkRuneOrder or {}

local DARK_RUNE_ID   = 1249609
local MAX_MARKED     = 5
local ROW_H          = 20
local ROUND_TIMEOUT  = 15  -- seconds between rounds

-- Hardcoded spell name — boss spellID is a secret and calling GetSpellName
-- with it in the main chunk taints the execution context.
local DARK_RUNE_NAME = "Dark Rune"

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
markedTitle:SetFont("Interface\\AddOns\\DarkRuneOrder\\fonts\\Expressway.ttf", 12, "OUTLINE")
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

-- ── Polling (avoids UNIT_AURA taint in Midnight raid context) ────────────────

local function CheckUnit(unitID)
    if not UnitExists(unitID) then return end
    if not DARK_RUNE_NAME then return end
    local hasAura
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        hasAura = C_UnitAuras.GetAuraDataBySpellName(unitID, DARK_RUNE_NAME, "HARMFUL")
    else
        local ok, result = pcall(AuraUtil.FindAuraByName, DARK_RUNE_NAME, unitID, "HARMFUL")
        hasAura = ok and result
    end
    if not hasAura then return end

    local name = UnitName(unitID)
    if not name then return end
    local shortName = name:match("^([^%-]+)") or name

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

    -- First debuff of a new round → open picker for leader/assistant/forceMode.
    -- Player aura data is not tainted, making this the only reliable trigger on
    -- this server (all boss cast APIs return secret-tainted values).
    if #markedPlayers == 1 then
        DarkRuneOrderDB = DarkRuneOrderDB or {}
        DarkRuneOrderDB.lastOrder = nil
        DarkRuneOrder.HideDisplay()
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or DarkRuneOrder.forceMode then
            if DarkRuneOrder.ShowPicker then DarkRuneOrder.ShowPicker() end
        end
    end

    RefreshMarked()
end

local function ScanGroupForDarkRune()
    CheckUnit("player")
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            CheckUnit("raid" .. i)
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            CheckUnit("party" .. i)
        end
    end
end

-- ── Callbacks called from core.lua's single event frame ──────────────────────

local scanTicker = nil

function DarkRuneOrder.StartScan()
    if scanTicker then return end
    scanTicker = C_Timer.NewTicker(0.5, ScanGroupForDarkRune)
end

function DarkRuneOrder.OnEncounterReset()
    ClearMarked()
    if scanTicker then
        scanTicker:Cancel()
        scanTicker = nil
    end
end
