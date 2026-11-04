--[[
    Eingebaute Polizeimeldungen (Config.Police.dispatch = 'builtin')
    bzw. Übergabe an ein externes Dispatch-System (dispatch = 'client').
]]

local activeBlips = {}

local function CreateAlertBlips(alert)
    local cfg = Config.Police.blip
    local c = alert.coords

    local radius = AddBlipForRadius(c.x, c.y, c.z, cfg.radius)
    SetBlipColour(radius, cfg.colour)
    SetBlipAlpha(radius, 110)
    SetBlipHighDetail(radius, true)

    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, cfg.sprite)
    SetBlipColour(blip, cfg.colour)
    SetBlipScale(blip, cfg.scale)
    SetBlipFlashes(blip, cfg.flash == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s %s'):format(alert.code or '', alert.title))
    EndTextCommandSetBlipName(blip)

    local entry = { radius = radius, blip = blip }
    activeBlips[#activeBlips + 1] = entry

    CreateThread(function()
        local duration = cfg.duration * 1000
        local start = GetGameTimer()
        while GetGameTimer() - start < duration do
            local remaining = 1.0 - (GetGameTimer() - start) / duration
            if DoesBlipExist(radius) then SetBlipAlpha(radius, math.floor(110 * remaining)) end
            if DoesBlipExist(blip) then SetBlipAlpha(blip, math.max(60, math.floor(255 * remaining))) end
            Wait(1000)
        end
        if DoesBlipExist(radius) then RemoveBlip(radius) end
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        for i, e in ipairs(activeBlips) do
            if e == entry then table.remove(activeBlips, i) break end
        end
    end)
end

RegisterNetEvent('wr_hunting:client:policeAlert', function(alert)
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    ESX.ShowAdvancedNotification(L('dispatch_sender'), ('%s %s'):format(alert.code or '', alert.title),
        ('%s~n~~y~%s'):format(alert.message, alert.street or ''), 'CHAR_CALL911', 1)
    CreateAlertBlips(alert)
end)

RegisterNetEvent('wr_hunting:client:customDispatch', function(alert)
    if type(Config.Police.clientDispatch) == 'function' then
        local ok, err = pcall(Config.Police.clientDispatch, alert)
        if not ok then print('^1[wr_hunting] clientDispatch Fehler:^7', err) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in ipairs(activeBlips) do
        if DoesBlipExist(e.radius) then RemoveBlip(e.radius) end
        if DoesBlipExist(e.blip) then RemoveBlip(e.blip) end
    end
end)
