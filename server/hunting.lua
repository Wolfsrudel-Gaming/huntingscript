--[[
    Abschüsse, Beutequalität, Polizeimeldungen (Wilderei / Jagdwaffen außerhalb
    der Reviere) und Weiterleitung von Schüssen an Tier-Besitzer.
]]

--[[ Polizei ]]

local function IsIgnoredJob(src)
    local job = GetJobName(src)
    return job ~= nil and TableContains(Config.Police.ignoredJobs, job)
end

local function GetPoliceSources()
    local list, seen = {}, {}
    if ESX.GetExtendedPlayers then
        for _, job in ipairs(Config.Police.jobs) do
            for _, xPlayer in pairs(ESX.GetExtendedPlayers('job', job)) do
                if not seen[xPlayer.source] then
                    seen[xPlayer.source] = true
                    list[#list + 1] = xPlayer.source
                end
            end
        end
    else
        for _, id in ipairs(ESX.GetPlayers()) do
            local xPlayer = ESX.GetPlayerFromId(id)
            if xPlayer and TableContains(Config.Police.jobs, xPlayer.job.name) then
                list[#list + 1] = xPlayer.source
            end
        end
    end
    return list
end

local function FuzzCoords(coords)
    local f = Config.Police.locationFuzz or 0.0
    if f <= 0 then return coords end
    local angle = math.random() * 2.0 * math.pi
    local dist = math.random() * f
    return vector3(coords.x + math.cos(angle) * dist, coords.y + math.sin(angle) * dist, coords.z)
end

--- Sendet eine Meldung an die Polizei (eingebaut oder extern).
---@param src number Verdächtiger
---@param alertType string 'kill' | 'weapon'
---@param coords vector3 tatsächliche Position
---@param info table { street, gender, animal, weapon }
function SendPoliceAlert(src, alertType, coords, info)
    info = info or {}
    local genderLabel = info.gender == 'female' and L('gender_female') or L('gender_male')
    local alert = {
        type    = alertType,
        coords  = FuzzCoords(coords),
        street  = info.street or '',
        code    = alertType == 'kill' and L('alert_kill_code') or L('alert_weapon_code'),
        title   = alertType == 'kill' and L('alert_kill_title') or L('alert_weapon_title'),
        message = alertType == 'kill'
            and L('alert_kill_message', genderLabel)
            or L('alert_weapon_message', genderLabel),
    }

    DebugPrint(('Polizeimeldung (%s) von Spieler %s'):format(alertType, src))

    local mode = Config.Police.dispatch
    if mode == 'client' then
        TriggerClientEvent('wr_hunting:client:customDispatch', src, alert)
        return
    elseif mode == 'server' then
        if type(Config.Police.serverDispatch) == 'function' then
            local ok, err = pcall(Config.Police.serverDispatch, src, alert)
            if not ok then print('^1[wr_hunting] serverDispatch Fehler:^7', err) end
        end
        return
    end

    for _, policeSrc in ipairs(GetPoliceSources()) do
        TriggerClientEvent('wr_hunting:client:policeAlert', policeSrc, alert)
    end
end

--[[ Jagdschein (optional, esx_license) ]]

local function HasHuntingLicense(src)
    if not Config.License.enabled then return true end
    if GetResourceState('esx_license') ~= 'started' then return true end
    local p = promise.new()
    local resolved = false
    TriggerEvent('esx_license:checkLicense', src, Config.License.type, function(has)
        if not resolved then
            resolved = true
            p:resolve(has == true)
        end
    end)
    SetTimeout(3000, function()
        if not resolved then
            resolved = true
            p:resolve(true)
        end
    end)
    return Citizen.Await(p)
end

--[[ Beutequalität ]]

local function DetermineQuality(weaponHash, bone)
    weaponHash = NormalizeHash(weaponHash)
    if RuinedCauseHashes[weaponHash] then return 'ruined' end
    local hw = HuntingWeaponHashes[weaponHash]
    if hw then
        if hw.clean then
            if bone and HeadshotBones[tonumber(bone)] then return 'perfect' end
            return 'good'
        end
        return 'damaged'
    end
    if KnifeWeaponHashes[weaponHash] then return 'good' end
    return 'damaged'
end

--[[ Abschuss ]]

local function HandleKillAlert(src, animal, cfg, coords, data)
    local killCfg = Config.Police.kill
    if not killCfg.enabled or IsIgnoredJob(src) then return end
    if IsOnCooldown(src, 'killAlert') then return end

    local chance = cfg.alertChance or 0
    if IsNightHour(data.hour) then chance = chance + (killCfg.nightBonus or 0) end
    if not GetZoneAt(coords, Config.ZoneMargin) then chance = math.max(chance, killCfg.outsideZoneChance or 0) end
    if cfg.protected then chance = math.max(chance, killCfg.protectedChance or 0) end
    if Config.License.enabled and not HasHuntingLicense(src) then
        chance = math.max(chance, killCfg.noLicenseChance or 0)
    end

    if math.random(100) <= chance then
        SetCooldown(src, 'killAlert', killCfg.cooldown or 30)
        SendPoliceAlert(src, 'kill', coords, { street = data.street, gender = data.gender, animal = animal.type })
    end
end

RegisterNetEvent('wr_hunting:server:animalKilled', function(netId, data)
    local src = source
    if type(data) ~= 'table' then data = {} end
    local animal = GetAnimalByNet(netId)
    if not animal or animal.verifying then return end
    -- Bereits als tot markiert (ohne Schützen)? Nur kurz danach noch zuordnen.
    if animal.dead and (animal.killer or os.time() - (animal.deadAt or 0) > 10) then return end
    if not DoesEntityExist(animal.entity) then return end

    local playerPed = GetPlayerPed(src)
    local coords = GetEntityCoords(animal.entity)
    if not IsPlayerNear(src, coords, 500.0) then return end

    animal.verifying = true
    local confirmed = animal.dead
    for _ = 1, 12 do
        if confirmed then break end
        if IsServerPedDead(animal) or GetPedSourceOfDeath(animal.entity) == playerPed then
            confirmed = true
            break
        end
        Wait(250)
    end
    animal.verifying = false

    if not confirmed or not DoesEntityExist(animal.entity) then
        DebugPrint(('Abschussmeldung von %s für %s abgelehnt'):format(src, netId))
        return
    end

    -- Waffe: serverseitige Todesursache bevorzugen
    local cause = GetPedCauseOfDeath(animal.entity)
    if not cause or cause == 0 then cause = tonumber(data.weapon) or 0 end
    local quality = DetermineQuality(cause, data.bone)

    if animal.dead then
        animal.killer = src
        animal.quality = quality
    else
        MarkAnimalDead(animal, src, quality)
    end

    local cfg = Config.Animals[animal.type]
    NotifyPlayer(src, L('kill_confirmed', cfg.label, L('quality_' .. quality)), 'success')
    HandleKillAlert(src, animal, cfg, coords, data)
end)

--[[ Jagdwaffe außerhalb eines Reviers ]]

RegisterNetEvent('wr_hunting:server:weaponDrawn', function(weaponHash, reason, street, gender)
    local src = source
    local wCfg = Config.Police.weapon
    if not wCfg.enabled or IsIgnoredJob(src) then return end
    if RateLimited(src, 'weaponDrawn', 1000) then return end
    if IsOnCooldown(src, 'weaponAlert') then return end

    local hw = HuntingWeaponHashes[NormalizeHash(weaponHash)]
    if not hw or not hw.alert then return end

    local coords = GetPlayerCoords(src)
    if not coords or GetZoneAt(coords, Config.ZoneMargin) then return end

    if math.random(100) <= (wCfg.chance or 100) then
        SetCooldown(src, 'weaponAlert', wCfg.cooldown or 60)
        SendPoliceAlert(src, 'weapon', coords, {
            street = type(street) == 'string' and street:sub(1, 100) or '',
            gender = gender,
            weapon = hw.name,
            reason = reason,
        })
    end
end)

--[[ Schüsse → Tiere in der Nähe flüchten ]]

RegisterNetEvent('wr_hunting:server:gunshot', function(silenced)
    local src = source
    if RateLimited(src, 'gunshot', 1000) then return end
    local coords = GetPlayerCoords(src)
    if not coords or not GetZoneAt(coords, Config.Behaviour.gunshotRadius) then return end

    local radius = silenced and Config.Behaviour.gunshotRadiusSilenced or Config.Behaviour.gunshotRadius
    for _, p in ipairs(GetPlayersWithCoords()) do
        if #(p.coords - coords) <= 450.0 then
            TriggerClientEvent('wr_hunting:client:gunshot', p.src, src, coords, radius)
        end
    end
end)

--[[ Initiale Synchronisation ]]

RegisterNetEvent('wr_hunting:server:requestSync', function()
    local src = source
    if RateLimited(src, 'requestSync', 2000) then return end
    PlayerBuckets[src] = GetBucket(src)
    TriggerClientEvent('wr_hunting:client:setBucket', src, PlayerBuckets[src])
    SyncCampfires(src)
    SyncTrophies(src)
end)
