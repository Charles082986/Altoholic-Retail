local addonName = "Altoholic"
local addon = _G[addonName]
local colors = addon.Colors

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Setup localized names for all the text strings
AltoTasksOptionsTextTask:SetText(L["Task"]..":")
AltoTasksOptionsTextNewTask:SetText(L["New"]..":")
AltoTasksOptionsTextTaskType:SetText(L["Task Type"]..":")
AltoTasksOptionsTextExpansionName:SetText(L["Expansion"]..":")
AltoTasksOptionsTextTaskTarget:SetText(L["Target"]..":")
AltoTasksOptionsTextMinimumLevel:SetText(L["Minimum Level"]..":")
AltoTasksOptionsTextFaction:SetText(L["FILTER_FACTIONS"]..":")
AltoTasksOptionsTextFootnote:SetText("For instructions, check this page: "..colors.green.."https://github.com/teelolws/Altoholic-Retail/wiki/Grids-Tasks-Manual")
AltoTasksOptions_AddButton:SetText("Add")
AltoTasksOptions_DeleteButton:SetText("Delete")

-- Widen the dropdown menus
UIDropDownMenu_SetWidth(AltoTasksOptions_TaskTypeDropdown, 200, 0)
UIDropDownMenu_SetWidth(AltoTasksOptions_TaskExpansionDropdown, 200, 0)
UIDropDownMenu_SetWidth(AltoTasksOptions_TaskTargetDropdown, 200, 0)
UIDropDownMenu_SetWidth(AltoTasksOptions_TaskNameDropdown, 200, 0)
	
-- Get the array of saved tasks
if not Altoholic.db.global.Tasks then
    Altoholic.db.global.Tasks = {}
end
local tasks = Altoholic.db.global.Tasks
local currentTask = nil

-- Data Structure:
-- array Tasks
-- > Name = STRING
-- > ID = NUMBER UNIQUE PRIMARY KEY
-- > Category = ENUM {Daily Quest / Dungeon / Raid / Dungeon Boss / Raid Boss / Profession Cooldown / Rare Spawn}
-- > Expansion = ENUM {Classic / TBC / WOTLK / Cataclysm / MOP / WOD / Legion / BFA / Shadowlands}
-- > Target = NUMBER variable {instanceID / questID / bossID / recipeID}
-- > (INTERNAL) Difficulty = ENUM {heroic / mythic} - for dungeons only

local expansions = {"Classic", "TBC", "WOTLK", "Cataclysm", "MOP", "WOD", "Legion", "BFA"}

-- Disable all the task type / expansion / target / minlvl / faction filter fields
UIDropDownMenu_DisableDropDown(AltoTasksOptions_TaskTypeDropdown)
UIDropDownMenu_DisableDropDown(AltoTasksOptions_TaskExpansionDropdown)
UIDropDownMenu_DisableDropDown(AltoTasksOptions_TaskTargetDropdown)
AltoTasksOptions_TaskMinimumLevelEditBox:SetEnabled(false)
AltoTasksOptions_TaskHordeCheckbox:SetEnabled(false)
AltoTasksOptions_TaskAllianceCheckbox:SetEnabled(false)

local function GetTaskByID(id)
    for _, task in pairs(tasks) do
        if id == task.ID then
            return task
        end
    end
    return nil
end

-- ==============================
-- ==============================
-- == Task Target Dropdown Menu Functions ==
-- ==============================
-- ==============================
local TaskOptionsScanningTooltip = CreateFrame("GameTooltip", "TaskOptionsScanningTooltip", UIParent, "GameTooltipTemplate")
-- Code from https://www.wowinterface.com/forums/showthread.php?t=46934
local QuestTitleFromID = setmetatable({}, { __index = function(t, id)
	TaskOptionsScanningTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	TaskOptionsScanningTooltip:SetHyperlink("quest:"..id)
	local title = TaskOptionsScanningTooltipTextLeft1:GetText()
	TaskOptionsScanningTooltip:Hide()
	if title and title ~= RETRIEVING_DATA then
		t[id] = title
		return title
	end
end })

