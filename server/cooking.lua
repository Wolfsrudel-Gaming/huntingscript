--[[
    Grillen, Lagerfeuer und Essen.
]]

local cooking = {}          -- [src] = { item, startedAt, duration }
local Campfires = {}        -- [id] = { id, coords, heading, bucket, expires, owner }
local nextCampfireId = 0
local eatCooldown = {}

--[[ Lagerfeuer ]]

local function CampfireList(bucket)
    local list = {}
    for _, fire in pairs(Campfires) do
        if bucket == nil or fire.bucket == bucket then
            list[#list + 1] = { id = fire.id, coords = fire.coords, heading = fire.heading, bucket = fire.bucket }
        end
    end
    return list
end

function SyncCampfires(src)
    TriggerClientEvent('wr_hunting:client:syncCampfires', src, CampfireList())
end

local function RemoveCampfire(id)
    if not Campfires[id] then return end
    Campfires[id] = nil
    TriggerClientEvent('wr_hunting:client:removeCampfire', -1, id)
end

local function IsNearCampfire(src, maxDist)
    local coords = GetPlayerCoords(src)
    if not coords then return false end
    local bucket = GetBucket(src)
    for _, fire in pairs(Campfires) do
        if fire.bucket == bucket and #(coords - fire.coords) <= maxDist then return true end
    end
    for _, station in ipairs(Config.Cooking.stations) do
        if #(coords - station.coords) <= maxDist then return true end
    end
    return false
end

ESX.RegisterUsableItem(Config.Campfire.item, function(src)
    if Inventory.Count(src, Config.Campfire.item) < 1 then return end
    TriggerClientEvent('wr_hunting:client:placeCampfire', src)
end)

RegisterNetEvent('wr_hunting:server:placeCampfire', function(coords, heading)
    local src = source
    if RateLimited(src, 'placeCampfire', 3000) then return end
    if type(coords) ~= 'vector3' then return end
    if not IsPlayerNear(src, coords, 5.0) then return end

    local identifier = GetIdentifier(src)
    local own = 0
    for _, fire in pairs(Campfires) do
        if fire.owner == identifier then own = own + 1 end
        if #(fire.coords - coords) < 3.0 then
            return NotifyPlayer(src, L('campfire_too_close'), 'error')
        end
    end
    if own >= Config.Campfire.maxPerPlayer then
        return NotifyPlayer(src, L('campfire_limit', Config.Campfire.maxPerPlayer), 'error')
    end
    if not Inventory.Remove(src, Config.Campfire.item, 1) then
        return NotifyPlayer(src, L('campfire_no_item'), 'error')
    end

    nextCampfireId = nextCampfireId + 1
    local fire = {
        id      = nextCampfireId,
        coords  = coords,
        heading = tonumber(heading) or 0.0,
        bucket  = GetBucket(src),
        expires = os.time() + Config.Campfire.lifetime,
        owner   = identifier,
    }
    Campfires[fire.id] = fire
    TriggerClientEvent('wr_hunting:client:addCampfire', -1,
        { id = fire.id, coords = fire.coords, heading = fire.heading, bucket = fire.bucket })
    NotifyPlayer(src, L('campfire_placed', math.floor(Config.Campfire.lifetime / 60)), 'success')
end)

RegisterNetEvent('wr_hunting:server:extinguishCampfire', function(id)
    local src = source
    local fire = Campfires[tonumber(id) or -1]
    if not fire or not IsPlayerNear(src, fire.coords, 4.0) then return end
    RemoveCampfire(fire.id)
    NotifyPlayer(src, L('campfire_extinguished'), 'info')
end)

CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        for id, fire in pairs(Campfires) do
            if fire.expires <= now then RemoveCampfire(id) end
        end
    end
end)

--[[ Grillen ]]

ESX.RegisterServerCallback('wr_hunting:cook:getMeat', function(src, cb)
    local list = {}
    for item, recipe in pairs(Config.Cooking.recipes) do
        local count = Inventory.Count(src, item)
        if count > 0 then
            list[#list + 1] = {
                item        = item,
                label       = Inventory.Label(item),
                count       = count,
                resultLabel = Inventory.Label(recipe.result),
                duration    = recipe.duration,
            }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    cb(true, list)
end)

ESX.RegisterServerCallback('wr_hunting:cook:start', function(src, cb, item, kind, spotId)
    local recipe = Config.Cooking.recipes[item]
    if not recipe then return cb(false, L('cook_error')) end
    -- Lagerfeuer und feste Feuerstellen sind dem Server bekannt und werden geprüft.
    -- Grills der Spielwelt kennt nur der Client.
    if (kind == 'campfire' or kind == 'station') and not IsNearCampfire(src, Config.Cooking.distance + 3.0) then
        return cb(false, L('too_far'))
    end
    if Inventory.Count(src, item) < 1 then return cb(false, L('cook_no_meat')) end
    if not Inventory.CanCarry(src, recipe.result, 1) then return cb(false, L('inventory_full')) end

    cooking[src] = { item = item, startedAt = GetGameTimer(), duration = recipe.duration * 1000 }
    cb(true, recipe.duration * 1000)
end)

ESX.RegisterServerCallback('wr_hunting:cook:finish', function(src, cb)
    local job = cooking[src]
    cooking[src] = nil
    if not job then return cb(false, L('cook_error')) end
    if GetGameTimer() - job.startedAt < job.duration * 0.85 then return cb(false, L('cook_too_fast')) end

    local recipe = Config.Cooking.recipes[job.item]
    if not Inventory.Remove(src, job.item, 1) then return cb(false, L('cook_no_meat')) end
    if not Inventory.Add(src, recipe.result, 1) then
        Inventory.Add(src, job.item, 1)
        return cb(false, L('inventory_full'))
    end
    IncrementStat(src, 'cooked', 1)
    AddXP(src, Config.Progression.xp.cook or 0)
    cb(true)
end)

RegisterNetEvent('wr_hunting:server:cancelCook', function()
    cooking[source] = nil
end)

--[[ Essen ]]

local function CanEat(src)
    local now = GetGameTimer()
    if eatCooldown[src] and now - eatCooldown[src] < Config.Eating.anim.duration + 1000 then return false end
    eatCooldown[src] = now
    return true
end

for item, data in pairs(Config.Eating.cooked) do
    ESX.RegisterUsableItem(item, function(src)
        if not CanEat(src) then return end
        if not Inventory.Remove(src, item, 1) then return end
        TriggerClientEvent('wr_hunting:client:eat', src, {
            raw = false, hunger = data.hunger, heal = data.heal, label = Inventory.Label(item),
        })
    end)
end

if Config.Eating.raw.enabled then
    for item in pairs(Config.Cooking.recipes) do
        ESX.RegisterUsableItem(item, function(src)
            if not CanEat(src) then return end
            if not Inventory.Remove(src, item, 1) then return end
            local raw = Config.Eating.raw
            TriggerClientEvent('wr_hunting:client:eat', src, {
                raw    = true,
                hunger = raw.hunger,
                sick   = math.random(100) <= raw.sickChance,
                damage = raw.damage,
                label  = Inventory.Label(item),
            })
        end)
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    cooking[src] = nil
    eatCooldown[src] = nil
end)
