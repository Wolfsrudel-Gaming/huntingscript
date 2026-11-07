--[[
    Köder (Kirrung / Salzlecke) auslegen und darstellen.
]]

local BaitProps = CreatePropSet(Config.Baits.renderDistance)

local function WithModel(bait)
    local cfg = Config.Baits.items[bait.item]
    bait.model = cfg and cfg.model or nil
    return bait
end

RegisterNetEvent('wr_hunting:client:syncBaits', function(list)
    for _, bait in ipairs(list or {}) do WithModel(bait) end
    BaitProps.Sync(list)
end)

RegisterNetEvent('wr_hunting:client:addBait', function(bait)
    BaitProps.Add(WithModel(bait))
end)

RegisterNetEvent('wr_hunting:client:removeBait', function(id)
    BaitProps.Remove(id)
end)

RegisterNetEvent('wr_hunting:client:placeBait', function(item)
    if Busy or not Config.Baits.items[item] then return end
    local ped = PlayerPedId()

    if Config.Baits.onlyInZones and not GetZoneAt(GetEntityCoords(ped)) then
        Notify(L('bait_only_zones'), 'error')
        return
    end
    if GetInteriorFromEntity(ped) ~= 0 then
        Notify(L('bait_invalid'), 'error')
        return
    end
    local spot = GetPlacementSpot(1.0)
    if not spot then
        Notify(L('bait_invalid'), 'error')
        return
    end

    Busy = true
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GARDENER_PLANT', 0, true)
    local completed = Progress(L('bait_placing'), Config.Baits.placeTime * 1000)
    ClearPedTasks(ped)
    if completed then
        TriggerServerEvent('wr_hunting:server:placeBait', item, spot)
    end
    Busy = false
end)
