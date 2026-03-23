--========================================
-- BGAuto.lua for Turtle WoW
-- Fully automatic BG queue with per-BG toggles
-- Hides TWMiniMapBattlefieldFrame, no NPC required
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
        arena3v3 = false,
        arena2v2 = false,
    }
}

-- Map BG names to friendly names
local BG_NAMES = {
    wsg = "Warsong Gulch",
    ab = "Arathi Basin",
    av = "Alterac Valley",
    tg = "Thorn Gorge",
}

--====================================================
-- Core function: Select BG by name and queue
--====================================================
local queueTimer = 0
local queueMode = "none" -- Track what we're queueing for

local function SelectBGByName(name, mode)
    mode = mode or "bg"
    if not TWMiniMapBattlefieldFrame or not TWMiniMapBattlefieldFrame.BGFinderQueueButton then
        print("BGAuto: TWMiniMapBattlefieldFrame not found!")
        return
    end

    -- Open minimap finder
    TWMiniMapBattlefieldFrame.BGFinderQueueButton:Click()

    -- Search through all dropdown buttons (expanded range to handle nested menus)
    local found = false
    for i=1, 50 do
        local b = _G["DropDownList1Button"..i]
        if b and b:IsVisible() then
            local btnText = b:GetText()
            if btnText and btnText == name then
                b:Click()
                found = true
                queueTimer = GetTime() + 0.5
                queueMode = mode
                break
            end
        end
    end

    if not found then
        print("BGAuto: Could not find '" .. name .. "' in queue menu")
        TWMiniMapBattlefieldFrame:Hide()
    end
end

local function SelectArenaType(arenaType)
    if not TWMiniMapBattlefieldFrame or not TWMiniMapBattlefieldFrame.BGFinderQueueButton then
        print("BGAuto: TWMiniMapBattlefieldFrame not found!")
        return
    end

    -- Open minimap finder
    TWMiniMapBattlefieldFrame.BGFinderQueueButton:Click()

    -- First, click on "Arenas" to open the submenu
    local found = false
    for i=1, 50 do
        local b = _G["DropDownList1Button"..i]
        if b and b:IsVisible() then
            local btnText = b:GetText()
            if btnText and btnText == "Arenas" then
                b:Click()
                found = true
                queueTimer = GetTime() + 0.3
                queueMode = "arena:" .. arenaType
                break
            end
        end
    end

    if not found then
        print("BGAuto: Could not find 'Arenas' in queue menu")
        TWMiniMapBattlefieldFrame:Hide()
    end
end

--====================================================
-- Automatic queue engine
--====================================================
local function TryQueue()
    if not BGAutoDB.enabled then return end

    -- Check arenas first
    if BGAutoDB.arenas.arena3v3 then
        SelectArenaType("3v3 Skirmish")
        return
    end
    
    if BGAutoDB.arenas.arena2v2 then
        SelectArenaType("2v2 Skirmish")
        return
    end

    -- Check all BGs in order
    for key, enabled in pairs(BGAutoDB.bgs) do
        if enabled then
            SelectBGByName(BG_NAMES[key], "bg")
            return
        end
    end
end

--====================================================
-- Event handler for auto requeue
--====================================================
local f = CreateFrame("Frame")
f:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        return
    end
    
    -- Check if we're waiting to click Join button or select arena type
    if queueTimer > 0 and GetTime() >= queueTimer then
        queueTimer = 0
        
        -- Handle arena submenu selection
        if queueMode:sub(1, 6) == "arena:" then
            local arenaType = queueMode:sub(8)
            local found = false
            for i=1, 50 do
                local b = _G["DropDownList1Button"..i]
                if b and b:IsVisible() then
                    local btnText = b:GetText()
                    if btnText and btnText == arenaType then
                        b:Click()
                        found = true
                        queueTimer = GetTime() + 0.3
                        queueMode = "none"
                        return
                    end
                end
            end
            if not found then
                print("BGAuto: Could not find '" .. arenaType .. "' in arena submenu")
                if TWMiniMapBattlefieldFrame then
                    TWMiniMapBattlefieldFrame:Hide()
                end
            end
        else
            -- Normal BG queueing
            if TWMiniMapBattlefieldFrame and TWMiniMapBattlefieldFrame.BattlefieldFrameJoinButton then
                TWMiniMapBattlefieldFrame.BattlefieldFrameJoinButton:Click()
            end
            if TWMiniMapBattlefieldFrame then
                TWMiniMapBattlefieldFrame:Hide()
            end
            queueMode = "none"
        end
        return
    end
    
    -- Check if we need to click Join after arena selection
    if queueTimer == 0 and queueMode ~= "none" then
        queueTimer = 0
        if TWMiniMapBattlefieldFrame and TWMiniMapBattlefieldFrame.BattlefieldFrameJoinButton then
            TWMiniMapBattlefieldFrame.BattlefieldFrameJoinButton:Click()
        end
        if TWMiniMapBattlefieldFrame then
            TWMiniMapBattlefieldFrame:Hide()
        end
        queueMode = "none"
        return
    end
    
    TryQueue()
end)

--====================================================
-- Minimal settings panel
--====================================================
local panel = CreateFrame("Frame", "BGAutoPanel", UIParent)
panel:SetWidth(220)
panel:SetHeight(250)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background"})
panel:SetBackdropColor(0,0,0,0.8)
panel:Hide()

-- Helper to create checkboxes
local function CreateCheckbox(parent, text, key, y)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetWidth(20)
    cb:SetHeight(20)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    
    -- Set checkbox textures for visibility
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    
    -- Create the text label
    local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbText:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cbText:SetText(text)
    
    cb:SetChecked(BGAutoDB.bgs[key])

    cb:SetScript("OnClick", function()
        BGAutoDB.bgs[key] = cb:GetChecked()
    end)
end

-- Add title
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", panel, "TOP", 0, -10)
title:SetText("BGAuto Settings")

-- Add per-BG checkboxes
CreateCheckbox(panel, "Warsong Gulch", "wsg", -30)
CreateCheckbox(panel, "Arathi Basin", "ab", -55)
CreateCheckbox(panel, "Alterac Valley", "av", -80)
CreateCheckbox(panel, "Thorn Gorge", "tg", -105)

-- Add arena label
local arenaLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arenaLabel:SetPoint("TOPLEFT", 20, -125)
arenaLabel:SetText("Arenas:")

-- Add arena checkboxes
local function CreateArenaCheckbox(parent, text, key, y)
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
    
    cb:SetChecked(BGAutoDB.arenas[key])
    
    cb:SetScript("OnClick", function()
        BGAutoDB.arenas[key] = cb:GetChecked()
    end)
end

CreateArenaCheckbox(panel, "3v3 Skirmish", "arena3v3", -145)
CreateArenaCheckbox(panel, "2v2 Skirmish", "arena2v2", -170)

-- Add close button
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

-- Slash command to toggle panel
SLASH_BGAUTO1 = "/bgauto"
SlashCmdList["BGAUTO"] = function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

--====================================================
-- Initial test print
--====================================================
print("BGAuto loaded. Type /bgauto to toggle settings.")