local function TaskTargetDropdown_SetSelectedDungeon(self, instanceID, difficulty)
    -- Make the dropdown have the name of the selected target
    local name = EJ_GetInstanceInfo(instanceID)
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTargetDropdown, name)
    
    -- Save the selected target
    currentTask.Target = instanceID
    currentTask.Difficulty = difficulty
end

local function TaskTargetDropdown_SetSelectedDungeonBoss(self, arg1, difficulty)     
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTargetDropdown, arg1["creatureName"].." "..difficulty)
    
    currentTask.Target = arg1
    currentTask.Difficulty = difficulty
    CloseDropDownMenus()
end

local function TaskTargetDropdown_SetSelectedDailyQuest(self, dailyQuestID, dailyQuestName)
    -- Make the dropdown have the name of the selected target
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTargetDropdown, dailyQuestName)
    
    -- Save the selected target
    currentTask.Target = dailyQuestID
end

-- DataStore only saves the name of the cooldown, not any associated spell ID, so have to store the target as a string and do string matching in grids
local function TaskTargetDropdown_SetSelectedProfessionCooldown(self, cooldownName)
    -- Make the dropdown have the name of the selected target
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTargetDropdown, cooldownName)
    
    -- Save the selected target
    currentTask.Target = cooldownName
end

local raidDifficultyIDs = {
    3, -- 10p normal
    4, -- 25p normal
    5, -- 10p heroic
    6, -- 25p heroic
    9, -- 40p
    14, -- flex normal
    15, -- flex heroic
    16, -- 20p mythic
    148, -- 20p
}

