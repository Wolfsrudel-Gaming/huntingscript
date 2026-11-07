--[[
    Ansitz / Tarnzelt: aufstellen, abbauen und Tarnwirkung (Player-State "huntHidden").
]]

local BlindProps = CreatePropSet(Config.Blinds.renderDistance)

local function WithModel(blind)
    blind.model = Config.Blinds.model
    return blind
end

RegisterNetEvent('wr_hunting:client:syncBlinds', function(list)
    for _, blind in ipairs(list or {}) do WithModel(blind) end
    BlindProps.Sync(list)
end)

RegisterNetEvent('wr_hunting:client:addBlind', function(blind)
    BlindProps.Add(WithModel(blind))
end)

RegisterNetEvent('wr_hunting:client:removeBlind', function(id)
    BlindProps.Remove(id)
end)

--[[ Aufstellen ]]

RegisterNetEvent('wr_hunting:client:placeBlind', function()
    if Busy then return end
    local ped = PlayerPedId()
    if GetInteriorFromEntity(ped) ~= 0 then
        Notify(L('blind_invalid'), 'error')
        return
    end
    local spot = GetPlacementSpot(2.0)
    if not spot then
        Notify(L('blind_invalid'), 'error')
        return
    end

    Busy = true
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_HAMMERING', 0, true)
    local completed = Progress(L('blind_placing'), Config.Blinds.placeTime * 1000)
    ClearPedTasks(ped)
    if completed then
        TriggerServerEvent('wr_hunting:server:placeBlind', spot, (GetEntityHeading(ped) + 180.0) % 360.0)
    end
    Busy = false
end)

--[[ Eigenes Tarnzelt abbauen ]]

RegisterInteraction('blind', function(coords)
    for id, blind in pairs(BlindProps.items) do
        if blind.own and blind.bucket == CurrentBucket then
            local dist = #(coords - blind.coords)
            if dist <= Config.Blinds.radius + 0.5 then
                return {
                    dist   = dist + 1.0,   -- andere Interaktionen haben Vorrang
                    text   = L('blind_pack_prompt'),
                    action = function()
                        local ped = PlayerPedId()
                        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_HAMMERING', 0, true)
                        local completed = Progress(L('blind_packing'), math.floor(Config.Blinds.placeTime * 500))
                        ClearPedTasks(ped)
                        if completed then TriggerServerEvent('wr_hunting:server:packBlind', id) end
                    end,
                }
            end
        end
    end
    return nil
end)

--[[ Tarnwirkung ]]

local function IsInsideBlind(coords)
    for _, blind in pairs(BlindProps.items) do
        if blind.bucket == CurrentBucket and #(coords - blind.coords) <= Config.Blinds.radius then
            return true
        end
    end
    for _, fixed in ipairs(Config.Blinds.fixed) do
        if #(coords - fixed.coords) <= (fixed.radius or Config.Blinds.radius) then
            return true
        end
    end
    return false
end

CreateThread(function()
    local hidden = false
    LocalPlayer.state:set('huntHidden', false, true)
    while true do
        local ped = PlayerPedId()
        local now = not IsPedInAnyVehicle(ped, false) and IsInsideBlind(GetEntityCoords(ped))
        if now ~= hidden then
            hidden = now
            LocalPlayer.state:set('huntHidden', hidden, true)
            Notify(hidden and L('blind_hidden') or L('blind_visible'), 'info')
        end
        Wait(750)
    end
end)
