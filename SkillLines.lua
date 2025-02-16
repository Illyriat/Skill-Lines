-- SkillLines Addon for ESO
SkillLines = {}
SkillLines.name = "SkillLines"
SkillLines.savedData = nil

-- Skill lines to track
local skillLines = {
    { category = "Armor", skillType = SKILL_TYPE_ARMOR, names = {"Light Armor", "Medium Armor", "Heavy Armor"} },
    { category = "Guild", skillType = SKILL_TYPE_GUILD, names = {"Fighters Guild", "Mages Guild", "Psijic Order", "Thieves Guild", "Undaunted"} },
    { category = "Alliance War", skillType = SKILL_TYPE_AVA, names = {"Assault", "Support"} },
}

-- Utility function to clean character names (removes ^Fx or ^Mx suffix)
local function CleanCharacterName(charName)
    return charName:gsub("%^%a+", "") -- Removes ^Fx or ^Mx
end

-- Retrieve all stored character names from SavedVars for the current megaserver
local function GetStoredCharacterData()
    local characters = {}
    local serverName = GetWorldName() -- Get the current megaserver
    local accountName = GetDisplayName()

    if SkillLines.savedData and SkillLines.savedData[serverName] and SkillLines.savedData[serverName][accountName] then
        d("SkillLines Debug: Retrieving characters for server: " .. serverName .. ", account: " .. accountName)
        for charName, charData in pairs(SkillLines.savedData[serverName][accountName]) do
            -- Skip the "version" key and ensure we're only processing character data
            if charName ~= "version" then
                d("SkillLines Debug: Found character: " .. charName)
                table.insert(characters, { name = charName, alliance = nil }) -- No alliance data stored
            end
        end
        -- Sort characters alphabetically by name
        table.sort(characters, function(a, b)
            return a.name < b.name
        end)
    else
        d("SkillLines Debug: No saved data found for server: " .. serverName .. ", account: " .. accountName)
    end
    return characters
end


-- Save character skill levels
local function UpdateCharacterSkillLevels()
    local charName = CleanCharacterName(GetUnitName("player"))
    local accountName = GetDisplayName()
    local serverName = GetWorldName()

    if not charName or charName == "" then return end

    -- Ensure SavedVars structure exists
    if not SkillLines.savedData then SkillLines.savedData = {} end
    if not SkillLines.savedData[serverName] then SkillLines.savedData[serverName] = {} end
    if not SkillLines.savedData[serverName][accountName] then SkillLines.savedData[serverName][accountName] = {} end
    if not SkillLines.savedData[serverName][accountName][charName] then
        SkillLines.savedData[serverName][accountName][charName] = {}
    end

    d("SkillLines Debug: Updating skill data for " .. charName)

    for _, category in ipairs(skillLines) do
        for _, skillName in ipairs(category.names) do
            local skillType = category.skillType
            local numSkillLines = GetNumSkillLines(skillType)

            for skillIndex = 1, numSkillLines do
                local name, rank = GetSkillLineInfo(skillType, skillIndex)
                if name and name == skillName then
                    SkillLines.savedData[serverName][accountName][charName][skillName] = rank or "-"
                end
            end
        end
    end
end

-- Retrieve stored skill levels
local function GetCharacterSkillLevels(charName, skillName)
    local accountName = GetDisplayName()
    local serverName = GetWorldName()
    charName = CleanCharacterName(charName)

    if not SkillLines.savedData or not SkillLines.savedData[serverName] or
       not SkillLines.savedData[serverName][accountName] or
       not SkillLines.savedData[serverName][accountName][charName] then
        return "-"
    end

    return SkillLines.savedData[serverName][accountName][charName][skillName] or "-"
end

-- Save window position when moved
local function SaveWindowPosition(control)
    local left, top = control:GetLeft(), control:GetTop()
    SkillLines.savedData.windowPosition = { left = left, top = top }
    d("SkillLines Debug: Window position saved: " .. left .. ", " .. top)
end

-- Restore window position if saved
local function RestoreWindowPosition(control)
    if SkillLines.savedData.windowPosition then
        local pos = SkillLines.savedData.windowPosition
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.left, pos.top)
        d("SkillLines Debug: Window position restored: " .. pos.left .. ", " .. pos.top)
    end
end

