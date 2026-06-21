-- ============================================================================
-- BotManagerUI_Editor.lua
-- ============================================================================
-- Premium Double-Pane Template Editor and Categories Upgrade Window for WotLK.
-- Aligns perfectly to the right of the main frame and offers Drag-and-Drop slots.
-- Modified: Dynamic Docking, Draggability, and Stats Panel Toggle integration.
-- ============================================================================

BotManagerEditorFrame = CreateFrame("Frame", "BotManagerEditorFrame", UIParent)
local frame = BotManagerEditorFrame
frame:Hide()
tinsert(UISpecialFrames, "BotManagerEditorFrame")
local EDITOR_MIN_WIDTH = 620
local EDITOR_MIN_HEIGHT = 460
local EDITOR_MAX_WIDTH = 900
local EDITOR_MAX_HEIGHT = 800

frame:SetSize(EDITOR_MIN_WIDTH, EDITOR_MIN_HEIGHT)
frame:SetResizable(true)
frame:SetMinResize(EDITOR_MIN_WIDTH, EDITOR_MIN_HEIGHT)
frame:SetMaxResize(EDITOR_MAX_WIDTH, EDITOR_MAX_HEIGHT)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)

-- Make it draggable/movable independently and highly responsive
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")

local DockToParentFrame

local function PinEditorToScreenPosition()
    local left = frame:GetLeft() or 0
    local top = frame:GetTop() or 0
    local width = frame:GetWidth() or EDITOR_MIN_WIDTH
    local height = frame:GetHeight() or EDITOR_MIN_HEIGHT

    frame:ClearAllPoints()
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

frame:SetScript("OnDragStart", function(self)
    PinEditorToScreenPosition()
    self:StartMoving()
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.hasBeenMoved = true
    if BotManager_DockStatsPanel then
        BotManager_DockStatsPanel()
    end
end)

local function SyncHeightToParent()
    if BotManagerFrame and not frame.hasBeenResized and not frame.isUserSizing then
        frame:SetHeight(math.max(EDITOR_MIN_HEIGHT, math.min(EDITOR_MAX_HEIGHT, BotManagerFrame:GetHeight() or EDITOR_MIN_HEIGHT)))
    end
end

-- Docking Helper
DockToParentFrame = function()
    if frame.hasBeenMoved then return end

    frame:ClearAllPoints()
    if BotManagerFrame then
        SyncHeightToParent()
        frame:SetPoint("TOPLEFT", BotManagerFrame, "TOPRIGHT", 10, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end
end

BotManager_DockEditorFrame = DockToParentFrame

local parentSizeHooked = false
local function HookParentSizing()
    if parentSizeHooked or not BotManagerFrame then return end
    parentSizeHooked = true
    BotManagerFrame:HookScript("OnSizeChanged", function()
        if frame:IsShown() and not frame.hasBeenResized and not frame.isUserSizing then
            SyncHeightToParent()
        end
        if frame:IsShown() and not frame.hasBeenMoved then
            DockToParentFrame()
        end
        if BotManager_DockStatsPanel then
            BotManager_DockStatsPanel()
        end
    end)
end

-- Match the main Bot Manager dialog frame.
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
frame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)

-- Close Button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

-- Resize Grip
local resizeGrip = CreateFrame("Button", nil, frame)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeGrip:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

local function StopEditorResize()
    if not frame.isUserSizing then return end
    frame:StopMovingOrSizing()
    frame.isUserSizing = false
    if frame.RefreshAll then
        frame:RefreshAll()
    end
end

local resizeWatcher = CreateFrame("Frame", nil, frame)
resizeWatcher:SetScript("OnUpdate", function()
    if frame.isUserSizing and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        StopEditorResize()
    end
end)

resizeGrip:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    frame.hasBeenResized = true
    frame.isUserSizing = true
    PinEditorToScreenPosition()
    frame:StartSizing("BOTTOMRIGHT")
end)
resizeGrip:SetScript("OnMouseUp", StopEditorResize)
frame:HookScript("OnHide", StopEditorResize)
frame:HookScript("OnHide", function()
    if BotManager_DockStatsPanel then
        BotManager_DockStatsPanel()
    end
end)

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -15)
title:SetText("T.Editor & Loot Distrib")
title:SetTextColor(0.92, 0.76, 0.36) -- Neon Amber Gold

-- ----------------------------------------------------------------------------
-- PERSISTENCE HOOK
-- ----------------------------------------------------------------------------
local categoriesDB = {}
local templatesDB = {}
local categoryPanels = {}
local categoryLists = {}
local TEMPLATE_SCHEMA_VERSION = 3
local TEMPLATE_DEFAULT_ROLE_KEY = "GENERAL"

local function EnsureTemplateDatabase()
    BotInventoryDB = BotInventoryDB or {}
    if BotInventoryDB.schemaVersion ~= TEMPLATE_SCHEMA_VERSION then
        BotInventoryDB.schemaVersion = TEMPLATE_SCHEMA_VERSION
        BotInventoryDB.classRoleTemplates = {}
        BotInventoryDB.classTemplates = nil
        BotInventoryDB.templates = nil
    else
        BotInventoryDB.classRoleTemplates = BotInventoryDB.classRoleTemplates or {}
        BotInventoryDB.classTemplates = nil
        BotInventoryDB.templates = nil
    end
    return BotInventoryDB.classRoleTemplates
end

local function GetSelectedBotData()
    local mainFrame = BotManagerFrame
    local db = BotManager_GetDb and BotManager_GetDb()
    local selectedBot = mainFrame and mainFrame.selectedBot
    return selectedBot, db and selectedBot and db[selectedBot]
end

local function GetActiveTemplatesDB(create)
    local _, botData = GetSelectedBotData()
    if BotManager_GetTemplateBucketForBot then
        return BotManager_GetTemplateBucketForBot(botData, create)
    end

    local className = botData and botData.className
    if not className then return nil end
    local classRoleTemplates = EnsureTemplateDatabase()
    if create and not classRoleTemplates[className] then
        classRoleTemplates[className] = {}
    end
    local classTemplates = classRoleTemplates[className]
    if not classTemplates then return nil end

    local roleKey = TEMPLATE_DEFAULT_ROLE_KEY
    if BotManager_GetTemplateRoleKeyForBot then
        roleKey = BotManager_GetTemplateRoleKeyForBot(botData) or roleKey
    elseif BotManager_GetBotRoleCategory then
        roleKey = BotManager_GetBotRoleCategory(botData) or roleKey
    end

    if create and not classTemplates[roleKey] then
        classTemplates[roleKey] = {}
    end
    return classTemplates[roleKey]
end

local function GetTemplateItemID(templateData, slotKey)
    if BotManager_GetTemplateItemID then
        return BotManager_GetTemplateItemID(templateData, slotKey)
    end
    local state = templateData and templateData[slotKey]
    return type(state) == "table" and tonumber(state.id) or 0
end

local function SetTemplateSlotRecord(templateData, slotKey, itemID, itemLink)
    if BotManager_SetTemplateSlot then
        BotManager_SetTemplateSlot(templateData, slotKey, itemID, itemLink)
    elseif type(templateData) == "table" then
        templateData[slotKey] = { id = itemID, enchant = 0, gems = { 0, 0, 0, 0 }, link = itemLink }
    end
end

local function GetTemplateSlotKeys()
    return BotManager_TemplateSlotKeys or {"HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2", "MAINHAND", "OFFHAND", "RANGED"}
end

local CATEGORY_SCHEMA_VERSION = 2
local CATEGORY_ORDER = {"TANK", "HEALER", "MELEE_DPS", "RANGED_DPS", "CASTER_DPS", "UTILITY"}

