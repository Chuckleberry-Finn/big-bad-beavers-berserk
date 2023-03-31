local berserkMode = {}


---@param player IsoPlayer|IsoGameCharacter
function berserkMode.enter(player, berserkData)
    berserkMode.rollNextDuration(player, berserkData)
    player:SayShout(SandboxVars.BerserkBeaver.message)
    player:getStats():setAnger(1)
    berserkData.stats = {}
    berserkData.skills = {}
    for i=1, Perks.getMaxIndex()-1 do
        ---@type PerkFactory.Perk
        local perk = Perks.fromIndex(i)
        if perk and (perk:getParent()==Perks.Combat or perk==Perks.Aiming) and perk~=Perks.Maintenance then

            local lvl = player:getPerkLevel(perk)
            local prevXP = (lvl > 0) and perk:getTotalXpForLevel(lvl) or 0
            local xp = player:getXp():getXP(perk) - prevXP

            berserkData.skills[perk:getId()] = {lvl=lvl,xp=xp}
            for n=lvl, 10 do player:LevelPerk(perk, false) end
            player:getXp():setXPToLevel(perk, player:getPerkLevel(perk))
        end
    end
end


---@param player IsoPlayer|IsoGameCharacter
function berserkMode.exit(player, berserkData)
    local pStats = player:getStats()
    pStats:setAnger(0)
    berserkMode.rollNextTime(player, berserkData)
    if getDebug() then print("BERSERK FINISHED: ") end

    if not berserkData.skills then return end
    local pXp = player:getXp()

    for perkID,lvlXp in pairs(berserkData.skills) do
        local perk = Perks[perkID]
        for i=10, lvlXp.lvl+1, -1 do player:LoseLevel(perk) end
        pXp:setXPToLevel(perk, player:getPerkLevel(perk))
        pXp:AddXP(perk, lvlXp.xp, true, false, true)
    end

    berserkData.skills = {}

    if berserkData.stats then
        pStats:setThirst(berserkData.stats.thirst)
        pStats:setHunger(berserkData.stats.hunger)
        pStats:setEndurance(berserkData.stats.endurance)
        pStats:setFatigue(berserkData.stats.fatigue)
        pStats:setStress(berserkData.stats.stress)
        pStats:setPanic(berserkData.stats.panic)
        pStats:setMorale(berserkData.stats.morale)
        berserkData.stats = nil
    end
end


---@param player IsoPlayer|IsoGameCharacter
function berserkMode.rollNextTime(player, berserkData)
    local playerHoursSurvived = player:getHoursSurvived()
    local addedHourMin = SandboxVars.BerserkBeaver.minInterval
    local addedHourMax = SandboxVars.BerserkBeaver.maxInterval+1 --ZombRand is exclusive to max arg
    berserkData.timeToRage = math.max(playerHoursSurvived,berserkData.timeToRage) + ZombRand(addedHourMin,addedHourMax)
    if getDebug() then print(" - berserkData.timeToRage: "..berserkData.timeToRage) end
end


function berserkMode.rollNextDuration(player, berserkData)
    local addedDurationMin = SandboxVars.BerserkBeaver.durationMin
    local addedDurationMax = SandboxVars.BerserkBeaver.durationMax+1 --ZombRand is exclusive to max arg
    berserkData.duration = ZombRand(addedDurationMin,addedDurationMax)
    if getDebug() then print(" - berserkData.duration: "..berserkData.duration) end
end

---set modData - or send back found data
function berserkMode.setOrGetBerserkData(player)
    local pMD = player:getModData()

    if pMD.berserkBigBadBeaverData then return pMD.berserkBigBadBeaverData end

    pMD.berserkBigBadBeaverData = {}
    pMD.berserkBigBadBeaverData.timeToRage = 0
    pMD.berserkBigBadBeaverData.duration = -1

    berserkMode.rollNextTime(player, pMD.berserkBigBadBeaverData)

    return pMD.berserkBigBadBeaverData
end


---@param player IsoPlayer|IsoGameCharacter
function berserkMode.update(player)

    local playerHoursSurvived = player:getHoursSurvived()
    local berserkData = berserkMode.setOrGetBerserkData(player)

    if berserkData.duration > 0.00 then
        local pStats = player:getStats()
        local anger = pStats:getAnger()
        pStats:setAnger(anger+0.1)

        if berserkData.stats then
            berserkData.stats.thirst = (berserkData.stats.thirst or 0) + (pStats:getThirst()*SandboxVars.BerserkBeaver.recoilMultiplier)
            pStats:setThirst(0)
            berserkData.stats.hunger = (berserkData.stats.hunger or 0) + (pStats:getHunger()*SandboxVars.BerserkBeaver.recoilMultiplier)
            pStats:setHunger(0)
            berserkData.stats.endurance = (berserkData.stats.endurance or 0) + ((1-pStats:getEndurance())*SandboxVars.BerserkBeaver.recoilMultiplier)
            pStats:setEndurance(1)
            berserkData.stats.fatigue = (berserkData.stats.fatigue or 0) + (pStats:getFatigue()*SandboxVars.BerserkBeaver.recoilMultiplier)
            pStats:setFatigue(0)
            berserkData.stats.stress = (berserkData.stats.stress or 0) + (pStats:getStress()*SandboxVars.BerserkBeaver.recoilMultiplier)
            pStats:setStress(0)
            berserkData.stats.panic = (berserkData.stats.panic or 0) + (pStats:getPanic()*SandboxVars.BerserkBeaver.recoilMultiplier)
            pStats:setPanic(0)
            berserkData.stats.morale = (berserkData.stats.morale or 0) + (pStats:getMorale()*SandboxVars.BerserkBeaver.recoilMultiplier)
            pStats:setMorale(0)
        end

        local gameTime = getGameTime()
        local tick = 1 / gameTime:getMinutesPerDay() / 60 * gameTime:getMultiplier() / 2

        berserkData.duration = berserkData.duration-tick
        if berserkData.duration <= 0.000 then
            berserkData.duration = 0
            berserkMode.exit(player, berserkData)
        end

    elseif berserkData.timeToRage <= playerHoursSurvived then
        berserkMode.enter(player, berserkData)

    elseif berserkData.timeToRage > playerHoursSurvived then
        local closeTo = berserkData.timeToRage - playerHoursSurvived
        local warmUp = 3
        if closeTo <= warmUp then
            local angerLevel = (warmUp-closeTo)/warmUp
            local pStats = player:getStats()
            pStats:setAnger(angerLevel)
        end
    end
end
Events.OnPlayerUpdate.Add(berserkMode.update)


return berserkMode