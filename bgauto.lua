--========================================
-- BGAuto.lua for Turtle WoW
-- Fully automatic BG queue with per-BG toggles
--========================================

-- SavedVariables
BGAutoDB = BGAutoDB or {
    enabled = true,
    bgs = {
        wsg = true,
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

-- Map BG keys to dropdown text and DropDownList1 button index
local BG_NAMES = {
    wsg = "Warsong Gulch",
    ab = "Arathi Basin",
    av = "Alterac Valley",
    tg = "Thorn Gorge",
}
local BG_INDICES = {
    wsg = 4,
    ab = 5,
    av = 6,
    tg = 7,
}

--====================================================
-- Queue state
--====================================================
local queueStep = "idle"
local queueTarget = nil
local queueTimerEnd = 0

local function StartTimer(seconds)
    queueTimerEnd = GetTime() + seconds
end

--====================================================
-- Step 1: Click TWMiniMapBattlefieldFrame to open dropdown
--====================================================
local function OpenDropdown()
    if not TWMiniMapBattlefieldFrame then
        print("BGAuto: TWMiniMapBattlefieldFrame not found!")
        return false
    end
    TWMiniMapBattlefieldFrame:Click()
    return true
end

--====================================================
-- Step 2: Click a BG in DropDownList1 by index
--====================================================
local function ClickDropdownBG(bgKey)
    local idx = BG_INDICES[bgKey]
    if not idx then
        print("BGAuto: Unknown BG key: " .. bgKey)
        return false
    end
    local b = _G["DropDownList1Button" .. idx]
    if b and b:IsVisible() then
        b:Click()
        return true
    end
    print("BGAuto: DropDownList1Button" .. idx .. " not found")
    return false
end

--====================================================
-- Step 2a: Click "Arena" in DropDownList1 (index 3)
--====================================================
local function ClickArenaDropdown()
    local b = _G["DropDownList1Button3"]
    if b and b:IsVisible() then
        b:Click()
        return true
    end
    print("BGAuto: DropDownList1Button3 (Arena) not found")
    return false
end

-- Map arena keys to DropDownList2 button indices
local ARENA_INDICES = {
    rated2v2 = 1,
    rated3v3 = 2,
    rated5v5 = 3,
    skirmish = 5,
}

--====================================================
-- Step 2b: Click arena type in DropDownList2 by index
--====================================================
local function ClickArenaType(arenaKey)
    local idx = ARENA_INDICES[arenaKey]
    if not idx then
        print("BGAuto: Unknown arena key: " .. arenaKey)
        return false
    end
    local b = _G["DropDownList2Button" .. idx]
    if b and b:IsVisible() then
        b:Click()
        return true
    end
    print("BGAuto: DropDownList2Button" .. idx .. " not found")
    return false
end

--====================================================
-- Step 3: Click BattlefieldFrameJoinButton
--====================================================
local function ClickJoinBattle()
    local btn = _G["BattlefieldFrameJoinButton"]
    if btn and btn:IsVisible() then
        btn:Click()
        return true
    end
    return false
end

--====================================================
-- Hide all BG-related frames
--====================================================
local function HideAllFrames()
    if _G["BattlefieldFrame"] then
        _G["BattlefieldFrame"]:Hide()
    end
    if _G["DropDownList1"] then
        _G["DropDownList1"]:Hide()
    end
    if _G["DropDownList2"] then
        _G["DropDownList2"]:Hide()
    end
end

--====================================================
-- Queue a BG by key
--====================================================
local function QueueBG(bgKey)
    if not OpenDropdown() then return end
    queueStep = "bg_select"
    queueTarget = bgKey
    StartTimer(0.3)
end

--====================================================
-- Queue an arena by key
--====================================================
local function QueueArena(arenaKey)
    if not OpenDropdown() then return end
    queueStep = "arena_open"
    queueTarget = arenaKey
    StartTimer(0.3)
end

--====================================================
-- Automatic queue engine
--====================================================
local BG_ORDER = {"wsg", "ab", "av", "tg"}
local ARENA_ORDER = {"rated2v2", "rated3v3", "rated5v5", "skirmish"}

local function TryQueue()
    if not BGAutoDB.enabled then return end
    if queueStep ~= "idle" then return end

    -- Check BGs in fixed order
    for _, key in ipairs(BG_ORDER) do
        if BGAutoDB.bgs[key] then
            QueueBG(key)
            return
        end
    end

    -- Check arenas in fixed order
    for _, key in ipairs(ARENA_ORDER) do
        if BGAutoDB.arenas[key] then
            QueueArena(key)
            return
        end
    end
end

--====================================================
-- OnUpdate handler for timed steps
--====================================================
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    if queueStep == "idle" then return end
    if GetTime() < queueTimerEnd then return end

    if queueStep == "bg_select" then
        if ClickDropdownBG(queueTarget) then
            queueStep = "bg_join"
            StartTimer(0.5)
        else
            queueStep = "idle"
            HideAllFrames()
        end

    elseif queueStep == "bg_join" then
        if ClickJoinBattle() then
            print("BGAuto: Queued for " .. BG_NAMES[queueTarget])
            queueStep = "idle"
            HideAllFrames()
        else
            StartTimer(0.2)
        end

    elseif queueStep == "arena_open" then
        if ClickArenaDropdown() then
            queueStep = "arena_select"
            StartTimer(0.3)
        else
            queueStep = "idle"
            HideAllFrames()
        end

    elseif queueStep == "arena_select" then
        if ClickArenaType(queueTarget) then
            queueStep = "arena_join"
            StartTimer(0.5)
        else
            queueStep = "idle"
            HideAllFrames()
        end

    elseif queueStep == "arena_join" then
        if ClickJoinBattle() then
            print("BGAuto: Queued for arena")
            queueStep = "idle"
            HideAllFrames()
        else
            StartTimer(0.2)
        end
    end
end)

--====================================================
-- Event handler for auto requeue
--====================================================
local f = CreateFrame("Frame")
f:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    TryQueue()
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

-- Helper to create checkboxes
local function CreateCheckbox(parent, text, dbTable, key, y)
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

    cb:SetChecked(dbTable[key] or false)

    cb:SetScript("OnClick", function()
        dbTable[key] = cb:GetChecked()
        if cb:GetChecked() then
            TryQueue()
        end
    end)
end

-- BG checkboxes
CreateCheckbox(panel, "Warsong Gulch", BGAutoDB.bgs, "wsg", -30)
CreateCheckbox(panel, "Arathi Basin", BGAutoDB.bgs, "ab", -55)
CreateCheckbox(panel, "Alterac Valley", BGAutoDB.bgs, "av", -80)
CreateCheckbox(panel, "Thorn Gorge", BGAutoDB.bgs, "tg", -105)

-- Arena label
local arenaLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arenaLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -130)
arenaLabel:SetText("Arenas:")

