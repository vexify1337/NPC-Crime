local QBCore = nil
local ESX = nil
local recent_notifications = {}

CreateThread(function()
    while not MySQL do
        Wait(100)
    end
    
    Wait(1000)
    local bridge = exports['oeva_bridge']:ret_bridge_table()
    if bridge and bridge.framework == 'qb-core' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif bridge and bridge.framework == 'es_extended' then
        ESX = exports['es_extended']:getSharedObject()
    end
    
    if Config.debug then
        print('[NPC Crime DEBUG SERVER] Resource initialized, MySQL: ' .. tostring(MySQL ~= nil))
    end
end)

function IsVehicleOwnedByPlayer(vehicle_plate, source)
    if not vehicle_plate or vehicle_plate == '' then
        return false, nil
    end
    
    local bridge = exports['oeva_bridge']:ret_bridge_table()
    if not bridge then
        return false, nil
    end
    
    if bridge.framework == 'qb-core' and QBCore and MySQL then
        local result = MySQL.Sync.fetchAll('SELECT citizenid FROM player_vehicles WHERE plate = @plate', {
            ['@plate'] = vehicle_plate
        })
        
        if result and #result > 0 then
            local Player = QBCore.Functions.GetPlayer(source)
            if Player and Player.PlayerData.citizenid == result[1].citizenid then
                return true, result[1].citizenid
            end
        end
    elseif bridge.framework == 'es_extended' and ESX and MySQL then
        local result = MySQL.Sync.fetchAll('SELECT owner FROM owned_vehicles WHERE plate = @plate', {
            ['@plate'] = vehicle_plate
        })
        
        if result and #result > 0 then
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer and xPlayer.identifier == result[1].owner then
                return true, result[1].owner
            end
        end
    end
    
    return false, nil
end

