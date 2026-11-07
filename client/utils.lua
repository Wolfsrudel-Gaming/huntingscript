ESX = exports['es_extended']:getSharedObject()

Busy = false                -- Spieler führt gerade eine Hunting-Aktion aus
CurrentBucket = 0           -- Routing-Bucket (vom Server synchronisiert)

local spawnedProps = {}     -- Handprops, die beim Ressourcen-Stopp entfernt werden

--[[ Benachrichtigungen ]]

function Notify(msg, ntype)
    if Config.Notify then
        return Config.Notify(msg, ntype)
    end
    ESX.ShowNotification(msg, ntype)
end

RegisterNetEvent('wr_hunting:client:notify', function(msg, ntype)
    Notify(msg, ntype)
end)

function HelpText(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

function DrawText3D(coords, text, scale)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.0, scale or 0.32)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

--[[ Laden von Assets ]]

function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

function LoadAnimDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

function LoadPtfx(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded(asset) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

--[[ Props ]]

function AttachPropToPed(ped, model, bone, pos, rot)
    local hash = LoadModel(model)
    if not hash then return nil end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, Config.NetworkedProps, Config.NetworkedProps, false)
    if obj == 0 then return nil end
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, bone), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    spawnedProps[obj] = true
    return obj
end

function DeleteProp(obj)
    if obj and DoesEntityExist(obj) then
        DetachEntity(obj, true, false)
        DeleteEntity(obj)
    end
    if obj then spawnedProps[obj] = nil end
end

--[[ Spieler ]]

function GetPlayerPedFromServerId(serverId)
    if not serverId then return nil end
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

function GetStreetLabel(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local zoneLabel = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if zoneLabel == 'NULL' then zoneLabel = '' end
    if street == nil or street == '' then return zoneLabel end
    if zoneLabel == '' then return street end
    return street .. ', ' .. zoneLabel
end

function FacePosition(coords)
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, 800)
    Wait(800)
end

--[[ Fortschrittsbalken (ohne Abhängigkeiten) ]]

local function DrawProgress(label, pct)
    local x, y, w, h = 0.5, 0.9, 0.17, 0.011
    DrawRect(x, y, w + 0.006, h + 0.01, 0, 0, 0, 170)
    DrawRect(x - w / 2 + (w * pct) / 2, y, w * pct, h, 116, 166, 72, 230)

    SetTextFont(4)
    SetTextScale(0.0, 0.36)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('%s  %d%%'):format(label, math.floor(pct * 100)))
    EndTextCommandDisplayText(x, y - 0.036)

    SetTextFont(4)
    SetTextScale(0.0, 0.28)
    SetTextColour(220, 220, 220, 200)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(L('progress_cancel'))
    EndTextCommandDisplayText(x, y + 0.012)
end

--- Blockierender Fortschrittsbalken. Gibt true zurück, wenn er vollständig durchlief.
---@param label string
---@param duration number Millisekunden
---@param opts table|nil { canCancel = bool, check = function():bool }
function Progress(label, duration, opts)
    opts = opts or {}
    local ped = PlayerPedId()
    local start = GetGameTimer()
    local completed = true

    while true do
        local pct = (GetGameTimer() - start) / duration
        if pct >= 1.0 then break end

        DisableControlAction(0, 21, true)   -- Sprint
        DisableControlAction(0, 22, true)   -- Springen
        DisableControlAction(0, 23, true)   -- Fahrzeug betreten
        DisableControlAction(0, 24, true)   -- Angriff
        DisableControlAction(0, 25, true)   -- Zielen
        DisableControlAction(0, 30, true)   -- Bewegen L/R
        DisableControlAction(0, 31, true)   -- Bewegen V/Z
        DisableControlAction(0, 36, true)   -- Ducken
        DisableControlAction(0, 37, true)   -- Waffenrad
        DisableControlAction(0, 44, true)   -- Deckung
        DisableControlAction(0, 140, true)  -- Nahkampf
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, Config.CancelKey, true)
        DisablePlayerFiring(PlayerId(), true)

        if opts.canCancel ~= false and IsDisabledControlJustPressed(0, Config.CancelKey) then
            completed = false
            break
        end
        if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, true) then
            completed = false
            break
        end
        if opts.check and not opts.check() then
            completed = false
            break
        end

        DrawProgress(label, pct)
        Wait(0)
    end

    return completed
end

--[[ Menüs (esx_context oder esx_menu_default) ]]

local function GetMenuSystem()
    if Config.Menu ~= 'auto' then return Config.Menu end
    if GetResourceState('esx_context') == 'started' then return 'esx_context' end
    return 'esx_menu_default'
end

