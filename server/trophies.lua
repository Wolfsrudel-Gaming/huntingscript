--[[
    Trophäen (Tierköpfe) als Deko – persistent in der Datenbank.
]]

local Trophies = {}     -- [id] = { id, identifier, item, coords, heading, bucket }

OnDatabaseReady(function()
    local rows = MySQL.query.await('SELECT * FROM `hunting_trophies`') or {}
    for _, row in ipairs(rows) do
        Trophies[row.id] = {
            id         = row.id,
            identifier = row.identifier,
            item       = row.item,
            coords     = vector3(row.x, row.y, row.z),
            heading    = row.heading,
            bucket     = row.bucket,
        }
    end
    DebugPrint(('%d Trophäen geladen'):format(#rows))

    -- Spieler, die bereits online sind (Ressourcen-Neustart), synchronisieren
    for _, id in ipairs(GetPlayers()) do
        SyncTrophies(tonumber(id))
    end
end)

local function ClientData(trophy, identifier)
    return {
        id      = trophy.id,
        item    = trophy.item,
        coords  = trophy.coords,
        heading = trophy.heading,
        bucket  = trophy.bucket,
        own     = identifier ~= nil and trophy.identifier == identifier,
    }
end

function SyncTrophies(src)
    local identifier = GetIdentifier(src)
    local list = {}
    for _, trophy in pairs(Trophies) do
        list[#list + 1] = ClientData(trophy, identifier)
    end
    TriggerClientEvent('wr_hunting:client:syncTrophies', src, list)
end

--- Sendet eine neue Trophäe an alle Spieler (mit korrektem "own"-Flag).
local function BroadcastTrophy(trophy)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        TriggerClientEvent('wr_hunting:client:addTrophy', src, ClientData(trophy, GetIdentifier(src)))
    end
end

for item in pairs(Config.Trophies.items) do
    ESX.RegisterUsableItem(item, function(src)
        if Inventory.Count(src, item) < 1 then return end
        TriggerClientEvent('wr_hunting:client:placeTrophy', src, item)
    end)
end

RegisterNetEvent('wr_hunting:server:placeTrophy', function(item, coords, heading)
    local src = source
    if RateLimited(src, 'placeTrophy', 2000) then return end
    if not Config.Trophies.items[item] or type(coords) ~= 'vector3' or not DatabaseReady then return end
    if not IsPlayerNear(src, coords, Config.Trophies.placeDistance + 4.0) then
        return NotifyPlayer(src, L('too_far'), 'error')
    end

    local identifier = GetIdentifier(src)
    if not identifier then return end

    local count = 0
    for _, trophy in pairs(Trophies) do
        if trophy.identifier == identifier then count = count + 1 end
    end
    if count >= Config.Trophies.maxPerPlayer then
        return NotifyPlayer(src, L('trophy_limit', Config.Trophies.maxPerPlayer), 'error')
    end
    if not Inventory.Remove(src, item, 1) then
        return NotifyPlayer(src, L('trophy_no_item'), 'error')
    end

    heading = (tonumber(heading) or 0.0) % 360.0
    local bucket = GetBucket(src)
    local id = MySQL.insert.await(
        'INSERT INTO `hunting_trophies` (`identifier`, `item`, `x`, `y`, `z`, `heading`, `bucket`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { identifier, item, coords.x, coords.y, coords.z, heading, bucket })

    if not id then
        Inventory.Add(src, item, 1)
        return NotifyPlayer(src, L('trophy_error'), 'error')
    end

    local trophy = { id = id, identifier = identifier, item = item, coords = coords, heading = heading, bucket = bucket }
    Trophies[id] = trophy
    BroadcastTrophy(trophy)
    NotifyPlayer(src, L('trophy_placed'), 'success')
end)

RegisterNetEvent('wr_hunting:server:removeTrophy', function(id)
    local src = source
    if RateLimited(src, 'removeTrophy', 1500) then return end
    local trophy = Trophies[tonumber(id) or -1]
    if not trophy then return end

    local isOwner = trophy.identifier == GetIdentifier(src)
    local admin = IsAdmin(src)
    if not isOwner and not admin then
        return NotifyPlayer(src, L('trophy_not_yours'), 'error')
    end
    if not IsPlayerNear(src, trophy.coords, 6.0) then
        return NotifyPlayer(src, L('too_far'), 'error')
    end
    if isOwner and not Inventory.CanCarry(src, trophy.item, 1) then
        return NotifyPlayer(src, L('inventory_full'), 'error')
    end

    Trophies[trophy.id] = nil
    MySQL.update.await('DELETE FROM `hunting_trophies` WHERE `id` = ?', { trophy.id })
    TriggerClientEvent('wr_hunting:client:removeTrophy', -1, trophy.id)

    if isOwner then
        Inventory.Add(src, trophy.item, 1)
        NotifyPlayer(src, L('trophy_removed'), 'success')
    else
        NotifyPlayer(src, L('trophy_removed_admin'), 'success')
    end
end)
