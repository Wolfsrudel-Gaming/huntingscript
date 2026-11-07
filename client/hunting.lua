--[[
    Jagdreviere (Blips & Hinweise), Abschussmeldung, Schuss-Weiterleitung
    und Erkennung gezogener Jagdwaffen außerhalb der Reviere.
]]

local zoneBlips = {}
local reportedKills = {}

--[[ Blips der Jagdreviere ]]

CreateThread(function()
    if not Config.ZoneBlips.enabled then return end
    for _, zone in ipairs(Config.Zones) do
        if zone.blip ~= false then
            local radiusBlip = AddBlipForRadius(zone.center.x, zone.center.y, zone.center.z, zone.radius)
            SetBlipColour(radiusBlip, Config.ZoneBlips.colour)
            SetBlipAlpha(radiusBlip, Config.ZoneBlips.radiusAlpha)
            SetBlipAsShortRange(radiusBlip, true)

            local blip = AddBlipForCoord(zone.center.x, zone.center.y, zone.center.z)
            SetBlipSprite(blip, Config.ZoneBlips.sprite)
            SetBlipColour(blip, Config.ZoneBlips.colour)
            SetBlipScale(blip, Config.ZoneBlips.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(zone.label)
            EndTextCommandSetBlipName(blip)

            zoneBlips[#zoneBlips + 1] = radiusBlip
            zoneBlips[#zoneBlips + 1] = blip
        end
    end
end)

--[[ Betreten/Verlassen eines Reviers + gezogene Jagdwaffen ]]

local function ReportWeapon(weapon, reason)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('wr_hunting:server:weaponDrawn', weapon, reason, GetStreetLabel(coords),
        IsPedMale(ped) and 'male' or 'female')
end

CreateThread(function()
    local lastZone = nil
    local lastWeapon = nil
    local lastInZone = nil

    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local zone = GetZoneAt(coords)
        local inZoneWithMargin = GetZoneAt(coords, Config.ZoneMargin) ~= nil

        -- Hinweise beim Betreten/Verlassen
        if Config.ZoneNotifications and zone ~= lastZone then
            if zone then
                Notify(L('zone_enter', zone.label), 'info')
            elseif lastZone then
                Notify(L('zone_leave', lastZone.label), 'info')
            end
        end
        lastZone = zone

        -- Jagdwaffen außerhalb eines Reviers
        local weapon = nil
        if not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
            weapon = NormalizeHash(GetSelectedPedWeapon(ped))
        end
        local hw = weapon and HuntingWeaponHashes[weapon]

        if hw and hw.alert and not inZoneWithMargin then
            if weapon ~= lastWeapon then
                ReportWeapon(weapon, 'drawn')
            elseif Config.Police.weapon.onLeaveZone and lastInZone then
                ReportWeapon(weapon, 'left_zone')
            end
        end

        lastWeapon = weapon
        lastInZone = inZoneWithMargin
        Wait(300)
    end
end)

--[[ Schüsse: Tiere in der Nähe flüchten lassen ]]

CreateThread(function()
    local lastSent = 0
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if IsPedArmed(ped, 4) and GetZoneAt(GetEntityCoords(ped), Config.Behaviour.gunshotRadius) then
            sleep = 0
            if IsPedShooting(ped) and GetGameTimer() - lastSent > 1500 then
                lastSent = GetGameTimer()
                TriggerServerEvent('wr_hunting:server:gunshot', IsPedCurrentWeaponSilenced(ped))
            end
        end
        Wait(sleep)
    end
end)

--[[ Abschuss melden ]]

local function ReportKill(victim)
    if not DoesEntityExist(victim) or not NetworkGetEntityIsNetworked(victim) then return end
    local netId = NetworkGetNetworkIdFromEntity(victim)
    if reportedKills[netId] then return end
    reportedKills[netId] = true

    -- Kurz warten, bis Todesursache & Trefferzone gesetzt sind
    Wait(250)
    local _, bone = GetPedLastDamageBone(victim)
    local weapon = GetPedCauseOfDeath(victim)
    if not weapon or weapon == 0 then
        weapon = GetSelectedPedWeapon(PlayerPedId())
    end
    local coords = GetEntityCoords(victim)
    local ped = PlayerPedId()

    TriggerServerEvent('wr_hunting:server:animalKilled', netId, {
        weapon = NormalizeHash(weapon),
        bone   = bone,
        hour   = GetClockHours(),
        street = GetStreetLabel(coords),
        gender = IsPedMale(ped) and 'male' or 'female',
    })
end

--- Treffer ohne Todesfolge (für Schweißfährte & Nachsuche)
local lastHitReport = {}
function ReportHit(victim, weaponArg)
    if not Config.Tracking.enabled or not DoesEntityExist(victim) then return end
    local netId = NetworkGetNetworkIdFromEntity(victim)
    local now = GetGameTimer()
    if lastHitReport[netId] and now - lastHitReport[netId] < 750 then return end
    lastHitReport[netId] = now

    local _, bone = GetPedLastDamageBone(victim)
    local weapon = tonumber(weaponArg) or 0
    if weapon == 0 then weapon = GetSelectedPedWeapon(PlayerPedId()) end
    local ped = PlayerPedId()
    TriggerServerEvent('wr_hunting:server:animalHit', netId, {
        weapon = NormalizeHash(weapon),
        bone   = bone,
        hour   = GetClockHours(),
        street = GetStreetLabel(GetEntityCoords(victim)),
        gender = IsPedMale(ped) and 'male' or 'female',
    })
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim, attacker = args[1], args[2]
    if attacker ~= PlayerPedId() or not victim or not DoesEntityExist(victim) then return end
    if not IsEntityAPed(victim) or not AnimalByModel[NormalizeHash(GetEntityModel(victim))] then return end
    if not NetworkGetEntityIsNetworked(victim) or not Entity(victim).state.huntAnimal then return end
    local fatal = args[6] == 1

    CreateThread(function()
        Wait(100)
        if fatal or IsPedDeadOrDying(victim, true) or IsEntityDead(victim) then
            ReportKill(victim)
        else
            ReportHit(victim, args[7])
        end
    end)
end)

-- Fallback: Tod wurde verzögert synchronisiert
CreateThread(function()
    while true do
        local myPed = PlayerPedId()
        for ped, animal in pairs(HuntAnimals) do
            if not reportedKills[animal.netId] and DoesEntityExist(ped)
                and (IsPedDeadOrDying(ped, true) or IsEntityDead(ped))
                and not Entity(ped).state.huntDead
                and GetPedSourceOfDeath(ped) == myPed then
                CreateThread(function() ReportKill(ped) end)
            end
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(zoneBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
