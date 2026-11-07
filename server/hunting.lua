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

--[[ Beutequalität ]]

function DetermineQuality(weaponHash, bone)
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

--- Grobe Waffenkategorie für die Kadaver-Untersuchung der Polizei.
function GetWeaponCategory(weaponHash)
    weaponHash = NormalizeHash(weaponHash)
    if weaponHash == 0 then return 'unknown' end
    if RuinedCauseHashes[weaponHash] then
        if weaponHash == HashOf('WEAPON_RUN_OVER_BY_CAR') or weaponHash == HashOf('WEAPON_RAMMED_BY_CAR') then
            return 'vehicle'
        end
        return 'explosive'
    end
    local hw = HuntingWeaponHashes[weaponHash]
    if hw then return hw.clean and 'rifle' or 'shotgun' end
    if KnifeWeaponHashes[weaponHash] then return 'knife' end
    return 'other'
end

--[[ Abschuss ]]

local function HandleKillAlert(src, animal, cfg, coords, data, violations)
    local killCfg = Config.Police.kill
    if not killCfg.enabled or IsIgnoredJob(src) then return end
    if IsOnCooldown(src, 'killAlert') then return end

    local chance = cfg.alertChance or 0
    if IsNightHour(data.hour) then chance = chance + (killCfg.nightBonus or 0) end
    if violations.outsideZone then chance = math.max(chance, killCfg.outsideZoneChance or 0) end
    if cfg.protected then chance = math.max(chance, killCfg.protectedChance or 0) end
    if violations.noLicense then chance = math.max(chance, killCfg.noLicenseChance or 0) end
    if violations.closedSeason then chance = math.max(chance, killCfg.closedSeasonChance or 0) end
    if violations.overLimit then chance = math.max(chance, killCfg.overLimitChance or 0) end

    if math.random(100) <= chance then
        SetCooldown(src, 'killAlert', killCfg.cooldown or 30)
        SendPoliceAlert(src, 'kill', coords, { street = data.street, gender = data.gender, animal = animal.type })
    end
end

--- Schließt einen Abschuss ab: Qualität, Legalität, Erfahrung, Statistik, Polizeimeldung.
---@param animal table Tierdaten
---@param src number Schütze
---@param cause number Waffen-Hash
---@param bone number|nil getroffener Knochen
---@param data table { hour, street, gender }
---@param opts table|nil { tracked = bool } – Tier ist nach einem Treffer verendet
function FinalizeKill(animal, src, cause, bone, data, opts)
    opts = opts or {}
    data = data or {}
    if not DoesEntityExist(animal.entity) or GetPlayerPing(src) <= 0 then
        MarkAnimalDead(animal)
        return
    end

    local cfg = Config.Animals[animal.type]
    local coords = GetEntityCoords(animal.entity)
    local quality = DetermineQuality(cause, bone)

    local dailyLimit = GetDailyLimit(animal.type)
    local violations = {
        outsideZone  = GetZoneAt(coords, Config.ZoneMargin) == nil,
        noLicense    = not HasValidLicense(src),
        closedSeason = IsClosedSeason(animal.type, GetCurrentMonth()),
        overLimit    = dailyLimit > 0 and GetDailyKills(src, animal.type) >= dailyLimit,
    }
    local illegal = violations.outsideZone or violations.noLicense or violations.closedSeason
        or violations.overLimit or cfg.protected == true

    if animal.dead then
        animal.killer = src
        animal.quality = quality
    else
        MarkAnimalDead(animal, src, quality)
    end
    animal.cause = NormalizeHash(cause)
    animal.violations = violations
    animal.illegal = illegal
    animal.tracked = opts.tracked == true

    RecordKill(src, animal.type, quality, illegal)

    if opts.tracked then
        NotifyPlayer(src, L('tracking_died', cfg.label), 'info')
    else
        NotifyPlayer(src, L('kill_confirmed', cfg.label, L('quality_' .. quality)), 'success')
    end

    -- Hinweise auf Verstöße (realistisch: der Jäger weiß, was er tut)
    if violations.noLicense then NotifyPlayer(src, L('violation_no_license'), 'error') end
    if violations.closedSeason then NotifyPlayer(src, L('violation_closed_season', cfg.label), 'error') end
    if violations.overLimit then NotifyPlayer(src, L('violation_over_limit', dailyLimit, cfg.label), 'error') end

    if not illegal then
        local xpCfg = Config.Progression.xp
        local xp = (xpCfg.kill and xpCfg.kill[animal.type]) or 0
        if quality == 'perfect' then xp = xp + (xpCfg.perfect or 0) end
        AddXP(src, xp)
    end

    HandleKillAlert(src, animal, cfg, coords, data, violations)
end

--- Tod ohne direkte Abschussmeldung (Verbluten, Sturz, ...): dem letzten Schützen zuordnen.
function HandleUnattributedDeath(animal)
    if animal.dead then return end
    local hit = animal.lastHit
    if Config.Tracking.enabled and hit and os.time() - hit.time <= Config.Tracking.attributionTime
        and GetPlayerPing(hit.src) > 0 then
        FinalizeKill(animal, hit.src, hit.weapon, hit.bone, hit.data, { tracked = true })
    else
        MarkAnimalDead(animal)
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
    FinalizeKill(animal, src, cause, data.bone, data)
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
    SyncBaits(src)
    SyncBlinds(src)
end)
