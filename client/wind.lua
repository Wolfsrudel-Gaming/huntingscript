--[[
    Wind & Witterung: Der Wind kommt serverweit synchronisiert aus
    GlobalState.huntWind (GTA-Heading, aus dem er weht).
]]

function GetWindHeading()
    return GlobalState.huntWind or 0.0
end

function GetWindLabel()
    return L(CompassKey(GetWindHeading()))
end

--- Multiplikator für den Wahrnehmungsradius eines Tieres durch die Witterung.
--- > 1: der Wind trägt die Witterung des Jägers zum Tier, < 1: Jäger steht unter Wind.
function GetWindMultiplier(playerCoords, animalCoords)
    if not Config.Wind.enabled or GlobalState.huntWind == nil then return 1.0 end
    local dx, dy = animalCoords.x - playerCoords.x, animalCoords.y - playerCoords.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.5 then return 1.0 end

    -- Richtung, in die der Wind weht (Gegenrichtung von "aus")
    local wx, wy = HeadingToVector(GetWindHeading() + 180.0)
    local dot = (dx / len) * wx + (dy / len) * wy
    if dot >= 0 then
        return 1.0 + (Config.Wind.scentMultiplier - 1.0) * dot
    end
    return 1.0 + (1.0 - Config.Wind.coverMultiplier) * dot
end

--[[ Anzeige in den Revieren ]]

CreateThread(function()
    if not Config.Wind.enabled or not Config.Wind.hud then return end
    while true do
        local ped = PlayerPedId()
        if GetZoneAt(GetEntityCoords(ped), Config.ZoneMargin) and not IsPedInAnyVehicle(ped, false)
            and not IsPauseMenuActive() and GlobalState.huntWind ~= nil then
            SetTextFont(4)
            SetTextScale(0.0, 0.34)
            SetTextColour(235, 235, 235, 200)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(L('wind_hud', GetWindLabel()))
            EndTextCommandDisplayText(0.165, 0.955)
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
