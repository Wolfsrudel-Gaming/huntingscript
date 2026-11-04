--[[
    Trophäen (Tierköpfe) als Dekoration: platzieren, persistent anzeigen, abnehmen.
]]

local Trophies = {}     -- [id] = { id, item, coords, heading, bucket, own }
local rendered = {}     -- [id] = entity

--- Ermittelt Modell & Typ einer Trophäe (Custom-Prop oder Präparat-Fallback).
local function ResolveModel(item)
    local cfg = Config.Trophies.items[item]
    if not cfg then return nil end
    if cfg.prop and IsModelInCdimage(GetHashKey(cfg.prop)) then
        return cfg.prop, false, cfg
    end
    return cfg.fallbackPed, true, cfg
end

local function CreateTrophyEntity(item, coords, heading, ghost)
    local model, isPed, cfg = ResolveModel(item)
    if not model then return nil end
    local hash = LoadModel(model)
    if not hash then return nil end

    local entity
    if isPed then
        entity = CreatePed(28, hash, coords.x, coords.y, coords.z, heading, false, false)
        SetEntityInvincible(entity, true)
        SetBlockingOfNonTemporaryEvents(entity, true)
        SetPedCanRagdoll(entity, false)
        SetPedCanPlayAmbientAnims(entity, false)
        SetPedCanPlayAmbientBaseAnims(entity, false)
        TaskStandStill(entity, -1)
        SetEntityHeading(entity, heading)
    else
        entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
        SetEntityRotation(entity, 0.0, 0.0, heading, 2, true)
    end
    SetModelAsNoLongerNeeded(hash)

    if ghost then
        SetEntityAlpha(entity, 170, false)
        SetEntityCollision(entity, false, false)
        FreezeEntityPosition(entity, true)
    elseif isPed then
        -- Präparat kurz absetzen lassen, dann einfrieren
        CreateThread(function()
            Wait(700)
            if DoesEntityExist(entity) then FreezeEntityPosition(entity, true) end
        end)
    else
        FreezeEntityPosition(entity, true)
    end
    return entity, isPed, cfg
end

local function Despawn(id)
    local ent = rendered[id]
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    rendered[id] = nil
end

--[[ Synchronisation ]]

RegisterNetEvent('wr_hunting:client:syncTrophies', function(list)
    for id in pairs(rendered) do Despawn(id) end
    Trophies = {}
    for _, t in ipairs(list or {}) do Trophies[t.id] = t end
end)

RegisterNetEvent('wr_hunting:client:addTrophy', function(trophy)
    Trophies[trophy.id] = trophy
end)

RegisterNetEvent('wr_hunting:client:removeTrophy', function(id)
    Trophies[id] = nil
    Despawn(id)
end)

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local range = Config.Trophies.renderDistance
        for id, t in pairs(Trophies) do
            local inRange = t.bucket == CurrentBucket and #(coords - t.coords) <= range
            if inRange and rendered[id] == nil then
                rendered[id] = CreateTrophyEntity(t.item, t.coords, t.heading, false) or false
            elseif not inRange and rendered[id] ~= nil then
                Despawn(id)
            end
        end
        for id in pairs(rendered) do
            if not Trophies[id] then Despawn(id) end
        end
        Wait(1500)
    end
end)

--[[ Platzierung ]]

local function DrawPlacementHelp()
    HelpText(L('trophy_place_help'))
end

