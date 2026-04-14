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

-- In TWW 12.x, UNIT_SPELLCAST_* events mark spellID as a "secret tainted" value
-- that cannot be compared (fires ADDON_ACTION_FORBIDDEN). COMBAT_LOG_EVENT_UNFILTERED
-- is restricted on this server. Fix: register UNIT_SPELLCAST_* but declare only
-- (self, event, unit) in the handler signature — Lua silently discards castGUID
-- and spellID, so the tainted values are never assigned to any local variable.
-- Spell identity is resolved by calling UnitCastingInfo with the clean unit token.

local DARK_RUNE_NAME   = "Dark Rune"
local DEATH_DIRGE_NAME = "Death's Dirge"

local darkRuneUnit = nil  -- boss token currently casting Dark Rune  (nil = none)
local dirgeUnit    = nil  -- boss token currently casting Death's Dirge (nil = none)

local bossEventFrame = CreateFrame("Frame")
bossEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START",      "boss1", "boss2", "boss3", "boss4", "boss5")
bossEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED",  "boss1", "boss2", "boss3", "boss4", "boss5")
bossEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP",       "boss1", "boss2", "boss3", "boss4", "boss5")
bossEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED","boss1", "boss2", "boss3", "boss4", "boss5")
bossEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED",     "boss1", "boss2", "boss3", "boss4", "boss5")

bossEventFrame:SetScript("OnEvent", function(self, event, unit)
    -- castGUID and spellID are intentionally absent from the signature.
    -- Lua discards the extra arguments → the tainted spellID is never stored
    -- in a local, so the secret-value comparison error cannot fire.

    if event == "UNIT_SPELLCAST_START" then
        -- Identify the spell via UnitCastingInfo using the clean unit token.
        local name, _, _, startMS, endMS = UnitCastingInfo(unit)

        if name == DARK_RUNE_NAME and not darkRuneUnit then
            darkRuneUnit = unit
            DarkRuneOrderDB = DarkRuneOrderDB or {}
            DarkRuneOrderDB.lastOrder = nil
            DarkRuneOrder.HideDisplay()
            if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or DarkRuneOrder.forceMode then
                if DarkRuneOrder.ShowPicker then DarkRuneOrder.ShowPicker() end
            end

        elseif name == DEATH_DIRGE_NAME and not dirgeUnit then
            dirgeUnit = unit
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

    else
        -- SUCCEEDED / STOP / INTERRUPTED / FAILED — clear per-unit tracking state.
        if unit == darkRuneUnit then darkRuneUnit = nil end
        if unit == dirgeUnit    then dirgeUnit = nil; castBarFrame:Hide() end
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
