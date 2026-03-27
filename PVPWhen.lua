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
        tg = false,
    },
    arenas = {
        skirmish = false,
    },
    minimap = {
        show = true,
        angle = 200,
    }
}

local UpdateMinimapPosition

-- Fix up saved variables after they load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function()
    if not PVPWhenDB.minimap then
        PVPWhenDB.minimap = { show = true, angle = 200 }
    end
    if not PVPWhenDB.arenas then
        PVPWhenDB.arenas = {
            skirmish = false,
        }
    end
    if _G["PVPWhenMinimapButton"] then
        UpdateMinimapPosition()
    end
end)

-- Arena API IDs for JoinArenaQueue
local ARENA_IDS = {
    skirmish = 0,
}

-- BG API names (what JoinBattlegroundQueue expects)
local BG_API_NAMES = {
    wsg = "Warsong Gulch",
    ab = "Arathi Basin",
    av = "Alterac Valley",
    tg = "ThornGorge",
}

--====================================================
-- Queue system: processes one BG at a time
--====================================================
local PVPWhenQueueFrame = CreateFrame("Frame")
local pendingQueue = {}
local isQueueing = false
local autoQueueActive = false

local function HideBattlefieldFrame()
    local gameMenuWasShown = _G["GameMenuFrame"] and _G["GameMenuFrame"]:IsShown()
    if _G["BattlefieldFrame"] then
        _G["BattlefieldFrame"]:Hide()
    end
    if gameMenuWasShown and _G["GameMenuFrame"] and not _G["GameMenuFrame"]:IsShown() then
        _G["GameMenuFrame"]:Show()
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

local currentAsGroup = 0

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
                if currentAsGroup == 1 then
                    JoinBattlefield(0, 1)
                else
                    JoinBattlefield(0)
                end
                PVPWhenQueueFrame:UnregisterEvent("BATTLEFIELDS_SHOW")
                HideBattlefieldFrame()
                local suffix = currentAsGroup == 1 and " (group)" or ""
                print("PVPWhen: Queued for " .. name .. suffix)
                isQueueing = false
                autoQueueActive = false
                ProcessNextQueue()
            end)
            JoinBattlegroundQueue(name)
            return
        end
    end
    currentAsGroup = 0
end

local function QueueBattleground(name)
    if IsAlreadyQueued(name) then return end
    table.insert(pendingQueue, name)
    ProcessNextQueue()
end

local function QueueBG(bgKey, asGroup)
    local name = BG_API_NAMES[bgKey]
    if not name then
        print("PVPWhen: Unknown BG key: " .. bgKey)
        return
    end
    if asGroup then currentAsGroup = 1 end
    QueueBattleground(name)
end

--====================================================
-- Queue a specific arena by key
--====================================================
local function QueueArena(arenaKey, asGroup)
    local id = ARENA_IDS[arenaKey]
    if id == nil then
        print("PVPWhen: Unknown arena key: " .. arenaKey)
        return
    end
    local joinFlag = asGroup and 1 or 0
    autoQueueActive = true
    PVPWhenQueueFrame:UnregisterAllEvents()
    PVPWhenQueueFrame:RegisterEvent("BATTLEFIELDS_SHOW")
    PVPWhenQueueFrame:SetScript("OnEvent", function()
        SetSelectedBattlefield(0)
        if joinFlag == 1 then
            JoinBattlefield(0, 1)
        else
            JoinBattlefield(0)
        end
        PVPWhenQueueFrame:UnregisterEvent("BATTLEFIELDS_SHOW")
        HideBattlefieldFrame()
        local suffix = joinFlag == 1 and " (group)" or ""
        print("PVPWhen: Queued for arena (" .. arenaKey .. ")" .. suffix)
        autoQueueActive = false
    end)
    JoinArenaQueue(id)
end

--====================================================
-- Queue all enabled BGs and arenas
--====================================================
local BG_ORDER = {"wsg", "ab", "av", "tg"}
local ARENA_ORDER = {"skirmish"}

