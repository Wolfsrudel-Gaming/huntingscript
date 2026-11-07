--[[
    Jäger-Profile: Erfahrung/Stufe, eingebauter Jagdschein, Statistik und
    Tageskontingent. Profile werden bei Bedarf geladen, im Speicher gehalten
    und regelmäßig gespeichert.
]]

local Profiles = {}     -- [identifier] = Profil
local loading = {}      -- [identifier] = promise
local sourceIds = {}    -- [src] = identifier (für playerDropped, wenn ESX den Spieler schon entfernt hat)

local function Today()
    return os.date('%Y-%m-%d')
end

local function DefaultStats()
    return { kills = {}, perfect = 0, trophies = 0, tanned = 0, cooked = 0, tracked = 0, poached = 0 }
end

local function Decode(str, fallback)
    if type(str) ~= 'string' or str == '' then return fallback end
    local ok, data = pcall(json.decode, str)
    if ok and type(data) == 'table' then return data end
    return fallback
end

local function LoadProfile(identifier)
    local row = MySQL.single.await('SELECT * FROM `hunting_players` WHERE `identifier` = ?', { identifier })
    local profile = {
        identifier   = identifier,
        xp           = 0,
        licenseUntil = 0,
        stats        = DefaultStats(),
        daily        = { date = Today(), kills = {} },
        dirty        = false,
    }
    if row then
        profile.xp = row.xp or 0
        profile.licenseUntil = row.license_until or 0
        profile.stats = Decode(row.stats, DefaultStats())
        profile.daily = Decode(row.daily, profile.daily)
        for key, value in pairs(DefaultStats()) do
            if profile.stats[key] == nil then profile.stats[key] = value end
        end
    else
        MySQL.insert.await('INSERT IGNORE INTO `hunting_players` (`identifier`) VALUES (?)', { identifier })
    end
    return profile
end

--- Liefert das Profil eines Spielers (lädt es bei Bedarf aus der Datenbank).
function GetProfile(src)
    local identifier = GetIdentifier(src)
    if not identifier or not DatabaseReady then return nil end
    sourceIds[src] = identifier
    if Profiles[identifier] then return Profiles[identifier] end

    if loading[identifier] then
        return Citizen.Await(loading[identifier])
    end

    local p = promise.new()
    loading[identifier] = p
    local ok, profile = pcall(LoadProfile, identifier)
    if not ok then
        print('^1[wr_hunting] Profil konnte nicht geladen werden:^7', profile)
        profile = nil
    end
    Profiles[identifier] = profile
    loading[identifier] = nil
    p:resolve(profile)
    return profile
end

function SaveProfile(profile)
    if not profile then return end
    profile.dirty = false
    MySQL.update('UPDATE `hunting_players` SET `xp` = ?, `license_until` = ?, `stats` = ?, `daily` = ? WHERE `identifier` = ?', {
        profile.xp, profile.licenseUntil, json.encode(profile.stats), json.encode(profile.daily), profile.identifier,
    })
end

local function GetDaily(profile)
    if profile.daily.date ~= Today() then
        profile.daily = { date = Today(), kills = {} }
        profile.dirty = true
    end
    return profile.daily
end

--[[ Erfahrung ]]

function GetHunterLevel(src)
    local profile = GetProfile(src)
    return profile and GetLevelFromXP(profile.xp) or 1
end

local function PublishLevel(src, profile)
    Player(src).state:set('huntLevel', GetLevelFromXP(profile.xp), true)
end

function AddXP(src, amount)
    if not Config.Progression.enabled or not amount or amount <= 0 then return end
    local profile = GetProfile(src)
    if not profile then return end
    local before = GetLevelFromXP(profile.xp)
    profile.xp = profile.xp + amount
    profile.dirty = true
    local after = GetLevelFromXP(profile.xp)
    PublishLevel(src, profile)
    TriggerClientEvent('wr_hunting:client:xp', src, amount, after > before and after or nil)
end

--[[ Statistik ]]

