--[[
    Serverweite Jagdbedingungen, synchronisiert über GlobalState:
      GlobalState.huntSeasons = { month = n, closed = { deer = bool, ... } }
      GlobalState.huntWind    = Heading (0-360, GTA-Konvention), aus dem der Wind kommt
]]

function GetCurrentMonth()
    return tonumber(os.date('%m'))
end

local function UpdateSeasons()
    local month = GetCurrentMonth()
    local closed = {}
    for name in pairs(Config.Animals) do
        closed[name] = IsClosedSeason(name, month)
    end
    GlobalState.huntSeasons = { month = month, closed = closed }
end

CreateThread(function()
    UpdateSeasons()
    while true do
        Wait(15 * 60 * 1000)
        UpdateSeasons()
    end
end)

CreateThread(function()
    if not Config.Wind.enabled then return end
    local heading = math.random(0, 359) + 0.0
    GlobalState.huntWind = heading
    while true do
        Wait(Config.Wind.changeInterval * 1000)
        local shift = (math.random() * 2.0 - 1.0) * Config.Wind.maxShift
        heading = (heading + shift) % 360.0
        GlobalState.huntWind = Round(heading, 1)
    end
end)