function GetVehicleOwnerByPlate(vehicle_plate)
    if not vehicle_plate or vehicle_plate == '' then
        if Config.debug then
            print('[NPC Crime DEBUG SERVER] GetVehicleOwnerByPlate: Invalid plate')
        end
        return nil
    end
    
    local bridge = exports['oeva_bridge']:ret_bridge_table()
    if not bridge then
        if Config.debug then
            print('[NPC Crime DEBUG SERVER] GetVehicleOwnerByPlate: Bridge not found')
        end
        return nil
    end
    
    if Config.debug then
        print('[NPC Crime DEBUG SERVER] Framework: ' .. tostring(bridge.framework))
    end
    
    if bridge.framework == 'qb-core' and QBCore then
        if Config.debug then
            print('[NPC Crime DEBUG SERVER] Querying QBCore database for plate: ' .. vehicle_plate)
        end
        
        if not MySQL then
            if Config.debug then
                print('[NPC Crime DEBUG SERVER] MySQL not available')
            end
            return nil
        end
        
        local result = MySQL.Sync.fetchAll('SELECT citizenid FROM player_vehicles WHERE plate = @plate', {
            ['@plate'] = vehicle_plate
        })
        
        if Config.debug then
            print('[NPC Crime DEBUG SERVER] Query result count: ' .. tostring(result and #result or 0))
        end
        
        if result and #result > 0 then
            if Config.debug then
                print('[NPC Crime DEBUG SERVER] Found owner: ' .. tostring(result[1].citizenid))
            end
            return result[1].citizenid
        end
    elseif bridge.framework == 'es_extended' and ESX then
        if Config.debug then
            print('[NPC Crime DEBUG SERVER] Querying ESX database for plate: ' .. vehicle_plate)
        end
        
        if not MySQL then
            if Config.debug then
                print('[NPC Crime DEBUG SERVER] MySQL not available')
            end
            return nil
        end
        
        local result = MySQL.Sync.fetchAll('SELECT owner FROM owned_vehicles WHERE plate = @plate', {
            ['@plate'] = vehicle_plate
        })
        
        if Config.debug then
            print('[NPC Crime DEBUG SERVER] Query result count: ' .. tostring(result and #result or 0))
        end
        
        if result and #result > 0 then
            if Config.debug then
                print('[NPC Crime DEBUG SERVER] Found owner: ' .. tostring(result[1].owner))
            end
            return result[1].owner
        end
    end
    
    if Config.debug then
        print('[NPC Crime DEBUG SERVER] No owner found for plate: ' .. vehicle_plate)
    end
    
    return nil
end

function GetPlayerSourceByIdentifier(identifier)
    if not identifier then
        return nil
    end
    
    local bridge = exports['oeva_bridge']:ret_bridge_table()
    if not bridge then
        return nil
    end
    
    if bridge.framework == 'qb-core' and QBCore then
        for _, player_id in ipairs(GetPlayers()) do
            local source = tonumber(player_id)
            if source then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player and Player.PlayerData.citizenid == identifier then
                    return source
                end
            end
        end
    elseif bridge.framework == 'es_extended' and ESX then
        local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
        if xPlayer then
            return xPlayer.source
        end
    end
    
    return nil
end

RegisterNetEvent('s6la_npc_crime:forceNetworkControl', function(netId, targetSrc)
    local src = source
    
    local entity = NetworkGetEntityFromNetworkId(netId)
    
    if not entity or entity == 0 then return end
    
    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
    end
    
    SetEntityAsMissionEntity(entity, true, true)
    
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)
    
    if targetSrc then
        SetNetworkIdOwner(netId, targetSrc)
    end
end)

RegisterNetEvent('s6la_npc_crime:getVehicleOwner', function(request_id, plate)
    local src = source
    
    if Config.debug then
        print('[NPC Crime DEBUG SERVER] Player ' .. src .. ' requested owner for plate: ' .. tostring(plate))
    end
    
    local owner = GetVehicleOwnerByPlate(plate)
    
    if Config.debug then
        print('[NPC Crime DEBUG SERVER] Owner result: ' .. tostring(owner))
    end
    
    TriggerClientEvent('s6la_npc_crime:vehicleOwnerResult', src, request_id, plate, owner)
end)

RegisterNetEvent('s6la_npc_crime:getPlayerSource', function(request_id, identifier)
    local src = source
    local player_source = GetPlayerSourceByIdentifier(identifier)
    TriggerClientEvent('s6la_npc_crime:playerSourceResult', src, request_id, identifier, player_source)
end)

RegisterNetEvent('s6la_npc_crime:notifyOwner', function(owner_identifier, plate, netId)
    local owner_source = GetPlayerSourceByIdentifier(owner_identifier)
    if owner_source and owner_source > 0 then
        local now = os.time()
        local last_time = recent_notifications[plate] or 0
        if now - last_time < 60 then
            return
        end
        recent_notifications[plate] = now
        local bridge = exports['oeva_bridge']:ret_bridge_table()
        if bridge and bridge.framework then
            exports['oeva_bridge']:notify(owner_source, 'Your vehicle (' .. plate .. ') is being stolen!', 'error', 8000)
        end
        if netId then
            TriggerClientEvent('s6la_npc_crime:setTheftBlip', owner_source, netId, plate)
        end
    end
end)

RegisterNetEvent('s6la_npc_crime:notifyStripped', function(owner_identifier, plate, x, y)
    local owner_source = GetPlayerSourceByIdentifier(owner_identifier)
    if owner_source and owner_source > 0 then
        local bridge = exports['oeva_bridge']:ret_bridge_table()
        if bridge and bridge.framework then
            exports['oeva_bridge']:notify(owner_source, 'Your vehicle (' .. plate .. ') has been stripped for parts and is broken. The remains are marked on your GPS.', 'error', 10000)
        end
        if x and y then
            TriggerClientEvent('s6la_npc_crime:setStrippedWaypoint', owner_source, x, y)
        end
    end
end)

exports('IsVehicleOwnedByPlayer', IsVehicleOwnedByPlayer)
exports('GetVehicleOwnerByPlate', GetVehicleOwnerByPlate) -- just incase you want it for another script and are already using this script?
exports('GetPlayerSourceByIdentifier', GetPlayerSourceByIdentifier)
