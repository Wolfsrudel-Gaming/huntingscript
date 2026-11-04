--[[
    Gerbrahmen: Felle werden persistent (Datenbank) gegerbt – Echtzeit, läuft
    auch weiter, wenn der Spieler offline ist oder der Server neu startet.
]]

local Racks = {}    -- [rackId] = { [slot] = { id, identifier, input, output, amount, finishAt } }

OnDatabaseReady(function()
    local rows = MySQL.query.await('SELECT * FROM `hunting_tanning`') or {}
    for _, row in ipairs(rows) do
        Racks[row.rack] = Racks[row.rack] or {}
        Racks[row.rack][row.slot] = {
            id         = row.id,
            identifier = row.identifier,
            input      = row.input,
            output     = row.output,
            amount     = row.amount,
            finishAt   = row.finish_at,
        }
    end
    DebugPrint(('%d Gerb-Aufträge geladen'):format(#rows))
end)

local function GetRack(index)
    return Config.Tanning.racks[tonumber(index) or -1]
end

local function IsNearRack(src, rack)
    return IsPlayerNear(src, rack.coords.xyz, 4.0)
end

local function CountPlayerJobs(identifier)
    local count = 0
    for _, slots in pairs(Racks) do
        for _, job in pairs(slots) do
            if job.identifier == identifier then count = count + 1 end
        end
    end
    return count
end

ESX.RegisterServerCallback('wr_hunting:tanning:getRack', function(src, cb, rackIndex)
    local rack = GetRack(rackIndex)
    if not rack or not DatabaseReady then return cb(false, L('tanning_error')) end
    if not IsNearRack(src, rack) then return cb(false, L('too_far')) end

    local identifier = GetIdentifier(src)
    local now = os.time()
    local result = {}
    local slots = Racks[rack.id] or {}
    for slot = 1, rack.slots do
        local job = slots[slot]
        if job then
            result[slot] = {
                own       = job.identifier == identifier,
                label     = Inventory.Label(job.input),
                remaining = job.finishAt - now,
            }
        end
    end
    cb(true, result)
end)

ESX.RegisterServerCallback('wr_hunting:tanning:getPelts', function(src, cb)
    local pelts = {}
    for item, recipe in pairs(Config.Tanning.recipes) do
        local count = Inventory.Count(src, item)
        if count > 0 then
            pelts[#pelts + 1] = { item = item, label = Inventory.Label(item), count = count, duration = recipe.duration }
        end
    end
    table.sort(pelts, function(a, b) return a.label < b.label end)
    cb(true, pelts)
end)

ESX.RegisterServerCallback('wr_hunting:tanning:insert', function(src, cb, rackIndex, slot, item)
    local rack = GetRack(rackIndex)
    slot = tonumber(slot)
    local recipe = Config.Tanning.recipes[item]
    if not rack or not recipe or not slot or slot < 1 or slot > rack.slots or not DatabaseReady then
        return cb(false, L('tanning_error'))
    end
    if not IsNearRack(src, rack) then return cb(false, L('too_far')) end

    local identifier = GetIdentifier(src)
    if not identifier then return cb(false, L('tanning_error')) end

    Racks[rack.id] = Racks[rack.id] or {}
    if Racks[rack.id][slot] then return cb(false, L('tanning_slot_taken')) end
    if CountPlayerJobs(identifier) >= Config.Tanning.maxPerPlayer then
        return cb(false, L('tanning_limit', Config.Tanning.maxPerPlayer))
    end
    if Inventory.Count(src, item) < 1 then return cb(false, L('tanning_no_pelts')) end

    local req = Config.Tanning.requiredItem
    if req and Inventory.Count(src, req.name) < req.count then
        return cb(false, L('tanning_need_item', req.count, Inventory.Label(req.name)))
    end

    -- Slot sofort reservieren (verhindert doppelte Belegung während der DB-Abfrage)
    local job = {
        identifier = identifier,
        input      = item,
        output     = recipe.result,
        amount     = recipe.amount or 1,
        finishAt   = os.time() + recipe.duration,
    }
    Racks[rack.id][slot] = job

    if not Inventory.Remove(src, item, 1) then
        Racks[rack.id][slot] = nil
        return cb(false, L('tanning_no_pelts'))
    end
    if req then Inventory.Remove(src, req.name, req.count) end

    local id = MySQL.insert.await(
        'INSERT INTO `hunting_tanning` (`rack`, `slot`, `identifier`, `input`, `output`, `amount`, `finish_at`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { rack.id, slot, identifier, item, job.output, job.amount, job.finishAt })
    job.id = id

    cb(true, L('tanning_started', Inventory.Label(item), FormatDuration(recipe.duration)))
end)

ESX.RegisterServerCallback('wr_hunting:tanning:collect', function(src, cb, rackIndex, slot)
    local rack = GetRack(rackIndex)
    slot = tonumber(slot)
    if not rack or not slot then return cb(false, L('tanning_error')) end
    if not IsNearRack(src, rack) then return cb(false, L('too_far')) end

    local job = Racks[rack.id] and Racks[rack.id][slot]
    if not job or job.collecting then return cb(false, L('tanning_error')) end
    if job.identifier ~= GetIdentifier(src) then return cb(false, L('tanning_not_yours')) end
    if job.finishAt > os.time() then return cb(false, L('tanning_not_ready')) end
    if not Inventory.CanCarry(src, job.output, job.amount) then return cb(false, L('inventory_full')) end

    job.collecting = true
    if not Inventory.Add(src, job.output, job.amount) then
        job.collecting = nil
        return cb(false, L('inventory_full'))
    end
    Racks[rack.id][slot] = nil
    if job.id then
        MySQL.update.await('DELETE FROM `hunting_tanning` WHERE `id` = ?', { job.id })
    else
        MySQL.update.await('DELETE FROM `hunting_tanning` WHERE `rack` = ? AND `slot` = ?', { rack.id, slot })
    end

    cb(true, L('tanning_collected', job.amount, Inventory.Label(job.output)))
end)

function FormatDuration(seconds)
    seconds = math.floor(seconds)
    if seconds >= 60 then
        return L('duration_minutes', math.floor(seconds / 60 + 0.5))
    end
    return L('duration_seconds', seconds)
end