-- Create UI Table
local function CreateSkillTable()
    local wm = WINDOW_MANAGER
    local control = wm:GetControlByName("SkillLinesUI")

    if not control then
        local screenWidth, screenHeight = GuiRoot:GetWidth(), GuiRoot:GetHeight()

        -- Determine number of columns based on skill categories
        local numColumns = 1  -- Start with 1 for character name column
        for _, category in ipairs(skillLines) do
            numColumns = numColumns + #category.names
        end

        -- Calculate column width dynamically
        local columnWidth = 90  -- Set a default column width
        local totalWidth = 20 + (numColumns * columnWidth)  -- Calculate required width

        -- Adjust UI window width based on required column space
        local padding = 40
        local windowWidth = math.min(math.max(totalWidth + padding, 750), screenWidth * 0.95)
        local windowHeight = math.min(0.7 * screenHeight, 650)  -- Height remains dynamic but capped

        control = wm:CreateTopLevelWindow("SkillLinesUI")
        control:SetDimensions(windowWidth, windowHeight)
        control:SetMovable(true)
        control:SetMouseEnabled(true)
        control:SetHidden(true)

        -- Save position when moved
        control:SetHandler("OnMoveStop", function() SaveWindowPosition(control) end)

        -- Restore saved position
        RestoreWindowPosition(control)

        local bg = wm:CreateControl(nil, control, CT_BACKDROP)
        bg:SetAnchorFill(control)
        bg:SetCenterColor(0, 0, 0, 0.8)

        -- Font Scaling - Keep text readable but compact
        local baseFontSize = 16  
        local scaleFactor = windowWidth / 1600  
        local fontSize = math.max(math.min(baseFontSize * scaleFactor, 16), 14)  

        -- Title
        local title = wm:CreateControl(nil, control, CT_LABEL)
        title:SetText("Skill Lines Tracker")
        title:SetAnchor(TOP, control, TOP, 0, 5)
        title:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize + 2))

        local container = wm:CreateControl(nil, control, CT_CONTROL)
        container:SetAnchor(TOPLEFT, control, TOPLEFT, 10, 30)
        container:SetDimensions(windowWidth - 20, windowHeight - 50)

        -- Adjust header placement dynamically
        local headerXOffset = 130
        for _, category in ipairs(skillLines) do
            for _, skillName in ipairs(category.names) do
                local skillHeader = wm:CreateControl(nil, container, CT_LABEL)
                skillHeader:SetText(skillName)
                skillHeader:SetAnchor(TOPLEFT, container, TOPLEFT, headerXOffset, 5)
                skillHeader:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", fontSize - 2))
                skillHeader:SetDimensions(columnWidth, 25)  
                skillHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)  
                skillHeader:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)  
                headerXOffset = headerXOffset + columnWidth
            end
        end

        -- Adjust row spacing
        local dataYOffset = 30
        for _, charData in ipairs(GetStoredCharacterData()) do
            local charControl = wm:CreateControl(nil, container, CT_LABEL)
            charControl:SetText(charData.name)
            charControl:SetAnchor(TOPLEFT, container, TOPLEFT, 10, dataYOffset)
            charControl:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", fontSize))
            charControl:SetDimensions(140, 25)  
            charControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            charControl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)  

            local xOffset = 130
            for _, category in ipairs(skillLines) do
                for _, skillName in ipairs(category.names) do
                    local skillControl = wm:CreateControl(nil, container, CT_LABEL)
                    local rank = GetCharacterSkillLevels(charData.name, skillName)
                    skillControl:SetText(tostring(rank))
                    skillControl:SetAnchor(TOPLEFT, container, TOPLEFT, xOffset, dataYOffset)
                    skillControl:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", fontSize))
                    skillControl:SetDimensions(columnWidth, 25)  
                    skillControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                    skillControl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)  
                    xOffset = xOffset + columnWidth
                end
            end
            dataYOffset = dataYOffset + 28
        end
    end
end




-- Show or Hide UI Based on Scene
local function OnSkillsSceneStateChange(oldState, newState)
    local control = WINDOW_MANAGER:GetControlByName("SkillLinesUI")
    if control then
        if newState == SCENE_SHOWN then
            UpdateCharacterSkillLevels()
            CreateSkillTable() -- Refresh the table when the skills scene is shown
            control:SetHidden(false)
        else
            control:SetHidden(true)
        end
    end
end

-- Event Handler
local function OnPlayerActivated()
    EVENT_MANAGER:RegisterForEvent(SkillLines.name, EVENT_SKILL_LINE_ADDED, function()
        UpdateCharacterSkillLevels()
        EVENT_MANAGER:UnregisterForEvent(SkillLines.name, EVENT_SKILL_LINE_ADDED)
    end)
    CreateSkillTable() -- Refresh the table when the player logs in
end

-- Register Addon
local function OnAddOnLoaded(event, addonName)
    if addonName ~= SkillLines.name then return end

    -- Use only account-wide storage and ensure proper structure
    SkillLines.savedData = ZO_SavedVars:NewAccountWide("SkillLinesSavedVars", 1, nil, {
        ["version"] = 1,
        ["EU Megaserver"] = {},
        ["NA Megaserver"] = {},
        windowPosition = { left = 100, top = 100 }
    })

    EVENT_MANAGER:RegisterForEvent(SkillLines.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    local skillsScene = SCENE_MANAGER:GetScene("skills")
    skillsScene:RegisterCallback("StateChange", OnSkillsSceneStateChange)
end


EVENT_MANAGER:RegisterForEvent(SkillLines.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)