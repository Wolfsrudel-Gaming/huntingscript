--[[
    Händler-NPCs zum Verkauf von Fleisch, Fellen, Leder und Trophäen
    sowie die initiale Synchronisation mit dem Server.
]]

local traderPeds = {}
local traderBlips = {}

CreateThread(function()
    for _, trader in ipairs(Config.Traders) do
        if trader.blip and trader.blip.enabled then
            local blip = AddBlipForCoord(trader.coords.x, trader.coords.y, trader.coords.z)
            SetBlipSprite(blip, trader.blip.sprite)
            SetBlipColour(blip, trader.blip.colour)
            SetBlipScale(blip, trader.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(trader.label)
            EndTextCommandSetBlipName(blip)
            traderBlips[#traderBlips + 1] = blip
        end
    end

    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for i, trader in ipairs(Config.Traders) do
            local pos = trader.coords.xyz
            local dist = #(coords - pos)
            if dist < 80.0 and not traderPeds[i] then
                local hash = LoadModel(trader.ped)
                if hash then
                    local z = GetGroundZ(pos.x, pos.y, pos.z)
                    local ped = CreatePed(4, hash, pos.x, pos.y, z, trader.coords.w, false, false)
                    SetEntityHeading(ped, trader.coords.w)
                    SetEntityInvincible(ped, true)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    SetPedCanRagdoll(ped, false)
                    SetPedFleeAttributes(ped, 0, false)
                    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
                    SetModelAsNoLongerNeeded(hash)
                    traderPeds[i] = ped
                    CreateThread(function()
                        Wait(1000)
                        if DoesEntityExist(ped) then FreezeEntityPosition(ped, true) end
                    end)
                end
            elseif dist > 100.0 and traderPeds[i] then
                DeleteEntity(traderPeds[i])
                traderPeds[i] = nil
            end
        end
        Wait(2000)
    end
end)

local function OpenTrader(index)
    local trader = Config.Traders[index]
    local ok, offers = Callback('wr_hunting:trader:getOffers', index)
    if not ok or not offers or #offers == 0 then
        Notify(L('trader_nothing'), 'error')
        return
    end

    local elements = {}
    for _, o in ipairs(offers) do
        elements[#elements + 1] = {
            label       = ('%s (x%d)'):format(o.label, o.count),
            description = L('trader_price', o.price, o.price * o.count),
            item        = o.item,
            count       = o.count,
        }
    end

    OpenMenu('wr_hunting_trader', trader.label, elements, function(selected)
        CreateThread(function()
            local success, msg = Callback('wr_hunting:trader:sell', index, selected.item, selected.count)
            Notify(msg, success and 'success' or 'error')
        end)
    end)
end

RegisterInteraction('trader', function(coords)
    for i, trader in ipairs(Config.Traders) do
        local dist = #(coords - trader.coords.xyz)
        if dist <= 2.5 then
            return {
                dist   = dist,
                text   = L('trader_prompt', trader.label),
                action = function() OpenTrader(i) end,
            }
        end
    end
    return nil
end)

--[[ Initiale Synchronisation (Trophäen, Lagerfeuer, Routing-Bucket) ]]

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    TriggerServerEvent('wr_hunting:server:requestSync')
end)

RegisterNetEvent('esx:playerLoaded', function()
    Wait(2000)
    TriggerServerEvent('wr_hunting:server:requestSync')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in pairs(traderPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, blip in ipairs(traderBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
