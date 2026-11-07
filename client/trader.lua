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

local OpenTrader

local function OpenSellMenu(index)
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

    OpenMenu('wr_hunting_trader_sell', trader.label, elements, function(selected)
        CreateThread(function()
            local success, msg = Callback('wr_hunting:trader:sell', index, selected.item, selected.count)
            Notify(msg, success and 'success' or 'error')
        end)
    end)
end

local function OpenShopMenu(index, shop)
    local trader = Config.Traders[index]
    local elements = {}
    for _, entry in ipairs(shop) do
        elements[#elements + 1] = {
            label       = entry.label,
            description = L('shop_price', entry.price),
            item        = entry.item,
        }
    end

    OpenMenu('wr_hunting_trader_shop', trader.label, elements, function(selected)
        CreateThread(function()
            local success, msg = Callback('wr_hunting:trader:buy', index, selected.item, 1)
            Notify(msg, success and 'success' or 'error')
            if success then OpenShopMenu(index, shop) end
        end)
    end)
end

local function BuyLicense(index)
    local success, msg = Callback('wr_hunting:trader:buyLicense', index)
    Notify(msg, success and 'success' or 'error')
end

OpenTrader = function(index)
    local trader = Config.Traders[index]
    local ok, info = Callback('wr_hunting:trader:getInfo', index)
    if not ok or not info then
        Notify(L('too_far'), 'error')
        return
    end

    local elements = {}
    if info.sells then
        elements[#elements + 1] = { label = L('trader_menu_sell'), description = L('trader_menu_sell_desc'), action = 'sell' }
    end
    if #info.shop > 0 then
        elements[#elements + 1] = { label = L('trader_menu_shop'), description = L('trader_menu_shop_desc'), action = 'shop' }
    end
    if info.license then
        elements[#elements + 1] = {
            label       = info.license.valid and L('trader_menu_license_extend') or L('trader_menu_license_buy'),
            description = L('trader_menu_license_desc', info.license.price, info.license.days, info.license.status),
            action      = 'license',
        }
    end

    if #elements == 0 then
        Notify(L('trader_nothing'), 'error')
        return
    end
    if #elements == 1 and elements[1].action == 'sell' then
        OpenSellMenu(index)
        return
    end

    OpenMenu('wr_hunting_trader', trader.label, elements, function(selected)
        CreateThread(function()
            if selected.action == 'sell' then
                OpenSellMenu(index)
            elseif selected.action == 'shop' then
                OpenShopMenu(index, info.shop)
            elseif selected.action == 'license' then
                BuyLicense(index)
            end
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
