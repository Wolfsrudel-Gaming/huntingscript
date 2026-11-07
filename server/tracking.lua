--[[
    Schweißfährte & Nachsuche (serverseitig):
    - Treffer ohne Todesfolge werden dem Schützen zugeordnet (animal.lastHit)
    - Blutspuren des Tier-Besitzers werden an Spieler in der Nähe verteilt
    - Verendet das Tier später, ordnet HandleUnattributedDeath es dem Schützen zu
]]

local BLOOD_RANGE = 300.0

local function BroadcastBlood(origin, points, pool)
    for _, p in ipairs(GetPlayersWithCoords()) do
        if #(p.coords - origin) <= BLOOD_RANGE then
            TriggerClientEvent('wr_hunting:client:blood', p.src, points, pool)
        end
    end
end

RegisterNetEvent('wr_hunting:server:animalHit', function(netId, data)
    local src = source
    if not Config.Tracking.enabled or type(data) ~= 'table' then return end
    local animal = GetAnimalByNet(netId)
    if not animal or animal.dead or not DoesEntityExist(animal.entity) then return end
    if RateLimited(src, 'animalHit:' .. tostring(netId), 500) then return end

    local coords = GetEntityCoords(animal.entity)
    if not IsPlayerNear(src, coords, 500.0) then return end

    -- Ein Treffer ohne Todesfolge belegt, dass das Tier gelebt hat (wichtig für die Todeserkennung)
    animal.seenAlive = true
    animal.lastHit = {
        src    = src,
        weapon = NormalizeHash(data.weapon),
        bone   = tonumber(data.bone),
        time   = os.time(),
        data   = {
            hour   = tonumber(data.hour),
            street = type(data.street) == 'string' and data.street:sub(1, 100) or '',
            gender = data.gender == 'female' and 'female' or 'male',
        },
    }

    -- Anschuss: Blutlache an der Trefferstelle
    BroadcastBlood(coords, { { x = coords.x, y = coords.y, z = coords.z } }, true)
end)

RegisterNetEvent('wr_hunting:server:bloodTrail', function(netId, points)
    local src = source
    if not Config.Tracking.enabled or type(points) ~= 'table' or #points == 0 or #points > 12 then return end
    local animal = GetAnimalByNet(netId)
    if not animal or not DoesEntityExist(animal.entity) then return end
    if NetworkGetEntityOwner(animal.entity) ~= src then return end
    if RateLimited(src, 'bloodTrail:' .. tostring(netId), 1000) then return end

    local coords = GetEntityCoords(animal.entity)
    local clean = {}
    for _, p in ipairs(points) do
        local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
        if x and y and z and #(vector3(x, y, z) - coords) <= 60.0 then
            clean[#clean + 1] = { x = x, y = y, z = z }
        end
    end
    if #clean > 0 then
        BroadcastBlood(coords, clean, false)
    end
end)
