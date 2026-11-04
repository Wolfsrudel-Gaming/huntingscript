--[[
    Zentrales Interaktionssystem: Module registrieren "Provider", die für die
    aktuelle Spielerposition eine mögliche Interaktion liefern. Die nächste
    Interaktion wird als Hilfetext angezeigt und mit Config.InteractKey ausgelöst.
]]

local providers = {}
local current = nil

---@param id string
---@param provider function(coords: vector3, ped: number): table|nil  { dist = number, text = string, action = function }
function RegisterInteraction(id, provider)
    providers[id] = provider
end

CreateThread(function()
    while true do
        local best = nil
        local ped = PlayerPedId()
        if not Busy and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) then
            local coords = GetEntityCoords(ped)
            for id, provider in pairs(providers) do
                local ok, result = pcall(provider, coords, ped)
                if ok and result and (not best or result.dist < best.dist) then
                    best = result
                elseif not ok then
                    DebugPrint(('Interaktion %s fehlgeschlagen: %s'):format(id, result))
                end
            end
        end
        current = best
        Wait(best and 200 or 600)
    end
end)

CreateThread(function()
    while true do
        if current and not Busy then
            HelpText(current.text)
            if IsControlJustReleased(0, Config.InteractKey) then
                local interaction = current
                current = nil
                Busy = true
                CreateThread(function()
                    local ok, err = pcall(interaction.action)
                    if not ok then print('^1[wr_hunting] Fehler bei Interaktion:^7', err) end
                    Busy = false
                end)
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)
