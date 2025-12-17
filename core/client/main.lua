local QBCore = nil
local ESX = nil

local tracked_vehicles = {}
local active_thefts = {}
local vehicle_owner_cache = {}
local pending_owner_requests = {}
local request_id_counter = 0
local recent_thefts = {}
local recent_owners = {}
local theft_blip = nil
local theft_vehicle = nil

CreateThread(function()
    Wait(1000)
    local bridge = exports['oeva_bridge']:ret_bridge_table()
    if bridge and bridge.framework == 'qb-core' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif bridge and bridge.framework == 'es_extended' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

RegisterNetEvent('s6la_npc_crime:vehicleOwnerResult', function(request_id, plate, owner)
    vehicle_owner_cache[plate] = owner
    if pending_owner_requests[request_id] then
        pending_owner_requests[request_id](owner)
        pending_owner_requests[request_id] = nil
    end
end)

RegisterNetEvent('s6la_npc_crime:playerSourceResult', function(request_id, identifier, player_source)
    if pending_owner_requests[request_id] then
        pending_owner_requests[request_id](player_source)
        pending_owner_requests[request_id] = nil
    end
end)

RegisterNetEvent('s6la_npc_crime:setTheftBlip', function(netId, plate)
    if theft_blip and DoesBlipExist(theft_blip) then
        RemoveBlip(theft_blip)
        theft_blip = nil
        theft_vehicle = nil
    end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end
    theft_vehicle = vehicle
    theft_blip = AddBlipForEntity(vehicle)
    SetBlipSprite(theft_blip, 225)
    SetBlipColour(theft_blip, 1)
    SetBlipScale(theft_blip, 0.9)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Stolen Vehicle")
    EndTextCommandSetBlipName(theft_blip)
    CreateThread(function()
        while theft_blip and DoesBlipExist(theft_blip) and DoesEntityExist(theft_vehicle) do
            Wait(1000)
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == theft_vehicle and GetPedInVehicleSeat(theft_vehicle, -1) == ped then
                break
            end
        end
        if theft_blip and DoesBlipExist(theft_blip) then
            RemoveBlip(theft_blip)
        end
        theft_blip = nil
        theft_vehicle = nil
    end)
end)

RegisterNetEvent('s6la_npc_crime:setStrippedWaypoint', function(x, y)
    if type(x) == "number" and type(y) == "number" then
        SetNewWaypoint(x + 0.0, y + 0.0)
    end
end)

local function get_vehicle_owner_by_plate(plate)
    if vehicle_owner_cache[plate] ~= nil then
        return vehicle_owner_cache[plate]
    end
    
    local request_id = request_id_counter + 1
    request_id_counter = request_id_counter + 1
    
    local result = nil
    local done = false
    
    pending_owner_requests[request_id] = function(owner)
        result = owner
        done = true
    end
    
    TriggerServerEvent('s6la_npc_crime:getVehicleOwner', request_id, plate)
    
    local timeout = 0
    while not done and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if result then
        vehicle_owner_cache[plate] = result
    end
    
    return result
end

local function get_player_source_by_identifier(identifier)
    local request_id = request_id_counter + 1
    request_id_counter = request_id_counter + 1
    
    local result = nil
    local done = false
    
    pending_owner_requests[request_id] = function(player_source)
        result = player_source
        done = true
    end
    
    TriggerServerEvent('s6la_npc_crime:getPlayerSource', request_id, identifier)
    
    local timeout = 0
    while not done and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    return result
end

local function load_model(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end
    
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    return HasModelLoaded(model)
end

local function load_animation_dict(dict)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 5000 do
        Wait(100)
        timeout = timeout + 100
    end
    return HasAnimDictLoaded(dict)
end

local function is_vehicle_stealable(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end
    
    local vehicle_model = GetEntityModel(vehicle)
    local vehicle_class = GetVehicleClass(vehicle)
    
    for _, whitelisted in ipairs(Config.whitelist_vehicles) do
        if GetHashKey(whitelisted) == vehicle_model then
            return false
        end
    end
    
    for _, blacklisted in ipairs(Config.blacklist_vehicles) do
        if GetHashKey(blacklisted) == vehicle_model then
            return true
        end
    end
    
    if Config.allowed_vehicle_classes[vehicle_class] then
        return true
    end
    
    return false
end

local function get_vehicle_plate(vehicle)
    if not DoesEntityExist(vehicle) then
        return nil
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    if plate then
        plate = string.gsub(plate, '%s+', '')
        plate = string.upper(plate)
    end
    
    return plate
end

local function is_vehicle_empty(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end
    
    local driver = GetPedInVehicleSeat(vehicle, -1)
    local passenger = GetPedInVehicleSeat(vehicle, 0)
    local back_left = GetPedInVehicleSeat(vehicle, 1)
    local back_right = GetPedInVehicleSeat(vehicle, 2)
    
    return driver == 0 and passenger == 0 and back_left == 0 and back_right == 0
end

local function get_owner_distance(owner_source, vehicle_coords)
    if not owner_source or owner_source <= 0 then
        return math.huge
    end
    
    local owner_ped = GetPlayerPed(owner_source)
    if not owner_ped or owner_ped == 0 then
        return math.huge
    end
    
    local owner_coords = GetEntityCoords(owner_ped)
    return #(owner_coords - vehicle_coords)
end

local function is_vehicle_locked(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end
    
    local lock_status = GetVehicleDoorLockStatus(vehicle)
    return lock_status == 2 or lock_status == 4
end

local function unlock_vehicle(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId then
        TriggerServerEvent('s6la_npc_crime:forceNetworkControl', netId)
    end
    
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    
    return true
end

local function get_random_destination(vehicle)
    if not Config.destinations or #Config.destinations == 0 then
        return nil
    end
    
    local vehicle_z = nil
    if vehicle and DoesEntityExist(vehicle) then
        local coords = GetEntityCoords(vehicle)
        vehicle_z = coords.z
    end
    
    local max_tries = #Config.destinations * 2
    local best_dest = nil
    local best_height_diff = nil
    
    for i = 1, max_tries do
        local idx = math.random(1, #Config.destinations)
        local dest = Config.destinations[idx]
        local dz = 0.0
        if vehicle_z then
            dz = math.abs(dest.z - vehicle_z)
        end
        
        if not vehicle_z or dz <= 12.0 then
            return vector3(dest.x, dest.y, dest.z)
        end
        
        if not best_dest or dz < best_height_diff then
            best_dest = dest
            best_height_diff = dz
        end
    end
    
    if best_dest then
        return vector3(best_dest.x, best_dest.y, best_dest.z)
    end
    
    return nil
end

local function find_nearby_npc(coords, max_distance)
    local peds = GetGamePool('CPed')
    local closest_npc = nil
    local closest_distance = math.huge
    
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) then
            if not IsPedAPlayer(ped) and not IsPedInAnyVehicle(ped, false) and not IsPedDeadOrDying(ped, true) then
                local ped_coords = GetEntityCoords(ped)
                local distance = #(ped_coords - coords)
                
                if distance < max_distance and distance < closest_distance then
                    local is_controlled = false
                    for _, tracked in pairs(tracked_vehicles) do
                        if tracked.npc == ped then
                            is_controlled = true
                            break
                        end
                    end
                    for _, theft in pairs(active_thefts) do
                        if theft.npc == ped then
                            is_controlled = true
                            break
                        end
                    end
                    
                    if not is_controlled then
                        closest_npc = ped
                        closest_distance = distance
                    end
                end
            end
        end
    end
    
    return closest_npc
end

local function get_closest_owned_vehicle()
    local ped = PlayerPedId()
    local player_coords = GetEntityCoords(ped)
    local closest_vehicle = nil
    local closest_distance = math.huge
    
    local vehicles = GetGamePool('CVehicle')
    
    if Config.debug then
        print('[NPC Crime DEBUG] Checking ' .. #vehicles .. ' vehicles in pool')
    end
    
    local checked_count = 0
    local empty_count = 0
    local owned_count = 0
    
    for _, vehicle in ipairs(vehicles) do
        checked_count = checked_count + 1
        
        if DoesEntityExist(vehicle) then
            if is_vehicle_empty(vehicle) then
                empty_count = empty_count + 1
                local plate = get_vehicle_plate(vehicle)
                
                if plate and plate ~= '' then
                    if Config.debug and checked_count <= 5 then
                        print('[NPC Crime DEBUG] Checking vehicle ' .. checked_count .. ' with plate: ' .. plate)
                    end
                    
                    local owner_identifier = get_vehicle_owner_by_plate(plate)
                    
                    if owner_identifier then
                        owned_count = owned_count + 1
                        local vehicle_coords = GetEntityCoords(vehicle)
                        local distance = #(player_coords - vehicle_coords)
                        
                        if Config.debug then
                            print('[NPC Crime DEBUG] Found owned vehicle at distance: ' .. string.format('%.2f', distance) .. 'm')
                        end
                        
                        if distance < closest_distance then
                            closest_distance = distance
                            closest_vehicle = vehicle
                        end
                    end
                end
            end
        end
    end
    
    if Config.debug then
        print('[NPC Crime DEBUG] Checked: ' .. checked_count .. ', Empty: ' .. empty_count .. ', Owned: ' .. owned_count)
        if closest_vehicle then
            print('[NPC Crime DEBUG] Closest owned vehicle found at distance: ' .. string.format('%.2f', closest_distance) .. 'm')
        end
    end
    
    return closest_vehicle
end

local function strip_vehicle(vehicle)
    if not DoesEntityExist(vehicle) then
        return
    end
    
    if Config.vehicle_stripping.remove_wheels then
        for i = 0, 3 do
            SetVehicleTyreBurst(vehicle, i, true, 1000.0)
        end
    end
    
    if Config.vehicle_stripping.remove_doors then
        for i = 0, 5 do
            SetVehicleDoorBroken(vehicle, i, true)
        end
    end
    
    if Config.vehicle_stripping.damage_engine then
        SetVehicleEngineHealth(vehicle, 100.0)
    end
    
    if Config.vehicle_stripping.damage_body then
        SetVehicleBodyHealth(vehicle, 200.0)
    end
    
    if Config.vehicle_stripping.set_dirt_level then
        SetVehicleDirtLevel(vehicle, Config.vehicle_stripping.set_dirt_level)
    end
end

CreateThread(function()
    while true do
        Wait(Config.distance_check.check_interval)
        
        if Config.debug then
            print('[NPC Crime DEBUG] Debug mode active, searching for closest owned vehicle...')
            local closest_vehicle = get_closest_owned_vehicle()
            
            if closest_vehicle then
                print('[NPC Crime DEBUG] Found closest vehicle: ' .. tostring(closest_vehicle))
                
                if not tracked_vehicles[closest_vehicle] then
                    local plate = get_vehicle_plate(closest_vehicle)
                    print('[NPC Crime DEBUG] Vehicle plate: ' .. tostring(plate))
                    
                    if plate and plate ~= '' then
                        print('[NPC Crime DEBUG] Querying vehicle owner for plate: ' .. plate)
                        local owner_identifier = get_vehicle_owner_by_plate(plate)
                        print('[NPC Crime DEBUG] Owner identifier result: ' .. tostring(owner_identifier))
                        
                        if owner_identifier then
                            print('[NPC Crime DEBUG] Vehicle is owned! Starting theft process...')
                            tracked_vehicles[closest_vehicle] = {
                                vehicle = closest_vehicle,
                                plate = plate,
                                owner_identifier = owner_identifier,
                                owner_source = nil,
                                distance_check_start = GetGameTimer(),
                                npc = nil,
                                state = 'tracking'
                            }
                            CreateThread(function()
                                Wait(1000)
                                if tracked_vehicles[closest_vehicle] then
                                    print('[NPC Crime DEBUG] Starting theft process for vehicle: ' .. tostring(closest_vehicle))
                                    tracked_vehicles[closest_vehicle].state = 'starting_theft'
                                    start_theft_process(tracked_vehicles[closest_vehicle])
                                else
                                    print('[NPC Crime DEBUG] Vehicle was removed from tracking before theft could start')
                                end
                            end)
                        else
                            print('[NPC Crime DEBUG] Vehicle has no owner or owner query failed')
                        end
                    else
                        print('[NPC Crime DEBUG] Vehicle has no plate or plate is empty')
                    end
                else
                    print('[NPC Crime DEBUG] Vehicle is already being tracked')
                end
            else
                print('[NPC Crime DEBUG] No owned vehicle found nearby')
            end
        else
            local vehicles = GetGamePool('CVehicle')
            local ped = PlayerPedId()
            local player_coords = GetEntityCoords(ped)
            
            for _, vehicle in ipairs(vehicles) do
                if DoesEntityExist(vehicle) and is_vehicle_stealable(vehicle) and is_vehicle_empty(vehicle) then
                    local vehicle_coords = GetEntityCoords(vehicle)
                    if #(vehicle_coords - player_coords) <= 100.0 then
                        local plate = get_vehicle_plate(vehicle)
                        if plate and plate ~= '' then
                            local last_theft = recent_thefts[plate]
                            if not last_theft then
                                local owner_identifier = get_vehicle_owner_by_plate(plate)
                                
                                if owner_identifier and not recent_owners[owner_identifier] then
                                    local owner_source = get_player_source_by_identifier(owner_identifier)
                                    local distance = math.huge
                                    
                                    if owner_source and owner_source > 0 then
                                        distance = get_owner_distance(owner_source, vehicle_coords)
                                    end
                                    
                                    local tracked = tracked_vehicles[vehicle]
                                    
                                    if distance > Config.distance_check.min_distance then
                                        if not tracked then
                                            local theft_chance = math.random(1, 100)
                                            local should_steal = Config.debug or theft_chance <= 60
                                            
                                            if should_steal then
                                                tracked_vehicles[vehicle] = {
                                                    vehicle = vehicle,
                                                    plate = plate,
                                                    owner_identifier = owner_identifier,
                                                    owner_source = owner_source,
                                                    distance_check_start = GetGameTimer(),
                                                    npc = nil,
                                                    state = 'tracking'
                                                }
                                            end
                                        elseif tracked.state == 'tracking' then
                                            local time_away = GetGameTimer() - tracked.distance_check_start
                                            if time_away >= Config.distance_check.time_before_theft then
                                                tracked.state = 'starting_theft'
                                                CreateThread(function()
                                                    start_theft_process(tracked)
                                                end)
                                            end
                                        end
                                    else
                                        if tracked then
                                            if tracked.npc and DoesEntityExist(tracked.npc) then
                                                DeleteEntity(tracked.npc)
                                            end
                                            tracked_vehicles[vehicle] = nil
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        for vehicle, data in pairs(tracked_vehicles) do
            if not DoesEntityExist(vehicle) or not is_vehicle_empty(vehicle) or active_thefts[vehicle] then
                if data.npc and DoesEntityExist(data.npc) then
                    ClearPedTasksImmediately(data.npc)
                    SetPedCanRagdoll(data.npc, true)
                    SetPedDiesWhenInjured(data.npc, true)
                    SetBlockingOfNonTemporaryEvents(data.npc, false)
                end
                tracked_vehicles[vehicle] = nil
            end
        end
    end
end)

function start_theft_process(tracked_data)
    if Config.debug then
        print('[NPC Crime DEBUG] start_theft_process called')
    end
    
    local vehicle = tracked_data.vehicle
    if not DoesEntityExist(vehicle) then
        if Config.debug then
            print('[NPC Crime DEBUG] Vehicle does not exist')
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    if not is_vehicle_empty(vehicle) then
        if Config.debug then
            print('[NPC Crime DEBUG] Vehicle is not empty')
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    local vehicle_coords = GetEntityCoords(vehicle)
    local npc = find_nearby_npc(vehicle_coords, 50.0)
    
    if not npc or not DoesEntityExist(npc) then
        if Config.debug then
            print('[NPC Crime DEBUG] No suitable NPC found nearby')
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    if Config.debug then
        print('[NPC Crime DEBUG] Found existing NPC: ' .. tostring(npc))
    end
    
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedFleeAttributes(npc, 0, false)
    SetPedCombatAttributes(npc, 46, true)
    SetPedCombatAbility(npc, 0)
    SetPedKeepTask(npc, true)
    SetPedCanRagdoll(npc, false)
    SetPedDiesWhenInjured(npc, false)
    
    ClearPedTasksImmediately(npc)
    Wait(200)
    
    tracked_data.npc = npc
    tracked_data.state = 'approaching'
    
    ResetPedStrafeClipset(npc)
    
    SetPedMoveRateOverride(npc, 1.5)
    TaskGoToEntity(npc, vehicle, -1, 1.5, 2.0, 1073741824, 0)
    
    local timeout = 0
    local max_timeout = 15000
    while DoesEntityExist(npc) and DoesEntityExist(vehicle) and timeout < max_timeout do
        Wait(200)
        timeout = timeout + 200
        
        local npc_coords_current = GetEntityCoords(npc)
        local distance_to_vehicle = #(npc_coords_current - vehicle_coords)
        
        if distance_to_vehicle < 2.0 then
            break
        end
    end
    
    TaskStandStill(npc, 100)
    Wait(100)
    
    if not DoesEntityExist(npc) or not DoesEntityExist(vehicle) or not is_vehicle_empty(vehicle) then
        if DoesEntityExist(npc) then
            ClearPedTasksImmediately(npc)
            SetPedCanRagdoll(npc, true)
            SetPedDiesWhenInjured(npc, true)
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    local is_locked = is_vehicle_locked(vehicle)
    
    if is_locked then
        tracked_data.state = 'carjacking'
        
        local door_bone_carjack = GetEntityBoneIndexByName(vehicle, 'door_dside_f')
        if door_bone_carjack == -1 then
            door_bone_carjack = 0
        end
        local door_coords_carjack = GetWorldPositionOfEntityBone(vehicle, door_bone_carjack)
        TaskGoStraightToCoord(npc, door_coords_carjack.x, door_coords_carjack.y, door_coords_carjack.z, 1.0, 3000, GetEntityHeading(vehicle), 0.1)
        local carjack_timeout = 0
        while DoesEntityExist(npc) and DoesEntityExist(vehicle) and carjack_timeout < 3000 do
            Wait(50)
            carjack_timeout = carjack_timeout + 50
            local npc_pos_carjack = GetEntityCoords(npc)
            local dist_carjack = #(npc_pos_carjack - door_coords_carjack)
            if dist_carjack < 1.2 then
                break
            end
        end
        
        local anim_dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
        local anim_name = 'machinic_loop_mechandplayer'
        
        if not load_animation_dict(anim_dict) then
            anim_dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
            anim_name = 'machinic_loop_mechandplayer'
            load_animation_dict(anim_dict)
        end
        
        local prop_model = GetHashKey('p_car_keys_01') -- i honestly dont know what prop to use, so fuck it.
        RequestModel(prop_model)
        local timeout = 0
        while not HasModelLoaded(prop_model) and timeout < 1000 do
            Wait(10)
            timeout = timeout + 10
        end
        
        local prop = nil
        if HasModelLoaded(prop_model) then
            local npc_coords = GetEntityCoords(npc)
            prop = CreateObject(prop_model, npc_coords.x, npc_coords.y, npc_coords.z, true, true, true)
            AttachEntityToEntity(prop, npc, GetPedBoneIndex(npc, 57005), 0.09, 0.04, -0.02, -78.0, 13.0, 28.0, false, true, true, true, 0, true)
        end
        
        if HasAnimDictLoaded(anim_dict) then
            TaskPlayAnim(npc, anim_dict, anim_name, 3.0, 3.0, 5000, 1, 0, false, false, false)
            Wait(5000)
            StopAnimTask(npc, anim_dict, anim_name, 1.0)
        else
            Wait(3000)
        end
        
        if prop and DoesEntityExist(prop) then
            DeleteObject(prop)
        end
        
        unlock_vehicle(vehicle)
    end
    
    if not DoesEntityExist(npc) or not DoesEntityExist(vehicle) or not is_vehicle_empty(vehicle) then
        if DoesEntityExist(npc) then
            ClearPedTasksImmediately(npc)
            SetPedCanRagdoll(npc, true)
            SetPedDiesWhenInjured(npc, true)
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    local npc_coords_final = GetEntityCoords(npc)
    local vehicle_coords_final = GetEntityCoords(vehicle)
    local dist_to_vehicle = #(npc_coords_final - vehicle_coords_final)
    
    if dist_to_vehicle > 2.0 then
        TaskGoToEntity(npc, vehicle, -1, 1.0, 2.0, 1073741824, 0)
        
        local enter_timeout = 0
        while DoesEntityExist(npc) and DoesEntityExist(vehicle) and enter_timeout < 5000 do
            Wait(100)
            enter_timeout = enter_timeout + 100
            local npc_pos = GetEntityCoords(npc)
            local veh_pos = GetEntityCoords(vehicle)
            local dist = #(npc_pos - veh_pos)
            if dist < 1.5 then
                break
            end
        end
    end
    
    if not DoesEntityExist(npc) or not DoesEntityExist(vehicle) or not is_vehicle_empty(vehicle) then
        if DoesEntityExist(npc) then
            ClearPedTasksImmediately(npc)
            SetPedCanRagdoll(npc, true)
            SetPedDiesWhenInjured(npc, true)
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    tracked_data.state = 'entering'
    
    local door_bone = GetEntityBoneIndexByName(vehicle, 'door_dside_f')
    if door_bone == -1 then
        door_bone = 0
    end
    
    local door_coords = GetWorldPositionOfEntityBone(vehicle, door_bone)
    TaskGoStraightToCoord(npc, door_coords.x, door_coords.y, door_coords.z, 1.0, 3000, GetEntityHeading(vehicle), 0.1)
    
    local approach_timeout = 0
    while DoesEntityExist(npc) and DoesEntityExist(vehicle) and approach_timeout < 3000 do
        Wait(50)
        approach_timeout = approach_timeout + 50
        local npc_pos = GetEntityCoords(npc)
        local dist = #(npc_pos - door_coords)
        if dist < 0.8 then
            break
        end
    end
    
    TaskEnterVehicle(npc, vehicle, 10000, -1, 1.0, 1, 0)
    
    local enter_check_timeout = 0
    local max_enter_wait = 15000
    while DoesEntityExist(npc) and DoesEntityExist(vehicle) and enter_check_timeout < max_enter_wait do
        Wait(200)
        enter_check_timeout = enter_check_timeout + 200
        
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if driver == npc then
            break
        end
        
        if enter_check_timeout > 8000 and enter_check_timeout % 3000 < 200 then
            local npc_pos = GetEntityCoords(npc)
            local veh_pos = GetEntityCoords(vehicle)
            local dist = #(npc_pos - veh_pos)
            if dist < 3.0 then
                ClearPedTasksImmediately(npc)
                Wait(200)
                TaskEnterVehicle(npc, vehicle, 10000, -1, 1.0, 1, 0)
            end
        end
    end
    
    if not DoesEntityExist(npc) or not DoesEntityExist(vehicle) then
        if DoesEntityExist(npc) then
            ClearPedTasksImmediately(npc)
            SetPedCanRagdoll(npc, true)
            SetPedDiesWhenInjured(npc, true)
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver ~= npc then
        if Config.debug then
            print('[NPC Crime DEBUG] NPC failed to enter vehicle after ' .. enter_check_timeout .. 'ms')
        end
        if DoesEntityExist(npc) then
            ClearPedTasksImmediately(npc)
            SetPedCanRagdoll(npc, true)
            SetPedDiesWhenInjured(npc, true)
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    tracked_data.state = 'driving'
    local destination = get_random_destination(vehicle)
    
    if not destination then
        if Config.debug then
            print('[NPC Crime] No destination found')
        end
        if DoesEntityExist(npc) then
            ClearPedTasksImmediately(npc)
            SetPedCanRagdoll(npc, true)
            SetPedDiesWhenInjured(npc, true)
        end
        tracked_vehicles[vehicle] = nil
        return
    end
    
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleHasBeenOwnedByPlayer(vehicle, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetEntityAsMissionEntity(npc, true, true)
    
    local plate = get_vehicle_plate(vehicle)
    if plate and tracked_data.owner_identifier then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        TriggerServerEvent('s6la_npc_crime:notifyOwner', tracked_data.owner_identifier, plate, netId)
    end
    
    SetDriveTaskMaxCruiseSpeed(npc, 50.0)
    SetDriveTaskDrivingStyle(npc, 1074528293)
    SetPedKeepTask(npc, true)
    TaskVehicleDriveToCoord(npc, vehicle, destination.x, destination.y, destination.z, 50.0, 0, GetEntityModel(vehicle), 1074528293, 10.0, -1.0)
    
    active_thefts[vehicle] = {
        vehicle = vehicle,
        npc = npc,
        destination = destination,
        state = 'driving',
        owner_identifier = tracked_data.owner_identifier
    }
    
    tracked_vehicles[vehicle] = nil
    
    CreateThread(function()
        monitor_theft(vehicle, npc, destination)
    end)
end

function monitor_theft(vehicle, npc, destination)
    local timeout = 0
    local max_timeout = 300000
    local last_position = GetEntityCoords(vehicle)
    local stuck_time = 0
    local last_heading = GetEntityHeading(vehicle)
    local rotation_stuck_time = 0
    local reached_destination = false
    
    while DoesEntityExist(vehicle) and DoesEntityExist(npc) and timeout < max_timeout do
        Wait(1000)
        timeout = timeout + 1000
        
        local vehicle_coords = GetEntityCoords(vehicle)
        local distance_to_dest = #(vehicle_coords - destination)
        
        if distance_to_dest < 10.0 then
            reached_destination = true
            break
        end
        
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if driver ~= npc then
            break
        end
        
        if IsPedDeadOrDying(npc, true) then
            break
        end
        
        local current_position = GetEntityCoords(vehicle)
        local current_heading = GetEntityHeading(vehicle)
        local distance_moved = #(current_position - last_position)
        local heading_change = math.abs(current_heading - last_heading)
        if heading_change > 180 then
            heading_change = 360 - heading_change
        end
        
        if distance_moved < 1.5 then
            stuck_time = stuck_time + 1
            if stuck_time > 5 then
                TaskVehicleTempAction(npc, vehicle, 1, 1000)
                Wait(500)
                TaskVehicleDriveToCoord(npc, vehicle, destination.x, destination.y, destination.z, 50.0, 0, GetEntityModel(vehicle), 1074528293, 10.0, -1.0)
                stuck_time = 0
            end
        elseif heading_change < 1.0 and distance_moved < 3.0 then
            rotation_stuck_time = rotation_stuck_time + 1
            if rotation_stuck_time > 3 then
                TaskVehicleTempAction(npc, vehicle, 27, 2000)
                Wait(1000)
                TaskVehicleDriveToCoord(npc, vehicle, destination.x, destination.y, destination.z, 50.0, 0, GetEntityModel(vehicle), 1074528293, 10.0, -1.0)
                rotation_stuck_time = 0
            end
        else
            stuck_time = 0
            rotation_stuck_time = 0
        end
        
        last_position = current_position
        last_heading = current_heading
    end
    
    if DoesEntityExist(npc) then
        if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == npc then
            TaskLeaveVehicle(npc, vehicle, 0)
            local leave_timeout = 0
            while DoesEntityExist(npc) and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == npc and leave_timeout < 5000 do
                Wait(200)
                leave_timeout = leave_timeout + 200
            end
        end
        
        if DoesEntityExist(npc) then
            ClearPedTasksImmediately(npc)
            SetPedCanRagdoll(npc, true)
            SetPedDiesWhenInjured(npc, true)
            SetBlockingOfNonTemporaryEvents(npc, false)
            local flee_coords = DoesEntityExist(vehicle) and GetEntityCoords(vehicle) or GetEntityCoords(npc)
            TaskSmartFleeCoord(npc, flee_coords.x, flee_coords.y, flee_coords.z, 200.0, -1, false, false)
        end
    end
    
    if DoesEntityExist(vehicle) then
        local plate = get_vehicle_plate(vehicle)
        if plate and plate ~= '' then
            recent_thefts[plate] = GetGameTimer()
            local data = active_thefts[vehicle]
            if data and data.owner_identifier then
                recent_owners[data.owner_identifier] = true
                if reached_destination then
                    TriggerServerEvent('s6la_npc_crime:notifyStripped', data.owner_identifier, plate, destination.x, destination.y)
                end
            end
        end
        if reached_destination then
            strip_vehicle(vehicle)
        end
    end
    
    active_thefts[vehicle] = nil
end

CreateThread(function()
    while true do
        Wait(5000)
        
        for vehicle, data in pairs(active_thefts) do
            if not DoesEntityExist(vehicle) or not DoesEntityExist(data.npc) or IsPedDeadOrDying(data.npc, true) then
                if DoesEntityExist(data.npc) then
                    ClearPedTasksImmediately(data.npc)
                    SetPedCanRagdoll(data.npc, true)
                    SetPedDiesWhenInjured(data.npc, true)
                    SetBlockingOfNonTemporaryEvents(data.npc, false)
                end
                active_thefts[vehicle] = nil
            else
                local driver = GetPedInVehicleSeat(vehicle, -1)
                if driver ~= data.npc then
                    if DoesEntityExist(data.npc) then
                        ClearPedTasksImmediately(data.npc)
                        SetPedCanRagdoll(data.npc, true)
                        SetPedDiesWhenInjured(data.npc, true)
                        SetBlockingOfNonTemporaryEvents(data.npc, false)
                    end
                    active_thefts[vehicle] = nil
                end
            end
        end
        
        for vehicle, data in pairs(tracked_vehicles) do
            if data.npc and DoesEntityExist(data.npc) then
                if IsPedDeadOrDying(data.npc, true) or not DoesEntityExist(vehicle) or not is_vehicle_empty(vehicle) then
                    if DoesEntityExist(data.npc) then
                        ClearPedTasksImmediately(data.npc)
                        SetPedCanRagdoll(data.npc, true)
                        SetPedDiesWhenInjured(data.npc, true)
                        SetBlockingOfNonTemporaryEvents(data.npc, false)
                    end
                    tracked_vehicles[vehicle] = nil
                end
            end
        end
    end
end)
