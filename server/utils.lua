ESX = exports['es_extended']:getSharedObject()

--[[ Spieler ]]

function GetXPlayer(src)
    return ESX.GetPlayerFromId(src)
end

function GetIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

function GetJobName(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.job and xPlayer.job.name or nil
end

function IsAdmin(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local group = xPlayer.getGroup and xPlayer.getGroup() or xPlayer.group
    return TableContains(Config.AdminGroups, group)
end

function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function IsPlayerNear(src, coords, maxDist)
    local pc = GetPlayerCoords(src)
    return pc ~= nil and #(pc - coords) <= maxDist
end

function NotifyPlayer(src, msg, ntype)
    TriggerClientEvent('wr_hunting:client:notify', src, msg, ntype)
end

--- Alle Spieler mit Position (OneSync)
function GetPlayersWithCoords()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local coords = GetPlayerCoords(src)
        if coords then
            list[#list + 1] = { src = src, coords = coords }
        end
    end
    return list
end

--[[ Cooldowns ]]

local cooldowns = {}

function IsOnCooldown(src, key)
    local entry = cooldowns[src]
    return entry ~= nil and entry[key] ~= nil and entry[key] > os.time()
end

function SetCooldown(src, key, seconds)
    cooldowns[src] = cooldowns[src] or {}
    cooldowns[src][key] = os.time() + seconds
end

--- Einfache Ratenbegrenzung für Events (Millisekunden)
local rateLimits = {}
function RateLimited(src, key, ms)
    rateLimits[src] = rateLimits[src] or {}
    local now = GetGameTimer()
    local last = rateLimits[src][key]
    if last and now - last < ms then return true end
    rateLimits[src][key] = now
    return false
end

AddEventHandler('playerDropped', function()
    local src = source
    cooldowns[src] = nil
    rateLimits[src] = nil
end)

--[[ Inventar-Abstraktion (ESX-Standardinventar oder ox_inventory) ]]

Inventory = {}

local oxState = GetResourceState('ox_inventory')
local useOx = Config.Inventory == 'ox'
    or (Config.Inventory == 'auto' and (oxState == 'started' or oxState == 'starting'))

function Inventory.IsOx()
    return useOx
end

function Inventory.Count(src, item)
    if useOx then
        return exports.ox_inventory:Search(src, 'count', item) or 0
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return 0 end
    local invItem = xPlayer.getInventoryItem(item)
    return invItem and invItem.count or 0
end

function Inventory.CanCarry(src, item, count)
    if useOx then
        return exports.ox_inventory:CanCarryItem(src, item, count) == true
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    if xPlayer.canCarryItem then
        return xPlayer.canCarryItem(item, count)
    end
    return true
end

function Inventory.Add(src, item, count)
    if count <= 0 then return true end
    if useOx then
        local ok = exports.ox_inventory:AddItem(src, item, count)
        return ok and true or false
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    xPlayer.addInventoryItem(item, count)
    return true
end

function Inventory.Remove(src, item, count)
    if Inventory.Count(src, item) < count then return false end
    if useOx then
        return exports.ox_inventory:RemoveItem(src, item, count) and true or false
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    xPlayer.removeInventoryItem(item, count)
    return true
end

function Inventory.HasWeapon(src, weaponName)
    if useOx then
        return Inventory.Count(src, weaponName) > 0
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    if xPlayer.hasWeapon then
        local has = xPlayer.hasWeapon(weaponName)
        if has then return true end
    end
    -- Fallback: Waffe als Item (z.B. bei Inventaren mit Waffen-Items)
    local invItem = xPlayer.getInventoryItem and xPlayer.getInventoryItem(weaponName)
    return invItem ~= nil and (invItem.count or 0) > 0
end

local labelCache = {}
function Inventory.Label(item)
    if labelCache[item] then return labelCache[item] end
    local label
    if useOx then
        local data = exports.ox_inventory:Items(item)
        label = data and data.label
    elseif ESX.GetItemLabel then
        label = ESX.GetItemLabel(item)
    end
    label = label or item
    labelCache[item] = label
    return label
end

function Inventory.AddMoney(src, account, amount)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    if account == 'money' and xPlayer.addMoney then
        xPlayer.addMoney(amount)
    else
        xPlayer.addAccountMoney(account, amount)
    end
    return true
end

function Inventory.GetMoney(src, account)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return 0 end
    if account == 'money' and xPlayer.getMoney then
        return xPlayer.getMoney() or 0
    end
    local acc = xPlayer.getAccount(account)
    return acc and acc.money or 0
end

function Inventory.RemoveMoney(src, account, amount)
    if amount <= 0 then return true end
    if Inventory.GetMoney(src, account) < amount then return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if account == 'money' and xPlayer.removeMoney then
        xPlayer.removeMoney(amount)
    else
        xPlayer.removeAccountMoney(account, amount)
    end
    return true
end

--- Nächster Spieler in Reichweite (ohne den Spieler selbst)
function GetClosestPlayer(src, maxDist)
    local coords = GetPlayerCoords(src)
    if not coords then return nil end
    local best, bestDist = nil, maxDist
    for _, p in ipairs(GetPlayersWithCoords()) do
        if p.src ~= src and GetBucket(p.src) == GetBucket(src) then
            local dist = #(p.coords - coords)
            if dist <= bestDist then best, bestDist = p.src, dist end
        end
    end
    return best
end

function IsPoliceJob(src)
    local job = GetJobName(src)
    return job ~= nil and TableContains(Config.Police.jobs, job)
end

--- Besitzt der Spieler ein Messer zum Ausnehmen?
function HasKnife(src)
    for _, weapon in ipairs(Config.Butchering.knifeWeapons) do
        if Inventory.HasWeapon(src, weapon) then return true end
    end
    for _, item in ipairs(Config.Butchering.knifeItems) do
        if Inventory.Count(src, item) > 0 then return true end
    end
    return false
end

--[[ Routing-Buckets an Clients übertragen (für Trophäen/Lagerfeuer in Instanzen) ]]

PlayerBuckets = {}

function GetBucket(src)
    return GetPlayerRoutingBucket(src) or 0
end

CreateThread(function()
    while true do
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local bucket = GetPlayerRoutingBucket(src)
            if PlayerBuckets[src] ~= bucket then
                PlayerBuckets[src] = bucket
                TriggerClientEvent('wr_hunting:client:setBucket', src, bucket)
            end
        end
        Wait(2500)
    end
end)

AddEventHandler('playerDropped', function()
    PlayerBuckets[source] = nil
end)
