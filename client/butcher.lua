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

--- Polizei: Kadaver auf Wilderei-Spuren untersuchen
local function Inspect(carcass, animal)
    FacePosition(GetEntityCoords(carcass))
    local ped = PlayerPedId()
    if LoadAnimDict(Config.Butchering.anim.dict) then
        TaskPlayAnim(ped, Config.Butchering.anim.dict, Config.Butchering.anim.name, 3.0, 3.0, -1, 1, 0.0, false, false, false)
    end
    local completed = Progress(L('inspect_progress'), 4000)
    ClearPedTasks(ped)
    if not completed then return end

    local ok, info = Callback('wr_hunting:police:inspect', animal.netId)
    if not ok then
        Notify(info or L('carcass_invalid'), 'error')
        return
    end

    local elements = {
        { label = L('inspect_species', info.label), disabled = true },
        { label = L('inspect_time', info.minutes), disabled = true },
        { label = L('inspect_weapon', info.weapon), disabled = true },
        { label = L('inspect_quality', info.quality), disabled = true },
    }
    if info.tracked then
        elements[#elements + 1] = { label = L('inspect_tracked'), disabled = true }
    end
    if #info.findings == 0 then
        elements[#elements + 1] = { label = L('inspect_no_findings'), disabled = true }
    else
        for _, finding in ipairs(info.findings) do
            elements[#elements + 1] = { label = L('inspect_finding', finding), disabled = true }
        end
    end
    OpenMenu('wr_hunting_inspect', L('inspect_title'), elements, function() end)
end

RegisterInteraction('butcher', function(coords)
    local carcass, dist, animal = GetNearestCarcass(coords)
    if not carcass then return nil end
    local result = {
        dist   = dist,
        text   = L('butcher_prompt', animal.cfg.label),
        action = function() Butcher(carcass, animal) end,
    }
    if Config.Police.inspection.enabled and IsPoliceClient() then
        result.secondary = {
            key    = Config.Police.inspection.key,
            text   = L('inspect_prompt'),
            action = function() Inspect(carcass, animal) end,
        }
    end
    return result
end)
