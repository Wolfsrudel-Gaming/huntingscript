--[[
    Grillen auf Grills der Spielwelt, an festen Feuerstellen und an selbst
    gebauten Lagerfeuern. Außerdem: Lagerfeuer platzieren und Fleisch essen.
]]

local Campfires = {}        -- [id] = { id, coords, heading, bucket, expires }
local renderedFires = {}    -- [key] = { obj = entity, fx = handle }
local grillHashes = {}

for _, model in ipairs(Config.Cooking.grillModels) do
    grillHashes[#grillHashes + 1] = GetHashKey(model)
end

--[[ Darstellung der Feuer (feste Feuerstellen + Lagerfeuer) ]]

local function SpawnFire(coords, heading)
    local entry = {}
    local hash = Config.Campfire.model and LoadModel(Config.Campfire.model)
    local z = GetGroundZ(coords.x, coords.y, coords.z)
    if hash then
        local obj = CreateObject(hash, coords.x, coords.y, z, false, false, false)
        SetEntityHeading(obj, heading or 0.0)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetModelAsNoLongerNeeded(hash)
        entry.obj = obj
    end
    local p = Config.Campfire.particle
    if p and LoadPtfx(p.asset) then
        UseParticleFxAssetNextCall(p.asset)
        entry.fx = StartParticleFxLoopedAtCoord(p.name, coords.x, coords.y, z + 0.05, 0.0, 0.0, 0.0,
            p.scale or 1.0, false, false, false, false)
    end
    return entry
end

local function RemoveFire(entry)
    if entry.fx then StopParticleFxLooped(entry.fx, false) end
    if entry.obj and DoesEntityExist(entry.obj) then DeleteEntity(entry.obj) end
end

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local range = Config.Campfire.renderDistance
        local wanted = {}

        for i, station in ipairs(Config.Cooking.stations) do
            if #(coords - station.coords) <= range then
                wanted['s' .. i] = { coords = station.coords, heading = 0.0 }
            end
        end
        for id, fire in pairs(Campfires) do
            if fire.bucket == CurrentBucket and #(coords - fire.coords) <= range then
                wanted['c' .. id] = fire
            end
        end

        for key, data in pairs(wanted) do
            if not renderedFires[key] then
                renderedFires[key] = SpawnFire(data.coords, data.heading)
            end
        end
        for key, entry in pairs(renderedFires) do
            if not wanted[key] then
                RemoveFire(entry)
                renderedFires[key] = nil
            end
        end
        Wait(1500)
    end
end)

RegisterNetEvent('wr_hunting:client:syncCampfires', function(list)
    Campfires = {}
    for _, fire in ipairs(list or {}) do
        Campfires[fire.id] = fire
    end
end)

RegisterNetEvent('wr_hunting:client:addCampfire', function(fire)
    Campfires[fire.id] = fire
end)

RegisterNetEvent('wr_hunting:client:removeCampfire', function(id)
    Campfires[id] = nil
end)

--[[ Kochstellen finden ]]

--- Liefert die nächste Kochstelle: { kind = 'grill'|'station'|'campfire', coords, id }
local function GetNearestCookingSpot(coords)
    local maxDist = Config.Cooking.distance
    local best = nil

    for _, hash in ipairs(grillHashes) do
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, maxDist, hash, false, false, false)
        if obj ~= 0 then
            local pos = GetEntityCoords(obj)
            local dist = #(coords - pos)
            if dist <= maxDist and (not best or dist < best.dist) then
                best = { kind = 'grill', coords = pos, dist = dist }
            end
        end
    end
    for i, station in ipairs(Config.Cooking.stations) do
        local dist = #(coords - station.coords)
        if dist <= maxDist and (not best or dist < best.dist) then
            best = { kind = 'station', coords = station.coords, dist = dist, index = i }
        end
    end
    for id, fire in pairs(Campfires) do
        if fire.bucket == CurrentBucket then
            local dist = #(coords - fire.coords)
            if dist <= maxDist and (not best or dist < best.dist) then
                best = { kind = 'campfire', coords = fire.coords, dist = dist, id = id }
            end
        end
    end
    return best
end

--[[ Grillen ]]

local function CookLoop(spot, item, amount)
    Busy = true
    local ped = PlayerPedId()
    FacePosition(spot.coords)
    TaskStartScenarioInPlace(ped, Config.Cooking.scenario, 0, true)

    local cooked = 0
    for i = 1, amount do
        local ok, durationOrMsg = Callback('wr_hunting:cook:start', item, spot.kind, spot.id or spot.index)
        if not ok then
            Notify(durationOrMsg, 'error')
            break
        end
        local completed = Progress(L('cook_progress', i, amount), durationOrMsg, {
            check = function() return #(GetEntityCoords(ped) - spot.coords) <= Config.Cooking.distance + 1.5 end,
        })
        if not completed then
            TriggerServerEvent('wr_hunting:server:cancelCook')
            Notify(L('cook_cancelled'), 'error')
            break
        end
        local success, msg = Callback('wr_hunting:cook:finish')
        if not success then
            Notify(msg, 'error')
            break
        end
        cooked = cooked + 1
    end

    ClearPedTasks(ped)
    if cooked > 0 then
        Notify(L('cook_done', cooked), 'success')
    end
    Busy = false
