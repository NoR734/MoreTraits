--- Useful Functions

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local statLimits = {
    panic = { CharacterStat.PANIC, 0, 100 },
    stress = { CharacterStat.STRESS, 0, 1 },
    fatigue = { CharacterStat.FATIGUE, 0, 1 },
    pain = { CharacterStat.PAIN, 0, 100 },
    boredom = { CharacterStat.BOREDOM, 0, 100 },
    unhappiness = { CharacterStat.UNHAPPINESS, 0, 100 },
    zombie_fever = { CharacterStat.ZOMBIE_FEVER, 0, 100 },
    sickness = { CharacterStat.SICKNESS, 0, 100 },
    anger = { CharacterStat.ANGER, 0, 1 },
    idleness = { CharacterStat.IDLENESS, 0, 1 },
    poison = { CharacterStat.POISON, 0, 100 },
    endurance = { CharacterStat.ENDURANCE, 0, 1 },
}

local commandTraitRequirements = {
    Vagabond = "Vagabond",
    Scrounger = "Scrounger",
    Antique = "AntiqueCollector",
    Incomprehensive = "Incomprehensive",
    Gourmand = "Gourmand",
    GraveRobber = "Graverobber",
    FastGimp = "Gimp",
    Immunocompromised = "Immunocompromised",
    GlassBody = "GlassBody",
    InfectPlayer = "Immunocompromised",
    EvasiveDodge = "Evasive",
    ApplyGordanite = "Gordanite",
    RevertGordanite = "Gordanite",
    ProwessGuns = "GunSpecialist",
}

local function canProcessTraitCommand(player, command)
    local trait = commandTraitRequirements[command]
    if not trait then
        return true
    end
    return player and player:hasTrait(trait)
end
local function tableContains(t, e)
    for _, value in pairs(t) do
        if value == e then
            return true
        end
    end
    return false
end


-- Function covers Vagabond, Scrounger, Antique
local function ProcessTraitLoot(player, args, modData, specificContainer)
    local gridSquare = getCell():getGridSquare(args.x, args.y, args.z)
    if not gridSquare then
        return
    end

    local objects = gridSquare:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local container = object:getContainer()

        -- Check if container exists AND (if specificContainer is nil OR matches the type)
        if container and (not specificContainer or container:getType() == specificContainer) then
            for _, itemType in ipairs(args.items) do
                local item = container:AddItem(itemType)
                if item then
                    sendAddItemToContainer(container, item)
                end
            end

            -- Set the specific ModData key (e.g., bVagbondRolled)
            object:getModData()[modData] = true
            object:transmitModData()
            break
        end
    end
end

-- Function covers Incomprehensive
local function ProcessTraitLootRemoval(player, args, modData)
    local gridSquare = getCell():getGridSquare(args.x, args.y, args.z)
    if not gridSquare then
        return
    end

    local objects = gridSquare:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local container = object:getContainer()

        if container then
            for _, itemType in ipairs(args.items) do
                local item = container:FindAndReturn(itemType)
                if item then
                    container:Remove(item)
                    sendRemoveItemFromContainer(container, item)
                end
            end
            object:getModData()[modData] = true
            object:transmitModData()
            break
        end
    end
end

-- Covers Gourmand
local function ProcessGourmand(player, args)
    local gridSquare = getCell():getGridSquare(args.x, args.y, args.z)
    if not gridSquare then
        return
    end

    local objects = gridSquare:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local container = object:getContainer()

        if container then
            for _, itemType in ipairs(args.items) do
                local items = container:getItems()
                for j = 0, items:size() - 1 do
                    local item = items:get(j)
                    if item and item:getFullType() == itemType and (item:isRotten() or not item:isFresh()) then
                        container:Remove(item)
                        sendRemoveItemFromContainer(container, item)

                        local newItem = container:AddItem(itemType)
                        if newItem then
                            sendAddItemToContainer(container, newItem)
                        end
                        break
                    end
                end
            end
            object:getModData().bGourmandRolled = true
            object:transmitModData()
            break
        end
    end
end

local function ProcessGraveRobber(player, args)
    local gridSquare = getCell():getGridSquare(args.x, args.y, args.z)
    if not gridSquare then
        return
    end

    local bodies = gridSquare:getDeadBodys()
    if bodies and not bodies:isEmpty() then
        local targetBody = bodies:get(0)
        local zombInv = targetBody:getContainer()

        for _, itemType in ipairs(args.items) do
            local item = zombInv:AddItem(itemType)
            if item then
                sendAddItemToContainer(zombInv, item)
            end
        end

        targetBody:getModData().bGraveRobberRolled = true
        targetBody:transmitModData()
    end
end

