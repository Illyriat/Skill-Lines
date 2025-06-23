 -- Ingame script to enable console Mode on PC
-- /script SetCVar("ForceConsoleFlow.2", "1")



SkillLines = {}
SkillLines.name = "SkillLines"
SkillLines.savedData = nil

-- Skill lines to track
local skillLines = {
    -- { category = "Class" , skillType = SKILL_TYPE_CLASS, names = {"Dragonknight", "Nightblade", "Sorcerer", "Templar", "Warden", "Necromancer"} },
    { category = "Weapon", skillType = SKILL_TYPE_WEAPON, names = {"Two Handed", "One Hand and Shield", "Dual Wield", "Bow", "Destruction Staff", "Restoration Staff"} },
    { category = "Armor", skillType = SKILL_TYPE_ARMOR, names = {"Light Armor", "Medium Armor", "Heavy Armor"} },
    { category = "World", skillType = SKILL_TYPE_WORLD, names = {"Excavation", "Legerdemain", "Scrying", "Soul Magic", "Werewolf", "Vampire"} },
    { category = "Guild", skillType = SKILL_TYPE_GUILD, names = {"Dark Brotherhood", "Fighters Guild", "Mages Guild", "Psijic Order", "Thieves Guild", "Undaunted"} },
    { category = "Alliance War", skillType = SKILL_TYPE_AVA, names = {"Assault", "Support"} },
    { category = "Racial", skillType = SKILL_TYPE_RACIAL, names = {"Nord Skills", "Redguard Skills", "Orc Skills", "Dark Elf Skills", "High Elf Skills", "Wood Elf Skills", "Argonian Skills", "Khajiit Skills", "Breton Skills"} },
    { category = "Craft", skillType = SKILL_TYPE_TRADESKILL, names = {"Alchemy", "Blacksmithing", "Clothing", "Enchanting", "Jewelry Crafting", "Provisioning", "Woodworking"} }
}

-- Utility function to clean character names (removes ^Fx or ^Mx suffix)
local function CleanCharacterName(charName)
    return charName:gsub("%^%a+", "") -- Removes ^Fx or ^Mx
end

-- Retrieve all stored character names from SavedVars for the current megaserver
local function GetStoredCharacterData()
    local characters = {}
    local serverName = SkillLines.activeServer or GetWorldName()
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
    d("SkillLines Debug Save Trigger: "..GetUnitName("player").." on "..GetWorldName())
    local charName = CleanCharacterName(GetUnitName("player"))
    local accountName = GetDisplayName()
    local serverName = GetWorldName()  -- Use only actual logged-in server!

    if not charName or charName == "" then return end

    -- Ensure SavedVars structure exists
    if not SkillLines.savedData then SkillLines.savedData = {} end
    if not SkillLines.savedData[serverName] then SkillLines.savedData[serverName] = {} end
    if not SkillLines.savedData[serverName][accountName] then SkillLines.savedData[serverName][accountName] = {} end
    if not SkillLines.savedData[serverName][accountName][charName] then
        SkillLines.savedData[serverName][accountName][charName] = {}
    end

    d("SkillLines Debug: Updating skill data for " .. charName .. " on server " .. serverName)

    for _, category in ipairs(skillLines) do
        for _, skillName in ipairs(category.names) do
            local skillType = category.skillType
            local numSkillLines = GetNumSkillLines(skillType)

            for skillIndex = 1, numSkillLines do
                local name, rank, discovered = GetSkillLineInfo(skillType, skillIndex)
                if name and name == skillName then
                    if discovered then
                        SkillLines.savedData[serverName][accountName][charName][skillName] = rank
                    else
                        SkillLines.savedData[serverName][accountName][charName][skillName] = "-"
                    end
                end
            end
        end
    end
end




-- Retrieve stored skill levels
local function GetCharacterSkillLevels(charName, skillName)
    local accountName = GetDisplayName()
    local serverName = SkillLines.activeServer or GetWorldName()
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


