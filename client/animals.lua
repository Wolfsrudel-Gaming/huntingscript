--[[
    Tier-KI (clientseitig)

    Die Tiere werden serverseitig als vernetzte Peds in der normalen Spielwelt
    erstellt. Die KI wird immer von dem Client ausgeführt, dem das Tier gerade
    gehört (OneSync-Ownership). Der Zustand (wander/flee/attack + Ziel) liegt in
    Entity-State-Bags, damit ein neuer Besitzer nahtlos übernehmen kann und alle
    Clients wissen, wen ein aggressives Tier gerade angreift.
]]

HuntAnimals = {}            -- [ped] = { netId, type, cfg, zone, home }

local memory = {}           -- [netId] = lokale KI-Daten des Besitzers
local lastHit = {}          -- [ped] = Zeitpunkt des letzten Treffers auf den lokalen Spieler
local deathReported = {}    -- [netId] = true

--[[ Hilfsfunktionen ]]

local function ToVector(t)
    if not t then return nil end
    return vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0)
end

local function IsAnimalDead(ped)
    return IsPedDeadOrDying(ped, true) or IsEntityDead(ped)
end

local function GetMemory(animal)
    local mem = memory[animal.netId]
    if not mem then
        mem = {
            mode      = nil,
            target    = nil,
            applied   = nil,
            since     = GetGameTimer(),
            nextRoll  = 0,
            stuck     = 0,
            usingGoto = false,
            home      = animal.home,
            flagsSet  = false,
        }
        memory[animal.netId] = mem
    end
    return mem
end

--- Sendet einen KI-Wechsel an den Server (der Server prüft die Ownership und
--- setzt die State-Bags für alle Clients).
local function SetMode(ped, animal, mode, target)
    local mem = GetMemory(animal)
    if mem.mode == mode and mem.target == target then return end
    mem.mode = mode
    mem.target = target
    mem.applied = nil
    mem.since = GetGameTimer()
    mem.stuck = 0
    mem.usingGoto = false
    TriggerServerEvent('wr_hunting:server:setAI', animal.netId, mode, target)
    DebugPrint(('Tier %s (%s) -> %s %s'):format(animal.netId, animal.type, mode, tostring(target)))
end

local function ApplyFlags(ped, animal)
    local cfg = animal.cfg
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedSeeingRange(ped, cfg.detection or 30.0)
    SetPedHearingRange(ped, cfg.detection or 30.0)
    if cfg.behaviour == 'aggressive' then
        SetPedCombatAttributes(ped, 5, true)    -- Kann bewaffnete Gegner bekämpfen
        SetPedCombatAttributes(ped, 46, true)   -- Kämpft immer
        SetPedCombatAttributes(ped, 17, false)  -- Kein Fluchtverhalten im Kampf
        SetPedCombatMovement(ped, 3)            -- Offensiv
        SetPedCombatRange(ped, 0)               -- Nahkampf
    end

    -- Gesundheit nur einmalig initialisieren (Max-Health wird synchronisiert)
    if cfg.health and GetEntityMaxHealth(ped) ~= cfg.health then
        SetEntityMaxHealth(ped, cfg.health)
        SetEntityHealth(ped, cfg.health)
    end
end

--- Tarnung eines Spielers: Ansitz und Jäger-Stufe (über Player-State-Bags synchronisiert).
local function CamouflageMultiplier(serverId)
    local pState = Player(serverId).state
    local mult = 1.0
    if pState.huntHidden then
        mult = mult * Config.Blinds.stealthMultiplier
    end
    if Config.Progression.enabled then
        local perks = Config.Progression.perks
        mult = mult * (1.0 - GetPerkValue(pState.huntLevel or 1, perks.stealth, perks.maxStealth))
    end
    return mult
end

