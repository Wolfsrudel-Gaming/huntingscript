--[[
    Ansitz / Tarnzelt: Spieler darin werden von Tieren kaum bemerkt.
    Die Tarnwirkung selbst wird clientseitig über den Player-State "huntHidden" gesetzt.
]]

local Blinds = {}       -- [id] = { id, coords, heading, bucket, owner, ownerSrc, expires }
local nextBlindId = 0

local function ClientData(blind, identifier)
    return {
        id      = blind.id,
        coords  = blind.coords,
        heading = blind.heading,
        bucket  = blind.bucket,
        own     = identifier ~= nil and blind.owner == identifier,
    }
end

function SyncBlinds(src)
    local identifier = GetIdentifier(src)
    local list = {}
    for _, blind in pairs(Blinds) do list[#list + 1] = ClientData(blind, identifier) end
    TriggerClientEvent('wr_hunting:client:syncBlinds', src, list)
end

local function RemoveBlind(id, returnItem)
    local blind = Blinds[id]
    if not blind then return end
    Blinds[id] = nil
    TriggerClientEvent('wr_hunting:client:removeBlind', -1, id)
    if returnItem and blind.ownerSrc and GetPlayerPing(blind.ownerSrc) > 0
        and GetIdentifier(blind.ownerSrc) == blind.owner then
        Inventory.Add(blind.ownerSrc, Config.Blinds.item, 1)
        NotifyPlayer(blind.ownerSrc, L('blind_expired'), 'info')
    end
end

ESX.RegisterUsableItem(Config.Blinds.item, function(src)
    if Inventory.Count(src, Config.Blinds.item) < 1 then return end
    TriggerClientEvent('wr_hunting:client:placeBlind', src)
end)

RegisterNetEvent('wr_hunting:server:placeBlind', function(coords, heading)
    local src = source
    if type(coords) ~= 'vector3' then return end
    if RateLimited(src, 'placeBlind', 3000) then return end
    if not IsPlayerNear(src, coords, 6.0) then return end

    local identifier = GetIdentifier(src)
    local own = 0
    for _, blind in pairs(Blinds) do
        if blind.owner == identifier then own = own + 1 end
        if #(blind.coords - coords) < 4.0 then
            return NotifyPlayer(src, L('blind_too_close'), 'error')
        end
    end
    if own >= Config.Blinds.maxPerPlayer then
        return NotifyPlayer(src, L('blind_limit', Config.Blinds.maxPerPlayer), 'error')
    end
    if not Inventory.Remove(src, Config.Blinds.item, 1) then
        return NotifyPlayer(src, L('blind_no_item'), 'error')
    end

    nextBlindId = nextBlindId + 1
    local blind = {
        id       = nextBlindId,
        coords   = coords,
        heading  = tonumber(heading) or 0.0,
        bucket   = GetBucket(src),
        owner    = identifier,
        ownerSrc = src,
        expires  = os.time() + Config.Blinds.lifetime,
    }
    Blinds[blind.id] = blind
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        TriggerClientEvent('wr_hunting:client:addBlind', target, ClientData(blind, GetIdentifier(target)))
    end
    NotifyPlayer(src, L('blind_placed'), 'success')
end)

RegisterNetEvent('wr_hunting:server:packBlind', function(id)
    local src = source
    local blind = Blinds[tonumber(id) or -1]
    if not blind then return end
    if blind.owner ~= GetIdentifier(src) then
        return NotifyPlayer(src, L('blind_not_yours'), 'error')
    end
    if not IsPlayerNear(src, blind.coords, 5.0) then
        return NotifyPlayer(src, L('too_far'), 'error')
    end
    if not Inventory.CanCarry(src, Config.Blinds.item, 1) then
        return NotifyPlayer(src, L('inventory_full'), 'error')
    end
    Blinds[blind.id] = nil
    TriggerClientEvent('wr_hunting:client:removeBlind', -1, blind.id)
    Inventory.Add(src, Config.Blinds.item, 1)
    NotifyPlayer(src, L('blind_packed'), 'success')
end)

CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for id, blind in pairs(Blinds) do
            if blind.expires <= now then RemoveBlind(id, true) end
        end
    end
end)

-- Besitzer-Quelle nach Reconnect aktualisieren, damit das Item beim automatischen Abbau zurückkommt
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local identifier = xPlayer and xPlayer.identifier
    if not identifier then return end
    for _, blind in pairs(Blinds) do
        if blind.owner == identifier then blind.ownerSrc = playerId end
    end
end)
