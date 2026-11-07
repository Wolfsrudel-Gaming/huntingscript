--[[
    Köder (Kirrung / Salzlecke): locken nach einiger Zeit passende Tiere an.
]]

local Baits = {}        -- [id] = { id, item, coords, zone, bucket, owner, expires, nextSpawn, spawned }
local nextBaitId = 0

function GetActiveBaits()
    return Baits
end

function OnBaitAnimalSpawned(id)
    local bait = Baits[id]
    if bait then bait.spawned = bait.spawned + 1 end
end

local function ClientData(bait)
    return { id = bait.id, item = bait.item, coords = bait.coords, bucket = bait.bucket }
end

function SyncBaits(src)
    local list = {}
    for _, bait in pairs(Baits) do list[#list + 1] = ClientData(bait) end
    TriggerClientEvent('wr_hunting:client:syncBaits', src, list)
end

local function RemoveBait(id)
    if not Baits[id] then return end
    Baits[id] = nil
    TriggerClientEvent('wr_hunting:client:removeBait', -1, id)
end

for item in pairs(Config.Baits.items) do
    ESX.RegisterUsableItem(item, function(src)
        if Inventory.Count(src, item) < 1 then return end
        TriggerClientEvent('wr_hunting:client:placeBait', src, item)
    end)
end

RegisterNetEvent('wr_hunting:server:placeBait', function(item, coords)
    local src = source
    local cfg = Config.Baits.items[item]
    if not cfg or type(coords) ~= 'vector3' then return end
    if RateLimited(src, 'placeBait', 3000) then return end
    if not IsPlayerNear(src, coords, 5.0) then return end

    local zone = GetZoneAt(coords)
    if Config.Baits.onlyInZones and not zone then
        return NotifyPlayer(src, L('bait_only_zones'), 'error')
    end

    local identifier = GetIdentifier(src)
    local own = 0
    for _, bait in pairs(Baits) do
        if bait.owner == identifier then own = own + 1 end
        if #(bait.coords - coords) < Config.Baits.minDistance then
            return NotifyPlayer(src, L('bait_too_close'), 'error')
        end
    end
    if own >= Config.Baits.maxPerPlayer then
        return NotifyPlayer(src, L('bait_limit', Config.Baits.maxPerPlayer), 'error')
    end
    if not Inventory.Remove(src, item, 1) then
        return NotifyPlayer(src, L('bait_no_item'), 'error')
    end

    nextBaitId = nextBaitId + 1
    local bait = {
        id        = nextBaitId,
        item      = item,
        coords    = coords,
        zone      = zone and zone.index or nil,
        bucket    = GetBucket(src),
        owner     = identifier,
        expires   = os.time() + cfg.duration,
        nextSpawn = os.time() + math.random(cfg.attractDelay[1], cfg.attractDelay[2]),
        spawned   = 0,
    }
    Baits[bait.id] = bait
    TriggerClientEvent('wr_hunting:client:addBait', -1, ClientData(bait))
    NotifyPlayer(src, L('bait_placed', Inventory.Label(item)), 'success')
end)

CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        for id, bait in pairs(Baits) do
            if bait.expires <= now then RemoveBait(id) end
        end
    end
end)
