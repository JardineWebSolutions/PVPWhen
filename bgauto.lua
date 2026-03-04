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
        sunny = false,
    }
}

-- Map BG names to friendly names
local BG_NAMES = {
    wsg = "Warsong Gulch",
    ab = "Arathi Basin",
    av = "Alterac Valley",
    sunny = "Sunnyvale Glade",
}

--====================================================
-- Core function: Select BG by name and queue
--====================================================
local function SelectBGByName(name)
    if not TWMiniMapBattlefieldFrame or not TWMiniMapBattlefieldFrame.BGFinderQueueButton then
        print("BGAuto: TWMiniMapBattlefieldFrame not found!")
        return
    end

    -- Open minimap finder
    TWMiniMapBattlefieldFrame.BGFinderQueueButton:Click()

    -- Wait briefly for dropdown to populate
    for i=1, 20 do
        local b = _G["DropDownList1Button"..i]
        if b and b:IsVisible() and b:GetText() == name then
            b:Click()
            break
        end
    end

    -- Click Join button
    if TWMiniMapBattlefieldFrame.BattlefieldFrameJoinButton then
        TWMiniMapBattlefieldFrame.BattlefieldFrameJoinButton:Click()
    end

    -- Hide frame instantly
    TWMiniMapBattlefieldFrame:Hide()
end

--====================================================
-- Automatic queue engine
--====================================================
local function TryQueue()
    if not BGAutoDB.enabled then return end

    -- Check all BGs in order
    for key, enabled in pairs(BGAutoDB.bgs) do
        if enabled then
            SelectBGByName(BG_NAMES[key])
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
f:SetScript("OnEvent", TryQueue)

--====================================================
-- Minimal settings panel
--====================================================
local panel = CreateFrame("Frame", "BGAutoPanel", UIParent)
panel:SetWidth(200)
panel:SetHeight(180)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background"})
panel:SetBackdropColor(0,0,0,0.8)
panel:Hide()

-- Helper to create checkboxes
local function CreateCheckbox(parent, text, key, y)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetWidth(20)
    cb:SetHeight(20)
    cb:SetPoint("TOPLEFT", 20, y)
    
    -- Create the text label
    local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbText:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cbText:SetText(text)
    
    cb:SetChecked(BGAutoDB.bgs[key])

    cb:SetScript("OnClick", function(self)
        BGAutoDB.bgs[key] = self:GetChecked()
    end)
end

-- Add per-BG checkboxes
CreateCheckbox(panel, "Warsong Gulch", "wsg", -30)
CreateCheckbox(panel, "Arathi Basin", "ab", -55)
CreateCheckbox(panel, "Alterac Valley", "av", -80)
CreateCheckbox(panel, "Sunnyvale Glade", "sunny", -105)

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