--- Effektiver Wahrnehmungsradius eines Tieres gegenüber einem Spieler-Ped.
local function DetectionRadius(animalCoords, base, playerPed, playerCoords, serverId, isNight)
    local b = Config.Behaviour
    local radius = base
    if IsPedInAnyVehicle(playerPed, false) then
        radius = radius * b.vehicleMultiplier
    elseif GetPedStealthMovement(playerPed) then
        radius = radius * b.stealthMultiplier
    elseif IsPedSprinting(playerPed) then
        radius = radius * b.sprintMultiplier
    end
    if isNight then radius = radius * b.nightMultiplier end
    radius = radius * GetWindMultiplier(playerCoords, animalCoords)
    radius = radius * CamouflageMultiplier(serverId)
    return radius
end

--- Sucht den nächsten Spieler, den das Tier wahrnimmt.
---@return number|nil serverId, number|nil ped, number|nil distance
local function FindNearestPlayer(ped, coords, baseRadius, useDetection)
    local isNight = IsNightHour(GetClockHours())
    local bestId, bestPed, bestDist = nil, nil, nil
    for _, player in ipairs(GetActivePlayers()) do
        local pPed = GetPlayerPed(player)
        local ignore = not useDetection and IsPedInAnyVehicle(pPed, false)   -- Angriffe nicht auf Fahrzeuge
        if pPed ~= 0 and not ignore and not IsEntityDead(pPed) then
            local pCoords = GetEntityCoords(pPed)
            local dist = #(pCoords - coords)
            local serverId = GetPlayerServerId(player)
            local radius = baseRadius
            if useDetection then
                radius = DetectionRadius(coords, baseRadius, pPed, pCoords, serverId, isNight)
                if dist <= radius and dist > radius * Config.Behaviour.noLosMultiplier
                    and not HasEntityClearLosToEntity(ped, pPed, 17) then
                    radius = radius * Config.Behaviour.noLosMultiplier
                end
            elseif Player(serverId).state.huntHidden then
                -- Im Ansitz wird man auch von angriffslustigen Tieren seltener entdeckt
                radius = radius * 0.5
            end
            if dist <= radius and (not bestDist or dist < bestDist) then
                bestId, bestPed, bestDist = GetPlayerServerId(player), pPed, dist
            end
        end
    end
    return bestId, bestPed, bestDist
end

--- Ermittelt den Spieler, der dem Tier zuletzt Schaden zugefügt hat.
local function FindAttacker(ped)
    for _, player in ipairs(GetActivePlayers()) do
        local pPed = GetPlayerPed(player)
        if pPed ~= 0 and HasEntityBeenDamagedByEntity(ped, pPed, true) then
            ClearEntityLastDamageEntity(ped)
            return GetPlayerServerId(player)
        end
    end
    ClearEntityLastDamageEntity(ped)
    return nil
end

--- Neuer Heimatpunkt nach einer Flucht: aktuelle Position, notfalls zurück ins Revier gezogen.
local function ComputeHome(animal, coords)
    local zone = animal.zone and Config.Zones[animal.zone]
    if not zone or IsPointInZone(zone, coords.x, coords.y) then
        return coords
    end
    local dir = vector3(coords.x - zone.center.x, coords.y - zone.center.y, 0.0)
    local len = #dir
    if len < 1.0 then return coords end
    local p = zone.center + dir / len * (zone.radius * 0.75)
    return vector3(p.x, p.y, coords.z)
end

--[[ KI-Zustände anwenden ]]