local function RefreshSkillData()
    local control = WINDOW_MANAGER:GetControlByName("SkillLinesUI")
    if not control then return end

    -- Clear old labels
    for categoryName, labelList in pairs(control.categoryLabels) do
        for _, label in ipairs(labelList) do
            label:SetHidden(true)
        end
        -- Reset the list (we'll rebuild it)
        control.categoryLabels[categoryName] = {}
    end

    -- Rebuild data
    local characters = GetStoredCharacterData()

    for i, category in ipairs(skillLines) do
        local container = control.categoryContainers[category.category]
        local labelList = control.categoryLabels[category.category]

        local yOffset = 30
        if #characters > 0 then
            for _, charData in ipairs(characters) do
                local nameLabel = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
                nameLabel:SetText(charData.name)
                nameLabel:SetAnchor(TOPLEFT, container, TOPLEFT, 10, yOffset)
                nameLabel:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
                nameLabel:SetDimensions(120, 25)
                table.insert(labelList, nameLabel)

                local xOffset = 130
                local columnWidth = 100
                for _, skillName in ipairs(category.names) do
                    local rankLabel = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
                    local rank = GetCharacterSkillLevels(charData.name, skillName) or "-"
                    rankLabel:SetText(tostring(rank))
                    rankLabel:SetAnchor(TOPLEFT, container, TOPLEFT, xOffset, yOffset)
                    rankLabel:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
                    rankLabel:SetDimensions(columnWidth, 25)
                    rankLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                    xOffset = xOffset + columnWidth
                    table.insert(labelList, rankLabel)
                end
                yOffset = yOffset + 28
            end
        else
            local noCharsLabel = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
            noCharsLabel:SetText("No character data available")
            noCharsLabel:SetAnchor(CENTER, container, CENTER, 0, 0)
            noCharsLabel:SetFont("$(MEDIUM_FONT)|16|soft-shadow-thin")
            table.insert(labelList, noCharsLabel)
        end
    end

    -- Reset to first tab
    if #skillLines > 0 and control.ShowCategory then
        control.ShowCategory(skillLines[1].category)
    end
end




-- Updated CreateSkillTable with Tabs (fixed button creation, full control cleanup, named title and tab buttons to avoid nil errors)
local function CreateSkillTable()
    local wm = WINDOW_MANAGER

    -- Check if the window already exists
    local control = wm:GetControlByName("SkillLinesUI")
    if control then return end -- Already created

    -- CREATE NEW WINDOW
    control = wm:CreateTopLevelWindow("SkillLinesUI")
    control:SetDimensions(math.min(1050, GuiRoot:GetWidth() * 0.95), math.min(700, GuiRoot:GetHeight() * 0.7))
    control:SetMovable(true)
    control:SetMouseEnabled(true)
    control:SetHidden(true)
    control:SetHandler("OnMoveStop", function() SaveWindowPosition(control) end)
    RestoreWindowPosition(control)

    -- BACKGROUND
    local bg = wm:CreateControl("$(parent)BG", control, CT_BACKDROP)
    bg:SetAnchorFill(control)
    bg:SetCenterColor(0, 0, 0, 0.8)

    -- TITLE
    local title = wm:CreateControl("$(parent)Title", control, CT_LABEL)
    title:SetText("Skill Lines Tracker")
    title:SetAnchor(TOP, control, TOP, 0, 5)
    title:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")

    -- SERVER SWITCH BUTTONS
    local euButton = wm:CreateControlFromVirtual("$(parent)EUButton", control, "ZO_DefaultButton")
    euButton:SetDimensions(100, 25)
    euButton:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -210, -10)
    euButton:SetText("EU Server")
    euButton:SetHandler("OnClicked", function()
        SkillLines.activeServer = "EU Megaserver"
        RefreshSkillData()
    end)

    local naButton = wm:CreateControlFromVirtual("$(parent)NAButton", control, "ZO_DefaultButton")
    naButton:SetDimensions(100, 25)
    naButton:SetAnchor(LEFT, euButton, RIGHT, 10, 0)
    naButton:SetText("NA Server")
    naButton:SetHandler("OnClicked", function()
        SkillLines.activeServer = "NA Megaserver"
        RefreshSkillData()
    end)

    -- Tabs and Containers
    control.tabButtons = {}
    control.categoryContainers = {}
    control.categoryLabels = {} -- NEW: Tracks created labels

    local tabX = 10

    local function ShowCategory(categoryName)
        for name, container in pairs(control.categoryContainers) do
            container:SetHidden(name ~= categoryName)
        end
    end
    control.ShowCategory = ShowCategory

    for i, category in ipairs(skillLines) do
        -- Tab Button
        local tab = wm:CreateControlFromVirtual("$(parent)Tab"..category.category, control, "ZO_DefaultButton")
        tab:SetDimensions(100, 25)
        tab:SetAnchor(TOPLEFT, control, TOPLEFT, tabX, 30)
        tab:SetText(category.category)
        tab:SetHandler("OnClicked", function()
            ShowCategory(category.category)
        end)
        control.tabButtons[#control.tabButtons + 1] = tab
        tabX = tabX + 105

        -- Container
        local container = wm:CreateControl("$(parent)Container"..category.category, control, CT_CONTROL)
        container:SetAnchor(TOPLEFT, control, TOPLEFT, 10, 60)
        container:SetDimensions(control:GetWidth() - 20, control:GetHeight() - 70)
        container:SetHidden(i ~= 1)
        control.categoryContainers[category.category] = container

        -- Initialize label tracking
        control.categoryLabels[category.category] = {}

        -- Headers
        local headerX = 130
        local columnWidth = 100

        for _, skillName in ipairs(category.names) do
            local header = wm:CreateControl(nil, container, CT_LABEL)
            header:SetText(skillName)
            header:SetAnchor(TOPLEFT, container, TOPLEFT, headerX, 5)
            header:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
            header:SetDimensions(columnWidth, 25)
            header:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            headerX = headerX + columnWidth
        end
    end

    -- Populate initial data
    RefreshSkillData()
end




-- Show or Hide UI Based on Scene
local function OnSkillsSceneStateChange(oldState, newState)
    local control = WINDOW_MANAGER:GetControlByName("SkillLinesUI")

    if newState == SCENE_SHOWN then
        UpdateCharacterSkillLevels()

        if not control then
            CreateSkillTable()
            control = WINDOW_MANAGER:GetControlByName("SkillLinesUI")
        end

        if control then
            control:SetHidden(false)
        end
    else
        if control then
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
    UpdateCharacterSkillLevels() -- Refresh the table when the player logs in
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