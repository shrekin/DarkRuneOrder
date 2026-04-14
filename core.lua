-- core.lua
DarkRuneOrder = DarkRuneOrder or {}

local ADDON_PREFIX = "DARKRUNE"
local ADDON_VERSION = "1.0.2"

-- Difficulty ID → number of symbols required
local SYMBOL_COUNT = { [14] = 3, [15] = 4, [16] = 5 }

-- State
DarkRuneOrder.testMode = false
DarkRuneOrder.forceMode = false
DarkRuneOrder.testDifficulty = 3  -- used only in test mode
DarkRuneOrder.playerVersions = {}  -- [shortName] = version string

local lastOrderTime = 0  -- throttle duplicate ORDER messages
local ORDER_THROTTLE = 2 -- seconds

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DarkRuneOrder" then
            DarkRuneOrder.OnLoad()
        end
    elseif event == "ENCOUNTER_START" then
        DarkRuneOrder.OnEncounterStart()
        if DarkRuneOrder.OnEncounterReset then DarkRuneOrder.OnEncounterReset() end
    elseif event == "ENCOUNTER_END" then
        DarkRuneOrder.OnEncounterEnd()
        if DarkRuneOrder.OnEncounterReset then DarkRuneOrder.OnEncounterReset() end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == ADDON_PREFIX then
            DarkRuneOrder.OnMessage(message, sender)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        DarkRuneOrder.BroadcastVersion()
        if DarkRuneOrder.RefreshDifficultyLabel then
            DarkRuneOrder.RefreshDifficultyLabel()
        end
    elseif event == "PLAYER_DIFFICULTY_CHANGED" then
        if DarkRuneOrder.RefreshDifficultyLabel then
            DarkRuneOrder.RefreshDifficultyLabel()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if DarkRuneOrder.RefreshRoster then DarkRuneOrder.RefreshRoster() end
    end
end)

function DarkRuneOrder.OnLoad()
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    DarkRuneOrderDB = DarkRuneOrderDB or {}
    DarkRuneOrderDB.history = DarkRuneOrderDB.history or {}
    local pname = UnitName("player")
    local playerShort = (pname and pname:match("^([^%-]+)")) or pname
    DarkRuneOrder.playerVersions[playerShort] = ADDON_VERSION
    -- Restore last known order so the display survives /reload
    if DarkRuneOrderDB.lastOrder and #DarkRuneOrderDB.lastOrder > 0 then
        DarkRuneOrder.ShowDisplay(DarkRuneOrderDB.lastOrder)
    end
    print("|cff00ff00DarkRuneOrder|r loaded. /dr or /dr t")
end

-- Returns how many symbols must be clicked for current difficulty
function DarkRuneOrder.GetSymbolCount()
    if DarkRuneOrder.testMode then
        return DarkRuneOrder.testDifficulty
    end
    local _, _, difficultyID = GetInstanceInfo()
    return SYMBOL_COUNT[difficultyID] or 3
end

function DarkRuneOrder.OnEncounterStart()
    -- Clear stale display when a new encounter begins
    DarkRuneOrderDB.lastOrder = nil
    DarkRuneOrder.HideDisplay()
end

function DarkRuneOrder.OnEncounterEnd()
    DarkRuneOrder.HideDisplay()
end

-- Checks if a sender name belongs to the current raid/group leader or assistant
function DarkRuneOrder.SenderIsLeader(sender)
    local senderShort = sender:match("^([^%-]+)") or sender
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local name = UnitName(unit)
            if name then
                local short = name:match("^([^%-]+)") or name
                if short == senderShort and (UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)) then
                    return true
                end
            end
        end
    elseif IsInGroup() then
        -- Check party members
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then
                local short = name:match("^([^%-]+)") or name
                if short == senderShort and (UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)) then
                    return true
                end
            end
        end
        -- Check player
        local pname = UnitName("player")
        local pshort = (pname and pname:match("^([^%-]+)")) or pname
        if pshort == senderShort and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            return true
        end
    end
    return false
end