local function EnsureCategoriesDatabase()
    BotInventoryDB = BotInventoryDB or {}
    if BotInventoryDB.categorySchemaVersion ~= CATEGORY_SCHEMA_VERSION then
        BotInventoryDB.categorySchemaVersion = CATEGORY_SCHEMA_VERSION
        BotInventoryDB.categories = {}
    else
        BotInventoryDB.categories = BotInventoryDB.categories or {}
    end

    local validKeys = {}
    for _, key in ipairs(CATEGORY_ORDER) do
        validKeys[key] = true
        BotInventoryDB.categories[key] = BotInventoryDB.categories[key] or {}
    end

    for key in pairs(BotInventoryDB.categories) do
        if not validKeys[key] then
            BotInventoryDB.categories[key] = nil
        end
    end

    return BotInventoryDB.categories
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        BotInventoryDB = BotInventoryDB or {}
        EnsureTemplateDatabase()
        EnsureCategoriesDatabase()
        
        categoriesDB = BotInventoryDB.categories
        templatesDB = GetActiveTemplatesDB(false)
        
        -- FIX: Prevent premature UI draws before frames finish instantiating
        if categoryLists and categoryLists.TANK then
            frame:RefreshAll()
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        frame:RefreshAll()
    end
end)

-- ----------------------------------------------------------------------------
-- CATEGORY DATA & DEFINITIONS
-- ----------------------------------------------------------------------------
local Categories = {
    TANK = {
        name = "Tank",
        scoreRoles = 1,
        color = "|cffc79c6e"
    },
    HEALER = {
        name = "Healer",
        scoreRoles = 8,
        color = "|cffff7d0a"
    },
    MELEE_DPS = {
        name = "Melee DPS",
        scoreRoles = 4,
        color = "|cfffff468"
    },
    RANGED_DPS = {
        name = "Ranged DPS",
        scoreRoles = 20,
        color = "|cffaad372"
    },
    CASTER_DPS = {
        name = "Caster DPS",
        scoreRoles = 20,
        color = "|cff3fc7eb"
    },
    UTILITY = {
        name = "Any / Utility",
        scoreRoles = nil,
        color = "|cffffffff"
    }
}

local function GetCategoryDisplayName(categoryKey)
    return (Categories[categoryKey] and Categories[categoryKey].name) or categoryKey or "Unknown"
end

local function GetItemColorCode(itemRarity)
    if not itemRarity then return "|cffffffff" end

    local quality = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemRarity]
    if quality and quality.hex then
        if string.sub(quality.hex, 1, 2) == "|c" then
            return quality.hex
        end
        return "|c" .. quality.hex
    end

    local r, g, b, hex = GetItemQualityColor(itemRarity)
    if hex then
        if string.sub(hex, 1, 2) == "|c" then
            return hex
        end
        return "|c" .. hex
    end

    r = math.floor((r or 1) * 255 + 0.5)
    g = math.floor((g or 1) * 255 + 0.5)
    b = math.floor((b or 1) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

local function FormatScoreValue(value)
    value = tonumber(value) or 0
    return tostring(math.floor(value + 0.5))
end

local CasterDpsClasses = {
    ["Mage"] = true, ["Warlock"] = true, ["Priest"] = true,
    ["Druid"] = true, ["Shaman"] = true, ["Necromancer"] = true,
    ["Archmage"] = true, ["Sea Witch"] = true, ["Sphynx"] = true
}

local PhysicalRangedClasses = {
    ["Hunter"] = true,
    ["Dark Ranger"] = true
}

local ROLE_TANK = 1
local ROLE_TANK_OFF = 2
local ROLE_DPS = 4
local ROLE_HEAL = 8
local ROLE_RANGED = 16

local SpecRoleCategory = {
    [1] = "MELEE_DPS", [2] = "MELEE_DPS", [3] = "TANK",
    [4] = "HEALER", [5] = "TANK", [6] = "MELEE_DPS",
    [7] = "RANGED_DPS", [8] = "RANGED_DPS", [9] = "RANGED_DPS",
    [10] = "MELEE_DPS", [11] = "MELEE_DPS", [12] = "MELEE_DPS",
    [13] = "HEALER", [14] = "HEALER", [15] = "CASTER_DPS",
    [19] = "CASTER_DPS", [20] = "MELEE_DPS", [21] = "HEALER",
    [22] = "CASTER_DPS", [23] = "CASTER_DPS", [24] = "CASTER_DPS",
    [25] = "CASTER_DPS", [26] = "CASTER_DPS", [27] = "CASTER_DPS",
    [28] = "CASTER_DPS", [30] = "HEALER"
}

local RoleSensitiveTankSpecs = {
    [16] = true, [17] = true, [18] = true,
    [29] = true
}

local function GetRoleFlags(botData)
    local roles = botData and botData.roles or 0
    local isTank = bit.band(roles, ROLE_TANK) > 0 or bit.band(roles, ROLE_TANK_OFF) > 0
    local isHealer = bit.band(roles, ROLE_HEAL) > 0
    local isRanged = bit.band(roles, ROLE_RANGED) > 0
    local isDPS = bit.band(roles, ROLE_DPS) > 0

    if not isTank and not isHealer and not isRanged and not isDPS then
        isDPS = true
    end

    return isTank, isHealer, isRanged, isDPS
end

local function GetFallbackRoleCategory(botData)
    local className = botData and botData.className
    local isTank, isHealer, isRanged, isDPS = GetRoleFlags(botData)
    if isTank then return "TANK" end
    if isHealer then return "HEALER" end
    if not isDPS then return nil end

    if PhysicalRangedClasses[className] then
        return "RANGED_DPS"
    elseif isRanged and CasterDpsClasses[className] then
        return "CASTER_DPS"
    elseif isRanged then
        return "RANGED_DPS"
    elseif CasterDpsClasses[className] and className ~= "Druid" and className ~= "Shaman" then
        return "CASTER_DPS"
    end

    return "MELEE_DPS"
end

local function GetResolvedRoleCategory(botData)
    if BotManager_GetBotRoleCategory then
        return BotManager_GetBotRoleCategory(botData)
    end

    local spec = botData and tonumber(botData.spec) or 0
    if RoleSensitiveTankSpecs[spec] then
        local isTank = GetRoleFlags(botData)
        if isTank then return "TANK" end
        return "MELEE_DPS"
    end

    if SpecRoleCategory[spec] then
        return SpecRoleCategory[spec]
    end

    return GetFallbackRoleCategory(botData)
end

local function BotFitsCategory(botData, categoryKey)
    if not botData then return false end
    local className = botData.className
    if not className then return false end

    if categoryKey == "UTILITY" then
        return true
    end
    
    return GetResolvedRoleCategory(botData) == categoryKey
end

local function GetBotMaxArmorSubclass(className)
    local prof = BotManager_ArmorProficiency and BotManager_ArmorProficiency[className]
    if not prof then return 1 end -- Cloth default
    if prof[4] then return 4 end -- Plate
    if prof[3] then return 3 end -- Mail
    if prof[2] then return 2 end -- Leather
    return 1 -- Cloth
end

local function GetCompatibleBotsCount(categoryKey)
    local db = BotManager_GetDb and BotManager_GetDb()
    if not db then return 0 end
    
    local count = 0
    for entry, info in pairs(db) do
        if type(info) == "table" and info.name then
            if BotFitsCategory(info, categoryKey) then
                count = count + 1
            end
        end
    end
    return count
end

-- Equipment Locations Slot Mappings
local EquipLocToSlot = {
    INVTYPE_HEAD = "HEAD", INVTYPE_NECK = "NECK", INVTYPE_SHOULDER = "SHOULDER",
    INVTYPE_CLOAK = "BACK", INVTYPE_CHEST = "CHEST", INVTYPE_ROBE = "CHEST",
    INVTYPE_WRIST = "WRIST", INVTYPE_HAND = "HANDS", INVTYPE_WAIST = "WAIST",
    INVTYPE_LEGS = "LEGS", INVTYPE_FEET = "FEET", INVTYPE_FINGER = "FINGER1",
    INVTYPE_TRINKET = "TRINKET1", INVTYPE_WEAPONMAINHAND = "MAINHAND", INVTYPE_2HWEAPON = "MAINHAND",
    INVTYPE_WEAPONOFFHAND = "OFFHAND", INVTYPE_SHIELD = "OFFHAND", INVTYPE_HOLDABLE = "OFFHAND",
    INVTYPE_RANGED = "RANGED", INVTYPE_THROWN = "RANGED", INVTYPE_RANGEDRIGHT = "RANGED", INVTYPE_RELIC = "RANGED",
    INVTYPE_WEAPON = "MAINHAND"
}

local SlotDisplayNames = {
    HEAD = "Head", NECK = "Neck", SHOULDER = "Shoulder", BACK = "Back",
    CHEST = "Chest", WRIST = "Wrist", HANDS = "Hands", WAIST = "Waist",
    LEGS = "Legs", FEET = "Feet", FINGER1 = "Ring 1", FINGER2 = "Ring 2",
    TRINKET1 = "Trinket 1", TRINKET2 = "Trinket 2",
    MAINHAND = "Main Hand", OFFHAND = "Off Hand", RANGED = "Ranged"
}

-- ----------------------------------------------------------------------------
-- TAB CONTROL SYSTEM
-- ----------------------------------------------------------------------------
local activeTab = "TEMPLATE"
local TemplateTabFrame = CreateFrame("Frame", nil, frame)
local CategoriesTabFrame = CreateFrame("Frame", nil, frame)

TemplateTabFrame:SetAllPoints()
CategoriesTabFrame:SetAllPoints()

local tabButtons = {}

local function SetTab(tabName)
    activeTab = tabName
    if tabName == "TEMPLATE" then
        TemplateTabFrame:Show()
        CategoriesTabFrame:Hide()
        tabButtons.template:SetBackdropBorderColor(0.92, 0.76, 0.36, 1.0)
        tabButtons.template.text:SetTextColor(0.92, 0.76, 0.36)
        tabButtons.categories:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
        tabButtons.categories.text:SetTextColor(0.6, 0.6, 0.6)
    else
        TemplateTabFrame:Hide()
        CategoriesTabFrame:Show()
        tabButtons.categories:SetBackdropBorderColor(0.92, 0.76, 0.36, 1.0)
        tabButtons.categories.text:SetTextColor(0.92, 0.76, 0.36)
        tabButtons.template:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
        tabButtons.template.text:SetTextColor(0.6, 0.6, 0.6)
    end
    if categoryLists and categoryLists.TANK then
        frame:RefreshAll()
    end
end

-- Create tab toggle frames
local function CreateTabButton(name, label, xOffset, targetTab, width)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(width or 110, 22)
    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset, -15)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    btn:SetBackdropColor(0.1, 0.1, 0.15, 0.8)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
    
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
    txt:SetText(label)
    btn.text = txt
    
    btn:SetScript("OnEnter", function()
        if activeTab ~= targetTab then
            btn:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.8)
        end
    end)
    btn:SetScript("OnLeave", function()
        if activeTab ~= targetTab then
            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
        end
    end)
    btn:SetScript("OnClick", function() SetTab(targetTab) end)
    
    tabButtons[name] = btn
