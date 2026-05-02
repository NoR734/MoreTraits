local function getPlayers()
    local online = getOnlinePlayers and getOnlinePlayers() or nil
    if not online then return {} end
    local players = {}
    for i = 0, online:size() - 1 do
        players[#players + 1] = online:get(i)
    end
    return players
end

local function resolveTraitId(trait)
    if ToadTraitsRegistries and ToadTraitsRegistries[trait] then
        return ToadTraitsRegistries[trait]
    end
    return trait
end

local function hasTrait(player, trait)
    if not player or not player.hasTrait then return false end
    return player:hasTrait(resolveTraitId(trait))
end

local function addTrait(player, trait)
    if not player or not player.getCharacterTraits then return end
    local traits = player:getCharacterTraits()
    local id = resolveTraitId(trait)
    if traits and not player:hasTrait(id) then
        traits:add(id)
    end
end

local function removeTrait(player, trait)
    if not player or not player.getCharacterTraits then return end
    local traits = player:getCharacterTraits()
    local id = resolveTraitId(trait)
    if traits and player:hasTrait(id) then
        traits:remove(id)
    end
end

local function evaluateLevelTraits(player)
    if not player or player:isDead() then return end
    local vars = SandboxVars and SandboxVars.MoreTraitsDynamic or nil
    if not vars then return end

    if vars.PackMouseDynamic == true
        and hasTrait(player, "packmouse")
        and player:getPerkLevel(Perks.Strength) >= vars.PackMouseDynamicSkill then
        removeTrait(player, "packmouse")
    end

    if vars.PackMuleDynamic == true
        and not hasTrait(player, "packmule")
        and player:getPerkLevel(Perks.Strength) >= vars.PackMuleDynamicSkill then
        addTrait(player, "packmule")
    end

    if vars.HardyDynamic == true
        and not hasTrait(player, "hardy")
        and player:getPerkLevel(Perks.Fitness) >= vars.HardyDynamicSkill then
        addTrait(player, "hardy")
    end
end

local function ProcessTraitChange(player, trait, isAddition)
    if not trait then return end
    local traits = player:getCharacterTraits()
    local exactTrait = ToadTraitsRegistries[trait]
    
    if isAddition then
         addTrait(player, trait)
    else
        removeTrait(player, trait)
    end
end

local function ProcessXPBoosts(player, perk, boostAmount)
    if not perk and not boostAmount then return end

    player:getXp():setPerkBoost(perk, boostAmount)
end

local function onClientCommands(module, command, player, args)
    if module ~= 'MoreTraitsDynamic' then return end
    if command == 'addTrait' then
        ProcessTraitChange(player, args.trait, true)
    elseif command == 'removeTrait' then
        ProcessTraitChange(player, args.trait, false)
    end

    if command == 'setXpBoosts' then
        ProcessXPBoosts(player, args.perk, args.boostAmount)
    end
end

local function runFullDynamicLevelSync(player)
    if not player or player:isDead() then return end
    if MTDTraitsGainsByLevel then
        MTDTraitsGainsByLevel(player, "characterInitialization")
    else
        evaluateLevelTraits(player)
    end
end

local function onMinute()
    for _, player in ipairs(getPlayers()) do
        runFullDynamicLevelSync(player)
    end
end

local function onLevelPerk(player, perk)
    if perk == Perks.Strength or perk == Perks.Fitness then
        runFullDynamicLevelSync(player)
    end
end

Events.OnClientCommand.Add(onClientCommands)
Events.LevelPerk.Add(onLevelPerk)
Events.EveryTenMinutes.Add(onMinute)