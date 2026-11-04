--[[
    Serverseitige Verwaltung der Wildtiere.

    - Tiere werden serverseitig (OneSync) als vernetzte Peds in der normalen
      Spielwelt erstellt – nur innerhalb der Jagdreviere und nur dann, wenn sich
      Spieler im Revier aufhalten.
    - Ein Client im Revier sucht einen passenden Bodenpunkt (Bodenhöhe ist nur
      clientseitig bekannt), der Server prüft und erstellt das Tier.
    - Tiere ohne Spieler in der Nähe sowie alte Kadaver werden entfernt.
]]

Animals = {}            -- [id] = Tierdaten
AnimalsByNet = {}       -- [netId] = Tierdaten

local nextAnimalId = 0
local nextRequestId = 0
local pendingRequests = {}  -- [requestId] = { src, zone, expires, forceType }
local zoneTimers = {}       -- [zoneIndex] = os.time() des nächsten Spawn-Versuchs

local AI_MODES = { wander = true, flee = true, attack = true }

--[[ Hilfsfunktionen ]]

function GetAnimalByNet(netId)
    return AnimalsByNet[tonumber(netId) or -1]
end

--- Serverseitige Todesprüfung. Ein Tier gilt erst als tot, wenn es vorher
--- einmal lebend synchronisiert wurde (frisch erstellte Peds melden ggf. 0 HP).
function IsServerPedDead(animal)
    if not DoesEntityExist(animal.entity) then return false end
    if GetEntityHealth(animal.entity) > 0 then
        animal.seenAlive = true
        return false
    end
    return animal.seenAlive == true
end

function RemoveAnimal(id)
    local animal = Animals[id]
    if not animal then return end
    if DoesEntityExist(animal.entity) then
        DeleteEntity(animal.entity)
    end
    AnimalsByNet[animal.netId] = nil
    Animals[id] = nil
end

local function CountAlive(zoneIndex)
    local zoneCount, total = 0, 0
    for _, animal in pairs(Animals) do
        if not animal.dead then
            total = total + 1
            if animal.zone == zoneIndex then zoneCount = zoneCount + 1 end
        end
    end
    return zoneCount, total
end

local function AnyPlayerWithin(coords, radius, players)
    for _, p in ipairs(players) do
        if #(p.coords - coords) <= radius then return true end
    end
    return false
end