local function TaskTargetDropdown_Opened(frame, level, menuList)
    -- Populate targets with different items depending on the category
    local category = currentTask.Category
    local expansion = currentTask.Expansion
    
    if category == "Dungeon" then
        -- Lets populate it with a list of Dungeons pulled from the Encounter Journal
        
        -- convert the expansion name to an expansion ID
        local expansionID = 1
        for k,v in pairs(expansions) do
            if (expansion == v) then
                expansionID = k
            end
        end

        -- Set the Encounter Journal to be checking that expansion                                             
        EJ_SelectTier(expansionID)
        
        -- Pull all the dungeon names for that expansion out of the Encounter Journal
        local index = 1
        local instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty = EJ_GetInstanceByIndex(index, false)
        while instanceID do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name.." (Heroic)"
            info.func = TaskTargetDropdown_SetSelectedDungeon
            info.arg1 = instanceID
            info.arg2 = "heroic"
            UIDropDownMenu_AddButton(info)
            info.text = name.." (Mythic)"
            info.arg2 = "mythic"
            UIDropDownMenu_AddButton(info)
            index = index + 1
            instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty = EJ_GetInstanceByIndex(index, false)
        end
    end
    
    if category == "Raid" then
        local expansionID = 1
        for k,v in pairs(expansions) do
            if (expansion == v) then
                expansionID = k
            end
        end

        -- Set the Encounter Journal to be checking that expansion                                             
        EJ_SelectTier(expansionID)
        
        -- Pull all the raid names for that expansion out of the Encounter Journal
        local index = 1
        local instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty = EJ_GetInstanceByIndex(index, true)
        while instanceID do
            EJ_SelectInstance(instanceID)
            local info = UIDropDownMenu_CreateInfo()
            info.arg1 = instanceID
            info.func = TaskTargetDropdown_SetSelectedDungeon
            if expansionID == 1 then
                -- Classic doesn't handle difficultyIDs properly, making a special case for them
                info.text = name
                info.arg2 = "classic"
                UIDropDownMenu_AddButton(info)
            else
                for _, difficultyID in pairs(raidDifficultyIDs) do
                    if EJ_IsValidInstanceDifficulty(difficultyID) then
                        local difficultyName = GetDifficultyInfo(difficultyID)
                        info.text = name.." "..difficultyName
                        info.arg2 = difficultyName
                        UIDropDownMenu_AddButton(info)
                    end
                end
            end
            index = index + 1
            instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty = EJ_GetInstanceByIndex(index, true)
        end
    end
    
    if category == "Dungeon Boss" then      
        -- convert the expansion name to an expansion ID
        local expansionID = 1
        for k,v in pairs(expansions) do
            if (expansion == v) then
                expansionID = k
            end
        end
        
        -- Set the Encounter Journal to be checking that expansion                                             
        EJ_SelectTier(expansionID)

        if level == 1 then    
            -- Pull all the dungeon names for that expansion out of the Encounter Journal
            local index = 1
            local instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty = EJ_GetInstanceByIndex(index, false)
            while instanceID do
                local info = UIDropDownMenu_CreateInfo()
                info.hasArrow = true
                info.text = name.." (Heroic)"
                info.menuList = { ["instanceID"] = instanceID, ["difficulty"] = "heroic" }
                UIDropDownMenu_AddButton(info)
                info.text = name.." (Mythic)"
                info.menuList = { ["instanceID"] = instanceID, ["difficulty"] = "mythic" }
                UIDropDownMenu_AddButton(info)
                index = index + 1
                instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty = EJ_GetInstanceByIndex(index, false)
            end
        else
            -- menuList is the instanceID selected and difficulty
            local instanceID = menuList["instanceID"]
            EJ_SelectInstance(instanceID)
            local difficulty = menuList["difficulty"]
            -- Pull all the boss names for the selected instanceID out of the Encounter Journal
            local index = 1
            local name, description, bossID, rootSectionID, link, journalInstanceID, dungeonEncounterID, _ = EJ_GetEncounterInfoByIndex(index, instanceID)
            while (name) do
                local info = UIDropDownMenu_CreateInfo()
                info.func = TaskTargetDropdown_SetSelectedDungeonBoss
                info.arg1 = { ["instanceID"] = instanceID, ["creatureName"] = name }
                info.arg2 = difficulty  
                if difficulty == "heroic" then
                    info.text = name.." (Heroic)"
                elseif difficulty == "mythic" then
                    info.text = name.." (Mythic)"
                end
                UIDropDownMenu_AddButton(info, level)
                
                index = index + 1
                name, description, bossID, rootSectionID, link, journalInstanceID, dungeonEncounterID, _ = EJ_GetEncounterInfoByIndex(index, instanceID)
            end
        end        
    end

    if category == "Raid Boss" then      
        -- convert the expansion name to an expansion ID
        local expansionID = 1
        for k,v in pairs(expansions) do
            if (expansion == v) then
                expansionID = k
            end
        end
        
        -- Set the Encounter Journal to be checking that expansion                                             
        EJ_SelectTier(expansionID)

        if level == 1 then    
            -- Pull all the raid names for that expansion out of the Encounter Journal
            local index = 1
            local instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty = EJ_GetInstanceByIndex(index, true)
            while instanceID do
                EJ_SelectInstance(instanceID)
                local info = UIDropDownMenu_CreateInfo()
                info.hasArrow = true
                if expansionID == 1 then
                    info.text = name
                    info.menuList = { ["instanceID"] = instanceID, ["difficulty"] = "classic" }
                    UIDropDownMenu_AddButton(info)
                else
                    for _, difficultyID in pairs(raidDifficultyIDs) do
                        if EJ_IsValidInstanceDifficulty(difficultyID) then
                            local difficultyName = GetDifficultyInfo(difficultyID)
                            info.text = name.." "..difficultyName
                            info.menuList = { ["instanceID"] = instanceID, ["difficulty"] = difficultyName }
                            UIDropDownMenu_AddButton(info)
                        end
                    end
                end
                index = index + 1
                instanceID, name, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty = EJ_GetInstanceByIndex(index, true)
            end
        else
            -- menuList is the instanceID selected and difficulty
            local instanceID = menuList["instanceID"]
            EJ_SelectInstance(instanceID)
            local difficulty = menuList["difficulty"]
            -- Pull all the boss names for the selected instanceID out of the Encounter Journal
            local index = 1
            local name, description, bossID, rootSectionID, link, journalInstanceID, dungeonEncounterID, _ = EJ_GetEncounterInfoByIndex(index, instanceID)
            while (name) do
                local info = UIDropDownMenu_CreateInfo()
                info.func = TaskTargetDropdown_SetSelectedDungeonBoss
                info.arg1 = { ["instanceID"] = instanceID, ["creatureName"] = name }
                info.arg2 = difficulty
                if expansionID == 1 then
                    info.text = name
                else
                    info.text = name.." "..difficulty
                end
                UIDropDownMenu_AddButton(info, level)
                
                index = index + 1
                name, description, bossID, rootSectionID, link, journalInstanceID, dungeonEncounterID, _ = EJ_GetEncounterInfoByIndex(index, instanceID)
            end
        end        
    end
        
    if category == "Daily Quest" then
        
        local a = false
        -- Lets populate this with daily quests already completed by the current character this day, pulled from Datastore_Quests1
        for _, daily in pairs(DataStore:GetDailiesHistory(DataStore:GetCharacter())) do 
            a = true
            local info = UIDropDownMenu_CreateInfo()
            info.text = daily.title
            info.func = TaskTargetDropdown_SetSelectedDailyQuest
            info.arg1 = daily.id
            info.arg2 = daily.title
            UIDropDownMenu_AddButton(info)
        end
        
        if not a then
            print("Altoholic: The Daily Quest dropdown will only list Daily Quests you have completed today on the character you are currently playing.")
        end
    end
    
    if category == "Profession Cooldown" then
        local a = false
        
        for _, profession in pairs(DataStore:GetProfessions(DataStore:GetCharacter())) do
            if DataStore:GetNumActiveCooldowns(profession) > 0 then
                for i = 1, DataStore:GetNumActiveCooldowns(profession) do
                    local name, expiresIn, resetsIn, expiresAt = DataStore:GetCraftCooldownInfo(profession, i)
                    a = true
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = name
                    info.func = TaskTargetDropdown_SetSelectedProfessionCooldown
                    info.arg1 = name
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
        
        if not a then
            print("Altoholic: The Profession Cooldown dropdown will only list cooldowns you actually have on cooldown on the character you are currently playing.")
        end
    end
