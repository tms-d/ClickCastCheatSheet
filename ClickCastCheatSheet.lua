--[[
    WoW Addon: ClickCastCheatSheet (Lua Only)
    Displays 15 spell icons (5 primary, 5 SHIFT, 5 CTRL) based on Click Bindings.
    The icons are arranged in a clustered layout, and the entire group is movable.
--]]

-- *** 1. CONFIGURATION: CORE ADJUSTABLE PARAMETERS ***
local BASE_ICON_SIZE = 25; -- Primary icon size
local MOD_ICON_SIZE = 15; -- Modifier icon size
local SPACING = 2; 
local ADDON_NAME = "ClickCastCheatSheet";

-- *** 2. GLOBAL SCREEN POSITION OFFSET ***
-- Use these to move the entire group relative to the center of the screen (0, 0)
local SCREEN_OFFSET_X = 0; 
local SCREEN_OFFSET_Y = 0; 

-- *** 3. ICON ZOOM CONFIGURATION ***
-- Sets the texture coordinates to zoom into the center of the icon (0.10 to 0.90 = 20% zoom)
local ZOOM_MIN_COORD = 0.10;
local ZOOM_MAX_COORD = 0.90;

local B_SIZE = BASE_ICON_SIZE;
local M_SIZE = MOD_ICON_SIZE;
local isInitialized = false;
local SCALE_MULTIPLIER = 1.0;
-- Border thickness in pixels around each icon
local BORDER = 1;
-- Debug mode flag
local DEBUG = false;
-- Lock mode flag (prevents dragging when true)
local LOCKED = false;

-- Helper function to print only when debug mode is enabled
local function DebugPrint(msg)
    if DEBUG then
        print(ADDON_NAME .. ": " .. msg)
    end
end

-- Helper to round to nearest integer pixel to avoid fractional-pixel alignment issues
local function Round(n)
    return math.floor((n) + 0.5)
end

-- Module-level reference to the container frame so lock/unlock can access it
local containerFrameRef = nil;

-- Apply or remove drag behavior based on LOCKED state
local function ApplyLockState(frame)
    if not frame then return end
    if LOCKED then
        frame:EnableMouse(false)
    else
        frame:EnableMouse(true)
    end
end

-- Saved-variables table (populated by WoW when declared in the .toc)
-- ClickCastCheatSheetDB = { x = <number>, y = <number>, debugMode = <boolean>, locked = <boolean> }

-- Vertical displacement for modifier icons relative to the base icon center.
local MOD_OFFSET = (B_SIZE / 2) + (M_SIZE / 2) + SPACING; 

