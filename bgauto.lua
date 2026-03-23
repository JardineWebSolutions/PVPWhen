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
        rated2v2 = false,
        rated3v3 = false,
        rated5v5 = false,
        skirmish = false,
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
    
    -- Try to find the battlefield frame using different names
    local frame = TWMiniMapBattlefieldFrame or _G["BattlefieldFrame"] or _G["BGFinderFrame"]
    
    if not frame then
        print("BGAuto: Could not find battlefield frame!")
        print("BGAuto: Available frames:")
        for key in pairs(_G) do
            if string.find(strlower(key), "battle") or string.find(strlower(key), "queue") or string.find(strlower(key), "arena") then
                print("  - " .. key)
            end
        end
        return
    end
    
    local queueButton = frame.BGFinderQueueButton or frame.QueueButton or frame.FindButton
    
    if not queueButton then
        print("BGAuto: Could not find queue button in battlefield frame!")
        return
    end

    -- Open minimap finder
    queueButton:Click()

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
        if frame then frame:Hide() end
    end
end

local function SelectArenaType(arenaType)
    -- Try to find the battlefield frame using different names
    local frame = TWMiniMapBattlefieldFrame or _G["BattlefieldFrame"] or _G["BGFinderFrame"]
    
    if not frame then
        print("BGAuto: Could not find battlefield frame for arena!")
        return
    end

    local queueButton = frame.BGFinderQueueButton or frame.QueueButton or frame.FindButton
    
    if not queueButton then
        print("BGAuto: Could not find queue button in battlefield frame!")
        return
    end

    -- Open minimap finder
    queueButton:Click()

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
        if frame then frame:Hide() end
    end
end

--====================================================
-- Automatic queue engine
--====================================================
local function TryQueue()
    if not BGAutoDB.enabled then return end
    
    -- Initialize arenas table if it doesn't exist (for backwards compatibility)
    if not BGAutoDB.arenas then
        BGAutoDB.arenas = {
            rated2v2 = false,
            rated3v3 = false,
            rated5v5 = false,
            skirmish = false,
        }
    end

    -- Check arenas first
    if BGAutoDB.arenas.rated2v2 then
        SelectArenaType("Rated (2v2)")
        return
    end
    
    if BGAutoDB.arenas.rated3v3 then
        SelectArenaType("Rated (3v3)")
        return
    end
    
    if BGAutoDB.arenas.rated5v5 then
        SelectArenaType("Rated (5v5)")
        return
    end
    
    if BGAutoDB.arenas.skirmish then
        SelectArenaType("Skirmish")
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
        if string.sub(queueMode, 1, 6) == "arena:" then
            local arenaType = string.sub(queueMode, 8)
            local found = false
            for i=1, 50 do
                local b = _G["DropDownList1Button"..i]
                if b and b:IsVisible() then
                    local btnText = b:GetText()
                    if btnText and btnText == arenaType then
                        b:Click()
                        found = true
                        queueTimer = GetTime() + 0.5
                        queueMode = "arena_waiting"
                        return
                    end
                end
            end
            if not found then
                print("BGAuto: Could not find '" .. arenaType .. "' in arena submenu")
            end
        else
            -- Normal BG queueing - we've clicked the BG, now wait for window to open
            queueMode = "bg_waiting"
            queueTimer = GetTime() + 0.5
            return
        end
        return
    end
    
    -- Check if we're waiting for BG window to open so we can click Join
    if queueMode == "bg_waiting" and GetTime() >= queueTimer then
        -- Search for any visible frame with a button containing "Join" text
        local joinBtn = nil
        local bgWindow = nil
        for i=1, 100 do
            local btn = _G["BattlefieldInstanceButton"..i] or _G["BattlegroundQueueButton"..i] or _G["JoinBattleButton"..i]
            if btn and btn:IsVisible() then
                joinBtn = btn
                break
            end
        end
        
        -- Try to find by searching through all visible frames for "Join Battle" button
        if not joinBtn then
            for key, frame in pairs(_G) do
                if type(frame) == "table" and frame.GetChildren then
                    for _, child in ipairs({frame:GetChildren()}) do
                        if child.GetText and child:GetText() and string.find(child:GetText(), "Join") then
                            joinBtn = child
                            bgWindow = frame
                            break
                        end
                    end
                end
            end
        end
        
        if joinBtn then
            joinBtn:Click()
            print("BGAuto: Queued successfully!")
            queueMode = "none"
            queueTimer = 0
            -- Hide the BG window after clicking
            if bgWindow then
                bgWindow:Hide()
            end
            -- Hide the dropdown menu
            local frame = TWMiniMapBattlefieldFrame or _G["BattlefieldFrame"] or _G["BGFinderFrame"]
            if frame then frame:Hide() end
        else
            -- Wait a bit longer for window to open
            if GetTime() - queueTimer < 2 then
                queueTimer = GetTime() + 0.2
            else
                print("BGAuto: Timeout waiting for BG window to open")
                queueMode = "none"
                queueTimer = 0
                -- Hide frames on timeout
                local frame = TWMiniMapBattlefieldFrame or _G["BattlefieldFrame"] or _G["BGFinderFrame"]
                if frame then frame:Hide() end
            end
        end
        return
    end
    
    -- Check if we're waiting for arena window to open
    if queueMode == "arena_waiting" and GetTime() >= queueTimer then
        local joinBtn = nil
        local arenaWindow = nil
        for key, frame in pairs(_G) do
            if type(frame) == "table" and frame.GetChildren then
                for _, child in ipairs({frame:GetChildren()}) do
                    if child.GetText and child:GetText() and string.find(child:GetText(), "Join") then
                        joinBtn = child
                        arenaWindow = frame
                        break
                    end
                end
            end
        end
        
        if joinBtn then
            joinBtn:Click()
            print("BGAuto: Queued for arena successfully!")
            queueMode = "none"
            queueTimer = 0
            -- Hide the arena window after clicking
            if arenaWindow then
                arenaWindow:Hide()
            end
            -- Hide the dropdown menu
            local frame = TWMiniMapBattlefieldFrame or _G["BattlefieldFrame"] or _G["BGFinderFrame"]
            if frame then frame:Hide() end
        else
            if GetTime() - queueTimer < 2 then
                queueTimer = GetTime() + 0.2
            else
                print("BGAuto: Timeout waiting for arena window to open")
                queueMode = "none"
                queueTimer = 0
                -- Hide frames on timeout
                local frame = TWMiniMapBattlefieldFrame or _G["BattlefieldFrame"] or _G["BGFinderFrame"]
                if frame then frame:Hide() end
            end
        end
        return
    end
    
    TryQueue()