--- Wählt eine Tierart anhand der Gewichtung des Reviers und der Tageszeit.
local function PickAnimalType(zone, hour)
    local period = GetDayPeriod(hour)
    local total, pool = 0.0, {}
    for name, weight in pairs(zone.animals) do
        local cfg = Config.Animals[name]
        if cfg then
            local mult = cfg.activity and cfg.activity[period] or 1.0
            local w = weight * mult
            if w > 0 then
                total = total + w
                pool[#pool + 1] = { name = name, weight = w }
            end
        end
    end
    if total <= 0 then return nil end
    local roll = math.random() * total
    for _, entry in ipairs(pool) do
        roll = roll - entry.weight
        if roll <= 0 then return entry.name end
    end
    return pool[#pool].name
end

--[[ Tiere erstellen ]]

local function CreateAnimal(typeName, zoneIndex, x, y, z, heading)
    local cfg = Config.Animals[typeName]
    if not cfg then return nil end

    local entity = CreatePed(28, cfg.hash, x, y, z + 0.5, heading, true, true)
    local timeout = GetGameTimer() + 3000
    while not DoesEntityExist(entity) and GetGameTimer() < timeout do
        Wait(10)
    end
    if not DoesEntityExist(entity) then
        DebugPrint(('Tier %s konnte nicht erstellt werden'):format(typeName))
        return nil
    end

    nextAnimalId = nextAnimalId + 1
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local animal = {
        id        = nextAnimalId,
        entity    = entity,
        netId     = netId,
        type      = typeName,
        zone      = zoneIndex,
        home      = vector3(x, y, z),
        spawnedAt = os.time(),
        dead      = false,
    }
    Animals[animal.id] = animal
    AnimalsByNet[netId] = animal

    local state = Entity(entity).state
    state:set('huntAnimal', { type = typeName, zone = zoneIndex, home = { x = x, y = y, z = z } }, true)
    state:set('huntAI', 'wander', true)

    DebugPrint(('Tier gespawnt: %s (netId %s) in Revier %s'):format(typeName, netId, tostring(zoneIndex)))
    return animal
end

--- Fragt bei einem Client gültige Spawnpunkte an.
local function RequestSpawn(src, zoneIndex, count, opts)
    opts = opts or {}
    nextRequestId = nextRequestId + 1
    pendingRequests[nextRequestId] = {
        src       = src,
        zone      = zoneIndex,
        expires   = os.time() + 15,
        forceType = opts.forceType,
        minDist   = opts.minDist or Config.Spawning.minDistance,
    }
    TriggerClientEvent('wr_hunting:client:findSpawn', src, nextRequestId, zoneIndex, count, opts.minDist, opts.maxDist)
end

RegisterNetEvent('wr_hunting:server:spawnPoints', function(requestId, points, hour)
    local src = source
    local req = pendingRequests[requestId]
    if not req or req.src ~= src or req.expires < os.time() then return end
    pendingRequests[requestId] = nil
    if type(points) ~= 'table' then return end

    local zone = req.zone and Config.Zones[req.zone]
    local players = GetPlayersWithCoords()
    local requester = GetPlayerCoords(src)
    if not requester then return end

    for _, p in ipairs(points) do
        local x, y, z, h = tonumber(p.x), tonumber(p.y), tonumber(p.z), tonumber(p.h) or 0.0
        if x and y and z then
            local point = vector3(x, y, z)
            local valid = #(point - requester) <= Config.Spawning.maxDistance + 30.0
            if valid and zone and not IsPointInZone(zone, x, y) then valid = false end
            if valid and not req.forceType then
                -- Nie direkt neben einem Spieler spawnen
                for _, pl in ipairs(players) do
                    if #(pl.coords - point) < req.minDist * 0.8 then valid = false break end
                end
            end

            if valid then
                local zoneCount, total = CountAlive(req.zone)
                if not req.forceType and (total >= Config.Spawning.maxGlobal or (zone and zoneCount >= zone.maxAnimals)) then
                    break
                end

                local typeName = req.forceType or (zone and PickAnimalType(zone, hour))
                local cfg = typeName and Config.Animals[typeName]
                if cfg then
                    local groupSize = 1
                    if not req.forceType and cfg.group then
                        groupSize = math.random(cfg.group[1], cfg.group[2])
                        if zone then groupSize = math.min(groupSize, zone.maxAnimals - zoneCount) end
                    end
                    for i = 1, math.max(1, groupSize) do
                        local ox, oy = 0.0, 0.0
                        if i > 1 then
                            ox, oy = math.random(-40, 40) / 10.0, math.random(-40, 40) / 10.0
                        end
                        CreateAnimal(typeName, req.zone, x + ox, y + oy, z + (i > 1 and 0.5 or 0.0), h)
                    end
                    -- Pro Anfrage nur eine Gruppe → natürliche Verteilung über Zeit
                    break
                end
            end
        end
    end
end)

--[[ KI-Zustand (vom Besitzer-Client gemeldet) ]]

RegisterNetEvent('wr_hunting:server:setAI', function(netId, mode, target)
    local src = source
    local animal = GetAnimalByNet(netId)
    if not animal or animal.dead or not AI_MODES[mode] then return end
    if not DoesEntityExist(animal.entity) then return end
    if NetworkGetEntityOwner(animal.entity) ~= src then return end
    if RateLimited(src, 'setAI:' .. netId, 200) then return end

    target = tonumber(target)
    if target and GetPlayerPing(target) <= 0 then target = nil end
    if mode == 'attack' and not target then return end

    local state = Entity(animal.entity).state
    state:set('huntAI', mode, true)
    state:set('huntTarget', target, true)
end)

--[[ Tod ohne bekannten Schützen (Sturz, NPC, ...) ]]

RegisterNetEvent('wr_hunting:server:animalDied', function(netId)
    local src = source
    local animal = GetAnimalByNet(netId)
    if not animal or animal.dead or animal.verifying then return end
    if not DoesEntityExist(animal.entity) then return end
    if not IsPlayerNear(src, GetEntityCoords(animal.entity), 450.0) then return end

    -- Dem Schützen Vorrang lassen, damit dessen Meldung zählt
    Wait(2500)
    if animal.dead or animal.verifying then return end
    for _ = 1, 8 do
        if IsServerPedDead(animal) or GetPedCauseOfDeath(animal.entity) ~= 0 then
            MarkAnimalDead(animal)
            return
        end
        Wait(250)
    end
end)

function MarkAnimalDead(animal, killer, quality)
    if animal.dead then return end
    animal.dead = true
    animal.deadAt = os.time()
    animal.killer = killer
    animal.quality = quality or 'damaged'
    if DoesEntityExist(animal.entity) then
        local state = Entity(animal.entity).state
        state:set('huntDead', true, true)
        state:set('huntAI', nil, true)
        state:set('huntTarget', nil, true)
    end
end

--[[ Haupt-Schleife: Spawnen & Aufräumen ]]

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        local players = GetPlayersWithCoords()

        -- Aufräumen
        for id, animal in pairs(Animals) do
            if not DoesEntityExist(animal.entity) then
                AnimalsByNet[animal.netId] = nil
                Animals[id] = nil
            else
                local coords = GetEntityCoords(animal.entity)
                if not animal.dead and not animal.verifying and IsServerPedDead(animal) then
                    -- Erst beim zweiten Durchlauf markieren, damit die Meldung des Schützen Vorrang hat
                    if not animal.deathSeen then
                        animal.deathSeen = now
                    elseif now - animal.deathSeen >= 3 then
                        MarkAnimalDead(animal)
                    end
                end
                if animal.dead then
                    if now - animal.deadAt > Config.Spawning.carcassLifetime then
                        RemoveAnimal(id)
                    end
                elseif not AnyPlayerWithin(coords, Config.Spawning.despawnDistance, players) then
                    RemoveAnimal(id)
                end
            end
        end

        for reqId, req in pairs(pendingRequests) do
            if req.expires < now then pendingRequests[reqId] = nil end
        end

        -- Spawnen
        for zoneIndex, zone in ipairs(Config.Zones) do
            local inZone = {}
            for _, p in ipairs(players) do
                if IsPointInZone(zone, p.coords.x, p.coords.y) then
                    inZone[#inZone + 1] = p
                end
            end

            if #inZone > 0 and now >= (zoneTimers[zoneIndex] or 0) then
                zoneTimers[zoneIndex] = now + Config.Spawning.interval
                local zoneCount, total = CountAlive(zoneIndex)
                if zoneCount < zone.maxAnimals and total < Config.Spawning.maxGlobal then
                    -- Spieler mit den wenigsten Tieren in seiner Umgebung bevorzugen
                    local best, bestCount = nil, nil
                    for _, p in ipairs(inZone) do
                        local count = 0
                        for _, animal in pairs(Animals) do
                            if not animal.dead and DoesEntityExist(animal.entity)
                                and #(GetEntityCoords(animal.entity) - p.coords) < 250.0 then
                                count = count + 1
                            end
                        end
                        if not bestCount or count < bestCount then best, bestCount = p, count end
                    end
                    if best then RequestSpawn(best.src, zoneIndex, 3) end
                end
            end
        end
    end
end)

--[[ Admin-Befehle ]]

local function AnimalTypeList()
    local list = {}
    for name in pairs(Config.Animals) do list[#list + 1] = name end
    table.sort(list)
    return table.concat(list, ', ')
end

ESX.RegisterCommand('huntspawn', 'admin', function(xPlayer, args)
    local typeName = args.type
    if not Config.Animals[typeName] then
        xPlayer.showNotification(L('admin_invalid_type', AnimalTypeList()))
        return
    end
    local coords = GetPlayerCoords(xPlayer.source)
    local zone = coords and GetZoneAt(coords)
    RequestSpawn(xPlayer.source, zone and zone.index or nil, 1, { forceType = typeName, minDist = 8.0, maxDist = 15.0 })
end, false, { help = 'Jagdtier spawnen', arguments = { { name = 'type', help = 'deer, boar, coyote, rabbit', type = 'string' } } })

ESX.RegisterCommand('huntclear', 'admin', function(xPlayer)
    local count = 0
    for id in pairs(Animals) do
        RemoveAnimal(id)
        count = count + 1
    end
    xPlayer.showNotification(L('admin_cleared', count))
end, false, { help = 'Alle Jagdtiere entfernen' })

--[[ Ressourcen-Stopp ]]

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, animal in pairs(Animals) do
        if DoesEntityExist(animal.entity) then DeleteEntity(animal.entity) end
    end
end)
