--[[
    Jäger-Funktionen: Jagdschein vorzeigen/prüfen, Statistik, Jagdzeiten und
    die Kadaver-Untersuchung durch die Polizei.
]]

local function CharacterName(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getName then return xPlayer.getName() end
    return GetPlayerName(src)
end

--[[ Fernglas ]]

ESX.RegisterUsableItem(Config.Binoculars.item, function(src)
    if Inventory.Count(src, Config.Binoculars.item) < 1 then return end
    TriggerClientEvent('wr_hunting:client:useBinoculars', src)
end)

--[[ Jagdschein vorzeigen ]]

RegisterCommand('jagdschein', function(src)
    if src == 0 or RateLimited(src, 'showLicense', 3000) then return end
    local valid, untilTs = GetLicenseStatus(src)
    local text = FormatLicense(valid, untilTs)
    NotifyPlayer(src, L('license_own', text), valid and 'success' or 'error')

    local target = GetClosestPlayer(src, 3.0)
    if target then
        NotifyPlayer(target, L('license_shown', CharacterName(src), text), 'info')
    end
end, false)

--[[ Polizei: Jagdschein der nächsten Person prüfen ]]

RegisterCommand('jagdscheinpruefen', function(src)
    if src == 0 or RateLimited(src, 'checkLicense', 3000) then return end
    if not IsPoliceJob(src) then
        return NotifyPlayer(src, L('police_only'), 'error')
    end
    local target = GetClosestPlayer(src, 3.0)
    if not target then
        return NotifyPlayer(src, L('no_player_nearby'), 'error')
    end
    local valid, untilTs = GetLicenseStatus(target)
    NotifyPlayer(src, L('license_checked', CharacterName(target), FormatLicense(valid, untilTs)), valid and 'success' or 'error')
    NotifyPlayer(target, L('license_being_checked'), 'info')
end, false)

--[[ Statistik ]]

ESX.RegisterServerCallback('wr_hunting:hunter:stats', function(src, cb)
    local profile = GetProfile(src)
    if not profile then return cb(false) end

    local level = GetLevelFromXP(profile.xp)
    local nextXp = Config.Progression.levels[level + 1]
    local kills = {}
    for name, cfg in pairs(Config.Animals) do
        kills[#kills + 1] = { label = cfg.label, count = profile.stats.kills[name] or 0 }
    end
    table.sort(kills, function(a, b) return a.label < b.label end)

    local valid, untilTs = GetLicenseStatus(src)
    cb(true, {
        level    = level,
        xp       = profile.xp,
        nextXp   = nextXp,
        kills    = kills,
        perfect  = profile.stats.perfect or 0,
        trophies = profile.stats.trophies or 0,
        tanned   = profile.stats.tanned or 0,
        cooked   = profile.stats.cooked or 0,
        tracked  = profile.stats.tracked or 0,
        poached  = profile.stats.poached or 0,
        license  = FormatLicense(valid, untilTs),
        enabled  = Config.Progression.enabled,
    })
end)

ESX.RegisterServerCallback('wr_hunting:hunter:seasons', function(src, cb)
    local month = GetCurrentMonth()
    local list = {}
    for name, cfg in pairs(Config.Animals) do
        list[#list + 1] = {
            label  = cfg.label,
            closed = IsClosedSeason(name, month),
            limit  = GetDailyLimit(name),
            today  = GetDailyKills(src, name),
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    cb(true, list)
end)

--[[ Polizei: Kadaver untersuchen ]]

ESX.RegisterServerCallback('wr_hunting:police:inspect', function(src, cb, netId)
    if not Config.Police.inspection.enabled or not IsPoliceJob(src) then return cb(false, L('police_only')) end
    local animal = GetAnimalByNet(netId)
    if not animal or not animal.dead or not DoesEntityExist(animal.entity) then
        return cb(false, L('carcass_invalid'))
    end
    if not IsPlayerNear(src, GetEntityCoords(animal.entity), 4.0) then return cb(false, L('too_far')) end

    local v = animal.violations or {}
    local findings = {}
    if v.closedSeason then findings[#findings + 1] = L('inspect_closed_season') end
    if v.outsideZone then findings[#findings + 1] = L('inspect_outside_zone') end
    if v.overLimit then findings[#findings + 1] = L('inspect_over_limit') end
    if Config.Animals[animal.type].protected then findings[#findings + 1] = L('inspect_protected') end

    cb(true, {
        label    = Config.Animals[animal.type].label,
        minutes  = math.floor((os.time() - (animal.deadAt or os.time())) / 60),
        weapon   = L('weapon_cat_' .. GetWeaponCategory(animal.cause or 0)),
        quality  = L('quality_' .. (animal.quality or 'damaged')),
        tracked  = animal.tracked == true,
        findings = findings,
    })
end)