local function UpdateStats(player, args, command)
    local stats = player:getStats()

    for field, config in pairs(statLimits) do
        local value = args[field]
        if value ~= nil then
            stats:set(config[1], clamp(value, config[2], config[3]))
        end
    end

    if args.zombie_infection ~= nil then
        stats:set(CharacterStat.ZOMBIE_INFECTION, args.zombie_infection)
        if args.zombie_infection == 0 and args.clear_wounds then
            local bodyDamage = player:getBodyDamage()
            bodyDamage:setInfected(false)
            bodyDamage:setInfectionMortalityDuration(-1)
            bodyDamage:setInfectionTime(-1)

            local parts = bodyDamage:getBodyParts()
            for i = 0, parts:size() - 1 do
                local b = parts:get(i)
                if b:HasInjury() and b:isInfectedWound() then
                    b:SetInfected(false)
                    b:setInfectedWound(false)
                end
                if args.amputee then
                    b:RestoreToFullHealth()
                end
            end
        end
    end

    -- print("Server: " .. tostring(command) .. " (Update) applied to " .. player:getUsername())
end

local function ProcessBodyPartMechanics(player, args)
    local PartIndexes = {}
    if type(args.bodyParts) == "table" then
        PartIndexes = args.bodyParts
    elseif args.bodyPart ~= nil then
        table.insert(PartIndexes, args.bodyPart)
    end

    local bodyDamage = player:getBodyDamage()
    local fitness = player:getFitness()

    for _, index in ipairs(PartIndexes) do
        local bodyPartType = BodyPartType.FromIndex(index)
        local bodyPart = bodyDamage:getBodyPart(bodyPartType)
        
        if bodyPart then
            if args.partPain ~= nil then
                bodyPart:setAdditionalPain(args.partPain)
            end
            if args.partDamage ~= nil then
                bodyPart:AddDamage(args.partDamage)
            end
            if args.partStiffness ~= nil then
                bodyPart:setStiffness(args.partStiffness)
                if args.clearStrain then
                    -- Convert index back to string to clear fitness UI/stats
                    local bodyPartString = BodyPartType.ToString(bodyPartType)
                    fitness:removeStiffnessValue(bodyPartString)
                end
            end
            if args.partAdd ~= nil then
                bodyPart:AddHealth(args.partHealthAdd)
            end
            if args.partReduce ~= nil then
                bodyPart:ReduceHealth(args.partHealthReduce)
            end
            if args.unwaveringStats ~= nil then
                local stats = args.unwaveringStats
                bodyPart:setScratchSpeedModifier(stats.scratch)
                bodyPart:setCutSpeedModifier(stats.cut)
                bodyPart:setDeepWoundSpeedModifier(stats.deep)
                bodyPart:setBurnSpeedModifier(stats.burn)
            end
            if args.indefatigable then
                if args.skipRestoreList and tableContains(args.skipRestoreList, index) then
                    bodyPart:SetHealth(100)
                else
                    bodyPart:RestoreToFullHealth()
                end
                bodyDamage:setOverallBodyHealth(100)
            end
        end
    end
end

local function ProcessUpdateWeight(player, args)
    if not args.weight then
        return
    end
    player:setMaxWeightBase(args.weight)
end

local FastGimpVector = Vector2.new(0, 0)
local function ProcessFastGimp(player, args)
    if not args.xSpeed and args.ySpeed then return end
    FastGimpVector:setX(args.xSpeed)
    FastGimpVector:setY(args.ySpeed)
    if player.MoveUnmodded then
        player:MoveUnmodded(FastGimpVector)
    elseif player.Move then
        player:Move(FastGimpVector)
    end
end

local function ProcessImmunocompromised(player, args)
    if not args.infectionIncrease then
        return
    end
    local parts = player:getBodyDamage():getBodyParts();
    for i = 0, parts:size() - 1 do
        local b = parts:get(i);
        local infectionValue = b:getWoundInfectionLevel()
        if infectionValue >= 10.0 then return end
        if b:isInfectedWound() and b:getAlcoholLevel() <= 0 then
            b:setWoundInfectionLevel(infectionValue + args.infectionIncrease);
        end
    end
end

local function ProcessGlassBody(player, args)
    local bodyDamage = player:getBodyDamage()

    if args.extraDamage ~= nil then
        bodyDamage:ReduceGeneralHealth(args.extraDamage)
    end

    local bodyPart = bodyDamage:getBodyPart(BodyPartType.FromIndex(args.partIndex))
    if bodyPart then
        if args.fractureTime > 0 then
            if bodyPart:getFractureTime() <= 0 then
                bodyPart:setFractureTime(args.fractureTime)
            end
        elseif args.doScratch then
            bodyPart:setScratched(true, true)
        end
    end
end

