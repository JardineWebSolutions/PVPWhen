--========================================
-- PVPWhen for Turtle WoW
-- Fully automatic BG queue using native API
--========================================

-- SavedVariables (persists between sessions)
PVPWhenDB = PVPWhenDB or {
    enabled = true,
    bgs = {
        wsg = false,
        ab = false,
        av = false,
    },
    arenas = {
        skirmish = false,
        rated2v2 = false,
        rated3v3 = false,
        rated5v5 = false,
    }
}

if not PVPWhenDB.arenas then
    PVPWhenDB.arenas = {
        skirmish = false,
        rated2v2 = false,
        rated3v3 = false,
        rated5v5 = false,
    }
end

-- Arena API IDs for JoinArenaQueue
local ARENA_IDS = {
    skirmish = 0,
    rated2v2 = 1,
    rated3v3 = 2,
    rated5v5 = 3,
}

-- BG API names (what JoinBattlegroundQueue expects)
local BG_API_NAMES = {
    wsg = "Warsong Gulch",
    ab = "Arathi Basin",
    av = "Alterac Valley",
}

--====================================================
-- Queue system: processes one BG at a time
--====================================================
local PVPWhenQueueFrame = CreateFrame("Frame")
local pendingQueue = {}
local isQueueing = false
local autoQueueActive = false

local function HideBattlefieldFrame()
    if _G["BattlefieldFrame"] then
        _G["BattlefieldFrame"]:Hide()
    end
end

local function IsAlreadyQueued(bgName)
    for i = 0, MAX_BATTLEFIELD_QUEUES do
        local status, name = GetBattlefieldStatus(i)
        if status and status ~= "none" and name == bgName then
            return true
        end
    end
    return false
end

local function ProcessNextQueue()
    if isQueueing then return end

    while getn(pendingQueue) > 0 do
        local name = table.remove(pendingQueue, 1)
        if not IsAlreadyQueued(name) then
            isQueueing = true
            autoQueueActive = true
            PVPWhenQueueFrame:UnregisterAllEvents()
            PVPWhenQueueFrame:RegisterEvent("BATTLEFIELDS_SHOW")
            PVPWhenQueueFrame:SetScript("OnEvent", function()
                SetSelectedBattlefield(0)
                JoinBattlefield(0)
                PVPWhenQueueFrame:UnregisterEvent("BATTLEFIELDS_SHOW")
                HideBattlefieldFrame()
                print("PVPWhen: Queued for " .. name)
                isQueueing = false
                autoQueueActive = false
                ProcessNextQueue()
            end)
            JoinBattlegroundQueue(name)
            return
        end
    end
end

local function QueueBattleground(name)
    if IsAlreadyQueued(name) then return end
    table.insert(pendingQueue, name)
    ProcessNextQueue()
end

local function QueueBG(bgKey)
    local name = BG_API_NAMES[bgKey]
    if not name then
        print("PVPWhen: Unknown BG key: " .. bgKey)
        return
    end
    QueueBattleground(name)
end

--====================================================
-- Queue a specific arena by key
--====================================================
local function QueueArena(arenaKey)
    local id = ARENA_IDS[arenaKey]
    if id == nil then
        print("PVPWhen: Unknown arena key: " .. arenaKey)
        return
    end
    autoQueueActive = true
    PVPWhenQueueFrame:UnregisterAllEvents()
    PVPWhenQueueFrame:RegisterEvent("BATTLEFIELDS_SHOW")
    PVPWhenQueueFrame:SetScript("OnEvent", function()
        SetSelectedBattlefield(0)
        JoinBattlefield(0)
        PVPWhenQueueFrame:UnregisterEvent("BATTLEFIELDS_SHOW")
        HideBattlefieldFrame()
        print("PVPWhen: Queued for arena (" .. arenaKey .. ")")
        autoQueueActive = false
    end)
    JoinArenaQueue(id)
end

--====================================================
-- Queue all enabled BGs and arenas
--====================================================
local BG_ORDER = {"wsg", "ab", "av"}
local ARENA_ORDER = {"skirmish", "rated2v2", "rated3v3", "rated5v5"}

local function QueueAll()
    if not PVPWhenDB.enabled then return end

    for _, key in ipairs(BG_ORDER) do
        if PVPWhenDB.bgs[key] then
            QueueBG(key)
        end
    end

    for _, key in ipairs(ARENA_ORDER) do
        if PVPWhenDB.arenas[key] then
            QueueArena(key)
        end
    end