local function ApplyMode(ped, animal, mem)
    local key = ('%s:%s'):format(mem.mode, tostring(mem.target))
    if mem.applied == key then return end

    if mem.mode == 'wander' then
        local home = mem.home or GetEntityCoords(ped)
        ClearPedTasks(ped)
        TaskWanderInArea(ped, home.x, home.y, home.z, animal.homeRadius or Config.Spawning.homeRadius, 2.0, 6.0)
    elseif mem.mode == 'rest' then
        -- Wundbett: schwer verletztes Tier bleibt liegen bzw. stehen
        ClearPedTasks(ped)
        TaskStandStill(ped, -1)
        SetPedKeepTask(ped, true)
    elseif mem.mode == 'flee' then
        local threat = GetPlayerPedFromServerId(mem.target)
        ClearPedTasks(ped)
        if threat then
            TaskSmartFleePed(ped, threat, 250.0, -1, false, false)
        else
            local c = mem.threatCoords or GetEntityCoords(ped)
            TaskSmartFleeCoord(ped, c.x, c.y, c.z, 250.0, -1, false, false)
        end
        SetPedKeepTask(ped, true)
    elseif mem.mode == 'attack' then
        local targetPed = GetPlayerPedFromServerId(mem.target)
        if not targetPed then return end
        ClearPedTasks(ped)
        TaskCombatPed(ped, targetPed, 0, 16)
        SetPedKeepTask(ped, true)
    end
    mem.applied = key
end

local function StartAttack(ped, animal, targetId)
    SetMode(ped, animal, 'attack', targetId)
end

local function StartFlee(ped, animal, threatId, threatCoords)
    local mem = GetMemory(animal)
    mem.threatCoords = threatCoords
    SetMode(ped, animal, 'flee', threatId)
end

local function StartWander(ped, animal)
    local mem = GetMemory(animal)
    -- Angelockte Tiere kehren zum Köder zurück, alle anderen bleiben, wo sie sind
    if animal.homeRadius and animal.home then
        mem.home = animal.home
    else
        mem.home = ComputeHome(animal, GetEntityCoords(ped))
    end
    SetMode(ped, animal, 'wander', nil)
end

--[[ Schweißfährte: Blutverlust & Blutspur (nur Besitzer) ]]

local function SendBlood(animal, mem, now)
    if #mem.blood > 0 and now >= (mem.nextBloodSend or 0) then
        mem.nextBloodSend = now + 1500
        TriggerServerEvent('wr_hunting:server:bloodTrail', animal.netId, mem.blood)
        mem.blood = {}
    end
end

