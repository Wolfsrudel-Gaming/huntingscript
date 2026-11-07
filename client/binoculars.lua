--[[
    Fernglas: Wild ansprechen – Art, Entfernung, Zustand und Schonzeit,
    dazu die aktuelle Windrichtung.
]]

local active = false

local function DrawInfo(text, y, scale)
    SetTextFont(4)
    SetTextScale(0.0, scale or 0.45)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, y)
end

--- Sucht das Tier, das dem Fadenkreuz am nächsten ist.
local function FindTargetAnimal(camCoords)
    local best, bestScore, bestAnimal, bestDist = nil, 0.06, nil, nil
    for ped, animal in pairs(HuntAnimals) do
        if DoesEntityExist(ped) then
            local c = GetEntityCoords(ped)
            local dist = #(c - camCoords)
            if dist <= Config.Binoculars.maxRange then
                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(c.x, c.y, c.z)
                if onScreen then
                    local score = math.sqrt((sx - 0.5) ^ 2 + (sy - 0.5) ^ 2)
                    if score < bestScore and HasEntityClearLosToEntity(PlayerPedId(), ped, 17) then
                        best, bestScore, bestAnimal, bestDist = ped, score, animal, dist
                    end
                end
            end
        end
    end
    return best, bestAnimal, bestDist
end

local function DescribeAnimal(ped, animal, dist)
    local status
    if IsPedDeadOrDying(ped, true) or IsEntityDead(ped) then
        status = L('binoc_dead')
    else
        local maxHealth = GetEntityMaxHealth(ped)
        if maxHealth > 0 and GetEntityHealth(ped) / maxHealth <= Config.Tracking.bleedThreshold then
            status = L('binoc_wounded')
        elseif Entity(ped).state.huntAI == 'flee' then
            status = L('binoc_fleeing')
        elseif Entity(ped).state.huntAI == 'attack' then
            status = L('binoc_aggressive')
        else
            status = L('binoc_calm')
        end
    end
    local seasons = GlobalState.huntSeasons
    local season = (seasons and seasons.closed and seasons.closed[animal.type]) and L('binoc_closed_season') or L('binoc_open_season')
    return L('binoc_target', animal.cfg.label, math.floor(dist), status), season
end

local function RunBinoculars()
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_BINOCULARS', 0, true)
    Wait(1200)

    local scaleform = RequestScaleformMovie('BINOCULARS')
    local timeout = GetGameTimer() + 3000
    while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() < timeout do Wait(10) end
    if HasScaleformMovieLoaded(scaleform) then
        BeginScaleformMovieMethod(scaleform, 'SET_CAM_LOGO')
        ScaleformMovieMethodAddParamInt(0)
        EndScaleformMovieMethod()
    end

    local cfg = Config.Binoculars
    local fov = cfg.fovMax
    local cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
    AttachCamToEntity(cam, ped, 0.0, 0.0, 0.7, true)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(ped), 2)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, false)

    while active do
        Wait(0)
        ped = PlayerPedId()
        if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) then break end
        if IsControlJustPressed(0, 177) or IsControlJustPressed(0, Config.InteractKey) then break end

        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 14, true)
        DisableControlAction(0, 15, true)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 37, true)
        DisableControlAction(0, 44, true)
        DisablePlayerFiring(PlayerId(), true)
        HideHudAndRadarThisFrame()

        -- Zoom
        if IsDisabledControlJustPressed(0, 15) then fov = math.max(cfg.fovMin, fov - cfg.zoomSpeed) end
        if IsDisabledControlJustPressed(0, 14) then fov = math.min(cfg.fovMax, fov + cfg.zoomSpeed) end
        SetCamFov(cam, fov)

        -- Umsehen (langsamer bei starkem Zoom)
        local zoomFactor = fov / cfg.fovMax
        local rx = GetDisabledControlNormal(0, 220)
        local ry = GetDisabledControlNormal(0, 221)
        local rot = GetCamRot(cam, 2)
        local newZ = rot.z + rx * -8.0 * zoomFactor
        local newX = math.max(-75.0, math.min(60.0, rot.x + ry * -8.0 * zoomFactor))
        SetCamRot(cam, newX, 0.0, newZ, 2)
        SetEntityHeading(ped, newZ)

        if HasScaleformMovieLoaded(scaleform) then
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
        end

        local target, animal, dist = FindTargetAnimal(GetCamCoord(cam))
        if target then
            local line1, line2 = DescribeAnimal(target, animal, dist)
            DrawInfo(line1, 0.62, 0.5)
            DrawInfo(line2, 0.66, 0.38)
        end
        if Config.Wind.enabled then
            DrawInfo(L('wind_hud', GetWindLabel()), 0.88, 0.36)
        end
        DrawInfo(L('binoc_help'), 0.92, 0.3)
    end

    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(cam, false)
    if HasScaleformMovieLoaded(scaleform) then SetScaleformMovieAsNoLongerNeeded(scaleform) end
    ClearPedTasks(PlayerPedId())
    active = false
end

RegisterNetEvent('wr_hunting:client:useBinoculars', function()
    if active then
        active = false
        return
    end
    if Busy or IsPedInAnyVehicle(PlayerPedId(), false) then return end
    active = true
    Busy = true
    local ok, err = pcall(RunBinoculars)
    if not ok then
        print('^1[wr_hunting] Fernglas-Fehler:^7', err)
        RenderScriptCams(false, false, 0, true, false)
        ClearPedTasks(PlayerPedId())
    end
    active = false
    Busy = false
end)