-- Broadcasts own version to the group
function DarkRuneOrder.BroadcastVersion()
    local pname = UnitName("player")
    local playerShort = (pname and pname:match("^([^%-]+)")) or pname
    DarkRuneOrder.playerVersions[playerShort] = ADDON_VERSION
    local msg = "VERSION_REPLY:" .. ADDON_VERSION
    if IsInRaid() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, msg, "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, msg, "PARTY")
    end
end

-- Asks all group members to send their version; clears stale data first
function DarkRuneOrder.RequestVersions()
    DarkRuneOrder.playerVersions = {}
    local pname = UnitName("player")
    local playerShort = (pname and pname:match("^([^%-]+)")) or pname
    DarkRuneOrder.playerVersions[playerShort] = ADDON_VERSION
    if DarkRuneOrder.RefreshRoster then
        DarkRuneOrder.RefreshRoster()
    end
    if IsInRaid() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "VERSION_REQUEST", "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "VERSION_REQUEST", "PARTY")
    end
end

-- Sends the ordered symbol list to the group
function DarkRuneOrder.SendOrder(symbolIDs)
    local prefix = (DarkRuneOrder.forceMode or DarkRuneOrder.testMode) and "FORCE_ORDER:" or "ORDER:"
    local payload = prefix .. table.concat(symbolIDs, ",")
    if DarkRuneOrder.testMode then
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(ADDON_PREFIX, payload, "WHISPER", UnitName("player"))
        else
            -- Solo: fire the handler directly without network
            DarkRuneOrder.OnMessage(payload, UnitName("player"))
        end
    elseif IsInRaid() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, payload, "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, payload, "PARTY")
    else
        DarkRuneOrder.OnMessage(payload, UnitName("player"))
    end

    -- Save to history (max 5 entries)
    DarkRuneOrderDB.history = DarkRuneOrderDB.history or {}
    table.insert(DarkRuneOrderDB.history, 1, {unpack(symbolIDs)})
    while #DarkRuneOrderDB.history > 5 do
        table.remove(DarkRuneOrderDB.history)
    end

    -- Announce order in chat
    local parts = {}
    for i, id in ipairs(symbolIDs) do
        parts[i] = id
    end
    local orderStr = table.concat(parts, ", ")
    if not DarkRuneOrder.testMode then
        if InCombatLockdown() then
            -- SendChatMessage is a protected function and is blocked during combat on this server.
            -- The order has already been delivered via C_ChatInfo.SendAddonMessage above.
            -- Suppress the chat attempt entirely to avoid ADDON_ACTION_FORBIDDEN being logged.
            if DarkRuneOrder.forceMode then
                print("|cffff6600DarkRuneOrder|r: Chat zablokowany podczas walki — kolejnosc wyslana przez kanal dodatku.")
            end
        elseif DarkRuneOrder.forceMode then
            -- Force mode: other players may not have the addon, so broadcast to /i (or /party) AND /say.
            if IsInRaid() then
                pcall(SendChatMessage, orderStr, "INSTANCE_CHAT")
            elseif IsInGroup() then
                pcall(SendChatMessage, orderStr, "PARTY")
            end
            pcall(SendChatMessage, orderStr, "SAY")
        else
            local chatOk = true
            if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) and IsInRaid() then
                chatOk = pcall(SendChatMessage, orderStr, "RAID_WARNING")
            elseif IsInRaid() then
                chatOk = pcall(SendChatMessage, orderStr, "INSTANCE_CHAT")
            elseif IsInGroup() then
                chatOk = pcall(SendChatMessage, orderStr, "PARTY")
            else
                chatOk = pcall(SendChatMessage, orderStr, "SAY")
            end
            if not chatOk then
                print("|cffff6600DarkRuneOrder|r: Chat zablokowany podczas walki — kolejnosc wyslana przez kanal dodatku.")
            end
        end
    end
end