end)

--====================================================
-- Minimal settings panel
--====================================================
local panel = CreateFrame("Frame", "BGAutoPanel", UIParent)
panel:SetWidth(220)
panel:SetHeight(320)
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
        -- Immediately queue when checkbox is clicked
        TryQueue()
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
    
    -- Ensure arenas table exists
    if not BGAutoDB.arenas then
        BGAutoDB.arenas = {
            rated2v2 = false,
            rated3v3 = false,
            rated5v5 = false,
            skirmish = false,
        }
    end
    
    cb:SetChecked(BGAutoDB.arenas[key] or false)
    
    cb:SetScript("OnClick", function()
        BGAutoDB.arenas[key] = cb:GetChecked()
        -- Immediately queue when checkbox is clicked
        TryQueue()
    end)
end

CreateArenaCheckbox(panel, "Rated (2v2)", "rated2v2", -145)
CreateArenaCheckbox(panel, "Rated (3v3)", "rated3v3", -170)
CreateArenaCheckbox(panel, "Rated (5v5)", "rated5v5", -195)
CreateArenaCheckbox(panel, "Skirmish", "skirmish", -220)

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

-- Add Queue Now button
local queueBtn = CreateFrame("Button", nil, panel)
queueBtn:SetWidth(100)
queueBtn:SetHeight(24)
queueBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 10)
queueBtn:SetNormalTexture("Interface\\Buttons\\UI-DialogBox-Button-Up")
queueBtn:SetPushedTexture("Interface\\Buttons\\UI-DialogBox-Button-Down")
queueBtn:SetHighlightTexture("Interface\\Buttons\\UI-DialogBox-Button-Highlight")

local queueBtnText = queueBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
queueBtnText:SetPoint("CENTER", queueBtn, "CENTER", 0, 0)
queueBtnText:SetText("Queue Now")

queueBtn:SetScript("OnClick", function()
    TryQueue()
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

-- Debug slash command - prints 10 results at a time, use /bgautodebug again for next page
BGAutoDebugPage = 0
BGAutoDebugResults = {}

SLASH_BGAUTODEBUG1 = "/bgautodebug"
SlashCmdList["BGAUTODEBUG"] = function()
    if getn(BGAutoDebugResults) == 0 then
        BGAutoDebugPage = 0
        for key in pairs(_G) do
            local lower = strlower(key)
            if string.find(lower, "battlefield") or string.find(lower, "battleground") or string.find(lower, "bgfinder") or string.find(lower, "twminimap") then
                table.insert(BGAutoDebugResults, key)
            end
        end
        table.sort(BGAutoDebugResults)
        print("BGAuto: Found " .. getn(BGAutoDebugResults) .. " frames. Showing 10 at a time:")
    end
    
    local startIdx = BGAutoDebugPage * 10 + 1
    local endIdx = startIdx + 9
    if endIdx > getn(BGAutoDebugResults) then
        endIdx = getn(BGAutoDebugResults)
    end
    
    for i = startIdx, endIdx do
        print(i .. ": " .. BGAutoDebugResults[i])
    end
    
    BGAutoDebugPage = BGAutoDebugPage + 1
    
    if endIdx >= getn(BGAutoDebugResults) then
        print("=== End of list ===")
        BGAutoDebugResults = {}
    else
        print("--- Type /bgautodebug for next page ---")
    end
end

--====================================================
-- Initial test print
--====================================================
print("BGAuto loaded. Type /bgauto to toggle settings.")