--- Gibt true zurück, wenn das Tier blutet.
local function HandleBleeding(ped, animal, mem, coords, health, now)
    local track = Config.Tracking
    if not track.enabled then return false end
    local maxHealth = GetEntityMaxHealth(ped)
    if maxHealth <= 0 or health / maxHealth > track.bleedThreshold then return false end

    mem.blood = mem.blood or {}
    if not mem.lastDrop or #(coords - mem.lastDrop) >= track.dropDistance then
        mem.lastDrop = coords
        mem.blood[#mem.blood + 1] = { x = coords.x, y = coords.y, z = coords.z }
    end

    if now >= (mem.nextBleed or 0) then
        mem.nextBleed = now + track.bleedInterval
        local newHealth = math.max(0, health - math.ceil(maxHealth * track.bleedRate))
        SetEntityHealth(ped, newHealth)
        mem.lastHealth = newHealth     -- kein "Treffer" durch Blutverlust
    end

    SendBlood(animal, mem, now)
    return true
end

--- Entscheidet, ob ein aggressives Tier angreift oder flüchtet.
local function RollAggression(agg, onDamage)
    local chance
    if onDamage then
        chance = agg.onDamageChance or agg.chance
    elseif IsNightHour(GetClockHours()) then
        chance = agg.nightChance or agg.chance
    else
        chance = agg.chance
    end
    return math.random(100) <= (chance or 0)
end

--[[ Hauptsteuerung für ein Tier, das diesem Client gehört ]]

local function ControlAnimal(ped, animal)
    local cfg = animal.cfg
    local mem = GetMemory(animal)
    local state = Entity(ped).state

    if IsAnimalDead(ped) then
        if not state.huntDead and not deathReported[animal.netId] then
            deathReported[animal.netId] = true
            TriggerServerEvent('wr_hunting:server:animalDied', animal.netId)
        end
        return
    end

    if not mem.flagsSet then
        ApplyFlags(ped, animal)
        mem.flagsSet = true
        -- Zustand vom vorherigen Besitzer übernehmen
        mem.mode = state.huntAI or 'wander'
        mem.target = state.huntTarget
        mem.since = GetGameTimer()
        mem.applied = nil
    end

    local now = GetGameTimer()
    local coords = GetEntityCoords(ped)
    local agg = cfg.aggressive

    -- Treffer erkannt?
    local health = GetEntityHealth(ped)
    if mem.lastHealth and health < mem.lastHealth then
        local attacker = FindAttacker(ped)
        if agg then
            if mem.mode ~= 'attack' then
                if attacker and RollAggression(agg, true) then
                    StartAttack(ped, animal, attacker)
                else
                    StartFlee(ped, animal, attacker, coords)
                end
            end
        elseif mem.mode ~= 'flee' or (attacker and attacker ~= mem.target) then
            StartFlee(ped, animal, attacker, coords)
        end
    end
    mem.lastHealth = health

    -- Angeschossen: Blutverlust & Schweißfährte
    local bleeding = HandleBleeding(ped, animal, mem, coords, health, now)
    local maxHealth = GetEntityMaxHealth(ped)
    local badlyHurt = bleeding and maxHealth > 0 and health / maxHealth <= Config.Tracking.restThreshold

    local mode = mem.mode or 'wander'

    if mode == 'rest' then
        -- Im Wundbett: nur bei unmittelbarer Gefahr erneut flüchten
        local threatId = FindNearestPlayer(ped, coords, (cfg.detection or 30.0) * 0.4, true)
        if threatId then StartFlee(ped, animal, threatId) end

    elseif mode == 'wander' then
        if agg then
            local targetId = FindNearestPlayer(ped, coords, agg.aggroRadius, false)
            if targetId and now >= mem.nextRoll then
                mem.nextRoll = now + 8000
                if RollAggression(agg, false) then
                    StartAttack(ped, animal, targetId)
                else
                    StartFlee(ped, animal, targetId)
                end
            elseif agg.fleeOnDetect then
                local threatId = FindNearestPlayer(ped, coords, cfg.detection, true)
                if threatId then StartFlee(ped, animal, threatId) end
            end
        else
            local threatId = FindNearestPlayer(ped, coords, cfg.detection, true)
            if threatId then StartFlee(ped, animal, threatId) end
        end

    elseif mode == 'flee' then
        if badlyHurt and now - mem.since > 15000 then
            -- Schwer verletzte Tiere legen sich nach kurzer Flucht ins Wundbett
            SetMode(ped, animal, 'rest', nil)
        elseif now - mem.since > (cfg.fleeTime or 20) * 1000 then
            local threatId = FindNearestPlayer(ped, coords, (cfg.detection or 30.0) * 0.8, true)
            if threatId then
                mem.since = now     -- Gefahr noch in der Nähe → weiter flüchten
                if threatId ~= mem.target then StartFlee(ped, animal, threatId) end
            else
                StartWander(ped, animal)
            end
        end

    elseif mode == 'attack' then
        local targetPed = GetPlayerPedFromServerId(mem.target)
        local giveUp = not targetPed or IsEntityDead(targetPed)
        local dist = targetPed and #(GetEntityCoords(targetPed) - coords) or 9999.0

        if not giveUp and agg then
            if dist > agg.chaseDistance then giveUp = true end
            if now - mem.since > agg.maxChaseTime * 1000 then giveUp = true end
            if IsPedInAnyVehicle(targetPed, false) and now - mem.since > 5000 then giveUp = true end
        end

        if giveUp or not agg then
            -- Rückzug nach einem Angriff
            StartFlee(ped, animal, mem.target, coords)
        else
            -- Falls das Tier im Kampfmodus nicht von selbst angreift: aktiv auf das Ziel zulaufen
            if dist > agg.reach + 1.0 and GetEntitySpeed(ped) < 0.5 then
                mem.stuck = mem.stuck + 1
                if mem.stuck >= 4 then
                    mem.stuck = 0
                    mem.usingGoto = true
                    ClearPedTasks(ped)
                    TaskGoToEntity(ped, targetPed, -1, agg.reach * 0.5, 3.0, 1073741824, 0)
                end
            else
                mem.stuck = 0
            end
            if mem.usingGoto and dist <= agg.reach + 0.5 then
                mem.usingGoto = false
                mem.applied = nil   -- erneut Kampf-Task setzen
            end
        end
    end

    if not mem.usingGoto then
        ApplyMode(ped, animal, mem)
    end
end

--[[ Threads ]]

-- 1) Scan: alle vernetzten Jagdtiere in Reichweite erfassen
CreateThread(function()
    while true do
        local found = {}
        for _, ped in ipairs(GetGamePool('CPed')) do
            local hash = NormalizeHash(GetEntityModel(ped))
            if AnimalByModel[hash] and NetworkGetEntityIsNetworked(ped) then
                local info = Entity(ped).state.huntAnimal
                if info and Config.Animals[info.type] then
                    local existing = HuntAnimals[ped]
                    found[ped] = existing or {
                        netId = NetworkGetNetworkIdFromEntity(ped),
                        type  = info.type,
                        cfg   = Config.Animals[info.type],
                        zone  = info.zone,
                        home  = ToVector(info.home),
                        homeRadius = info.homeRadius,
                    }
                end
            end
        end
        -- Speicher für verschwundene Tiere aufräumen
        local alive = {}
        for _, a in pairs(found) do alive[a.netId] = true end
        for netId in pairs(memory) do
            if not alive[netId] then memory[netId] = nil end
        end
        for ped in pairs(lastHit) do
            if not found[ped] then lastHit[ped] = nil end
        end
        HuntAnimals = found
        Wait(1000)
    end
end)