RegisterNetEvent('wr_hunting:client:placeTrophy', function(item)
    if Busy or not Config.Trophies.items[item] then return end
    Busy = true

    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    local ghost, isPed, cfg = CreateTrophyEntity(item, start, 0.0, true)
    if not ghost then
        Notify(L('trophy_model_missing'), 'error')
        Busy = false
        return
    end

    local rotation, height = 0.0, 0.0
    local valid, finalPos, finalHeading = false, nil, 0.0
    local confirmed = false

    while true do
        Wait(0)
        DrawPlacementHelp()
        DisableControlAction(0, 24, true)   -- Angriff
        DisableControlAction(0, 25, true)   -- Zielen
        DisableControlAction(0, 14, true)   -- Mausrad (Waffe)
        DisableControlAction(0, 15, true)
        DisableControlAction(0, 16, true)
        DisableControlAction(0, 17, true)
        DisableControlAction(0, 37, true)   -- Waffenrad
        DisableControlAction(0, 44, true)   -- Deckung
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisablePlayerFiring(PlayerId(), true)

        if IsDisabledControlJustPressed(0, 14) then rotation = rotation - 10.0 end   -- Mausrad runter
        if IsDisabledControlJustPressed(0, 15) then rotation = rotation + 10.0 end   -- Mausrad hoch
        if IsControlPressed(0, 174) then rotation = rotation - 1.5 end               -- Pfeil links
        if IsControlPressed(0, 175) then rotation = rotation + 1.5 end               -- Pfeil rechts
        if IsControlPressed(0, 172) then height = math.min(height + 0.01, 2.0) end                          -- Pfeil hoch
        if IsControlPressed(0, 173) then height = math.max(height - 0.01, -1.0) end                         -- Pfeil runter

        local hit, pos, normal = RaycastFromCamera(Config.Trophies.placeDistance + 4.0, ghost)
        ped = PlayerPedId()
        valid = false
        if hit and #(pos - GetEntityCoords(ped)) <= Config.Trophies.placeDistance then
            valid = true
            if isPed or normal.z > 0.7 then
                -- Boden: Präparat oder Prop aufstellen
                finalHeading = (GetEntityHeading(ped) + 180.0 + rotation) % 360.0
                finalPos = vector3(pos.x, pos.y, pos.z + height)
                if isPed then
                    SetEntityCoords(ghost, finalPos.x, finalPos.y, finalPos.z, false, false, false, false)
                    SetEntityHeading(ghost, finalHeading)
                else
                    SetEntityCoordsNoOffset(ghost, finalPos.x, finalPos.y, finalPos.z, false, false, false)
                    SetEntityRotation(ghost, 0.0, 0.0, finalHeading, 2, true)
                end
            else
                -- Wand: Prop an der Wand ausrichten
                finalHeading = (GetHeadingFromVector_2d(normal.x, normal.y) + (cfg.headingOffset or 0.0) + rotation) % 360.0
                local p = pos + normal * (cfg.wallOffset or 0.05)
                finalPos = vector3(p.x, p.y, p.z + height)
                SetEntityCoordsNoOffset(ghost, finalPos.x, finalPos.y, finalPos.z, false, false, false)
                SetEntityRotation(ghost, 0.0, 0.0, finalHeading, 2, true)
            end
        end
        SetEntityAlpha(ghost, valid and 170 or 60, false)

        if valid and IsControlJustReleased(0, Config.InteractKey) then
            confirmed = true
            break
        end
        if IsControlJustReleased(0, 177) or IsDisabledControlJustReleased(0, 25) then   -- Backspace / Rechtsklick
            break
        end
    end

    DeleteEntity(ghost)

    if confirmed and finalPos then
        TriggerServerEvent('wr_hunting:server:placeTrophy', item, finalPos, finalHeading)
    else
        Notify(L('trophy_place_cancelled'), 'info')
    end
    Busy = false
end)

--[[ Eigene Trophäe abnehmen ]]

RegisterInteraction('trophy', function(coords)
    local best, bestDist = nil, nil
    for id, t in pairs(Trophies) do
        if t.own and t.bucket == CurrentBucket then
            local dist = #(coords - t.coords)
            if dist <= 2.0 and (not bestDist or dist < bestDist) then
                best, bestDist = id, dist
            end
        end
    end
    if not best then return nil end
    return {
        dist   = bestDist + 0.5,    -- Kadaver/Kochstellen haben Vorrang
        text   = L('trophy_pickup_prompt'),
        action = function()
            TriggerServerEvent('wr_hunting:server:removeTrophy', best)
        end,
    }
end)

-- Admin: nächstgelegene Trophäe entfernen
RegisterCommand('trophaeentfernen', function()
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, nil
    for id, t in pairs(Trophies) do
        if t.bucket == CurrentBucket then
            local dist = #(coords - t.coords)
            if dist <= 5.0 and (not bestDist or dist < bestDist) then best, bestDist = id, dist end
        end
    end
    if not best then
        Notify(L('trophy_none_nearby'), 'error')
        return
    end
    TriggerServerEvent('wr_hunting:server:removeTrophy', best)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(rendered) do Despawn(id) end
end)
