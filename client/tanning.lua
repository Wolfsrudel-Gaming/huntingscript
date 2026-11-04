--[[
    Gerbrahmen: rohe Felle aufspannen und später als gegerbtes Leder abholen.
]]

local rackProps = {}    -- [rackIndex] = entity
local rackBlips = {}

--[[ Props & Blips ]]

CreateThread(function()
    local blipCfg = Config.Tanning.blip
    if blipCfg and blipCfg.enabled then
        local done = {}
        for _, rack in ipairs(Config.Tanning.racks) do
            -- Mehrere Rahmen am selben Ort → nur ein Blip
            local key = ('%d:%d'):format(math.floor(rack.coords.x / 25), math.floor(rack.coords.y / 25))
            if not done[key] then
                done[key] = true
                local blip = AddBlipForCoord(rack.coords.x, rack.coords.y, rack.coords.z)
                SetBlipSprite(blip, blipCfg.sprite)
                SetBlipColour(blip, blipCfg.colour)
                SetBlipScale(blip, blipCfg.scale)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(L('tanning_blip'))
                EndTextCommandSetBlipName(blip)
                rackBlips[#rackBlips + 1] = blip
            end
        end
    end

    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for i, rack in ipairs(Config.Tanning.racks) do
            if rack.model then
                local pos = vector3(rack.coords.x, rack.coords.y, rack.coords.z)
                local dist = #(coords - pos)
                if dist < 80.0 and not rackProps[i] then
                    local hash = LoadModel(rack.model)
                    if hash then
                        local z = GetGroundZ(pos.x, pos.y, pos.z)
                        local obj = CreateObject(hash, pos.x, pos.y, z, false, false, false)
                        SetEntityHeading(obj, rack.coords.w)
                        PlaceObjectOnGroundProperly(obj)
                        FreezeEntityPosition(obj, true)
                        SetModelAsNoLongerNeeded(hash)
                        rackProps[i] = obj
                    end
                elseif dist > 100.0 and rackProps[i] then
                    DeleteEntity(rackProps[i])
                    rackProps[i] = nil
                end
            end
        end
        Wait(2000)
    end
end)

--[[ Interaktion ]]

local function PlayWorkAnim(ped)
    if LoadAnimDict('mini@repair') then
        TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 3.0, 3.0, -1, 1, 0.0, false, false, false)
    end
end

local function InsertPelt(rack, rackIndex, slot)
    local ok, pelts = Callback('wr_hunting:tanning:getPelts')
    if not ok or not pelts or #pelts == 0 then
        Notify(L('tanning_no_pelts'), 'error')
        return
    end

    local elements = {}
    for _, p in ipairs(pelts) do
        elements[#elements + 1] = {
            label       = ('%s (x%d)'):format(p.label, p.count),
            description = L('tanning_duration', FormatTime(p.duration)),
            item        = p.item,
        }
    end

    OpenMenu('wr_hunting_tanning_pelts', L('tanning_choose_pelt'), elements, function(selected)
        CreateThread(function()
            Busy = true
            local ped = PlayerPedId()
            FacePosition(rack.coords.xyz)
            PlayWorkAnim(ped)
            local completed = Progress(L('tanning_placing'), Config.Tanning.placeTime * 1000)
            ClearPedTasks(ped)
            if completed then
                local success, msg = Callback('wr_hunting:tanning:insert', rackIndex, slot, selected.item)
                Notify(msg, success and 'success' or 'error')
            end
            Busy = false
        end)
    end)
end

local function CollectSlot(rack, rackIndex, slot)
    local ped = PlayerPedId()
    FacePosition(rack.coords.xyz)
    PlayWorkAnim(ped)
    local completed = Progress(L('tanning_collecting'), Config.Tanning.collectTime * 1000)
    ClearPedTasks(ped)
    if completed then
        local success, msg = Callback('wr_hunting:tanning:collect', rackIndex, slot)
        Notify(msg, success and 'success' or 'error')
    end
end

local function OpenRack(rack, rackIndex)
    local ok, slots = Callback('wr_hunting:tanning:getRack', rackIndex)
    if not ok then
        Notify(slots or L('tanning_error'), 'error')
        return
    end

    local elements = {}
    for slot = 1, rack.slots do
        local s = slots[slot]
        local e = { slot = slot }
        if not s then
            e.label = L('tanning_slot_free', slot)
            e.description = L('tanning_slot_free_desc')
            e.action = 'insert'
        elseif s.own and s.remaining <= 0 then
            e.label = L('tanning_slot_ready', slot, s.label)
            e.description = L('tanning_slot_ready_desc')
            e.action = 'collect'
        elseif s.own then
            e.label = L('tanning_slot_busy_own', slot, s.label)
            e.description = L('tanning_remaining', FormatTime(s.remaining))
            e.disabled = true
        else
            e.label = L('tanning_slot_busy', slot)
            e.description = L('tanning_slot_busy_desc')
            e.disabled = true
        end
        elements[#elements + 1] = e
    end

    OpenMenu('wr_hunting_tanning', rack.label, elements, function(selected)
        if selected.action == 'insert' then
            InsertPelt(rack, rackIndex, selected.slot)
        elseif selected.action == 'collect' then
            CreateThread(function()
                Busy = true
                CollectSlot(rack, rackIndex, selected.slot)
                Busy = false
            end)
        end
    end)
end

RegisterInteraction('tanning', function(coords)
    local best, bestDist, bestIndex = nil, nil, nil
    for i, rack in ipairs(Config.Tanning.racks) do
        local dist = #(coords - rack.coords.xyz)
        if dist <= 2.0 and (not bestDist or dist < bestDist) then
            best, bestDist, bestIndex = rack, dist, i
        end
    end
    if not best then return nil end
    return {
        dist   = bestDist,
        text   = L('tanning_prompt'),
        action = function() OpenRack(best, bestIndex) end,
    }
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, obj in pairs(rackProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    for _, blip in ipairs(rackBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