-- Arena checkboxes
CreateCheckbox(panel, "Rated (2v2)", BGAutoDB.arenas, "rated2v2", -150)
CreateCheckbox(panel, "Rated (3v3)", BGAutoDB.arenas, "rated3v3", -175)
CreateCheckbox(panel, "Rated (5v5)", BGAutoDB.arenas, "rated5v5", -200)
CreateCheckbox(panel, "Skirmish", BGAutoDB.arenas, "skirmish", -225)

-- Queue Now button
local queueBtn = CreateFrame("Button", nil, panel)
queueBtn:SetWidth(100)
queueBtn:SetHeight(24)
queueBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 35)
queueBtn:SetNormalTexture("Interface\\Buttons\\UI-DialogBox-Button-Up")
queueBtn:SetPushedTexture("Interface\\Buttons\\UI-DialogBox-Button-Down")
queueBtn:SetHighlightTexture("Interface\\Buttons\\UI-DialogBox-Button-Highlight")

local queueBtnText = queueBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
queueBtnText:SetPoint("CENTER", queueBtn, "CENTER", 0, 0)
queueBtnText:SetText("Queue Now")

queueBtn:SetScript("OnClick", function()
    TryQueue()
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

-- Slash command
SLASH_BGAUTO1 = "/bgauto"
SlashCmdList["BGAUTO"] = function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

-- Debug command
SLASH_BGAUTODEBUG1 = "/bgautodebug"
SlashCmdList["BGAUTODEBUG"] = function()
    local frame = GetMouseFocus()
    if frame then
        local name = frame:GetName() or "unnamed"
        local parent = frame:GetParent()
        local parentName = "none"
        if parent and parent.GetName then
            parentName = parent:GetName() or "unnamed"
        end
        print("Frame: " .. name)
        print("Parent: " .. parentName)
        if frame.GetText then
            local txt = frame:GetText()
            if txt then
                print("Text: " .. txt)
            end
        end
    else
        print("No frame under cursor")
    end
end

print("BGAuto loaded. Type /bgauto to toggle settings.")