-- Re-sends the last order from history
function DarkRuneOrder.SendLastOrder()
    DarkRuneOrderDB.history = DarkRuneOrderDB.history or {}
    if #DarkRuneOrderDB.history == 0 then
        print("|cff00ff00DarkRuneOrder|r: No order history available.")
        return
    end
    local last = DarkRuneOrderDB.history[1]
    DarkRuneOrder.SendOrder(last)
end

-- Sends a reset signal to the group
function DarkRuneOrder.SendReset()
    if DarkRuneOrder.testMode then
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "RESET", "WHISPER", UnitName("player"))
        else
            DarkRuneOrder.OnMessage("RESET", UnitName("player"))
        end
    elseif IsInRaid() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "RESET", "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "RESET", "PARTY")
    else
        DarkRuneOrder.OnMessage("RESET", UnitName("player"))
    end
end

-- Handles all incoming addon messages
function DarkRuneOrder.OnMessage(message, sender)
    -- Version request: reply with our version
    if message == "VERSION_REQUEST" then
        DarkRuneOrder.BroadcastVersion()
        return
    end

    -- Version reply: store the sender's version
    local ver = message:match("^VERSION_REPLY:(.+)$")
    if ver then
        local senderShort = sender:match("^([^%-]+)") or sender
        DarkRuneOrder.playerVersions[senderShort] = ver
        if DarkRuneOrder.RefreshRoster then
            DarkRuneOrder.RefreshRoster()
        end
        return
    end

    if message == "RESET" then
        DarkRuneOrderDB.lastOrder = nil
        DarkRuneOrder.HideDisplay()
        return
    end

    -- Validate parsed symbol IDs
    local function ValidateSymbols(ids)
        for _, id in ipairs(ids) do
            if not DarkRuneOrder.SymbolByID[id] then
                return false
            end
        end
        return #ids > 0
    end

    if message:sub(1, 12) == "FORCE_ORDER:" then
        -- Throttle: ignore duplicate orders within ORDER_THROTTLE seconds
        local now = GetTime()
        if now - lastOrderTime < ORDER_THROTTLE then return end
        lastOrderTime = now

        local ids = {}
        for id in message:sub(13):gmatch("[^,]+") do
            table.insert(ids, id)
        end
        if not ValidateSymbols(ids) then return end
        DarkRuneOrderDB.lastOrder = ids
        DarkRuneOrder.ShowDisplay(ids)
        return
    end

    if message:sub(1, 6) == "ORDER:" then
        if not DarkRuneOrder.testMode and not DarkRuneOrder.SenderIsLeader(sender) then
            return
        end
        -- Throttle: ignore duplicate orders within ORDER_THROTTLE seconds
        local now = GetTime()
        if now - lastOrderTime < ORDER_THROTTLE then return end
        lastOrderTime = now

        local ids = {}
        for id in message:sub(7):gmatch("[^,]+") do
            table.insert(ids, id)
        end
        if not ValidateSymbols(ids) then return end
        DarkRuneOrderDB.lastOrder = ids
        DarkRuneOrder.ShowDisplay(ids)
    end
end

-- Slash commands
SLASH_DARKRUNE1 = "/dr"
SlashCmdList["DARKRUNE"] = function(msg)
    local arg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if arg == "t" then
        DarkRuneOrder.testMode = true
        DarkRuneOrder.forceMode = false
        DarkRuneOrder.testDifficulty = 3
        DarkRuneOrder.ShowPicker()
    elseif arg == "force" then
        DarkRuneOrder.testMode = false
        DarkRuneOrder.forceMode = true
        DarkRuneOrder.ShowPicker()
    elseif arg == "minimap" then
        if DarkRuneOrder.ToggleMinimapButton then
            DarkRuneOrder.ToggleMinimapButton()
        end
    elseif arg == "last" then
        DarkRuneOrder.SendLastOrder()
    else
        DarkRuneOrder.testMode = false
        DarkRuneOrder.forceMode = false
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            DarkRuneOrder.ShowPicker()
        else
            print("|cff00ff00DarkRuneOrder|r: Only the raid leader or assistant can open the picker. Use /dr force to override.")
        end
    end
end