function IncrementStat(src, key, amount)
    local profile = GetProfile(src)
    if not profile then return end
    profile.stats[key] = (profile.stats[key] or 0) + (amount or 1)
    profile.dirty = true
end

function RecordKill(src, animalType, quality, illegal)
    local profile = GetProfile(src)
    if not profile then return end
    profile.stats.kills[animalType] = (profile.stats.kills[animalType] or 0) + 1
    if quality == 'perfect' then profile.stats.perfect = profile.stats.perfect + 1 end
    if illegal then profile.stats.poached = profile.stats.poached + 1 end
    local daily = GetDaily(profile)
    daily.kills[animalType] = (daily.kills[animalType] or 0) + 1
    profile.dirty = true
end

function GetDailyKills(src, animalType)
    local profile = GetProfile(src)
    if not profile then return 0 end
    return GetDaily(profile).kills[animalType] or 0
end

--[[ Jagdschein ]]

local function CheckEsxLicense(src)
    if GetResourceState('esx_license') ~= 'started' then return true end
    local p = promise.new()
    local resolved = false
    TriggerEvent('esx_license:checkLicense', src, Config.License.type, function(has)
        if not resolved then
            resolved = true
            p:resolve(has == true)
        end
    end)
    SetTimeout(3000, function()
        if not resolved then
            resolved = true
            p:resolve(true)
        end
    end)
    return Citizen.Await(p)
end

--- Gibt (gültig, Ablaufzeitpunkt) zurück. Ablaufzeitpunkt nur beim eingebauten Jagdschein.
function GetLicenseStatus(src)
    if not Config.License.enabled then return true, nil end
    if Config.License.provider == 'esx_license' then
        return CheckEsxLicense(src), nil
    end
    local profile = GetProfile(src)
    if not profile then return false, 0 end
    return profile.licenseUntil > os.time(), profile.licenseUntil
end

function HasValidLicense(src)
    local valid = GetLicenseStatus(src)
    return valid
end

--- Kauft oder verlängert den eingebauten Jagdschein.
function BuyLicense(src)
    if not Config.License.enabled or Config.License.provider ~= 'builtin' then
        return false, L('license_not_available')
    end
    local profile = GetProfile(src)
    if not profile then return false, L('license_error') end

    local price = Config.License.price
    if not Inventory.RemoveMoney(src, Config.License.account, price) then
        return false, L('not_enough_money', price)
    end

    local base = math.max(os.time(), profile.licenseUntil)
    profile.licenseUntil = base + Config.License.durationDays * 86400
    SaveProfile(profile)
    return true, L('license_bought', os.date('%d.%m.%Y %H:%M', profile.licenseUntil))
end

function FormatLicense(valid, untilTs)
    if not Config.License.enabled then return L('license_not_required') end
    if untilTs == nil then
        return valid and L('license_valid_external') or L('license_invalid')
    end
    if valid then
        return L('license_valid_until', os.date('%d.%m.%Y %H:%M', untilTs))
    end
    if untilTs > 0 then
        return L('license_expired', os.date('%d.%m.%Y', untilTs))
    end
    return L('license_none')
end

--[[ Lebenszyklus ]]

local function OnPlayerReady(src)
    CreateThread(function()
        local profile = GetProfile(src)
        if profile then PublishLevel(src, profile) end
    end)
end

AddEventHandler('esx:playerLoaded', function(playerId)
    OnPlayerReady(playerId)
end)

OnDatabaseReady(function()
    for _, id in ipairs(GetPlayers()) do
        OnPlayerReady(tonumber(id))
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local identifier = sourceIds[src]
    sourceIds[src] = nil
    local profile = identifier and Profiles[identifier]
    if profile then
        SaveProfile(profile)
        Profiles[identifier] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        for _, profile in pairs(Profiles) do
            if profile.dirty then SaveProfile(profile) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, profile in pairs(Profiles) do
        if profile.dirty then SaveProfile(profile) end
    end
end)
