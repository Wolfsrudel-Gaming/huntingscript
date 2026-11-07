--[[
    Schweißfährte: Blutspuren angeschossener Tiere werden bei allen Spielern
    in der Nähe als Decals in die Welt gelegt.
]]

local DECAL_SPLATTER = 1010     -- splatters_blood
local DECAL_POOL     = 9001     -- solidPool_blood

local decals = {}               -- FIFO der erstellten Decals

local function AddBloodDecal(x, y, z, pool)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
    if not found then groundZ = z - 0.9 end

    local size = pool and (0.6 + math.random() * 0.4) or (0.18 + math.random() * 0.22)
    -- leicht versetzt, damit die Spur natürlich wirkt
    local ox, oy = (math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.6
    local decal = AddDecal(pool and DECAL_POOL or DECAL_SPLATTER,
        x + ox, y + oy, groundZ + 0.3,
        0.0, 0.0, -1.0,
        0.0, 1.0, 0.0,
        size, size,
        0.196, 0.0, 0.0, 1.0,
        Config.Tracking.decalLifetime + 0.0,
        false, false, false)

    if decal and decal ~= 0 then
        decals[#decals + 1] = decal
        while #decals > Config.Tracking.maxDecals do
            local oldest = table.remove(decals, 1)
            if IsDecalAlive(oldest) then RemoveDecal(oldest) end
        end
    end
end

RegisterNetEvent('wr_hunting:client:blood', function(points, pool)
    if not Config.Tracking.enabled or type(points) ~= 'table' then return end
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, p in ipairs(points) do
        if p.x and p.y and p.z and #(myCoords - vector3(p.x, p.y, p.z)) <= 300.0 then
            AddBloodDecal(p.x, p.y, p.z, pool)
            if pool then
                -- Anschuss: zusätzliche Spritzer rund um die Trefferstelle
                for _ = 1, 3 do AddBloodDecal(p.x, p.y, p.z, false) end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, decal in ipairs(decals) do
        if IsDecalAlive(decal) then RemoveDecal(decal) end
    end
end)