-- BASE ANCHORS (Relative to the container's center 0,0) - Center point for the 5 main icons.
local BASE_ANCHORS = {
    -- MiddleButton (3): Top Center
    ["MiddleButton"] = {x = 0, y = (B_SIZE + SPACING * 2) - (M_SIZE/2)},
    -- LeftButton (1): Left Center
    ["LeftButton"]   = {x = -(B_SIZE + SPACING * 2), y = 0},
    -- RightButton (2): Right Center
    ["RightButton"]  = {x = (B_SIZE + SPACING * 2), y = 0},
    -- Button4 (4): Bottom Left
    ["Button4"]      = {x = -(B_SIZE/2 + SPACING) + (B_SIZE/3), y = -(B_SIZE + B_SIZE * 0.85)},
    -- Button5 (5): Bottom Right (Offset to be visually below Button4)
    ["Button5"]      = {x = (B_SIZE/2 + SPACING) + (B_SIZE/3), y = (-(B_SIZE + B_SIZE * 0.85) - (B_SIZE / 2))}, 
};

-- Configuration: {key, button, modifier, frameSize, x_rel, y_rel}
local SPELL_CONFIG = {
    -- BASE (No Modifier) Group
    {key = "BUTTON3", button = "MiddleButton", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},
    {key = "BUTTON1", button = "LeftButton", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},
    {key = "BUTTON2", button = "RightButton", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},
    {key = "BUTTON4", button = "Button4", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},
    {key = "BUTTON5", button = "Button5", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},

    -- SHIFT Modifier Group (Positioned above the base icon)
    {key = "SHIFTB3", button = "MiddleButton", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET}, 
    {key = "SHIFTB1", button = "LeftButton", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET}, 
    {key = "SHIFTB2", button = "RightButton", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET},
    {key = "SHIFTB4", button = "Button4", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET},
    {key = "SHIFTB5", button = "Button5", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET},
    
    -- CTRL Modifier Group (Positioned below the base icon)
    {key = "CTRLB3", button = "MiddleButton", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
    {key = "CTRLB1", button = "LeftButton", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
    {key = "CTRLB2", button = "RightButton", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
    {key = "CTRLB4", button = "Button4", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
    {key = "CTRLB5", button = "Button5", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
};

-- Table to track spell IDs and their cooldown frames for updates
-- Keyed by config key (e.g. "BUTTON3") to avoid collisions when multiple bindings use the same spell
local SPELL_COOLDOWNS = {};
-- Track last known cooldown state to only update on changes
local LAST_COOLDOWN_STATE = {};

-- Function to format cooldown time nicely
local function FormatCooldownTime(secondsRemaining)
    if secondsRemaining >= 60 then
        return math.ceil(secondsRemaining / 60) .. "m"
    else
        return math.ceil(secondsRemaining)
    end
end

-- Function to update a single spell cooldown display and text
local function UpdateSpellCooldown(trackingKey, cooldownData)
    if not trackingKey or not cooldownData then
        DebugPrint("UpdateSpellCooldown called with invalid args: key=" .. tostring(trackingKey) .. ", cooldownData=" .. tostring(cooldownData))
        return
    end

    local spellID = cooldownData.spellID
    local cooldownFrame = cooldownData.cooldownFrame

    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    
    -- In Midnight, only isOnGCD is reliably accessible
    -- If isOnGCD is true, it's just the global cooldown - don't display
    -- If isOnGCD is false or nil, there's a real cooldown - display it
    local isOnGCD = (cooldownInfo and cooldownInfo.isOnGCD) or false
    local isRealCooldown = not isOnGCD
    
    -- Only update if the cooldown state has changed
    local lastState = LAST_COOLDOWN_STATE[trackingKey]
    local wasOnCooldown = lastState and lastState.isOnCooldown
    
    if isRealCooldown ~= wasOnCooldown then
        -- State changed, update it
        LAST_COOLDOWN_STATE[trackingKey] = {
            isOnCooldown = isRealCooldown
        }
        
        if isRealCooldown then
            DebugPrint("Spell " .. spellID .. " cooldown started")
            -- SetCooldown needs startTime, duration, modRate
            -- Try to safely extract them, but they may be secret
            local startTime = cooldownInfo and cooldownInfo.startTime or 0
            local duration = cooldownInfo and cooldownInfo.duration or 0
            local modRate = cooldownInfo and cooldownInfo.modRate or 1
            
            -- Use pcall to safely call SetCooldown in case values are inaccessible
            local success = pcall(function()
                cooldownFrame:SetCooldown(startTime, duration, modRate)
            end)
            
            if not success then
                DebugPrint("Could not set cooldown with restricted values, clearing instead")
                cooldownFrame:Clear()
            end
        else
            DebugPrint("Spell " .. spellID .. " cooldown ended")
            cooldownFrame:Clear()
        end
    end
end

-- Function to update all spell cooldowns
local function UpdateAllCooldowns()
    for trackingKey, cooldownData in pairs(SPELL_COOLDOWNS) do
        UpdateSpellCooldown(trackingKey, cooldownData)
    end
end
local eventFrame = CreateFrame("Frame", ADDON_NAME .. "EventFrame"); 


-- =========================================================================
-- CLICK BINDING LOOKUP LOGIC
-- =========================================================================

local function FindBoundSpellID(buttonName, modifierName)
    local this_spellid = nil
    
    -- Check if the C_ClickBindings API is available
    if not C_ClickBindings or not C_ClickBindings.GetProfileInfo then
        DebugPrint("C_ClickBindings API not available")
        return nil 
    end

    DebugPrint("Looking for binding: button=" .. buttonName .. ", modifier=" .. modifierName)

    local clickbindingsprofile = C_ClickBindings.GetProfileInfo()
    
    if not clickbindingsprofile then
        DebugPrint("No click bindings profile found")
        return nil
    end
    
    DebugPrint("Found " .. #clickbindingsprofile .. " click bindings total")

    for _, v in pairs(clickbindingsprofile) do
        -- Match the specific mouse button and modifier string ("" or "SHIFT" or "CTRL")
        if v.button == buttonName and C_ClickBindings.GetStringFromModifiers(v.modifiers) == modifierName then
            if v.type == 1 then
                -- Type 1: Direct spell action
                this_spellid = v.actionID
                DebugPrint("Found direct spell binding: " .. buttonName .. " + " .. modifierName .. " -> SpellID " .. this_spellid)
                break
            elseif v.type == 2 then
                -- Type 2: Macro action (requires secondary lookup)
                this_spellid = GetMacroSpell(v.actionID) 
                DebugPrint("Found macro binding: " .. buttonName .. " + " .. modifierName .. " -> SpellID " .. tostring(this_spellid))
                break
            end
        end
    end
    
    return this_spellid
end


-- =========================================================================
-- INITIALIZATION WORKER FUNCTION
-- =========================================================================

local function InitializeWorker()
    DebugPrint("InitializeWorker started")

    -- Create the main container frame that holds all icons and is movable
    local f_container = CreateFrame("Frame", ADDON_NAME .. "ContainerFrame", UIParent);
    DebugPrint("Container frame created")

    if not C_Spell or not C_Spell.GetSpellInfo then
        error("C_Spell API not available yet. Cannot initialize.")
    end
    DebugPrint("C_Spell API available")

    -- Setup the movable parent container
    f_container:SetFrameStrata("MEDIUM");
    local containerSize = Round(200 * SCALE_MULTIPLIER)
    f_container:SetSize(containerSize, containerSize);
    
    -- Anchor using the saved variables if present, otherwise the global offset variables
    ClickCastCheatSheetDB = ClickCastCheatSheetDB or {};
    
    -- Load debug mode from saved variables
    if type(ClickCastCheatSheetDB.debugMode) == "boolean" then
        DEBUG = ClickCastCheatSheetDB.debugMode
        DebugPrint("Loaded debug mode from saved variables: " .. tostring(DEBUG))
    end
    
    -- Load locked state from saved variables
    if type(ClickCastCheatSheetDB.locked) == "boolean" then
        LOCKED = ClickCastCheatSheetDB.locked
        DebugPrint("Loaded locked state from saved variables: " .. tostring(LOCKED))
    end

    -- Load scale multiplier from saved variables
    if type(ClickCastCheatSheetDB.scale) == "number" then
        SCALE_MULTIPLIER = ClickCastCheatSheetDB.scale
        DebugPrint("Loaded scale from saved variables: " .. SCALE_MULTIPLIER)
    end
    
    local savedX, savedY = ClickCastCheatSheetDB.x, ClickCastCheatSheetDB.y;
    if type(savedX) == "number" and type(savedY) == "number" then
        f_container:SetPoint("CENTER", UIParent, "CENTER", savedX, savedY);
        DebugPrint("Using saved position: X=" .. savedX .. ", Y=" .. savedY)
    else
        f_container:SetPoint("CENTER", UIParent, "CENTER", SCREEN_OFFSET_X, SCREEN_OFFSET_Y);
        DebugPrint("Using default position: X=" .. SCREEN_OFFSET_X .. ", Y=" .. SCREEN_OFFSET_Y)
    end
    f_container:SetClampedToScreen(true);
    f_container:SetMovable(true);
    f_container:SetUserPlaced(true);
    f_container:EnableMouse(true);
    f_container:RegisterForDrag("LeftButton");
    containerFrameRef = f_container;
    ApplyLockState(f_container);
    f_container:SetScript("OnDragStart", f_container.StartMoving);
    -- When the user stops dragging, stop moving and save the center offsets
    f_container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
        -- Ensure the saved table exists
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {};
        local px, py = self:GetCenter();
        local ux, uy = UIParent:GetCenter();
        if px and py and ux and uy then
            ClickCastCheatSheetDB.x = px - ux;
            ClickCastCheatSheetDB.y = py - uy;
        end
    end);
    
    -- Register for SPELL_UPDATE_COOLDOWN events (event-driven instead of polling)
    -- This event fires with unrestricted access to cooldown data
    f_container:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    f_container:SetScript("OnEvent", function(self, event, spellID)
        if event == "SPELL_UPDATE_COOLDOWN" then
            -- Update all tracked spells when any cooldown changes
            -- We check all tracked spells because a single event might affect multiple
            UpdateAllCooldowns()
        end
    end);

    local iconCount = 0
    for _, config in ipairs(SPELL_CONFIG) do
        local foundSpellId = FindBoundSpellID(config.button, config.modifier);
        
        -- Only proceed if a spell binding was successfully found
        if foundSpellId then
            iconCount = iconCount + 1
            local SPELL_ID_TO_TRACK = foundSpellId;
            local key = config.key;
            local button = config.button;

            DebugPrint("Found spell for " .. key .. " (button=" .. button .. ", modifier=" .. config.modifier .. "): SpellID=" .. SPELL_ID_TO_TRACK)

            -- 1. Get Spell Icon Texture
            local ICON_TEXTURE;
            local spellInfo = C_Spell.GetSpellInfo(SPELL_ID_TO_TRACK);
            if spellInfo then
                ICON_TEXTURE = spellInfo.icon or spellInfo.iconID
            end
            
            -- Fallback to Question Mark if icon data is missing for a found spell ID
            if not ICON_TEXTURE then
                ICON_TEXTURE = "Interface\\ICONS\\INV_Misc_QuestionMark";
                DebugPrint("No icon found for spell " .. SPELL_ID_TO_TRACK .. ", using fallback")
            end

            -- 2. Create the Icon Frame
            -- Create an icon frame slightly larger than the icon so we can draw a border
            -- without shrinking the visible icon area.
            local scaledFrameSize = Round(config.frameSize * SCALE_MULTIPLIER)
            local scaledBorder = Round(BORDER * SCALE_MULTIPLIER)
            local iconFrame = CreateFrame("Frame", ADDON_NAME .. key .. "IconFrame", f_container);
            iconFrame:SetSize(scaledFrameSize + (scaledBorder * 2), scaledFrameSize + (scaledBorder * 2));
            -- Create 4 solid-color textures to form a 2px black border inside the frame
            local top = iconFrame:CreateTexture(nil, "OVERLAY")
            top:SetColorTexture(0,0,0,1)
            top:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
            top:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 0, 0)
            top:SetHeight(scaledBorder)

            local bottom = iconFrame:CreateTexture(nil, "OVERLAY")
            bottom:SetColorTexture(0,0,0,1)
            bottom:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
            bottom:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
            bottom:SetHeight(scaledBorder)

            local left = iconFrame:CreateTexture(nil, "OVERLAY")
            left:SetColorTexture(0,0,0,1)
            left:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
            left:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
            left:SetWidth(scaledBorder)

            local right = iconFrame:CreateTexture(nil, "OVERLAY")
            right:SetColorTexture(0,0,0,1)
            right:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 0, 0)
            right:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
            right:SetWidth(scaledBorder)
            
            -- Calculate Final Position
            local baseAnchor = BASE_ANCHORS[button];
            local totalX = baseAnchor.x + (config.x_rel or 0);
            local totalY = baseAnchor.y + (config.y_rel or 0);
            -- Apply scale multiplier to positions
            totalX = Round(totalX * SCALE_MULTIPLIER)
            totalY = Round(totalY * SCALE_MULTIPLIER)

            iconFrame:SetPoint("CENTER", f_container, "CENTER", totalX, totalY);
            iconFrame:SetFrameLevel(f_container:GetFrameLevel() + 1);
            
            -- 3. Create the Texture
            local texture = iconFrame:CreateTexture(nil, "BACKGROUND");
            -- Place the icon texture inset by the border thickness so the icon keeps its
            -- original configured size while the border occupies the extra padding.
            texture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", scaledBorder, -scaledBorder);
            texture:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -scaledBorder, scaledBorder);
            texture:SetTexture(ICON_TEXTURE);
            -- Apply the zoom configuration
            texture:SetTexCoord(ZOOM_MIN_COORD, ZOOM_MAX_COORD, ZOOM_MIN_COORD, ZOOM_MAX_COORD);
            texture:SetVertexColor(1, 1, 1, 1);
            
            -- 4. Create the Cooldown Widget
            -- The cooldown widget displays a spiral overlay showing the remaining cooldown
            local cooldownFrame = CreateFrame("Cooldown", ADDON_NAME .. key .. "Cooldown", iconFrame, "CooldownFrameTemplate");
            cooldownFrame:SetAllPoints(iconFrame);
            cooldownFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 10);
            
            -- Track this spell's cooldown for updates (keyed by config key to avoid collisions)
            SPELL_COOLDOWNS[key] = {
                spellID = SPELL_ID_TO_TRACK,
                cooldownFrame = cooldownFrame
            };

            -- Initial cooldown update
            UpdateSpellCooldown(key, SPELL_COOLDOWNS[key]);
            
            iconFrame:Show();
            DebugPrint("Created icon frame for " .. key)
        else
            DebugPrint("No binding found for " .. config.key)
        end
    end
    
    DebugPrint("Total icons created: " .. iconCount)
    f_container:Show();
    DebugPrint("Container frame shown")
end


-- =========================================================================
-- INITIALIZATION LOGIC (Runs once after PLAYER_LOGIN)
-- =========================================================================

local function OnInitializationEvent(self, event, ...)
    if isInitialized then return end
    
    DebugPrint("Initialization event triggered: " .. event)
    
    -- Execute the initialization worker inside a protected call
    local success, err = pcall(InitializeWorker)

    if success then
        isInitialized = true;
        print(ADDON_NAME .. " loaded successfully");
    else
        print(ADDON_NAME .. " initialization failed: " .. tostring(err));
        DebugPrint("Error details: " .. tostring(err));
    end
    
    -- Unregister events to prevent re-initialization unless explicitly reset
    self:UnregisterEvent("PLAYER_LOGIN");
end


-- =========================================================================
-- REINITIALIZE FRAMES
-- =========================================================================

local function ReinitializeFrames()
    -- Hide and release child icon frames
    for _, config in ipairs(SPELL_CONFIG) do
        local iconName = ADDON_NAME .. config.key .. "IconFrame"
        local iconFrame = _G[iconName]
        if iconFrame then
            iconFrame:Hide()
            iconFrame:ClearAllPoints()
            iconFrame:SetParent(nil)
            _G[iconName] = nil
        end
    end

    -- Hide and release the old container frame
    local containerName = ADDON_NAME .. "ContainerFrame"
    local frame = _G[containerName]
    if frame then
        frame:Hide()
        frame:UnregisterAllEvents()
        frame:ClearAllPoints()
        frame:SetParent(nil)
        _G[containerName] = nil
    end

    -- Clear tracking tables
    isInitialized = false
    table.wipe(SPELL_COOLDOWNS)
    table.wipe(LAST_COOLDOWN_STATE)

    -- Reinitialize
    InitializeWorker()
end


-- =========================================================================
-- SLASH COMMAND HANDLER
-- =========================================================================

local function HandleSlashCommand(msg)
    local command = msg:lower():trim()

    if command == "debug" then
        DEBUG = not DEBUG
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {};
        ClickCastCheatSheetDB.debugMode = DEBUG;
        if DEBUG then
            print(ADDON_NAME .. ": Debug mode enabled")
        else
            print(ADDON_NAME .. ": Debug mode disabled")
        end
    elseif command == "reload" then
        print(ADDON_NAME .. ": Refreshing click bindings...")
        ReinitializeFrames()
    elseif command == "lock" then
        LOCKED = true
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        ClickCastCheatSheetDB.locked = true
        ApplyLockState(containerFrameRef)
        print(ADDON_NAME .. ": Position locked")
    elseif command == "unlock" then
        LOCKED = false
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        ClickCastCheatSheetDB.locked = false
        ApplyLockState(containerFrameRef)
        print(ADDON_NAME .. ": Position unlocked")
    else
        print(ADDON_NAME .. ": Unknown command: " .. msg)
        print("Usage: /cccs debug - Toggle debug mode")
        print("Usage: /cccs reload - Refresh click bindings")
        print("Usage: /cccs lock - Lock icon position")
        print("Usage: /cccs unlock - Unlock icon position")
    end
end

SLASH_CLICKCASTCHEATSHEET1 = "/cccs"
SlashCmdList["CLICKCASTCHEATSHEET"] = HandleSlashCommand


-- =========================================================================
-- SETTINGS PANEL CREATION
-- =========================================================================

-- Helper: creates a slider with an editable text input next to it
-- Returns the slider frame and editbox frame
local function CreateSliderWithEditBox(parent, label, minVal, maxVal, step, width, anchorFrame, anchorOffsetY)
    local sliderLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sliderLabel:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, anchorOffsetY)
    sliderLabel:SetText(label)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -10)
    slider:SetWidth(width)
    -- Hide the default Low/High labels to save vertical space
    if slider.Low then slider.Low:SetText("") end
    if slider.High then slider.High:SetText("") end
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
    editBox:SetSize(60, 20)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetJustifyH("CENTER")

    -- Sync editbox text while dragging
    slider:SetScript("OnValueChanged", function(self, value, userInput)
        if userInput then
            editBox:SetText(string.format("%.1f", value))
        end
    end)

    -- Pressing enter in editbox updates the slider
    editBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(minVal, math.min(maxVal, val))
            slider:SetValue(val)
            self:SetText(string.format("%.1f", val))
        else
            self:SetText(string.format("%.1f", slider:GetValue()))
        end
        self:ClearFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(string.format("%.1f", slider:GetValue()))
        self:ClearFocus()
    end)

    return slider, editBox, sliderLabel