local function ProcessInfectPlayer(player)
    local bodyDamage = player:getBodyDamage()
    bodyDamage:setInfected(true)
end

local function ProcessEvasive(player, args)
    local bodyDamage = player:getBodyDamage()
    local bodyPart = bodyDamage:getBodyPart(BodyPartType.FromIndex(args.partIndex))
    
    if not bodyPart then return end;

    if bodyPart:IsInfected() and not args.wasInfectedBefore and args.isInfected then
        bodyPart:SetInfected(false)
        bodyDamage:setInfected(false)
        bodyDamage:setInfectionMortalityDuration(-1)
        bodyDamage:setInfectionTime(-1)
        bodyDamage:setInfectionGrowthRate(0)
    end
    
    if bodyPart:bleeding() then
        bodyPart:setBleedingTime(0)
        bodyPart:setBleeding(false)
    end

    if bodyPart:scratched() then
        bodyPart:setScratchTime(0)
        bodyPart:setScratched(false, false)
    end

    if bodyPart:isCut() then
        bodyPart:setCutTime(0)
        bodyPart:setCut(false, false)
    end

    if bodyPart:bitten() then
        bodyPart:setBitten(false, false)
        bodyPart:setHealth(100.0)
    end
end

local function ProcessApplyGordanite(player, args)
    local item = player:getInventory():getItemById(args.itemID)
    if item and args.stats then
        local s = args.stats
        item:setMinDamage(s.minDmg)
        item:setMaxDamage(s.maxDmg)
        item:setPushBackMod(s.pushBack)
        item:setDoorDamage(s.doorDmg)
        item:setTreeDamage(s.treeDmg)
        item:setCriticalChance(s.crit)
        item:setSwingTime(s.swing)
        item:setBaseSpeed(s.speed)
        item:setWeaponLength(s.length)
        item:setMinimumSwingTime(s.minSwing)
        item:getModData().MTHasBeenModified = true
    end
end

local function ProcessRevertGordanite(player, args)
    local item = player:getInventory():getItemById(args.itemID)
    if item then
        local moddata = item:getModData()
        if moddata.MTHasBeenModified then
            item:setMinDamage(moddata.MinDamage)
            item:setMaxDamage(moddata.MaxDamage)
            item:setPushBackMod(moddata.PushBack)
            item:setDoorDamage(moddata.DoorDamage)
            item:setTreeDamage(moddata.TreeDamage)
            item:setCriticalChance(moddata.CriticalChance)
            item:setSwingTime(moddata.SwingTime)
            item:setBaseSpeed(moddata.BaseSpeed)
            item:setWeaponLength(0.4)
            item:setMinimumSwingTime(moddata.MinimumSwing)
            moddata.MTHasBeenModified = false
        end
    end
end

local function ProcessProwessGuns(player, args)
    if not args.weaponID then return end

    local primaryWeapon = player:getPrimaryHandItem()
    if not primaryWeapon or primaryWeapon:getID() ~= args.weaponID then return end

    local currentCapacity = primaryWeapon:getCurrentAmmoCount()
    primaryWeapon:setCurrentAmmoCount(currentCapacity + 1);
    sendAddItemToContainer(primaryWeapon:getContainer(), player)
end

local commandHandlers = {
    Vagabond = function(player, args) ProcessTraitLoot(player, args, "bVagbondRolled", "bin") end,
    Scrounger = function(player, args) ProcessTraitLoot(player, args, "bScroungerorIncomprehensiveRolled", nil) end,
    Antique = function(player, args) ProcessTraitLoot(player, args, "bAntiqueRolled", nil) end,
    Incomprehensive = function(player, args) ProcessTraitLootRemoval(player, args, "bScroungerorIncomprehensiveRolled") end,
    Gourmand = ProcessGourmand,
    GraveRobber = ProcessGraveRobber,
    UpdateStats = UpdateStats,
    BodyPartMechanics = ProcessBodyPartMechanics,
    MT_updateWeight = ProcessUpdateWeight,
    FastGimp = ProcessFastGimp,
    Immunocompromised = ProcessImmunocompromised,
    GlassBody = ProcessGlassBody,
    InfectPlayer = function(player, _) ProcessInfectPlayer(player) end,
    EvasiveDodge = ProcessEvasive,
    ApplyGordanite = ProcessApplyGordanite,
    RevertGordanite = ProcessRevertGordanite,
    ProwessGuns = ProcessProwessGuns,
}

local function onClientCommands(module, command, player, args)
    if module ~= 'ToadTraits' then
        return
    end

    if not canProcessTraitCommand(player, command) then
        return
    end

    local handler = commandHandlers[command]
    if not handler then
        return
    end

    handler(player, args or {}, command)
end

Events.OnClientCommand.Add(onClientCommands)