end

CreateTabButton("template", "Templates", 180, "TEMPLATE")
CreateTabButton("categories", "Loot Distribution", 295, "CATEGORIES", 140)

-- ----------------------------------------------------------------------------
-- TAB 1: TEMPLATE EDITOR IMPLEMENTATION
-- ----------------------------------------------------------------------------
local LeftPanel = CreateFrame("Frame", nil, TemplateTabFrame)
LeftPanel:SetWidth(130)
LeftPanel:SetPoint("TOPLEFT", TemplateTabFrame, "TOPLEFT", 10, -50)
LeftPanel:SetPoint("BOTTOMLEFT", TemplateTabFrame, "BOTTOMLEFT", 10, 15)
LeftPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 12, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
LeftPanel:SetBackdropColor(0.02, 0.02, 0.03, 0.5)
LeftPanel:SetBackdropBorderColor(0.65, 0.52, 0.22, 0.3)

-- Template List Scroll
local ScrollFrame = CreateFrame("ScrollFrame", "BME_TemplatesScrollFrame", LeftPanel, "UIPanelScrollFrameTemplate")
ScrollFrame:SetPoint("TOPLEFT", LeftPanel, "TOPLEFT", 5, -5)
ScrollFrame:SetPoint("BOTTOMRIGHT", LeftPanel, "BOTTOMRIGHT", -25, 60)

local ScrollContent = CreateFrame("Frame", nil, ScrollFrame)
ScrollContent:SetSize(100, 320)
ScrollFrame:SetScrollChild(ScrollContent)

local selectedTemplate = nil
local templateButtons = {}

