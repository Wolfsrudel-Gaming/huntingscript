--[[
    Ausnehmen von Kadavern: Fleisch, Fell und sehr selten ein Tierkopf (1 zu 250).
]]

local function IsLockValid(animal)
    if not animal.lock then return false end
    if GetPlayerPing(animal.lock) <= 0 then return false end
    -- Verwaiste Sperre nach Ablauf der Dauer + Puffer freigeben
    return GetGameTimer() - animal.lockAt < animal.lockDuration + 15000
end

local function ReleaseLock(animal)
    animal.lock = nil
    if DoesEntityExist(animal.entity) then
        Entity(animal.entity).state:set('huntButchering', nil, true)
    end
end

ESX.RegisterServerCallback('wr_hunting:butcher:start', function(src, cb, netId)
    local animal = GetAnimalByNet(netId)
    if not animal or not animal.dead or animal.butchered or not DoesEntityExist(animal.entity) then
        return cb(false, L('carcass_invalid'))
    end
    if IsLockValid(animal) and animal.lock ~= src then
        return cb(false, L('carcass_busy'))
    end
    if not IsPlayerNear(src, GetEntityCoords(animal.entity), Config.Butchering.distance + 2.0) then
        return cb(false, L('too_far'))
    end
    if not HasKnife(src) then
        return cb(false, L('need_knife'))
    end

    local cfg = Config.Animals[animal.type]
    local loot = cfg.loot or {}
    if loot.meat and not Inventory.CanCarry(src, loot.meat.item, loot.meat.max + 1) then
        return cb(false, L('inventory_full'))
    end
    if loot.pelt and not Inventory.CanCarry(src, loot.pelt.item, 1) then
        return cb(false, L('inventory_full'))
    end

    local duration = (cfg.butcherTime or 10) * 1000
    animal.lock = src
    animal.lockAt = GetGameTimer()
    animal.lockDuration = duration
    Entity(animal.entity).state:set('huntButchering', src, true)
    cb(true, duration)
end)

RegisterNetEvent('wr_hunting:server:cancelButcher', function(netId)
    local src = source
    local animal = GetAnimalByNet(netId)
    if animal and animal.lock == src then
        ReleaseLock(animal)
    end
end)

ESX.RegisterServerCallback('wr_hunting:butcher:finish', function(src, cb, netId)
    local animal = GetAnimalByNet(netId)
    if not animal or animal.butchered or animal.lock ~= src or not DoesEntityExist(animal.entity) then
        return cb(false, L('carcass_invalid'))
    end
    if GetGameTimer() - animal.lockAt < animal.lockDuration * 0.85 then
        ReleaseLock(animal)
        return cb(false, L('butcher_too_fast'))
    end
    if not IsPlayerNear(src, GetEntityCoords(animal.entity), Config.Butchering.distance + 3.0) then
        ReleaseLock(animal)
        return cb(false, L('too_far'))
    end

    animal.butchered = true
    ReleaseLock(animal)

    local cfg = Config.Animals[animal.type]
    local loot = cfg.loot or {}
    local quality = Config.Quality[animal.quality or 'damaged'] or Config.Quality.damaged
    local received = {}

    -- Fleisch
    if loot.meat then
        local amount = math.random(loot.meat.min, loot.meat.max) + (quality.meatBonus or 0)
        amount = math.max(amount, loot.meat.min > 0 and 1 or 0)
        if amount > 0 and Inventory.Add(src, loot.meat.item, amount) then
            received[#received + 1] = ('%dx %s'):format(amount, Inventory.Label(loot.meat.item))
        end
    end

    -- Fell
    if loot.pelt and math.random(100) <= (quality.peltChance or 100) then
        if Inventory.Add(src, loot.pelt.item, 1) then
            received[#received + 1] = ('1x %s'):format(Inventory.Label(loot.pelt.item))
        end
    elseif loot.pelt then
        NotifyPlayer(src, L('pelt_ruined'), 'error')
    end

    -- Trophäe (Tierkopf) – sehr selten
    local trophy = false
    if loot.trophy and math.random(1, Config.Butchering.trophyChance) == 1 then
        if Inventory.CanCarry(src, loot.trophy, 1) and Inventory.Add(src, loot.trophy, 1) then
            trophy = true
            received[#received + 1] = ('1x %s'):format(Inventory.Label(loot.trophy))
            print(('[wr_hunting] %s (%s) hat eine Trophäe erhalten: %s'):format(GetPlayerName(src), GetIdentifier(src) or '?', loot.trophy))
        end
    end

    -- Kadaver entfernen
    local id = animal.id
    SetTimeout(1000, function() RemoveAnimal(id) end)

    if trophy then
        NotifyPlayer(src, L('trophy_found', cfg.label), 'success')
    end

    if #received == 0 then
        return cb(true, L('butcher_nothing'))
    end
    cb(true, L('butcher_success', table.concat(received, ', ')))
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, animal in pairs(Animals) do
        if animal.lock == src then ReleaseLock(animal) end
    end
end)
