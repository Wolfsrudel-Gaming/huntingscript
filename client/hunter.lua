--[[
    Jäger: Erfahrung/Stufen-Hinweise, Statistik, Jagdzeiten und Job-Cache
    (für Polizeifunktionen).
]]

local playerJob = nil

local function UpdateJob(job)
    playerJob = job and job.name or nil
end

CreateThread(function()
    while not ESX.IsPlayerLoaded or not ESX.IsPlayerLoaded() do Wait(500) end
    local data = ESX.GetPlayerData()
    UpdateJob(data and data.job)
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    UpdateJob(xPlayer and xPlayer.job)
end)

RegisterNetEvent('esx:setJob', function(job)
    UpdateJob(job)
end)

function IsPoliceClient()
    return playerJob ~= nil and TableContains(Config.Police.jobs, playerJob)
end

--[[ Erfahrung ]]

RegisterNetEvent('wr_hunting:client:xp', function(amount, newLevel)
    if newLevel then
        PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
        Notify(L('level_up', newLevel), 'success')
    elseif Config.Debug then
        Notify(L('xp_gained', amount), 'info')
    end
end)

--[[ Statistik ]]

RegisterCommand('jagdstatistik', function()
    local ok, stats = Callback('wr_hunting:hunter:stats')
    if not ok or not stats then
        Notify(L('stats_unavailable'), 'error')
        return
    end

    local elements = {}
    if stats.enabled then
        local progress = stats.nextXp and L('stats_xp_next', stats.xp, stats.nextXp) or L('stats_xp_max', stats.xp)
        elements[#elements + 1] = { label = L('stats_level', stats.level), description = progress, disabled = true }
    end
    elements[#elements + 1] = { label = L('stats_license'), description = stats.license, disabled = true }
    for _, kill in ipairs(stats.kills) do
        elements[#elements + 1] = { label = L('stats_kills', kill.label, kill.count), disabled = true }
    end
    elements[#elements + 1] = { label = L('stats_perfect', stats.perfect), disabled = true }
    elements[#elements + 1] = { label = L('stats_tracked', stats.tracked), disabled = true }
    elements[#elements + 1] = { label = L('stats_trophies', stats.trophies), disabled = true }
    elements[#elements + 1] = { label = L('stats_tanned', stats.tanned), disabled = true }
    elements[#elements + 1] = { label = L('stats_cooked', stats.cooked), disabled = true }
    if stats.poached > 0 then
        elements[#elements + 1] = { label = L('stats_poached', stats.poached), disabled = true }
    end

    OpenMenu('wr_hunting_stats', L('stats_title'), elements, function() end)
end, false)

--[[ Jagdzeiten & Tageskontingent ]]

RegisterCommand('jagdzeiten', function()
    local ok, list = Callback('wr_hunting:hunter:seasons')
    if not ok or not list then return end

    local elements = {}
    for _, entry in ipairs(list) do
        local limit = entry.limit > 0 and L('season_limit', entry.today, entry.limit) or L('season_no_limit', entry.today)
        elements[#elements + 1] = {
            label       = L(entry.closed and 'season_closed' or 'season_open', entry.label),
            description = limit,
            disabled    = true,
        }
    end
    if Config.Wind.enabled then
        elements[#elements + 1] = { label = L('wind_hud', GetWindLabel()), disabled = true }
    end
    OpenMenu('wr_hunting_seasons', L('season_title'), elements, function() end)
end, false)

TriggerEvent('chat:addSuggestion', '/jagdschein', L('cmd_license'))
TriggerEvent('chat:addSuggestion', '/jagdscheinpruefen', L('cmd_check_license'))
TriggerEvent('chat:addSuggestion', '/jagdstatistik', L('cmd_stats'))
TriggerEvent('chat:addSuggestion', '/jagdzeiten', L('cmd_seasons'))