local function QueueAll(asGroup)
    if not PVPWhenDB.enabled then return end

    for _, key in ipairs(BG_ORDER) do
        if PVPWhenDB.bgs[key] then
            QueueBG(key, asGroup)
        end
    end

    for _, key in ipairs(ARENA_ORDER) do
        if PVPWhenDB.arenas[key] then
            QueueArena(key, asGroup)
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
panel:SetWidth(250)
panel:SetHeight(300)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropColor(0.05, 0.05, 0.1, 0.9)
panel:SetBackdropBorderColor(0.6, 0.6, 0.8, 0.8)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() panel:StartMoving() end)
panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
local panelRealShow = panel:GetScript("OnShow") or nil
local panelAllowHide = true
panel.ForceShow = function(self)
    panelAllowHide = true
    self:Show()
end
panel.ForceHide = function(self)
    panelAllowHide = true
    self:Hide()
end

local origHide = panel.Hide
panel.Hide = function(self)
    if panelAllowHide then
        panelAllowHide = false
        origHide(self)
    end
end

panel:ForceHide()

-- Header bar
local header = CreateFrame("Frame", nil, panel)
header:SetWidth(242)
header:SetHeight(28)
header:SetPoint("TOP", panel, "TOP", 0, -4)
header:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
header:SetBackdropColor(0.15, 0.1, 0.3, 1.0)
header:SetBackdropBorderColor(0.5, 0.4, 0.7, 0.6)

-- Title with PVP icon
local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("CENTER", header, "CENTER", 0, 0)
title:SetText("|cffff8800PVPWhen|r")

-- Close button (X)
local closeBtn = CreateFrame("Button", nil, panel)
closeBtn:SetWidth(20)
closeBtn:SetHeight(20)
closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
closeBtn:SetScript("OnClick", function()
    panel:ForceHide()
end)

-- Section label helper
local function CreateSectionLabel(parent, text, y)
    local bg = CreateFrame("Frame", nil, parent)
    bg:SetWidth(220)
    bg:SetHeight(18)
    bg:SetPoint("TOP", parent, "TOP", 0, y)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    })
    bg:SetBackdropColor(0.2, 0.15, 0.35, 0.7)

    local label = bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", bg, "LEFT", 8, 0)
    label:SetText("|cffffff00" .. text .. "|r")
    return bg
end

-- Separator line helper
local function CreateSeparator(parent, y)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetWidth(210)
    sep:SetHeight(1)
    sep:SetPoint("TOP", parent, "TOP", 0, y)
    sep:SetTexture(0.4, 0.4, 0.5, 0.5)
    return sep
end

-- Styled checkbox helper
local function MakeCheckbox(parent, text, y)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetWidth(24)
    cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)

    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")

    local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbText:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    cbText:SetText("|cffffffff" .. text .. "|r")

    return cb
end

-- Battlegrounds section
CreateSectionLabel(panel, "Battlegrounds", -36)

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

CreateBGCheckbox(panel, "Warsong Gulch", "wsg", -58)
CreateBGCheckbox(panel, "Arathi Basin", "ab", -84)
CreateBGCheckbox(panel, "Alterac Valley", "av", -110)
CreateBGCheckbox(panel, "Thorn Gorge", "tg", -136)

-- Arenas section
CreateSeparator(panel, -166)
CreateSectionLabel(panel, "Arenas", -170)

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

CreateArenaCheckbox(panel, "Skirmish", "skirmish", -192)

-- Buttons
CreateSeparator(panel, -222)

local queueBtn = CreateFrame("Button", nil, panel)
queueBtn:SetWidth(140)
queueBtn:SetHeight(28)
queueBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 48)
queueBtn:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
queueBtn:SetBackdropColor(0.1, 0.4, 0.1, 0.8)
queueBtn:SetBackdropBorderColor(0.3, 0.7, 0.3, 0.8)

