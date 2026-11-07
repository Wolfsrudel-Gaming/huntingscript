Locales = Locales or {}

--- Übersetzung abrufen. Fällt auf Englisch bzw. den Schlüssel zurück.
function L(key, ...)
    local lang = Locales[Config.Locale] or Locales['de'] or {}
    local str = lang[key] or (Locales['en'] and Locales['en'][key]) or key
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, str, ...)
        if ok then return res end
    end
    return str
end

--- Normalisiert einen Hash auf einen vorzeichenlosen 32-Bit-Wert, damit Client-
--- und Server-Werte (signed/unsigned) vergleichbar sind.
function NormalizeHash(hash)
    hash = tonumber(hash) or 0
    if hash < 0 then hash = hash + 4294967296 end
    return math.floor(hash)
end

function HashOf(name)
    return NormalizeHash(GetHashKey(name))
end

function DebugPrint(...)
    if Config.Debug then
        print('^3[wr_hunting]^7', ...)
    end
end

--[[ Lookup-Tabellen ]]
AnimalByModel = {}
for name, cfg in pairs(Config.Animals) do
    cfg.name = name
    cfg.hash = HashOf(cfg.model)
    AnimalByModel[cfg.hash] = name
end

for index, zone in ipairs(Config.Zones) do
    zone.index = index
end

HuntingWeaponHashes = {}
for name, data in pairs(Config.HuntingWeapons) do
    HuntingWeaponHashes[HashOf(name)] = {
        name  = name,
        clean = data.clean == true,
        alert = data.alertOutsideZone ~= false,
    }
end

RuinedCauseHashes = {}
for _, name in ipairs(Config.RuinedCauses) do
    RuinedCauseHashes[HashOf(name)] = true
end

KnifeWeaponHashes = {}
for _, name in ipairs(Config.Butchering.knifeWeapons) do
    KnifeWeaponHashes[HashOf(name)] = name
end

HeadshotBones = {}
for _, bone in ipairs(Config.HeadshotBones) do
    HeadshotBones[bone] = true
end

--[[ Reviere ]]

--- Liefert das Revier an einer Position (2D-Prüfung) oder nil.
---@param coords vector3
---@param margin number|nil zusätzliche Toleranz in Metern
function GetZoneAt(coords, margin)
    if not coords then return nil end
    margin = margin or 0.0
    for _, zone in ipairs(Config.Zones) do
        local dx, dy = coords.x - zone.center.x, coords.y - zone.center.y
        local r = zone.radius + margin
        if dx * dx + dy * dy <= r * r then
            return zone
        end
    end
    return nil
end

function IsPointInZone(zone, x, y)
    local dx, dy = x - zone.center.x, y - zone.center.y
    return dx * dx + dy * dy <= zone.radius * zone.radius
end

--[[ Tageszeit ]]
function GetDayPeriod(hour)
    hour = tonumber(hour) or 12
    if hour >= 22 or hour < 5 then return 'night' end
    if hour < 8 then return 'dawn' end
    if hour < 18 then return 'day' end
    return 'dusk'
end

function IsNightHour(hour)
    return GetDayPeriod(hour) == 'night'
end

--[[ Schonzeiten ]]

---@param month number 1-12 (reales Serverdatum)
function IsClosedSeason(animalType, month)
    if not Config.Seasons.enabled then return false end
    local season = Config.Seasons.animals[animalType]
    if not season or not season.closedMonths then return false end
    return TableContains(season.closedMonths, tonumber(month))
end

function GetDailyLimit(animalType)
    if not Config.Seasons.enabled then return 0 end
    local season = Config.Seasons.animals[animalType]
    return season and season.dailyLimit or 0
end

--[[ Erfahrung ]]

function GetLevelFromXP(xp)
    local level = 1
    for i, threshold in ipairs(Config.Progression.levels) do
        if (xp or 0) >= threshold then level = i end
    end
    return level
end

--- Prozentualer Bonus einer Stufe (Stufe 1 = 0).
function GetPerkValue(level, perPerLevel, max)
    local value = math.max(0, (tonumber(level) or 1) - 1) * perPerLevel
    if max then value = math.min(value, max) end
    return value
end

--[[ Wind ]]

--- GTA-Heading (0 = Nord, 90 = West) → Richtungsvektor (x, y)
function HeadingToVector(heading)
    local r = math.rad(heading)
    return -math.sin(r), math.cos(r)
end

--- Locale-Schlüssel der Himmelsrichtung, aus der der Wind kommt.
function CompassKey(heading)
    local keys = { 'n', 'nw', 'w', 'sw', 's', 'se', 'e', 'ne' }
    local index = math.floor(((heading % 360.0) + 22.5) / 45.0) % 8
    return 'compass_' .. keys[index + 1]
end

function Round(value, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(value * m + 0.5) / m
end

function TableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end