local function RefreshTemplateList()
    templatesDB = GetActiveTemplatesDB(false)
    local children = { ScrollContent:GetChildren() }
    for _, child in ipairs(children) do child:Hide() end
    
    local sortedNames = {}
    if templatesDB then
        for name in pairs(templatesDB) do
            table.insert(sortedNames, name)
        end
    end
    table.sort(sortedNames)

    if selectedTemplate and (not templatesDB or not templatesDB[selectedTemplate]) then
        selectedTemplate = nil
    end
    
    for i, name in ipairs(sortedNames) do
        local btn = templateButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, ScrollContent)
            btn:SetSize(95, 20)
            btn:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 8, edgeSize = 8,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            
            local btnTxt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnTxt:SetPoint("LEFT", btn, "LEFT", 5, 0)
            btn.text = btnTxt
            
            templateButtons[i] = btn
        end
        
        btn:SetPoint("TOPLEFT", ScrollContent, "TOPLEFT", 2, -(i - 1) * 22)
        btn:Show()
        btn.text:SetText(name)
        
        if selectedTemplate == name then
            btn:SetBackdropColor(0.65, 0.52, 0.22, 0.6)
            btn:SetBackdropBorderColor(0.65, 0.52, 0.22, 1.0)
        else
            btn:SetBackdropColor(0.1, 0.1, 0.12, 0.4)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.3)
        end
        
        btn:SetScript("OnClick", function()
            selectedTemplate = name
            RefreshTemplateList()
            frame:RefreshPaperdoll()
        end)
    end

    ScrollContent:SetHeight(math.max(1, #sortedNames * 22 + 4))
end

-- New Template Input
local editBox = CreateFrame("EditBox", "BME_NewTemplateEditBox", LeftPanel, "InputBoxTemplate")
editBox:SetSize(80, 20)
editBox:SetPoint("BOTTOMLEFT", LeftPanel, "BOTTOMLEFT", 10, 32)
editBox:SetAutoFocus(false)

local addBtn = CreateFrame("Button", nil, LeftPanel, "UIPanelButtonTemplate")
addBtn:SetSize(22, 20)
addBtn:SetPoint("LEFT", editBox, "RIGHT", 5, 0)
addBtn:SetText("+")
addBtn:SetScript("OnClick", function()
    local name = editBox:GetText()
    if name and name ~= "" then
        templatesDB = GetActiveTemplatesDB(true)
        if templatesDB then
            if not templatesDB[name] then
                templatesDB[name] = {}
                editBox:SetText("")
                editBox:ClearFocus()
                selectedTemplate = name
                RefreshTemplateList()
                frame:RefreshPaperdoll()
                print("|cff00ff00BotManager:|r Created template '" .. name .. "'.")
            else
                print("|cffff0000BotManager:|r Template already exists!")
            end
        else
            print("|cffff0000BotManager:|r Select a bot in the main UI before creating a class/role template.")
        end
    end
end)

-- Delete Button
local deleteBtn = CreateFrame("Button", nil, LeftPanel, "UIPanelButtonTemplate")
deleteBtn:SetSize(110, 18)
deleteBtn:SetPoint("BOTTOMLEFT", LeftPanel, "BOTTOMLEFT", 8, 8)
deleteBtn:SetText("Delete Selected")
deleteBtn:SetScript("OnClick", function()
    if selectedTemplate then
        templatesDB = GetActiveTemplatesDB(false)
        if templatesDB then
            templatesDB[selectedTemplate] = nil
            print("|cff00ff00BotManager:|r Deleted template '" .. selectedTemplate .. "'.")
            selectedTemplate = nil
            RefreshTemplateList()
            frame:RefreshPaperdoll()
        end
    else
        print("|cffff0000BotManager:|r Select a template first.")
    end
end)


-- Right Side: The Paperdoll Editor Frame
local PaperdollPanel = CreateFrame("Frame", nil, TemplateTabFrame)
PaperdollPanel:SetPoint("TOPLEFT", LeftPanel, "TOPRIGHT", 10, 0)
PaperdollPanel:SetPoint("TOPRIGHT", TemplateTabFrame, "TOPRIGHT", -10, -50)
PaperdollPanel:SetPoint("BOTTOMRIGHT", TemplateTabFrame, "BOTTOMRIGHT", -10, 15)
PaperdollPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 12, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
PaperdollPanel:SetBackdropColor(0.02, 0.02, 0.03, 0.4)
PaperdollPanel:SetBackdropBorderColor(0.65, 0.52, 0.22, 0.3)

-- Paperdoll slots grid configuration
local slotLayout = {
    -- Left side slots
    { key = "HEAD", side = "LEFT", index = 1, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Head" },
    { key = "NECK", side = "LEFT", index = 2, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Neck" },
    { key = "SHOULDER", side = "LEFT", index = 3, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Shoulder" },
    { key = "BACK", side = "LEFT", index = 4, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Chest" }, -- Cloak
    { key = "CHEST", side = "LEFT", index = 5, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Chest" },
    { key = "SHIRT", side = "LEFT", index = 6, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Shirt", isFake = true },
    { key = "TABARD", side = "LEFT", index = 7, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Tabard", isFake = true },
    { key = "WRIST", side = "LEFT", index = 8, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Wrists" },

    -- Right side slots
    { key = "HANDS", side = "RIGHT", index = 1, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Hands" },
    { key = "WAIST", side = "RIGHT", index = 2, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Waist" },
    { key = "LEGS", side = "RIGHT", index = 3, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Legs" },
    { key = "FEET", side = "RIGHT", index = 4, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Feet" },
    { key = "FINGER1", side = "RIGHT", index = 5, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Finger" },
    { key = "FINGER2", side = "RIGHT", index = 6, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Finger" },
    { key = "TRINKET1", side = "RIGHT", index = 7, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Trinket" },
    { key = "TRINKET2", side = "RIGHT", index = 8, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Trinket" },

    -- Bottom slots
    { key = "MAINHAND", side = "BOTTOM", offset = -45, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-MainHand" },
    { key = "OFFHAND", side = "BOTTOM", offset = 0, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-SecondaryHand" },
    { key = "RANGED", side = "BOTTOM", offset = 45, texture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Ranged" }
}

local slotButtons = {}

local function CreatePaperdollSlot(data)
    local key = data.key
    local btn = CreateFrame("Button", "BME_Slot_" .. key, PaperdollPanel, "ItemButtonTemplate")
    btn:SetSize(34, 34)
    btn.emptyTexture = data.texture
    btn.isFake = data.isFake
    
    btn.icon = _G[btn:GetName() .. "IconTexture"]
    btn.icon:SetTexture(btn.emptyTexture)
    
    -- Glow border for rarity
    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetSize(56, 56)
    glow:SetPoint("CENTER", btn, "CENTER", 0, 0)
    glow:Hide()
    btn.rarityGlow = glow
    
    if data.side == "LEFT" then
        btn:SetPoint("TOPLEFT", PaperdollPanel, "TOPLEFT", 15, -15 - (data.index - 1) * 38)
    elseif data.side == "RIGHT" then
        btn:SetPoint("TOPRIGHT", PaperdollPanel, "TOPRIGHT", -15, -15 - (data.index - 1) * 38)
    elseif data.side == "BOTTOM" then
        btn:SetPoint("BOTTOM", PaperdollPanel, "BOTTOM", data.offset, 45)
    end
    
    -- Drag and drop logic
    if not btn.isFake then
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        btn:SetScript("OnReceiveDrag", function()
            if not selectedTemplate then
                print("|cffff0000BotManager:|r Select or create a template first!")
                return
            end
            local infoType, itemID, itemLink = GetCursorInfo()
            if infoType == "item" then
                ClearCursor()
                templatesDB = GetActiveTemplatesDB(true)
                if not templatesDB or not templatesDB[selectedTemplate] then return end
                SetTemplateSlotRecord(templatesDB[selectedTemplate], key, itemID, itemLink)
                frame:RefreshPaperdoll()
                print("|cff00ff00BotManager:|r Assigned item to template slot " .. key .. ".")
            end
        end)
        
        btn:SetScript("OnClick", function(self, button)
            if not selectedTemplate then return end
            templatesDB = GetActiveTemplatesDB(false)
            if not templatesDB or not templatesDB[selectedTemplate] then return end
            if button == "RightButton" then
                if GetTemplateItemID(templatesDB[selectedTemplate], key) > 0 then
                    templatesDB[selectedTemplate][key] = nil
                    frame:RefreshPaperdoll()
                    print("|cff00ff00BotManager:|r Cleared template slot " .. key .. ".")
                end
            else
                -- Clicked: if cursor has item, drop it
                local infoType, itemID, itemLink = GetCursorInfo()
                if infoType == "item" then
                    ClearCursor()
                    SetTemplateSlotRecord(templatesDB[selectedTemplate], key, itemID, itemLink)
                    frame:RefreshPaperdoll()
                    print("|cff00ff00BotManager:|r Assigned item to template slot " .. key .. ".")
                end
            end
        end)
        
        btn:SetScript("OnEnter", function(self)
            if not selectedTemplate then return end
            templatesDB = GetActiveTemplatesDB(false)
            local itemID = templatesDB and templatesDB[selectedTemplate] and GetTemplateItemID(templatesDB[selectedTemplate], key) or 0
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if itemID and itemID > 0 then
                GameTooltip:SetHyperlink("item:" .. itemID)
            else
                GameTooltip:SetText(key .. "\n(Drag item here to slot)")
            end
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        btn:Disable()
        btn:SetAlpha(0.3)
    end
    
    slotButtons[key] = btn
end

-- Build all paperdoll slot buttons
for _, data in ipairs(slotLayout) do
    CreatePaperdollSlot(data)
end

function frame:RefreshPaperdoll()
    -- Render template title inside panel
    if not PaperdollPanel.titleText then
        PaperdollPanel.titleText = PaperdollPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        PaperdollPanel.titleText:SetPoint("TOP", PaperdollPanel, "TOP", 0, -10)
    end
    
    if selectedTemplate then
        PaperdollPanel.titleText:SetText("|cffffd700Template: " .. selectedTemplate .. "|r")
    else
        PaperdollPanel.titleText:SetText("|cff808080No Template Selected|r")
    end

    for key, btn in pairs(slotButtons) do
        if btn.isFake then
            -- Leave fake slots visually empty
        else
            templatesDB = GetActiveTemplatesDB(false)
            local itemID = selectedTemplate and templatesDB and templatesDB[selectedTemplate] and GetTemplateItemID(templatesDB[selectedTemplate], key) or 0
            if itemID > 0 then
                local itemName, _, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
                if itemTexture then
                    btn.icon:SetTexture(itemTexture)
                else
                    btn.icon:SetTexture(btn.emptyTexture)
                end
                
                if itemRarity and itemRarity > 1 then
                    local r, g, b = GetItemQualityColor(itemRarity)
                    btn.rarityGlow:SetVertexColor(r, g, b)
                    btn.rarityGlow:Show()
                else
                    btn.rarityGlow:Hide()
                end
            else
                btn.icon:SetTexture(btn.emptyTexture)
                btn.rarityGlow:Hide()
            end
        end
    end
end

-- Update Selected Template From Bot Button
local updateTemplateBtn = CreateFrame("Button", nil, PaperdollPanel, "UIPanelButtonTemplate")
updateTemplateBtn:SetSize(130, 24)
updateTemplateBtn:SetPoint("BOTTOM", PaperdollPanel, "BOTTOM", -65, 10)
updateTemplateBtn:SetText("Update From Bot")
updateTemplateBtn:SetScript("OnClick", function()
    if not selectedTemplate then
        print("|cffff0000BotManager:|r No template selected!")
        return
    end

    local selectedBot, botData = GetSelectedBotData()
    if not selectedBot or not botData then
        print("|cffff0000BotManager:|r Select a bot in the main UI before updating a template.")
        return
    end
    
    templatesDB = GetActiveTemplatesDB(false)
    local t = templatesDB and templatesDB[selectedTemplate]
    if not t then
        print("|cffff0000BotManager:|r Template '" .. selectedTemplate .. "' is not available for " .. (botData.className or "this bot") .. ".")
        return
    end

    for key in pairs(t) do
        t[key] = nil
    end

    local copied = 0
    if botData.gear then
        for _, slotKey in ipairs(GetTemplateSlotKeys()) do
            local gearData = botData.gear[slotKey]
            local itemID = gearData and tonumber(gearData.id) or 0
            if itemID > 0 then
                SetTemplateSlotRecord(t, slotKey, itemID)
                copied = copied + 1
            end
        end
    end
    
    frame:RefreshPaperdoll()
    print("|cff00ff00BotManager:|r Updated template '" .. selectedTemplate .. "' from " .. (botData.name or "selected bot") .. " (" .. copied .. " slots).")
end)

-- Clear Template Slots Button
local clearTemplateBtn = CreateFrame("Button", nil, PaperdollPanel, "UIPanelButtonTemplate")
clearTemplateBtn:SetSize(110, 24)
clearTemplateBtn:SetPoint("BOTTOM", PaperdollPanel, "BOTTOM", 65, 10)
clearTemplateBtn:SetText("Clear All Slots")
clearTemplateBtn:SetScript("OnClick", function()
    templatesDB = GetActiveTemplatesDB(false)
    if selectedTemplate and templatesDB and templatesDB[selectedTemplate] then
        templatesDB[selectedTemplate] = {}
        frame:RefreshPaperdoll()
        print("|cff00ff00BotManager:|r Cleared all slots in template '" .. selectedTemplate .. "'.")
    else
        print("|cffff0000BotManager:|r Select a template first.")
    end
end)


-- ----------------------------------------------------------------------------
-- TAB 2: CATEGORIES UPGRADE SYSTEM IMPLEMENTATION
-- ----------------------------------------------------------------------------
categoryPanels = {}
categoryLists = {}
local categoryPreview = { statuses = {}, readyByCategory = {} }

local StatusColors = {
    READY = "|cff00ff00",
    MISSING = "|cffff6060",
    CACHE = "|cffffff00",
    SKIP = "|cffaaaaaa",
    NO_UPGRADE = "|cff808080",
}

local ArmorUpgradeSlots = {
    INVTYPE_HEAD = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
}

local function GetAvailableItemCount(itemID)
    if BotManager_GetItemCountInBags then
        return BotManager_GetItemCountInBags(itemID) or 0
    end
    return GetItemCount and (GetItemCount(itemID, false) or 0) or 0
end

local function GetCategoryScore(itemID, botData, categoryKey)
    if not BotManager_ScoreItemForClass then return 0, true end
    local category = Categories[categoryKey]
    local roles = category and category.scoreRoles or botData.roles or 0
    if BotManager_GetRoleMaskForCategory then
        roles = BotManager_GetRoleMaskForCategory(categoryKey) or roles
    end
    return BotManager_ScoreItemForClass(itemID, botData.className, roles, botData.spec)
end

local function GetTempGearForBot(tempGearByEntry, entry, botData)
    if tempGearByEntry[entry] then return tempGearByEntry[entry] end

    local tempGear = {}
    if botData.gear then
        for slotKey, gearData in pairs(botData.gear) do
            tempGear[slotKey] = gearData and gearData.id or 0
        end
    end
    tempGearByEntry[entry] = tempGear
    return tempGear
end

local function GetBestPairedSlot(botData, categoryKey, tempGear, firstSlot, secondSlot)
    local firstItem = tempGear[firstSlot] or 0
    local secondItem = tempGear[secondSlot] or 0
    local firstScore = firstItem > 0 and GetCategoryScore(firstItem, botData, categoryKey) or 0
    local secondScore = secondItem > 0 and GetCategoryScore(secondItem, botData, categoryKey) or 0

    if firstScore <= secondScore then
        return firstSlot, firstItem, firstScore
    end
    return secondSlot, secondItem, secondScore
end

local function GetTargetSlotForDistribution(itemEquipLoc, botData, categoryKey, tempGear)
    local targetSlot = EquipLocToSlot[itemEquipLoc]
    if not targetSlot then return nil end

    if itemEquipLoc == "INVTYPE_FINGER" then
        return GetBestPairedSlot(botData, categoryKey, tempGear, "FINGER1", "FINGER2")
    elseif itemEquipLoc == "INVTYPE_TRINKET" then
        return GetBestPairedSlot(botData, categoryKey, tempGear, "TRINKET1", "TRINKET2")
    elseif itemEquipLoc == "INVTYPE_WEAPON" then
        return GetBestPairedSlot(botData, categoryKey, tempGear, "MAINHAND", "OFFHAND")
    end

    local currentItemID = tempGear[targetSlot] or 0
    local currentScore = currentItemID > 0 and GetCategoryScore(currentItemID, botData, categoryKey) or 0
    return targetSlot, currentItemID, currentScore
end

local function CanUseItemForDistribution(botData, entry, itemID, itemType, itemSubType, itemEquipLoc, categoryKey)
    if BotManager_CanBotEquipItem then
        local canEquip, failReason = BotManager_CanBotEquipItem(botData.className, itemID, entry)
        if failReason == "CACHE" then
            return false, "CACHE"
        elseif not canEquip then
            return false, "Cannot equip"
        end
    end

    if itemType == "Armor" and ArmorUpgradeSlots[itemEquipLoc] then
        local subclassID = BotManager_ArmorSubtypeToID and BotManager_ArmorSubtypeToID[itemSubType]
        local maxSubclass = GetBotMaxArmorSubclass(botData.className)
        if subclassID and maxSubclass and subclassID ~= maxSubclass then
            return false, "Wrong armor"
        end
    end

    return true
end

local function FindBestDistributionTarget(db, categoryKey, itemID, itemType, itemSubType, itemEquipLoc, tempGearByEntry)
    local bestCandidate = nil
    local bestUpgrade = -999999
    local sawRoleMatch = false
    local sawEquipMatch = false
    local sawUsefulStats = false
    local sawCacheWait = false

    for entry, botData in pairs(db) do
        if type(entry) == "number" and type(botData) == "table" and botData.name and BotFitsCategory(botData, categoryKey) then
            sawRoleMatch = true
            local canUse, blockReason = CanUseItemForDistribution(botData, entry, itemID, itemType, itemSubType, itemEquipLoc, categoryKey)
            if blockReason == "CACHE" then
                sawCacheWait = true
            end

            if canUse then
                local tempGear = GetTempGearForBot(tempGearByEntry, entry, botData)
                local targetSlot, currentItemID, currentItemScore = GetTargetSlotForDistribution(itemEquipLoc, botData, categoryKey, tempGear)
                if targetSlot then
                    sawEquipMatch = true
                    local newScore, relevant = GetCategoryScore(itemID, botData, categoryKey)
                    local hasUsefulStats = relevant and (newScore or 0) > 0
                    if hasUsefulStats then
                        sawUsefulStats = true
                        local upgrade = newScore - (currentItemScore or 0)

                        if currentItemID ~= itemID and upgrade > 0 and upgrade > bestUpgrade then
                            bestUpgrade = upgrade
                            local roleCategory = categoryKey == "UTILITY" and GetResolvedRoleCategory(botData) or categoryKey
                            bestCandidate = {
                                entry = entry,
                                botName = botData.name,
                                slotKey = targetSlot,
                                currentItemID = currentItemID or 0,
                                currentScore = currentItemScore or 0,
                                newScore = newScore or 0,
                                upgrade = upgrade,
                                roleCategory = roleCategory,
                                reason = "Matched " .. GetCategoryDisplayName(roleCategory) .. " role/talent scoring and beats the current slot."
                            }
                        end
                    end
                end
            end
        end
    end

    if bestCandidate then return bestCandidate end
    if sawCacheWait then return nil, "CACHE" end
    if not sawRoleMatch then return nil, "No role bots" end
    if not sawEquipMatch then return nil, "Cannot equip" end
    if not sawUsefulStats then return nil, "No useful stats" end
    return nil, "No upgrade"
end

local function BuildDistributionPlan(categoryKeys)
    local db = BotManager_GetDb and BotManager_GetDb()
    local plan = {
        actions = {},
        statuses = {},
        plannedIndexes = {},
        readyByCategory = {},
    }
    if not db then return plan end

    local tempGearByEntry = {}
    local availableByItem = {}
    local consumedByItem = {}

    for _, categoryKey in ipairs(categoryKeys) do
        local items = categoriesDB and categoriesDB[categoryKey] or {}
        plan.statuses[categoryKey] = {}
        plan.plannedIndexes[categoryKey] = {}
        plan.readyByCategory[categoryKey] = 0

        for index, itemID in ipairs(items) do
            local status = { state = "SKIP", text = "Checking" }
            local itemName, itemLink, _, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemID)

            if not itemName then
                status.state = "CACHE"
                status.text = "Loading"
                status.reason = "Waiting for the client item cache before scoring."
            elseif not EquipLocToSlot[itemEquipLoc] then
                status.state = "SKIP"
                status.text = "Not gear"
                status.reason = "This item does not map to an equipment slot."
            else
                if availableByItem[itemID] == nil then
                    availableByItem[itemID] = GetAvailableItemCount(itemID)
                end

                local consumed = consumedByItem[itemID] or 0
                if availableByItem[itemID] <= consumed then
                    status.state = "MISSING"
                    status.text = "No copy"
                    status.reason = "No available copy was found in your bags for this queued item."
                else
                    local candidate, reason = FindBestDistributionTarget(db, categoryKey, itemID, itemType, itemSubType, itemEquipLoc, tempGearByEntry)
                    if candidate then
                        consumedByItem[itemID] = consumed + 1
                        local tempGear = tempGearByEntry[candidate.entry]
                        if tempGear then
                            tempGear[candidate.slotKey] = itemID
                        end

                        local upgradeText = "+" .. tostring(math.floor(candidate.upgrade + 0.5))
                        status.state = "READY"
                        status.text = candidate.botName .. " " .. upgradeText
                        status.botName = candidate.botName
                        status.slotKey = candidate.slotKey
                        status.currentItemID = candidate.currentItemID
                        status.currentScore = candidate.currentScore or 0
                        status.newScore = candidate.newScore or 0
                        status.upgrade = candidate.upgrade or 0
                        status.roleCategory = candidate.roleCategory
                        status.reason = candidate.reason
                        plan.readyByCategory[categoryKey] = plan.readyByCategory[categoryKey] + 1
                        plan.plannedIndexes[categoryKey][index] = true
                        table.insert(plan.actions, {
                            type = "EQUIP",
                            botEntry = candidate.entry,
                            botName = candidate.botName,
                            slotKey = candidate.slotKey,
                            itemID = itemID,
                            itemName = itemName
                        })
                    elseif reason == "CACHE" then
                        status.state = "CACHE"
                        status.text = "Loading"
                        status.reason = "Waiting for item or bot equipment data before scoring."
                    elseif reason == "No upgrade" then
                        status.state = "NO_UPGRADE"
                        status.text = "No upgrade"
                        status.reason = "Can be equipped, but the role/talent score is not higher than the current slot."
                    elseif reason == "No useful stats" then
                        status.state = "NO_UPGRADE"
                        status.text = "No useful stats"
                        status.reason = "No positive role/talent score was found for bots that can equip this item."
                    else
                        status.state = "SKIP"
                        status.text = reason or "Skipped"
                        status.reason = reason or "Skipped by the compatibility checks."
                    end
                end
            end

            plan.statuses[categoryKey][index] = status
        end
    end

    return plan
end

local function RemovePlannedRows(plannedIndexes)
    for _, categoryKey in ipairs(CATEGORY_ORDER) do
        local list = categoriesDB and categoriesDB[categoryKey]
        local planned = plannedIndexes and plannedIndexes[categoryKey]
        if list and planned then
            for index = #list, 1, -1 do
                if planned[index] then
                    table.remove(list, index)
                end
            end
        end
    end
end

local function AddCategoryItem(categoryKey, itemID)
    categoriesDB = EnsureCategoriesDatabase()
    if not categoriesDB[categoryKey] then categoriesDB[categoryKey] = {} end

    table.insert(categoriesDB[categoryKey], itemID)
    frame:RefreshAll()
    print("|cff00ff00BotManager:|r Added item to " .. Categories[categoryKey].name .. " queue.")
end

local function RemoveCategoryItem(categoryKey, index)
    if categoriesDB[categoryKey] then
        table.remove(categoriesDB[categoryKey], index)
        frame:RefreshAll()
        print("|cff00ff00BotManager:|r Removed item from category.")
    end
end

local function DistributeCategoryUpgrades(categoryKey)
    categoriesDB = EnsureCategoriesDatabase()
    local items = categoriesDB[categoryKey]
    if not items or #items == 0 then
        print("|cffff0000BotManager:|r Category list is empty!")
        return
    end

    local plan = BuildDistributionPlan({ categoryKey })
    categoryPreview = plan

    if #plan.actions > 0 then
        RemovePlannedRows(plan.plannedIndexes)
        frame:RefreshAll()
        print("|cff00ff00BotManager:|r Queued " .. #plan.actions .. " " .. Categories[categoryKey].name .. " upgrade(s).")
        BotManager_StartSequentialActions(plan.actions, nil, Categories[categoryKey].name, "CATEGORIES_DISTRIBUTE")
    else
        frame:RefreshAll()
        print("|cff00ff00BotManager:|r No ready upgrades found in " .. Categories[categoryKey].name .. ". Check the row statuses.")
    end
end

-- Single-category Loot Distribution view. This avoids tiny stacked lists and
-- keeps the active queue readable while the window is resized.
local selectedCategoryKey = CATEGORY_ORDER[1]
local categorySelectorButtons = {}

local function ApplyInnerBackdrop(target, alpha)
    target:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    target:SetBackdropColor(0.08, 0.08, 0.08, alpha or 0.9)
    target:SetBackdropBorderColor(0.65, 0.52, 0.22, 0.35)
end

local CategorySelectorPanel = CreateFrame("Frame", "BME_CategorySelectorPanel", CategoriesTabFrame)
CategorySelectorPanel:SetPoint("TOPLEFT", CategoriesTabFrame, "TOPLEFT", 10, -52)
CategorySelectorPanel:SetPoint("BOTTOMLEFT", CategoriesTabFrame, "BOTTOMLEFT", 10, 48)
CategorySelectorPanel:SetWidth(145)
ApplyInnerBackdrop(CategorySelectorPanel, 0.92)

local CategoryDetailPanel = CreateFrame("Frame", "BME_CategoryDetailPanel", CategoriesTabFrame)
CategoryDetailPanel:SetPoint("TOPLEFT", CategorySelectorPanel, "TOPRIGHT", 10, 0)
CategoryDetailPanel:SetPoint("BOTTOMRIGHT", CategoriesTabFrame, "BOTTOMRIGHT", -10, 48)
ApplyInnerBackdrop(CategoryDetailPanel, 0.92)

local function LayoutCategoryRow(row, rowWidth)
    if not row then return end
    rowWidth = math.max(260, rowWidth or 260)
    row:SetSize(rowWidth, 25)
    if row.delBtn then
        row.delBtn:ClearAllPoints()
        row.delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    end
    if row.statusText then
        row.statusText:ClearAllPoints()
        row.statusText:SetPoint("RIGHT", row.delBtn or row, row.delBtn and "LEFT" or "RIGHT", row.delBtn and -6 or -18, 0)
        row.statusText:SetWidth(112)
    end
    if row.text then
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", row.statusText, "LEFT", -8, 0)
    end
end

local function LayoutCategoryView()
    for _, key in ipairs(CATEGORY_ORDER) do
        local listData = categoryLists[key]
        if listData and listData.scroll and listData.content then
            local rowWidth = (listData.scroll:GetWidth() or 0) - 6
            if rowWidth < 260 then
                rowWidth = math.max(260, (CategoryDetailPanel:GetWidth() or 420) - 120)
            end
            listData.content:SetWidth(rowWidth)
            for _, row in ipairs(listData.items) do
                LayoutCategoryRow(row, rowWidth)
            end
        end
    end
end

local function SetCategorySelector(key)
    selectedCategoryKey = key or selectedCategoryKey or CATEGORY_ORDER[1]

    for _, categoryKey in ipairs(CATEGORY_ORDER) do
        local panel = categoryPanels[categoryKey]
        local button = categorySelectorButtons[categoryKey]
        local isSelected = categoryKey == selectedCategoryKey

        if panel then
            if isSelected then panel:Show() else panel:Hide() end
        end
        if button then
            if isSelected then
                button:SetBackdropColor(0.65, 0.52, 0.22, 0.55)
                button:SetBackdropBorderColor(0.92, 0.76, 0.36, 1.0)
                button.title:SetTextColor(1.0, 0.82, 0.25)
            else
                button:SetBackdropColor(0.1, 0.1, 0.12, 0.45)
                button:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.45)
                button.title:SetTextColor(0.82, 0.82, 0.82)
            end
        end
    end

    LayoutCategoryView()
end

local function CreateCategorySelectorButton(key, config, index)
    local btn = CreateFrame("Button", nil, CategorySelectorPanel)
    btn:SetHeight(42)
    btn:SetPoint("TOPLEFT", CategorySelectorPanel, "TOPLEFT", 10, -10 - ((index - 1) * 46))
    btn:SetPoint("TOPRIGHT", CategorySelectorPanel, "TOPRIGHT", -10, -10 - ((index - 1) * 46))
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    btn:SetBackdropColor(0.1, 0.1, 0.12, 0.45)
    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.45)

    local titleText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleText:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -7)
    titleText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -8, -7)
    titleText:SetJustifyH("LEFT")
    titleText:SetText(config.name)
    btn.title = titleText

    local countText = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 6)
    countText:SetText("0 queued")
    btn.countText = countText

    local readyText = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    readyText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -8, 6)
    readyText:SetText("0 ready")
    btn.readyText = readyText

    btn:SetScript("OnClick", function()
        SetCategorySelector(key)
        if frame.RefreshAll then frame:RefreshAll() end
    end)
    btn:SetScript("OnEnter", function(self)
        if key ~= selectedCategoryKey then
            self:SetBackdropBorderColor(0.65, 0.52, 0.22, 0.75)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if key ~= selectedCategoryKey then
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.45)
        end
    end)

    categorySelectorButtons[key] = btn
end

local function CreateCategoryPanel(key, config, index)
    local cell = CreateFrame("Frame", nil, CategoryDetailPanel)
    cell:SetAllPoints(CategoryDetailPanel)
    cell:Hide()

    local headerText = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("TOPLEFT", cell, "TOPLEFT", 16, -14)
    headerText:SetText(config.color .. config.name .. "|r")
    cell.header = headerText
    
    local compText = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    compText:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -18, -18)
    compText:SetText("0 ready / 0 queued / 0 bots")
    cell.compText = compText

    local dragBox = CreateFrame("Button", nil, cell)
    dragBox:SetSize(54, 54)
    dragBox:SetPoint("TOPLEFT", cell, "TOPLEFT", 16, -46)
    dragBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    dragBox:SetBackdropColor(0.04, 0.06, 0.08, 0.7)
    dragBox:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.4)
    
    local dragIcon = dragBox:CreateTexture(nil, "BACKGROUND")
    dragIcon:SetSize(36, 36)
    dragIcon:SetPoint("CENTER", dragBox, "CENTER", 0, 0)
    dragIcon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
    dragIcon:SetAlpha(0.55)
    
    dragBox:SetScript("OnEnter", function()
        dragBox:SetBackdropBorderColor(0.0, 0.8, 1.0, 1.0)
        GameTooltip:SetOwner(dragBox, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drop an item into this role queue.")
        GameTooltip:Show()
    end)
    dragBox:SetScript("OnLeave", function()
        dragBox:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.4)
        GameTooltip:Hide()
    end)
    
    dragBox:SetScript("OnReceiveDrag", function()
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" then
            ClearCursor()
            AddCategoryItem(key, itemID)
        end
    end)
    dragBox:SetScript("OnClick", function()
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" then
            ClearCursor()
            AddCategoryItem(key, itemID)
        end
    end)

    local itemContainer = CreateFrame("Frame", nil, cell)
    itemContainer:SetPoint("TOPLEFT", dragBox, "TOPRIGHT", 12, 0)
    itemContainer:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -16, -46)
    itemContainer:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -16, 44)
    itemContainer:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    itemContainer:SetBackdropColor(0.0, 0.0, 0.0, 0.55)
    itemContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.55)
    cell.itemContainer = itemContainer
    
    local itemScroll = CreateFrame("ScrollFrame", "BME_Scroll_" .. key, itemContainer, "UIPanelScrollFrameTemplate")
    itemScroll:SetPoint("TOPLEFT", itemContainer, "TOPLEFT", 6, -6)
    itemScroll:SetPoint("BOTTOMRIGHT", itemContainer, "BOTTOMRIGHT", -24, 6)
    
    local itemContent = CreateFrame("Frame", nil, itemScroll)
    itemContent:SetSize(360, 120)
    itemScroll:SetScrollChild(itemContent)
    
    local distBtn = CreateFrame("Button", nil, cell, "UIPanelButtonTemplate")
    distBtn:SetPoint("BOTTOMLEFT", itemContainer, "BOTTOMLEFT", 0, -32)
    distBtn:SetPoint("BOTTOMRIGHT", itemContainer, "BOTTOMRIGHT", 0, -32)
    distBtn:SetHeight(24)
    distBtn:SetText("Distribute Ready")
    distBtn:SetScript("OnClick", function()
        DistributeCategoryUpgrades(key)
    end)
    cell.distBtn = distBtn
    
    categoryPanels[key] = cell
    categoryLists[key] = { scroll = itemScroll, content = itemContent, items = {} }
end

for index, key in ipairs(CATEGORY_ORDER) do
    CreateCategorySelectorButton(key, Categories[key], index)
    CreateCategoryPanel(key, Categories[key], index)
end

SetCategorySelector(selectedCategoryKey)

frame:HookScript("OnSizeChanged", function()
    if activeTab == "CATEGORIES" then
        LayoutCategoryView()
    end
    if BotManager_DockStatsPanel then
        BotManager_DockStatsPanel()
    end
end)

local function AddDistributionStatusTooltip(tooltipCategory, tooltipStatus)
    tooltipStatus = tooltipStatus or {}
    local categoryName = GetCategoryDisplayName(tooltipCategory)
    GameTooltip:AddLine(categoryName .. ": " .. (tooltipStatus.text or ""), 0.8, 0.8, 0.8)

    if tooltipStatus.state == "READY" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Recommendation", 1.0, 0.82, 0.0)
        GameTooltip:AddLine("Target: " .. (tooltipStatus.botName or "Unknown"), 0.7, 1.0, 0.7)
        if tooltipStatus.slotKey then
            GameTooltip:AddLine("Slot: " .. (SlotDisplayNames[tooltipStatus.slotKey] or tooltipStatus.slotKey), 0.7, 0.85, 1.0)
        end
        if tooltipStatus.currentItemID and tooltipStatus.currentItemID > 0 then
            local currentName, currentLink = GetItemInfo(tooltipStatus.currentItemID)
            GameTooltip:AddLine("Replaces: " .. (currentLink or currentName or ("Item #" .. tooltipStatus.currentItemID)), 0.85, 0.85, 0.85)
        else
            GameTooltip:AddLine("Replaces: empty slot", 0.85, 0.85, 0.85)
        end
        GameTooltip:AddLine(
            "Score: " .. FormatScoreValue(tooltipStatus.newScore) ..
            " vs " .. FormatScoreValue(tooltipStatus.currentScore) ..
            " (+" .. FormatScoreValue(tooltipStatus.upgrade) .. ")",
            0.7, 1.0, 0.7
        )
        if tooltipStatus.roleCategory then
            GameTooltip:AddLine("Scored as: " .. GetCategoryDisplayName(tooltipStatus.roleCategory), 0.7, 0.85, 1.0)
        end
        GameTooltip:AddLine(tooltipStatus.reason or "This item scored higher for the bot's role and talent setup.", 0.72, 0.72, 0.72, true)
    elseif tooltipStatus.reason then
        GameTooltip:AddLine(tooltipStatus.reason, 0.72, 0.72, 0.72, true)
    end
end

local function RefreshCategoryLists()
    categoriesDB = EnsureCategoriesDatabase()
    categoryPreview = BuildDistributionPlan(CATEGORY_ORDER)

    for _, key in ipairs(CATEGORY_ORDER) do
        local listData = categoryLists[key]
        for _, row in ipairs(listData.items) do row:Hide() end
        
        local activeList = categoriesDB and categoriesDB[key] or {}
        local count = GetCompatibleBotsCount(key)
        local readyCount = categoryPreview.readyByCategory[key] or 0
        
        if categoryPanels[key] and categoryPanels[key].compText then
            categoryPanels[key].compText:SetText(readyCount .. " ready / " .. #activeList .. " queued / " .. count .. " bots")
        end
        if categorySelectorButtons[key] then
            categorySelectorButtons[key].countText:SetText(#activeList .. " queued")
            categorySelectorButtons[key].readyText:SetText(readyCount .. " ready")
        end

        local rowWidth = (listData.scroll:GetWidth() or 0) - 6
        if rowWidth < 260 then
            rowWidth = math.max(260, (CategoryDetailPanel:GetWidth() or 420) - 120)
        end
        listData.content:SetWidth(rowWidth)
        
        for i, itemID in ipairs(activeList) do
            local row = listData.items[i]
            if not row then
                row = CreateFrame("Frame", nil, listData.content)
                row:SetSize(rowWidth, 25)
                
                local icon = row:CreateTexture(nil, "BACKGROUND")
                icon:SetSize(20, 20)
                icon:SetPoint("LEFT", row, "LEFT", 2, 0)
                row.icon = icon
                
                local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetJustifyH("LEFT")
                row.text = txt

                local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                statusText:SetJustifyH("RIGHT")
                row.statusText = statusText
                
                local delBtn = CreateFrame("Button", nil, row)
                delBtn:SetSize(12, 12)
                row.delBtn = delBtn
                
                local delIcon = delBtn:CreateTexture(nil, "OVERLAY")
                delIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                delIcon:SetAllPoints()
                
                delBtn:SetScript("OnEnter", function()
                    delIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
                end)
                delBtn:SetScript("OnLeave", function()
                    delIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                end)
                delBtn:SetScript("OnClick", function(self)
                    local rowFrame = self:GetParent()
                    if rowFrame and rowFrame.categoryKey and rowFrame.index then
                        RemoveCategoryItem(rowFrame.categoryKey, rowFrame.index)
                    end
                end)

                row:SetScript("OnEnter", function(self)
                    local tooltipItemID = self.itemID
                    local tooltipStatus = self.statusData or {}
                    local tooltipCategory = self.categoryKey
                    local tooltipItemName = tooltipItemID and GetItemInfo(tooltipItemID)

                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if tooltipItemName then
                        GameTooltip:SetHyperlink("item:" .. tooltipItemID)
                        GameTooltip:AddLine(" ")
                        AddDistributionStatusTooltip(tooltipCategory, tooltipStatus)
                    elseif tooltipItemID then
                        GameTooltip:SetText("Item #" .. tooltipItemID)
                        GameTooltip:AddLine("Item info is not cached yet.", 1, 0.82, 0)
                    end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                
                listData.items[i] = row
            end
            
            row.categoryKey = key
            row.index = i
            row.itemID = itemID
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", listData.content, "TOPLEFT", 0, -(i - 1) * 25)
            LayoutCategoryRow(row, rowWidth)
            row:Show()
            
            local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
            if itemName then
                row.icon:SetTexture(itemTexture)
                row.text:SetText(GetItemColorCode(itemRarity) .. itemName .. "|r")
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                row.text:SetText("|cff808080Loading...|r")
            end

            local status = categoryPreview.statuses[key] and categoryPreview.statuses[key][i] or { state = "SKIP", text = "Pending" }
            local color = StatusColors[status.state] or "|cffffffff"
            row.statusData = status
            row.statusText:SetText(color .. status.text .. "|r")
        end

        listData.content:SetHeight(math.max(72, #activeList * 25 + 4))
    end

    SetCategorySelector(selectedCategoryKey)
end

local distributeAllBtn = CreateFrame("Button", nil, CategoriesTabFrame, "UIPanelButtonTemplate")
distributeAllBtn:SetSize(220, 24)
distributeAllBtn:SetPoint("BOTTOM", CategoriesTabFrame, "BOTTOM", 0, 15)
distributeAllBtn:SetText("Distribute All Ready")
distributeAllBtn:SetScript("OnClick", function()
    categoriesDB = EnsureCategoriesDatabase()
    local plan = BuildDistributionPlan(CATEGORY_ORDER)
    categoryPreview = plan

    if #plan.actions > 0 then
        RemovePlannedRows(plan.plannedIndexes)
        frame:RefreshAll()
        print("|cff00ff00BotManager:|r Queued " .. #plan.actions .. " role-based upgrade(s).")
        BotManager_StartSequentialActions(plan.actions, nil, "Role Queues", "CATEGORIES_DISTRIBUTE_ALL")
    else
        frame:RefreshAll()
        print("|cff00ff00BotManager:|r No ready upgrades found. Check the row statuses.")
    end
end)


-- ----------------------------------------------------------------------------
-- GLOBAL REFRESH DISPATCHER
-- ----------------------------------------------------------------------------
function frame:RefreshAll()
    if activeTab == "TEMPLATE" then
        RefreshTemplateList()
        frame:RefreshPaperdoll()
    else
        RefreshCategoryLists()
    end
end

-- Refresh UI seamlessly on visibility toggle
frame:SetScript("OnShow", function(self)
    self:Raise()
    HookParentSizing()
    DockToParentFrame() -- Dynamic safe positioning on open
    if BotManager_DockStatsPanel then
        BotManager_DockStatsPanel()
    end
    if categoryLists and categoryLists.TANK then
        frame:RefreshAll()
    end
end)

-- Default to Template view
SetTab("TEMPLATE")
