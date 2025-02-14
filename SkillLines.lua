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

-- Create UI Table
local function CreateSkillTable()
    local wm = WINDOW_MANAGER
    local control = wm:GetControlByName("SkillLinesUI")

    if not control then
        control = wm:CreateTopLevelWindow("SkillLinesUI")
        control:SetDimensions(1600, 880)
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        control:SetMovable(true)
        control:SetMouseEnabled(true)
        control:SetHidden(true) -- UI starts hidden

        local bg = wm:CreateControl(nil, control, CT_BACKDROP)
        bg:SetAnchorFill(control)
        bg:SetCenterColor(0, 0, 0, 0.8)

        local title = wm:CreateControl(nil, control, CT_LABEL)
        title:SetText("Skill Lines Tracker")
        title:SetAnchor(TOP, control, TOP, 0, 10)
        title:SetFont("ZoFontWinH2")

        local container = wm:CreateControl(nil, control, CT_CONTROL)
        container:SetAnchor(TOPLEFT, control, TOPLEFT, 10, 40)
        container:SetDimensions(1580, 750)

        local characters = GetStoredCharacterData()
        local headerXOffset = 250

        -- Create headers for each skill line
        for _, category in ipairs(skillLines) do
            for _, skillName in ipairs(category.names) do
                local skillHeader = wm:CreateControl(nil, container, CT_LABEL)
                skillHeader:SetText(skillName)
                skillHeader:SetAnchor(TOPLEFT, container, TOPLEFT, headerXOffset, 10)
                skillHeader:SetFont("ZoFontWinH4")
                headerXOffset = headerXOffset + 130
            end
        end

        -- Populate the table with character data
        local dataYOffset = 40
        for _, charData in ipairs(characters) do
            d("SkillLines Debug: Adding character to table: " .. charData.name)
            local charControl = wm:CreateControl(nil, container, CT_LABEL)
            charControl:SetText(charData.name)
            charControl:SetAnchor(TOPLEFT, container, TOPLEFT, 10, dataYOffset)
            charControl:SetFont("ZoFontWinH4")

            local xOffset = 250
            for _, category in ipairs(skillLines) do
                for _, skillName in ipairs(category.names) do
                    local skillControl = wm:CreateControl(nil, container, CT_LABEL)
                    local rank = GetCharacterSkillLevels(charData.name, skillName)
                    skillControl:SetText(tostring(rank))
                    skillControl:SetAnchor(TOPLEFT, container, TOPLEFT, xOffset, dataYOffset)
                    skillControl:SetFont("ZoFontWinH4")
                    xOffset = xOffset + 130
                end
            end
            dataYOffset = dataYOffset + 40
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
    })

    EVENT_MANAGER:RegisterForEvent(SkillLines.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    local skillsScene = SCENE_MANAGER:GetScene("skills")
    skillsScene:RegisterCallback("StateChange", OnSkillsSceneStateChange)
end


EVENT_MANAGER:RegisterForEvent(SkillLines.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)