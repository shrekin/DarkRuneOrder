-- roster.lua
DarkRuneOrder = DarkRuneOrder or {}

local ROW_HEIGHT  = 22
local MAX_ROWS    = 40
local CONTENT_W   = 220

local rosterFrame = CreateFrame("Frame", "DarkRuneOrderRoster", UIParent, "BackdropTemplate")
rosterFrame:SetSize(280, 320)
rosterFrame:SetPoint("CENTER", UIParent, "CENTER", 130, 0)
rosterFrame:SetMovable(true)
rosterFrame:EnableMouse(true)
rosterFrame:RegisterForDrag("LeftButton")
rosterFrame:SetScript("OnDragStart", rosterFrame.StartMoving)
rosterFrame:SetScript("OnDragStop", rosterFrame.StopMovingOrSizing)
rosterFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 32, edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
rosterFrame:SetBackdropBorderColor(0.408, 0.227, 0.651, 1)
rosterFrame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
        rosterFrame:Hide()
    end
end)
rosterFrame:Hide()

-- Title
local rosterTitle = rosterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rosterTitle:SetFont("Fonts\\FORCED_NARROWS.TTF", 14, "OUTLINE")
rosterTitle:SetPoint("TOP", rosterFrame, "TOP", 0, -14)
rosterTitle:SetText("Addon Status")
rosterTitle:SetTextColor(1, 1, 1, 1)

-- Close button
local rosterClose = CreateFrame("Button", nil, rosterFrame, "UIPanelCloseButton")
rosterClose:SetSize(24, 24)
rosterClose:SetPoint("TOPRIGHT", rosterFrame, "TOPRIGHT", -2, -2)

-- Refresh button
local refreshBtn = CreateFrame("Button", nil, rosterFrame, "GameMenuButtonTemplate")
refreshBtn:SetSize(80, 22)
refreshBtn:SetPoint("BOTTOM", rosterFrame, "BOTTOM", 0, 8)
refreshBtn:SetText("Refresh")
refreshBtn:SetScript("OnClick", function()
    DarkRuneOrder.RequestVersions()
end)

-- Scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, rosterFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT",     rosterFrame, "TOPLEFT",     8,   -38)
scrollFrame:SetPoint("BOTTOMRIGHT", rosterFrame, "BOTTOMRIGHT", -28,  38)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(CONTENT_W, 1)
scrollFrame:SetScrollChild(content)

-- Column headers
local hdrStatus = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrStatus:SetPoint("TOPLEFT", content, "TOPLEFT", 4, 0)
hdrStatus:SetWidth(18)
hdrStatus:SetJustifyH("LEFT")
hdrStatus:SetText("|cffcccccc-|r")

local hdrName = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrName:SetPoint("TOPLEFT", content, "TOPLEFT", 26, 0)
hdrName:SetWidth(120)
hdrName:SetJustifyH("LEFT")
hdrName:SetText("|cffccccccPlayer|r")

local hdrVersion = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrVersion:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, 0)
hdrVersion:SetWidth(70)
hdrVersion:SetJustifyH("RIGHT")
hdrVersion:SetText("|cffccccccVersion|r")

-- Pre-build row pool
local rows = {}
for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(CONTENT_W, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i) * ROW_HEIGHT)

    -- Alternating row background
    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints()
    rowBg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)

    -- Green checkmark (addon installed)
    local checkTex = row:CreateTexture(nil, "OVERLAY")
    checkTex:SetSize(14, 14)
    checkTex:SetPoint("LEFT", row, "LEFT", 4, 0)
    checkTex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    checkTex:Hide()
    row.checkTex = checkTex

    -- Red X (addon not installed)
    local crossTex = row:CreateTexture(nil, "OVERLAY")
    crossTex:SetSize(14, 14)
    crossTex:SetPoint("LEFT", row, "LEFT", 4, 0)
    crossTex:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    crossTex:Hide()
    row.crossTex = crossTex

    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("LEFT", row, "LEFT", 26, 0)
    nameLabel:SetWidth(120)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetTextColor(1, 1, 1, 1)
    row.nameLabel = nameLabel

    local versionLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionLabel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    versionLabel:SetWidth(70)
    versionLabel:SetJustifyH("RIGHT")
    row.versionLabel = versionLabel

    row:Hide()
    rows[i] = row
end

-- Returns ordered list of short player names for the current group
local function GetGroupMembers()
    local members = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = UnitName("raid" .. i)
            if name then
                table.insert(members, (name:match("^([^%-]+)") or name))
            end
        end
    elseif IsInGroup() then
        table.insert(members, UnitName("player"))
        for i = 1, GetNumSubgroupMembers() do
            local name = UnitName("party" .. i)
            if name then
                table.insert(members, (name:match("^([^%-]+)") or name))
            end
        end
    else
        table.insert(members, UnitName("player"))
    end
    return members
end

function DarkRuneOrder.RefreshRoster()
    if not rosterFrame:IsShown() then return end

    local members = GetGroupMembers()

    for i = 1, MAX_ROWS do
        rows[i]:Hide()
        rows[i].checkTex:Hide()
        rows[i].crossTex:Hide()
    end

    for i, name in ipairs(members) do
        if i > MAX_ROWS then break end
        local row     = rows[i]
        local version = DarkRuneOrder.playerVersions[name]

        if version then
            row.checkTex:Show()
            row.crossTex:Hide()
            row.versionLabel:SetText("|cffaaaaaa" .. version .. "|r")
        else
            row.checkTex:Hide()
            row.crossTex:Show()
            row.versionLabel:SetText("|cff666666-|r")
        end
        row.nameLabel:SetText(name)
        row:Show()
    end

    content:SetHeight(math.max((#members + 1) * ROW_HEIGHT, 1))
end

function DarkRuneOrder.ShowRoster()
    rosterFrame:Show()
    DarkRuneOrder.RequestVersions()
end

-- Auto-refresh roster when group composition changes
local rosterEventFrame = CreateFrame("Frame")
rosterEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterEventFrame:SetScript("OnEvent", function()
    DarkRuneOrder.RefreshRoster()
end)
