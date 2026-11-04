--[[
    Ausnehmen erlegter Tiere mit einem Messer.
]]

local function GetNearestCarcass(coords)
    local best, bestDist, bestAnimal = nil, nil, nil
    for ped, animal in pairs(HuntAnimals) do
        if DoesEntityExist(ped) then
            local state = Entity(ped).state
            if state.huntDead and not state.huntButchered then
                local dist = #(GetEntityCoords(ped) - coords)
                if dist <= Config.Butchering.distance and (not bestDist or dist < bestDist) then
                    best, bestDist, bestAnimal = ped, dist, animal
                end
            end
        end
    end
    return best, bestDist, bestAnimal
end

local function PlayButcherAnim(ped)
    local anim = Config.Butchering.anim
    local upper = Config.Butchering.upperAnim
    if LoadAnimDict(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.name, 3.0, 3.0, -1, 1, 0.0, false, false, false)
    end
    Wait(300)
    if LoadAnimDict(upper.dict) then
        TaskPlayAnim(ped, upper.dict, upper.name, 3.0, 3.0, -1, 49, 0.0, false, false, false)
    end
end

local function Butcher(carcass, animal)
    local ped = PlayerPedId()
    local ok, durationOrMsg = Callback('wr_hunting:butcher:start', animal.netId)
    if not ok then
        Notify(durationOrMsg or L('butcher_failed'), 'error')
        return
    end

    FacePosition(GetEntityCoords(carcass))

    -- Messer in die Hand (falls als Waffe vorhanden) oder Messer-Prop anheften
    local knifeProp = nil
    local equipped = false
    for hash, name in pairs(KnifeWeaponHashes) do
        if HasPedGotWeapon(ped, GetHashKey(name), false) then
            SetCurrentPedWeapon(ped, GetHashKey(name), true)
            equipped = true
            break
        end
    end
    if not equipped and Config.Butchering.knifeProp then
        knifeProp = AttachPropToPed(ped, Config.Butchering.knifeProp, 57005,
            vector3(0.12, 0.03, -0.02), vector3(-80.0, 0.0, 0.0))
    end

    PlayButcherAnim(ped)

    local completed = Progress(L('butcher_progress', animal.cfg.label), durationOrMsg, {
        check = function()
            return DoesEntityExist(carcass) and #(GetEntityCoords(ped) - GetEntityCoords(carcass)) <= Config.Butchering.distance + 1.0
        end,
    })

    ClearPedTasks(ped)
    DeleteProp(knifeProp)
    if equipped then SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true) end

    if not completed then
        TriggerServerEvent('wr_hunting:server:cancelButcher', animal.netId)
        Notify(L('butcher_cancelled'), 'error')
        return
    end

    local success, message = Callback('wr_hunting:butcher:finish', animal.netId)
    Notify(message or L('butcher_failed'), success and 'success' or 'error')
end

RegisterInteraction('butcher', function(coords)
    local carcass, dist, animal = GetNearestCarcass(coords)
    if not carcass then return nil end
    return {
        dist   = dist,
        text   = L('butcher_prompt', animal.cfg.label),
        action = function() Butcher(carcass, animal) end,
    }
end)