local queueBtnText = queueBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
queueBtnText:SetPoint("CENTER", queueBtn, "CENTER", 0, 0)
queueBtnText:SetText("|cffffffffQueue All|r")

queueBtn:SetScript("OnEnter", function()
    queueBtn:SetBackdropColor(0.15, 0.5, 0.15, 1.0)
end)
queueBtn:SetScript("OnLeave", function()
    queueBtn:SetBackdropColor(0.1, 0.4, 0.1, 0.8)
end)
queueBtn:SetScript("OnClick", function()
    QueueAll()
end)

local groupBtn = CreateFrame("Button", nil, panel)
groupBtn:SetWidth(140)
groupBtn:SetHeight(28)
groupBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 16)
groupBtn:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
groupBtn:SetBackdropColor(0.1, 0.1, 0.4, 0.8)
groupBtn:SetBackdropBorderColor(0.3, 0.3, 0.7, 0.8)

local groupBtnText = groupBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groupBtnText:SetPoint("CENTER", groupBtn, "CENTER", 0, 0)
groupBtnText:SetText("|cffffffffGroup Queue|r")

groupBtn:SetScript("OnEnter", function()
    groupBtn:SetBackdropColor(0.15, 0.15, 0.5, 1.0)
end)
groupBtn:SetScript("OnLeave", function()
    groupBtn:SetBackdropColor(0.1, 0.1, 0.4, 0.8)
end)
groupBtn:SetScript("OnClick", function()
    QueueAll(true)
end)


--====================================================
-- Minimap icon
--====================================================
if not PVPWhenDB.minimap then
    PVPWhenDB.minimap = { angle = 200 }
end

local minimapBtn = CreateFrame("Button", "PVPWhenMinimapButton", Minimap)
minimapBtn:SetWidth(32)
minimapBtn:SetHeight(32)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:EnableMouse(true)
minimapBtn:SetMovable(true)
minimapBtn:RegisterForDrag("RightButton")
minimapBtn:RegisterForClicks("LeftButtonUp")

-- Properties that minimap bag addons look for
minimapBtn.icon = minimapBtn:CreateTexture(nil, "BACKGROUND")
minimapBtn.icon:SetWidth(20)
minimapBtn.icon:SetHeight(20)
minimapBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
minimapBtn.icon:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)

local overlay = minimapBtn:CreateTexture(nil, "OVERLAY")
overlay:SetWidth(52)
overlay:SetHeight(52)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 0, 0)

-- Compatibility for minimap bag addons
minimapBtn.GetIcon = function() return "Interface\\Icons\\INV_Misc_QuestionMark" end

UpdateMinimapPosition = function()
    if not PVPWhenDB.minimap then PVPWhenDB.minimap = { angle = 200 } end
    local angle = math.rad(PVPWhenDB.minimap.angle or 200)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local isDragging = false
minimapBtn:SetScript("OnDragStart", function()
    isDragging = true
end)

minimapBtn:SetScript("OnDragStop", function()
    isDragging = false
end)

minimapBtn:SetScript("OnUpdate", function()
    if not isDragging then return end
    if not PVPWhenDB.minimap then PVPWhenDB.minimap = { angle = 200 } end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx = cx / scale
    cy = cy / scale
    PVPWhenDB.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
    UpdateMinimapPosition()
end)

minimapBtn:SetScript("OnClick", function()
    if panel:IsShown() then
        panel:ForceHide()
    else
        panel:ForceShow()
    end
end)

minimapBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(minimapBtn, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cffff8800PVPWhen|r")
    GameTooltip:AddLine("|cffffffffClick:|r Toggle settings")
    GameTooltip:AddLine("|cffffffffRight-drag:|r Move icon")
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

UpdateMinimapPosition()

-- Slash commands
SLASH_PVPWHEN1 = "/pvpwhen"
SlashCmdList["PVPWHEN"] = function()
    if panel:IsShown() then
        panel:ForceHide()
    else
        panel:ForceShow()
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