end

-- Converts the targetID to its associated string, based on the category
local function getCurrentTargetName()
    local category = currentTask.Category
    local expansion = currentTask.Expansion
    local targetID = currentTask.Target
    
    if not targetID then return nil end
        
    if (category == "Dungeon") or (category == "Raid") then
        -- trim out all the extra parameters returned, we just want the name here
        local name = EJ_GetInstanceInfo(targetID)
        return name
    end
    
    if category == "Daily Quest" then
        local name = QuestTitleFromID[targetID]
        return name
    end
    
    if category == "Profession Cooldown" then
        return targetID
    end
    
    if (category == "Dungeon Boss") or (category == "Raid Boss") then
        return targetID["creatureName"]
    end
    
    AltoholicTabGrids:Update()        
end

-- ==============================
-- ==============================
-- == Task Expansion Dropdown Menu Functions ==
-- ==============================
-- ==============================
local function TaskExpansionDropdown_SetSelected(self, expansionName)
    -- Make the dropdown have the name of the selected expansion
    UIDropDownMenu_SetText(AltoTasksOptions_TaskExpansionDropdown, expansionName)
    
    -- Save the selected task expansion
    currentTask.Expansion = expansionName
    
    -- Wipe any selected target
    currentTask.Target = nil
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTargetDropdown, "")
    
    -- If both a category and an expansion are selected, enable the target dropdown
    if currentTask.Category then
        UIDropDownMenu_EnableDropDown(AltoTasksOptions_TaskTargetDropdown)
    end        