end

local function OpenCookingMenu(spot)
    local ok, meats = Callback('wr_hunting:cook:getMeat')
    local elements = {}

    if ok and meats then
        for _, m in ipairs(meats) do
            elements[#elements + 1] = {
                label = L('cook_one', m.label), description = L('cook_desc', m.resultLabel, m.duration),
                item = m.item, amount = 1,
            }
            if m.count > 1 then
                local amount = math.min(m.count, Config.Cooking.maxBatch)
                elements[#elements + 1] = {
                    label = L('cook_all', amount, m.label), description = L('cook_desc', m.resultLabel, m.duration),
                    item = m.item, amount = amount,
                }
            end
        end
    end

    if spot.kind == 'campfire' then
        elements[#elements + 1] = { label = L('campfire_extinguish'), extinguish = true }
    end

    if #elements == 0 then
        Notify(L('cook_no_meat'), 'error')
        return
    end

    OpenMenu('wr_hunting_cooking', spot.kind == 'grill' and L('cook_title_grill') or L('cook_title_fire'), elements,
        function(selected)
            if selected.extinguish then
                TriggerServerEvent('wr_hunting:server:extinguishCampfire', spot.id)
                return
            end
            CreateThread(function() CookLoop(spot, selected.item, selected.amount) end)
        end)
end

RegisterInteraction('cooking', function(coords)
    local spot = GetNearestCookingSpot(coords)
    if not spot then return nil end
    return {
        dist   = spot.dist,
        text   = spot.kind == 'grill' and L('cook_prompt_grill') or L('cook_prompt_fire'),
        action = function() OpenCookingMenu(spot) end,
    }
end)

--[[ Lagerfeuer platzieren ]]

RegisterNetEvent('wr_hunting:client:placeCampfire', function()
    if Busy then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        Notify(L('campfire_invalid'), 'error')
        return
    end
    if not Config.Campfire.allowInInteriors and GetInteriorFromEntity(ped) ~= 0 then
        Notify(L('campfire_indoors'), 'error')
        return
    end

    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.2, 0.0)
    local found, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    if not found or math.abs(groundZ - pos.z) > 2.0 then
        Notify(L('campfire_invalid'), 'error')
        return
    end
    local isWater = GetWaterHeight(pos.x, pos.y, groundZ)
    if isWater or IsEntityInWater(ped) then
        Notify(L('campfire_invalid'), 'error')
        return
    end

    Busy = true
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GARDENER_PLANT', 0, true)
    local completed = Progress(L('campfire_placing'), Config.Campfire.placeTime * 1000)
    ClearPedTasks(ped)
    if completed then
        TriggerServerEvent('wr_hunting:server:placeCampfire', vector3(pos.x, pos.y, groundZ), GetEntityHeading(ped))
    end
    Busy = false
end)

--[[ Essen ]]

local function PlayEatAnim()
    local ped = PlayerPedId()
    local anim = Config.Eating.anim
    local prop = AttachPropToPed(ped, anim.prop, 18905, vector3(0.12, 0.028, 0.001), vector3(10.0, 175.0, 0.0))
    if LoadAnimDict(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.name, 3.0, 3.0, anim.duration, 49, 0.0, false, false, false)
    end
    Wait(anim.duration)
    ClearPedSecondaryTask(ped)
    DeleteProp(prop)
end

local function GetSick(damage)
    Wait(math.random(8000, 20000))
    local ped = PlayerPedId()
    Notify(L('eat_raw_sick'), 'error')
    AnimpostfxPlay('DrugsDrivingIn', 0, true)
    if LoadAnimDict('missheistpaletoscore1leadinout') then
        TaskPlayAnim(ped, 'missheistpaletoscore1leadinout', 'trv_puking_leadout', 3.0, 3.0, 6000, 0, 0.0, false, false, false)
    end
    Wait(6000)
    ApplyDamageToPed(ped, damage, false)
    Wait(15000)
    AnimpostfxStop('DrugsDrivingIn')
end

RegisterNetEvent('wr_hunting:client:eat', function(data)
    Busy = true
    PlayEatAnim()
    Busy = false

    if data.hunger and data.hunger > 0 and Config.Eating.statusEvent then
        TriggerEvent(Config.Eating.statusEvent, 'hunger', data.hunger)
    end
    if data.heal and data.heal > 0 then
        local ped = PlayerPedId()
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + data.heal))
    end

    if data.raw then
        if data.sick then
            CreateThread(function() GetSick(data.damage or 10) end)
        else
            Notify(L('eat_raw_lucky'), 'info')
        end
    else
        Notify(L('eat_done', data.label or ''), 'success')
    end
end)

--[[ Aufräumen ]]

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, entry in pairs(renderedFires) do RemoveFire(entry) end
end)