--- Öffnet ein einfaches Auswahlmenü.
---@param name string eindeutiger Menüname
---@param title string
---@param elements table { { label = '', description = '', disabled = bool, value = any } }
---@param onSelect function(element)
function OpenMenu(name, title, elements, onSelect)
    local system = GetMenuSystem()

    if system == 'esx_context' then
        local ctx = { { unselectable = true, icon = 'fas fa-paw', title = title } }
        for i, e in ipairs(elements) do
            ctx[#ctx + 1] = {
                title       = e.label,
                description = e.description,
                icon        = e.icon,
                disabled    = e.disabled,
                index       = i,
            }
        end
        ESX.OpenContext('right', ctx, function(_, element)
            local selected = element and element.index and elements[element.index]
            if not selected or selected.disabled then return end
            ESX.CloseContext()
            onSelect(selected)
        end, function() end)
        return
    end

    local els = {}
    for i, e in ipairs(elements) do
        local label = e.label
        if e.description then
            label = ('%s <span style="opacity:0.65">– %s</span>'):format(e.label, e.description)
        end
        els[#els + 1] = { label = label, index = i }
    end

    ESX.UI.Menu.CloseAll()
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), name, {
        title    = title,
        align    = 'top-left',
        elements = els,
    }, function(data, menu)
        local selected = elements[data.current.index]
        if not selected or selected.disabled then return end
        menu.close()
        onSelect(selected)
    end, function(_, menu)
        menu.close()
    end)
end

--[[ Server-Callbacks als synchrone Aufrufe ]]

function Callback(name, ...)
    local p = promise.new()
    ESX.TriggerServerCallback(name, function(...)
        p:resolve(table.pack(...))
    end, ...)
    local result = Citizen.Await(p)
    return table.unpack(result, 1, result.n)
end

--[[ Raycast / Mathe ]]

function RotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

function RaycastFromCamera(distance, ignore)
    local camPos = GetGameplayCamCoord()
    local dir = RotationToDirection(GetGameplayCamRot(2))
    local dest = camPos + dir * distance
    local ray = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z,
        1 + 16, ignore or PlayerPedId(), 4)
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(ray)
    return hit == 1, endCoords, surfaceNormal, entityHit
end

function FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    return ('%02d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

--- Ermittelt den Boden an einer Position (benötigt geladene Kollision).
function GetGroundZ(x, y, z)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 3.0, false)
    if found then return groundZ end
    return z
end

--[[ Lokale Welt-Props (Köder, Tarnzelte, ...), vom Server synchronisiert ]]

--- Erstellt eine Prop-Sammlung, deren Einträge ({ id, coords, heading?, bucket, model })
--- in Reichweite als lokale, eingefrorene Objekte dargestellt werden.
function CreatePropSet(renderDistance)
    local set = { items = {}, rendered = {} }

    local function Despawn(id)
        local obj = set.rendered[id]
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
        set.rendered[id] = nil
    end

    function set.Sync(list)
        for id in pairs(set.rendered) do Despawn(id) end
        set.items = {}
        for _, item in ipairs(list or {}) do set.items[item.id] = item end
    end

    function set.Add(item)
        set.items[item.id] = item
    end

    function set.Remove(id)
        set.items[id] = nil
        Despawn(id)
    end

    function set.Clear()
        for id in pairs(set.rendered) do Despawn(id) end
    end

    CreateThread(function()
        while true do
            local coords = GetEntityCoords(PlayerPedId())
            for id, item in pairs(set.items) do
                local inRange = item.bucket == CurrentBucket and #(coords - item.coords) <= renderDistance
                if inRange and set.rendered[id] == nil then
                    local hash = item.model and LoadModel(item.model)
                    if hash then
                        local z = GetGroundZ(item.coords.x, item.coords.y, item.coords.z)
                        local obj = CreateObject(hash, item.coords.x, item.coords.y, z, false, false, false)
                        SetEntityHeading(obj, item.heading or 0.0)
                        PlaceObjectOnGroundProperly(obj)
                        FreezeEntityPosition(obj, true)
                        SetModelAsNoLongerNeeded(hash)
                        set.rendered[id] = obj
                    else
                        set.rendered[id] = false
                    end
                elseif not inRange and set.rendered[id] ~= nil then
                    Despawn(id)
                end
            end
            Wait(1500)
        end
    end)

    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then set.Clear() end
    end)

    return set
end

--- Prüft, ob an der Position vor dem Spieler etwas aufgestellt werden kann.
---@return vector3|nil Bodenposition
function GetPlacementSpot(distance)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityInWater(ped) then return nil end
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, distance or 1.2, 0.0)
    local found, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    if not found or math.abs(groundZ - pos.z) > 2.0 then return nil end
    local isWater = GetWaterHeight(pos.x, pos.y, groundZ)
    if isWater then return nil end
    return vector3(pos.x, pos.y, groundZ)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for obj in pairs(spawnedProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end)

RegisterNetEvent('wr_hunting:client:setBucket', function(bucket)
    CurrentBucket = bucket or 0
end)