end

local function TaskExpansionDropdown_Opened(frame, level, menuList)
    for _, expansion in pairs(expansions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = expansion
        info.func = TaskExpansionDropdown_SetSelected
        info.arg1 = expansion
        UIDropDownMenu_AddButton(info)
    end
end

-- ==============================
-- ==============================
-- == Task Type Dropdown Menu Functions ==
-- ==============================
-- ==============================
local function TaskTypeDropdown_SetSelected(self, categoryName)
    -- Make the dropdown have the name of the selected category
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTypeDropdown, categoryName)
    
    -- Save the selected category
    currentTask.Category = categoryName
    
    -- Daily Quests and Profession Cooldowns don't need an expansion. 
    -- So, clear the expansion, disable it, and enable the target dropdown
    if (categoryName == "Daily Quest") or (categoryName == "Profession Cooldown") then
        UIDropDownMenu_DisableDropDown(AltoTasksOptions_TaskExpansionDropdown)
        UIDropDownMenu_SetText(AltoTasksOptions_TaskExpansionDropdown, "")
        currentTask.Expansion = nil
        UIDropDownMenu_EnableDropDown(AltoTasksOptions_TaskTargetDropdown)        
    
    -- For Dungeons and Raids, an expansion is required
    else
        UIDropDownMenu_EnableDropDown(AltoTasksOptions_TaskExpansionDropdown)
        if currentTask.Expansion then
            -- If both a category and an expansion are selected, enable the target dropdown
            UIDropDownMenu_EnableDropDown(AltoTasksOptions_TaskTargetDropdown)
        end
    end
    
    -- Wipe any selected target
    currentTask.Target = nil
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTargetDropdown, "")
end

local function TaskTypeDropdown_Opened(frame, level, menuList)
    local currentTaskType = currentTask.Category
    
    local categories = {"Daily Quest", "Dungeon", "Raid", "Dungeon Boss", "Raid Boss", "Profession Cooldown", "Rare Spawn"}
    
    for _, category in pairs(categories) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = category
        info.func = TaskTypeDropdown_SetSelected
        info.arg1 = category
        UIDropDownMenu_AddButton(info)
    end
end

-- ==============================
-- ==============================
-- == Task Name Dropdown Menu Functions ==
-- ==============================
-- ==============================

local function TaskNameDropdown_SetSelected(self, id)
    -- Make the dropdown have the name of the selected task
    UIDropDownMenu_SetText(AltoTasksOptions_TaskNameDropdown, GetTaskByID(id).Name)
    currentTask = GetTaskByID(id)
    
    -- Enable all the other dropdowns and fields
    UIDropDownMenu_EnableDropDown(AltoTasksOptions_TaskTypeDropdown)
    UIDropDownMenu_EnableDropDown(AltoTasksOptions_TaskExpansionDropdown)
    AltoTasksOptions_TaskMinimumLevelEditBox:SetEnabled(true)
    AltoTasksOptions_TaskHordeCheckbox:SetEnabled(true)
    AltoTasksOptions_TaskAllianceCheckbox:SetEnabled(true)
    
    -- Populate them
    addon:DDM_Initialize(AltoTasksOptions_TaskTypeDropdown, TaskTypeDropdown_Opened)
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTypeDropdown, currentTask.Category)
    addon:DDM_Initialize(AltoTasksOptions_TaskExpansionDropdown, TaskExpansionDropdown_Opened)
    UIDropDownMenu_SetText(AltoTasksOptions_TaskExpansionDropdown, currentTask.Expansion)
    addon:DDM_Initialize(AltoTasksOptions_TaskTargetDropdown, TaskTargetDropdown_Opened)
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTargetDropdown, getCurrentTargetName())

    -- Target Dropdown should only be enabled if there is a category and expansion selected
    -- OR the selected category is a category that doesn't require an expansion
    if currentTask.Category and ((currentTask.Category == "Daily Quest") or (currentTask.Category == "Profession Cooldown")) then 
        UIDropDownMenu_DisableDropDown(AltoTasksOptions_TaskExpansionDropdown)
        UIDropDownMenu_EnableDropDown(AltoTasksOptions_TaskTargetDropdown)
    elseif currentTask.Category and currentTask.Expansion then
        UIDropDownMenu_EnableDropDown(AltoTasksOptions_TaskTargetDropdown)
    else
        UIDropDownMenu_DisableDropDown(AltoTasksOptions_TaskTargetDropdown)
    end
    