end

--====================================================
-- ALWAYS keep queued for checked BGs
--====================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    if isQueueing then return end
    if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then return end
    QueueAll()
end)

-- Only hide the BattlefieldFrame when the addon is auto-queueing
local hideFrame = CreateFrame("Frame")
hideFrame:RegisterEvent("BATTLEFIELDS_SHOW")
hideFrame:SetScript("OnEvent", function()
    if autoQueueActive then
        HideBattlefieldFrame()
    end
end)

--====================================================
-- Settings panel
--====================================================
local panel = CreateFrame("Frame", "PVPWhenPanel", UIParent)
panel:SetWidth(220)
panel:SetHeight(300)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background"})
panel:SetBackdropColor(0, 0, 0, 0.8)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() panel:StartMoving() end)
panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
panel:Hide()

-- Title
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", panel, "TOP", 0, -10)
title:SetText("PVPWhen")

-- Helper to create a styled checkbox
local function MakeCheckbox(parent, text, y)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetWidth(20)
    cb:SetHeight(20)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)

    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")

    local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbText:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cbText:SetText(text)

    return cb
end

-- BG checkboxes
local function CreateBGCheckbox(parent, text, key, y)
    local cb = MakeCheckbox(parent, text, y)
    cb:SetChecked(PVPWhenDB.bgs[key] or false)
    cb:SetScript("OnClick", function()
        PVPWhenDB.bgs[key] = cb:GetChecked()
        if cb:GetChecked() then
            QueueBG(key)
        end
    end)
end

CreateBGCheckbox(panel, "Warsong Gulch", "wsg", -30)
CreateBGCheckbox(panel, "Arathi Basin", "ab", -55)
CreateBGCheckbox(panel, "Alterac Valley", "av", -80)

-- Arena label
local arenaLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arenaLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -110)
arenaLabel:SetText("Arenas:")

-- Arena checkboxes
local function CreateArenaCheckbox(parent, text, key, y)
    local cb = MakeCheckbox(parent, text, y)
    if not PVPWhenDB.arenas then PVPWhenDB.arenas = {} end
    cb:SetChecked(PVPWhenDB.arenas[key] or false)
    cb:SetScript("OnClick", function()
        if not PVPWhenDB.arenas then PVPWhenDB.arenas = {} end
        PVPWhenDB.arenas[key] = cb:GetChecked()
        if cb:GetChecked() then
            QueueArena(key)
        end
    end)
end

CreateArenaCheckbox(panel, "Skirmish", "skirmish", -130)
CreateArenaCheckbox(panel, "Rated (2v2)", "rated2v2", -155)
CreateArenaCheckbox(panel, "Rated (3v3)", "rated3v3", -180)
CreateArenaCheckbox(panel, "Rated (5v5)", "rated5v5", -205)

-- Queue All button
local queueBtn = CreateFrame("Button", nil, panel)
queueBtn:SetWidth(100)
queueBtn:SetHeight(24)
queueBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 35)
queueBtn:SetNormalTexture("Interface\\Buttons\\UI-DialogBox-Button-Up")
queueBtn:SetPushedTexture("Interface\\Buttons\\UI-DialogBox-Button-Down")
queueBtn:SetHighlightTexture("Interface\\Buttons\\UI-DialogBox-Button-Highlight")

local queueBtnText = queueBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
queueBtnText:SetPoint("CENTER", queueBtn, "CENTER", 0, 0)
queueBtnText:SetText("Queue All")

queueBtn:SetScript("OnClick", function()
    QueueAll()
end)

-- Close button
local closeBtn = CreateFrame("Button", nil, panel)
closeBtn:SetWidth(16)
closeBtn:SetHeight(16)
closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
closeBtn:SetScript("OnClick", function()
    panel:Hide()
end)

-- Slash commands
SLASH_PVPWHEN1 = "/pvpwhen"
SlashCmdList["PVPWHEN"] = function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

-- Debug: show current queue status
SLASH_PVPWHENDEBUG1 = "/pvpwhendebug"
SlashCmdList["PVPWHENDEBUG"] = function()
    print("=== PVPWhen Queue Status ===")
    for i = 0, MAX_BATTLEFIELD_QUEUES do
        local status, name = GetBattlefieldStatus(i)
        if status and status ~= "none" then
            print("  Slot " .. i .. ": " .. status .. " - " .. (name or "unknown"))
        end
    end
end

print("PVPWhen loaded. Type /pvpwhen to toggle settings.")
