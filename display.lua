-- display.lua
DarkRuneOrder = DarkRuneOrder or {}

local displayFrame = CreateFrame("Frame", "DarkRuneOrderDisplay", UIParent)
displayFrame:SetSize(300, 80)
displayFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
displayFrame:SetMovable(true)
displayFrame:EnableMouse(true)
displayFrame:RegisterForDrag("LeftButton")
displayFrame:SetScript("OnDragStart", displayFrame.StartMoving)
displayFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position (C4)
    local point, _, relPoint, x, y = self:GetPoint()
    DarkRuneOrderDB = DarkRuneOrderDB or {}
    DarkRuneOrderDB.displayPos = { point, relPoint, x, y }
end)
displayFrame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
        DarkRuneOrderDB.lastOrder = nil
        DarkRuneOrder.HideDisplay()
        DarkRuneOrder.ResetPicker()
    end
end)
displayFrame:Hide()

-- Restore saved position (C4)
local function RestoreDisplayPosition()
    DarkRuneOrderDB = DarkRuneOrderDB or {}
    local pos = DarkRuneOrderDB.displayPos
    if pos then
        displayFrame:ClearAllPoints()
        displayFrame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
end

-- Defer position restore until SavedVariables are loaded
local posRestoreFrame = CreateFrame("Frame")
posRestoreFrame:RegisterEvent("ADDON_LOADED")
posRestoreFrame:SetScript("OnEvent", function(self, event, name)
    if name == "DarkRuneOrder" then
        RestoreDisplayPosition()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

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

-- ── Cast bar (Death's Dirge, spell 1249620) ──────────────────────────────────

local castEndTime    = 0
local castDuration   = 1  -- avoid division by zero

-- Spell IDs for L'ura abilities — integers cannot be "secret string" tainted.
local DARK_RUNE_SPELL_ID   = 1249609  -- "Dark Rune"    (same as DARK_RUNE_ID in marked.lua)
local DEATH_DIRGE_SPELL_ID = 1249620  -- "Death's Dirge"

local castBarFrame = CreateFrame("Frame", "DarkRuneOrderCastBar", UIParent)
castBarFrame:SetHeight(18)
castBarFrame:SetPoint("TOP", displayFrame, "BOTTOM", 0, -2)
castBarFrame:SetWidth(300)

local castBarBg = castBarFrame:CreateTexture(nil, "BACKGROUND")
castBarBg:SetAllPoints()
castBarBg:SetColorTexture(0, 0, 0, 0.75)

local castBarBorderLine = castBarFrame:CreateTexture(nil, "BORDER")
castBarBorderLine:SetHeight(1)
castBarBorderLine:SetPoint("BOTTOMLEFT",  castBarFrame, "BOTTOMLEFT")
castBarBorderLine:SetPoint("BOTTOMRIGHT", castBarFrame, "BOTTOMRIGHT")
castBarBorderLine:SetColorTexture(0.5, 0.4, 0.8, 1)

local castBarFill = castBarFrame:CreateTexture(nil, "ARTWORK")
castBarFill:SetPoint("TOPLEFT",    castBarFrame, "TOPLEFT",    1, -1)
castBarFill:SetPoint("BOTTOMLEFT", castBarFrame, "BOTTOMLEFT", 1,  1)
castBarFill:SetColorTexture(0.85, 0.15, 0.15, 0.9)

local castBarLabel = castBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
castBarLabel:SetAllPoints()
castBarLabel:SetJustifyH("CENTER")
castBarLabel:SetTextColor(1, 1, 1, 1)

castBarFrame:Hide()

castBarFrame:SetScript("OnUpdate", function(self)
    local remaining = castEndTime - GetTime()
    if remaining <= 0 then
        self:Hide()
        return
    end
    local frac   = math.max(remaining / castDuration, 0)
    local fillW  = math.max((self:GetWidth() - 2) * frac, 0)
    castBarFill:SetWidth(fillW)
    castBarLabel:SetText(string.format("Death's Dirge  %.1fs", remaining))
end)

-- UNIT_SPELLCAST_* events for boss units deliver spellID as a "secret tainted"
-- value in TWW (Patch 12.x) — comparing it causes ADDON_ACTION_FORBIDDEN errors.
-- COMBAT_LOG_EVENT_UNFILTERED via CombatLogGetCurrentEventInfo() returns untainted
-- values that can be compared freely.

local WATCHED_SUBEVENTS = {
    SPELL_CAST_START   = true,
    SPELL_CAST_SUCCESS = true,
    SPELL_CAST_FAILED  = true,
    SPELL_INTERRUPT    = true,
}

local function IsBossGUID(guid)
    for i = 1, 5 do
        if UnitGUID("boss" .. i) == guid then return true end
    end
    return false
end

local function GUIDToUnit(guid)
    for i = 1, 5 do
        local u = "boss" .. i
        if UnitGUID(u) == guid then return u end
    end
end

local bossEventFrame = CreateFrame("Frame")
bossEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

bossEventFrame:SetScript("OnEvent", function(self)
    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _,
          spellID, _, _, extraSpellID = CombatLogGetCurrentEventInfo()

    if not WATCHED_SUBEVENTS[subevent] then return end

    if subevent == "SPELL_CAST_START" then
        if spellID ~= DARK_RUNE_SPELL_ID and spellID ~= DEATH_DIRGE_SPELL_ID then return end
        if not IsBossGUID(sourceGUID) then return end

        if spellID == DARK_RUNE_SPELL_ID then
            DarkRuneOrderDB = DarkRuneOrderDB or {}
            DarkRuneOrderDB.lastOrder = nil
            DarkRuneOrder.HideDisplay()
            if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or DarkRuneOrder.forceMode then
                if DarkRuneOrder.ShowPicker then DarkRuneOrder.ShowPicker() end
            end

        else  -- DEATH_DIRGE_SPELL_ID
            local bossUnit = GUIDToUnit(sourceGUID)
            local startMS, endMS
            if bossUnit then
                _, _, _, startMS, endMS = UnitCastingInfo(bossUnit)
            end
            if startMS and endMS then
                castDuration = math.max((endMS - startMS) / 1000, 0.001)
                castEndTime  = endMS / 1000
            else
                castDuration = 5
                castEndTime  = GetTime() + 5
            end
            castBarFrame:SetWidth(displayFrame:GetWidth())
            castBarFrame:Show()
        end

    elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED" then
        if spellID ~= DEATH_DIRGE_SPELL_ID then return end
        if not IsBossGUID(sourceGUID) then return end
        castBarFrame:Hide()

    elseif subevent == "SPELL_INTERRUPT" then
        -- extraSpellID (field 15) = spell that was interrupted; destGUID = the caster whose spell was stopped
        if extraSpellID ~= DEATH_DIRGE_SPELL_ID then return end
        if not IsBossGUID(destGUID) then return end
        castBarFrame:Hide()
    end
end)

-- ── Public API ────────────────────────────────────────────────────────────────

-- Fade-in animation helper (B2)
local function StartFadeIn(frame)
    local elapsed = 0
    frame:SetAlpha(0)
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local alpha = math.min(elapsed / 0.3, 1)
        self:SetAlpha(alpha)
        if alpha >= 1 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Shows the display with an ordered list of symbol IDs
function DarkRuneOrder.ShowDisplay(symbolIDs)
    local count = #symbolIDs

    -- Play sound to alert the player (B1)
    PlaySound(SOUNDKIT.RAID_WARNING)

    -- Resize frame to fit exactly the number of symbols
    displayFrame:SetWidth(count * CELL_WIDTH + 16)
    castBarFrame:SetWidth(count * CELL_WIDTH + 16)

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
    StartFadeIn(displayFrame)  -- (B2)
end

function DarkRuneOrder.HideDisplay()
    displayFrame:Hide()
    castBarFrame:Hide()
end

-- Simulates a Death's Dirge cast for testing (duration in seconds)
function DarkRuneOrder.SimulateCast(duration)
    duration = duration or 6
    castDuration = duration
    castEndTime  = GetTime() + duration
    castBarFrame:SetWidth(displayFrame:GetWidth())
    castBarFrame:Show()
end