-- 2) KI für Tiere, die diesem Client gehören
CreateThread(function()
    local me = PlayerId()
    while true do
        local sleep = 1000
        for ped, animal in pairs(HuntAnimals) do
            if DoesEntityExist(ped) and NetworkGetEntityOwner(ped) == me then
                sleep = 400
                local ok, err = pcall(ControlAnimal, ped, animal)
                if not ok then DebugPrint('KI-Fehler: ' .. tostring(err)) end
            elseif memory[animal.netId] then
                -- Ownership verloren → beim nächsten Mal Flags/Tasks neu setzen
                memory[animal.netId].flagsSet = false
                memory[animal.netId].applied = nil
            end
        end
        Wait(sleep)
    end
end)

-- 3) Schaden durch angreifende Tiere am lokalen Spieler
local function ApplyAnimalHit(myPed, animalPed, animal)
    local agg = animal.cfg.aggressive
    local damage = math.random(agg.damage[1], agg.damage[2])
    ApplyDamageToPed(myPed, damage, false)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
    if agg.ragdollChance and agg.ragdollChance > 0 and math.random(100) <= agg.ragdollChance then
        local fwd = GetEntityForwardVector(animalPed)
        SetPedToRagdoll(myPed, 1500, 2500, 0, false, false, false)
        ApplyForceToEntity(myPed, 1, fwd.x * 6.0, fwd.y * 6.0, 2.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    end
end

CreateThread(function()
    while true do
        local sleep = 500
        local myPed = PlayerPedId()
        local myId = GetPlayerServerId(PlayerId())
        if not IsEntityDead(myPed) then
            local myCoords = GetEntityCoords(myPed)
            for ped, animal in pairs(HuntAnimals) do
                local agg = animal.cfg.aggressive
                if agg and DoesEntityExist(ped) then
                    local state = Entity(ped).state
                    if state.huntAI == 'attack' and state.huntTarget == myId and not IsAnimalDead(ped) then
                        sleep = 100
                        local dist = #(GetEntityCoords(ped) - myCoords)
                        if dist <= agg.reach and not IsPedInAnyVehicle(myPed, false) then
                            local now = GetGameTimer()
                            if now - (lastHit[ped] or 0) >= agg.cooldown then
                                lastHit[ped] = now
                                ApplyAnimalHit(myPed, ped, animal)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- 4) Schüsse in der Nähe → Tiere flüchten (vom Server weitergeleitet)
RegisterNetEvent('wr_hunting:client:gunshot', function(shooterId, coords, radius)
    local me = PlayerId()
    for ped, animal in pairs(HuntAnimals) do
        if DoesEntityExist(ped) and NetworkGetEntityOwner(ped) == me and not IsAnimalDead(ped) then
            local mem = GetMemory(animal)
            if mem.mode ~= 'attack' and #(GetEntityCoords(ped) - coords) <= radius then
                StartFlee(ped, animal, shooterId, coords)
            end
        end
    end
end)

--[[ Spawnpunkt-Suche (Anfrage vom Server) ]]

local function FindGround(x, y, refZ)
    for _, startZ in ipairs({ refZ + 80.0, refZ + 250.0, 1000.0 }) do
        local found, groundZ, normal = GetGroundZAndNormalFor_3dCoord(x, y, startZ)
        if found then
            if normal.z < Config.Spawning.minGroundNormal then return nil end
            local isWater, waterZ = GetWaterHeight(x, y, groundZ)
            if isWater and waterZ > groundZ then return nil end
            if GetInteriorAtCoords(x, y, groundZ) ~= 0 then return nil end
            return groundZ
        end
    end
    return nil
end

RegisterNetEvent('wr_hunting:client:findSpawn', function(requestId, zoneIndex, count, minDist, maxDist, customOrigin)
    local zone = zoneIndex and Config.Zones[zoneIndex]
    -- customOrigin: z.B. ein Köder, um den herum gesucht wird
    local origin = customOrigin or GetEntityCoords(PlayerPedId())
    minDist = minDist or Config.Spawning.minDistance
    maxDist = maxDist or Config.Spawning.maxDistance

    local points = {}
    local tries = 0
    while #points < count and tries < 30 do
        tries = tries + 1
        local angle = math.random() * 2.0 * math.pi
        local dist = minDist + math.random() * (maxDist - minDist)
        local x = origin.x + math.cos(angle) * dist
        local y = origin.y + math.sin(angle) * dist

        if not zone or IsPointInZone(zone, x, y) then
            RequestCollisionAtCoord(x, y, origin.z)
            local z = FindGround(x, y, origin.z)
            if z then
                local visible = Config.Spawning.avoidVisible and IsSphereVisible(x, y, z + 0.5, 1.5)
                if not visible or tries > 20 then
                    points[#points + 1] = { x = x, y = y, z = z, h = math.random() * 360.0 }
                end
            end
        end
        Wait(0)
    end

    TriggerServerEvent('wr_hunting:server:spawnPoints', requestId, points, GetClockHours())
end)

--[[ Debug-Anzeige ]]

if Config.Debug then
    CreateThread(function()
        while true do
            for ped, animal in pairs(HuntAnimals) do
                if DoesEntityExist(ped) then
                    local state = Entity(ped).state
                    local c = GetEntityCoords(ped)
                    DrawText3D(vector3(c.x, c.y, c.z + 1.2), ('%s #%s\n%s %s\nOwner: %s  HP: %s'):format(
                        animal.type, animal.netId, tostring(state.huntAI), tostring(state.huntTarget or ''),
                        GetPlayerServerId(NetworkGetEntityOwner(ped)), GetEntityHealth(ped)), 0.3)
                end
            end
            Wait(0)
        end
    end)
end