end

local function TaskNameDropdown_Opened(frame, level, menuList)
    for _, task in pairs(tasks) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = task.Name
        info.func = TaskNameDropdown_SetSelected
        info.arg1 = task.ID
        UIDropDownMenu_AddButton(info)
    end
end

-- ==============================
-- ==============================
-- == Initialization functions ==
-- ==============================
-- ==============================

-- Check if the array of saved tasks is empty
-- > if it is, disable the task field
if #tasks == 0 then
    UIDropDownMenu_DisableDropDown(AltoTasksOptions_TaskNameDropdown)
else
-- > otherwise, populate it
    addon:DDM_Initialize(AltoTasksOptions_TaskNameDropdown, TaskNameDropdown_Opened)
end

-- ==============================
-- ==============================
-- == Add Button functions ==
-- ==============================
-- ==============================

-- Crude primary key implementation
local function GetNextPrimaryKey()
    local i = 0
    local taken = true
    while(taken) do
        i = i + 1
        taken = false
        for _, task in pairs(tasks) do
            if task.ID == i then
                taken = true
            end
        end
    end
    return i
end

-- function to handle the add button being pushed
local function AddClicked()
    -- Check integrity of the TaskNameEditBox
    local taskName = AltoTasksOptions_TaskNameEditBox:GetText()
    
    if #taskName < 1 then
        print("Error: Task Name cannot be empty")
        return
    end
    
    local id = GetNextPrimaryKey()
    
    -- Add new task name to saved variables
    table.insert(tasks, {["Name"] = taskName, ["ID"] = id,})
    
    -- If this was the first task name, initialize the dropdown
    if #tasks == 1 then
        addon:DDM_Initialize(AltoTasksOptions_TaskNameDropdown, TaskNameDropdown_Opened)    
    end
    
    -- Set the new task as the currently selected task
    TaskNameDropdown_SetSelected(nil, id)
    
    AltoholicTabGrids:Update()
end
AltoTasksOptions_AddButton:SetScript("OnClick", AddClicked)

-- ==============================
-- ==============================
-- == Delete Button functions ==
-- ==============================
-- ==============================
-- function to handle the add button being pushed
local function DeleteClicked()

    -- Check that a task is actually selected
    if not currentTask then return end
    
    -- Remove the currentTask from the tasks table
    local id = currentTask.ID
    for k,v in pairs(tasks) do
        if v.ID == id then
            table.remove(tasks, k)
            break
        end
    end
    
    -- Clear the other dropdowns and such
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTypeDropdown, nil)
    UIDropDownMenu_SetText(AltoTasksOptions_TaskExpansionDropdown, nil)
    UIDropDownMenu_SetText(AltoTasksOptions_TaskTargetDropdown, nil)

    AltoholicTabGrids:Update()
end
AltoTasksOptions_DeleteButton:SetScript("OnClick", DeleteClicked)

-- ==============================
-- ==============================

-- ==============================
-- ==============================

-- function to handle a task being selected 