end

local function CreateSettingsPanel()
    local container = CreateFrame("Frame")
    container:SetSize(600, 280)

    -- Debug mode checkbox
    local debugCheckbox = CreateFrame("CheckButton", nil, container)
    debugCheckbox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -10)
    debugCheckbox:SetSize(24, 24)

    debugCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    debugCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    debugCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    debugCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    debugCheckbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")

    local debugLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugLabel:SetPoint("LEFT", debugCheckbox, "RIGHT", 10, 0)
    debugLabel:SetText("Enable Debug Mode")

    local function UpdateDebugCheckbox()
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        debugCheckbox:SetChecked(ClickCastCheatSheetDB.debugMode or false)
    end

    debugCheckbox:SetScript("OnClick", function(self)
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        DEBUG = self:GetChecked()
        ClickCastCheatSheetDB.debugMode = DEBUG
        if DEBUG then
            print(ADDON_NAME .. ": Debug mode enabled")
        else
            print(ADDON_NAME .. ": Debug mode disabled")
        end
    end)

    debugCheckbox:SetScript("OnShow", UpdateDebugCheckbox)

    -- Lock position checkbox
    local lockCheckbox = CreateFrame("CheckButton", nil, container)
    lockCheckbox:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -5)
    lockCheckbox:SetSize(24, 24)

    lockCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    lockCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    lockCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    lockCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    lockCheckbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")

    local lockLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockLabel:SetPoint("LEFT", lockCheckbox, "RIGHT", 10, 0)
    lockLabel:SetText("Lock Position")

    lockCheckbox:SetScript("OnClick", function(self)
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        LOCKED = self:GetChecked()
        ClickCastCheatSheetDB.locked = LOCKED
        ApplyLockState(containerFrameRef)
        if LOCKED then
            print(ADDON_NAME .. ": Position locked")
        else
            print(ADDON_NAME .. ": Position unlocked")
        end
    end)

    -- Scale slider with editbox
    local scaleSlider, scaleEditBox, scaleLabel = CreateSliderWithEditBox(
        container, "Icon Scale:", 0.5, 3.0, 0.1, 200, lockCheckbox, -10
    )

    scaleSlider:SetScript("OnMouseUp", function(self)
        local value = self:GetValue()
        SCALE_MULTIPLIER = value
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        ClickCastCheatSheetDB.scale = value
        ReinitializeFrames()
    end)

    scaleEditBox:HookScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(0.5, math.min(3.0, value))
            SCALE_MULTIPLIER = value
            ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
            ClickCastCheatSheetDB.scale = value
            ReinitializeFrames()
        end
    end)

    -- Position X slider with editbox
    local xSlider, xEditBox, xLabel = CreateSliderWithEditBox(
        container, "Position X:", -2000, 2000, 1, 200, scaleSlider, -20
    )

    local function ApplyPosition()
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        local containerFrame = _G[ADDON_NAME .. "ContainerFrame"]
        if containerFrame then
            containerFrame:ClearAllPoints()
            containerFrame:SetPoint("CENTER", UIParent, "CENTER", ClickCastCheatSheetDB.x or 0, ClickCastCheatSheetDB.y or 0)
        end
    end

    xSlider:SetScript("OnMouseUp", function(self)
        local value = self:GetValue()
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        ClickCastCheatSheetDB.x = value
        ApplyPosition()
    end)

    xEditBox:HookScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(-2000, math.min(2000, value))
            ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
            ClickCastCheatSheetDB.x = value
            xSlider:SetValue(value)
            ApplyPosition()
        end
    end)

    -- Position Y slider with editbox
    local ySlider, yEditBox, yLabel = CreateSliderWithEditBox(
        container, "Position Y:", -2000, 2000, 1, 200, xSlider, -20
    )

    ySlider:SetScript("OnMouseUp", function(self)
        local value = self:GetValue()
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        ClickCastCheatSheetDB.y = value
        ApplyPosition()
    end)

    yEditBox:HookScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(-2000, math.min(2000, value))
            ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
            ClickCastCheatSheetDB.y = value
            ySlider:SetValue(value)
            ApplyPosition()
        end
    end)

    -- OnShow: sync all controls from saved variables
    container:SetScript("OnShow", function()
        ClickCastCheatSheetDB = ClickCastCheatSheetDB or {}
        -- Debug checkbox
        debugCheckbox:SetChecked(ClickCastCheatSheetDB.debugMode or false)
        -- Lock checkbox
        lockCheckbox:SetChecked(ClickCastCheatSheetDB.locked or false)
        -- Scale
        local savedScale = ClickCastCheatSheetDB.scale or 1.0
        scaleSlider:SetValue(savedScale)
        scaleEditBox:SetText(string.format("%.1f", savedScale))
        -- Position X
        local savedX = ClickCastCheatSheetDB.x or 0
        xSlider:SetValue(savedX)
        xEditBox:SetText(string.format("%.1f", savedX))
        -- Position Y
        local savedY = ClickCastCheatSheetDB.y or 0
        ySlider:SetValue(savedY)
        yEditBox:SetText(string.format("%.1f", savedY))
    end)

    local category = Settings.RegisterCanvasLayoutCategory(container, ADDON_NAME)
    category.ID = ADDON_NAME
    Settings.RegisterAddOnCategory(category)
end

-- =========================================================================
-- EVENT REGISTRATION
-- =========================================================================

-- Handle initialization - PLAYER_LOGIN for first load, ADDON_LOADED for reloads
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            isInitialized = false
            table.wipe(SPELL_COOLDOWNS)
            table.wipe(LAST_COOLDOWN_STATE)
            DebugPrint("Addon loaded, resetting initialization")
        end
    elseif event == "PLAYER_LOGIN" then
        OnInitializationEvent(self, event)
        CreateSettingsPanel()
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if isInitialized then
            DebugPrint("Spec changed, refreshing click bindings...")
            ReinitializeFrames()
        end
    end
end)
