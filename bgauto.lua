--========================================
-- BGAuto.lua for Turtle WoW
-- Fully automatic BG queue using native API
--========================================

-- SavedVariables (persists between sessions)
BGAutoDB = BGAutoDB or {
    enabled = true,
    bgs = {
        wsg = false,
        ab = false,
        av = false,
        tg = false,
    },
    arenas = {
        rated2v2 = false,
        rated3v3 = false,
        rated5v5 = false,
        skirmish = false,
    }
}

if not BGAutoDB.arenas then
    BGAutoDB.arenas = {
        rated2v2 = false,
        rated3v3 = false,
        rated5v5 = false,
        skirmish = false,
    }
end


-- BG API names (what JoinBattlegroundQueue expects)
local BG_API_NAMES = {
    wsg = "Warsong Gulch",
    ab = "Arathi Basin",
    av = "Alterac Valley",
    tg = "Thorn Gorge",
}

local BG_DISPLAY_NAMES = {
    wsg = "Warsong Gulch",
    ab = "Arathi Basin",
    av = "Alterac Valley",
    tg = "Thorn Gorge",
}

local ARENA_DISPLAY_NAMES = {
    rated2v2 = "Rated (2v2)",
    rated3v3 = "Rated (3v3)",
    rated5v5 = "Rated (5v5)",
    skirmish = "Skirmish",
}

--====================================================
-- Queue system: processes one BG at a time
--====================================================
local BGQueueFrame = CreateFrame("Frame")
local pendingQueue = {}
local isQueueing = false

local function HideBattlefieldFrame()
    if _G["BattlefieldFrame"] then
        _G["BattlefieldFrame"]:Hide()
    end
end

-- Check if already queued for a specific BG name
local function IsAlreadyQueued(bgName)
    for i = 0, MAX_BATTLEFIELD_QUEUES do
        local status, name = GetBattlefieldStatus(i)
        if status and status ~= "none" and name == bgName then
            return true
        end
    end
    return false
end

-- Process the next item in the pending queue
local function ProcessNextQueue()
    if isQueueing then return end

    while getn(pendingQueue) > 0 do
        local name = table.remove(pendingQueue, 1)
        if not IsAlreadyQueued(name) then
            isQueueing = true
            BGQueueFrame:UnregisterAllEvents()
            BGQueueFrame:RegisterEvent("BATTLEFIELDS_SHOW")
            BGQueueFrame:SetScript("OnEvent", function()
                SetSelectedBattlefield(0)
                JoinBattlefield(0)
                BGQueueFrame:UnregisterEvent("BATTLEFIELDS_SHOW")
                HideBattlefieldFrame()
                print("BGAuto: Queued for " .. name)
                isQueueing = false
                ProcessNextQueue()
            end)
            JoinBattlegroundQueue(name)
            return
        end
    end
end

-- Add a BG/arena to the pending queue
local function QueueBattleground(name)
    if IsAlreadyQueued(name) then return end
    table.insert(pendingQueue, name)
    ProcessNextQueue()
end

--====================================================
-- Queue a specific BG by key
--====================================================
local function QueueBG(bgKey)
    local name = BG_API_NAMES[bgKey]
    if not name then
        print("BGAuto: Unknown BG key: " .. bgKey)
        return
    end
    QueueBattleground(name)
end

--====================================================
-- Queue a specific arena by key
--====================================================
local function QueueArena(arenaKey)
    local name = ARENA_DISPLAY_NAMES[arenaKey]
    if not name then
        print("BGAuto: Unknown arena key: " .. arenaKey)
        return
    end
    QueueBattleground(name)
end

--====================================================
-- Queue all enabled BGs and arenas
--====================================================
local BG_ORDER = {"wsg", "ab", "av", "tg"}
local ARENA_ORDER = {"rated2v2", "rated3v3", "rated5v5", "skirmish"}

local function QueueAll()
    if not BGAutoDB.enabled then return end

    for _, key in ipairs(BG_ORDER) do
        if BGAutoDB.bgs[key] then
            QueueBG(key)
        end
    end

    for _, key in ipairs(ARENA_ORDER) do
        if BGAutoDB.arenas[key] then
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

-- Hide the BattlefieldFrame whenever it opens (so AV window doesn't stay up)
local hideFrame = CreateFrame("Frame")
hideFrame:RegisterEvent("BATTLEFIELDS_SHOW")
hideFrame:SetScript("OnEvent", function()
    HideBattlefieldFrame()
end)

--====================================================
-- Settings panel
--====================================================
local panel = CreateFrame("Frame", "BGAutoPanel", UIParent)
panel:SetWidth(220)
panel:SetHeight(320)
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
title:SetText("BGAuto Settings")

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
    cb:SetChecked(BGAutoDB.bgs[key] or false)
    cb:SetScript("OnClick", function()
        BGAutoDB.bgs[key] = cb:GetChecked()
        if cb:GetChecked() then
            QueueBG(key)
        end
    end)
end

CreateBGCheckbox(panel, "Warsong Gulch", "wsg", -30)
CreateBGCheckbox(panel, "Arathi Basin", "ab", -55)
CreateBGCheckbox(panel, "Alterac Valley", "av", -80)
CreateBGCheckbox(panel, "Thorn Gorge", "tg", -105)

-- Arena label
local arenaLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arenaLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -130)
arenaLabel:SetText("Arenas:")

-- Arena checkboxes
local function CreateArenaCheckbox(parent, text, key, y)
    local cb = MakeCheckbox(parent, text, y)
    cb:SetChecked(BGAutoDB.arenas[key] or false)
    cb:SetScript("OnClick", function()
        BGAutoDB.arenas[key] = cb:GetChecked()
        if cb:GetChecked() then
            QueueArena(key)
        end
    end)
end

CreateArenaCheckbox(panel, "Rated (2v2)", "rated2v2", -150)
CreateArenaCheckbox(panel, "Rated (3v3)", "rated3v3", -175)
CreateArenaCheckbox(panel, "Rated (5v5)", "rated5v5", -200)
CreateArenaCheckbox(panel, "Skirmish", "skirmish", -225)

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
SLASH_BGAUTO1 = "/bgauto"
SlashCmdList["BGAUTO"] = function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

-- Debug: show current queue status and available BGs
SLASH_BGAUTODEBUG1 = "/bgautodebug"
SlashCmdList["BGAUTODEBUG"] = function()
    print("=== Queue Status ===")
    for i = 0, MAX_BATTLEFIELD_QUEUES do
        local status, name = GetBattlefieldStatus(i)
        if status and status ~= "none" then
            print("  Slot " .. i .. ": " .. status .. " - " .. (name or "unknown"))
        end
    end

    print("=== Trying BG names ===")
    local testNames = {
        "Warsong Gulch", "Arathi Basin", "Alterac Valley",
        "Thorn Gorge", "ThornGorge", "Thorn gorge",
        "Blood Ring", "Azshara Crater",
    }
    for _, n in ipairs(testNames) do
        print("  " .. n)
    end
    print("Try: /bgtest NAME to test a specific name")
end

-- Test a specific BG name
SLASH_BGTEST1 = "/bgtest"
SlashCmdList["BGTEST"] = function(msg)
    if msg and msg ~= "" then
        print("BGAuto: Testing queue for '" .. msg .. "'")
        QueueBattleground(msg)
    else
        print("Usage: /bgtest Thorn Gorge")
    end
end

print("BGAuto loaded. Type /bgauto to toggle settings.")
