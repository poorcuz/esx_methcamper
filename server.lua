local camperBuckets = {}
local lockedCampers = {}
local camperStates = {} -- Track which players are in which campers
local camperBeakers = {} -- Track which campers have beakers placed
local placingBeakers = {} -- Track which campers have players in the process of placing a beaker
local cookingStates = {} -- Track which campers are currently cooking
local cookingTimers = {} -- Track cooking timers for each camper
local camperVehicles = {} -- Track vehicle network IDs for each camper

-- Utility Functions
function GetCamperBucket(plate)
    if not plate then return nil end
    if camperBuckets[plate] then return camperBuckets[plate] end

    local bucket = Config.Buckets.Min
    while bucket <= Config.Buckets.Max do
        if not IsBucketOccupied(bucket) then
            camperBuckets[plate] = bucket
            return bucket
        end
        bucket = bucket + 1
    end

    print("^1[ERROR]^7 No available routing buckets for camper with plate: " .. plate)
    return nil
end

function IsBucketOccupied(bucket)
    if not bucket then return false end
    for _, usedBucket in pairs(camperBuckets) do
        if usedBucket == bucket then return true end
    end
    return false
end

function FreeCamperBucket(plate)
    if not plate then return false end
    for playerId, camperPlate in pairs(camperStates) do
        if camperPlate == plate then return false end
    end
    if camperBuckets[plate] then
        camperBuckets[plate] = nil
        return true
    end
    return false
end

function GetPlayersInCamper(plate)
    local players = {}
    for playerId, camperPlate in pairs(camperStates) do
        if camperPlate == plate then
            table.insert(players, playerId)
        end
    end
    return players
end

function ToggleCamperLock(plate, source)
    if not plate then return false end
    
    local _res = nil
    exports["bc_car-tools"]:hasVehicleKeyAccess(source, plate, function(hasAccess)
        if hasAccess then
            _res = true
            if not lockedCampers[plate] then
                lockedCampers[plate] = true
            else
                lockedCampers[plate] = nil
            end
        else
            _res = false
        end
    end)

    while _res == nil do
        Citizen.Wait(10)
    end
    return _res
end

function IsCamperLocked(plate)
    return lockedCampers[plate] or false
end

-- Inventory Functions
function HasRequiredItems(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then 
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.player_not_found, source))
        return false 
    end
    
    local items, weight = exports["inventory"]:getInventory(xPlayer, {
        type = "camper_cooking",
        id = plate,
        save = true
    })
        
    if not items then 
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.inventory_failed, plate))
        return false 
    end
    
    for _, requiredItem in ipairs(Config.MixRecipe) do
        local found = false
        for _, inventoryItem in ipairs(items) do
            if inventoryItem.name == requiredItem.name and inventoryItem.count >= Config.Mix.requiredEach then
                found = true
                break
            end
        end
        if not found then
            print("^1[ERROR]^7 " .. string.format(Config.Lang.error.missing_item, requiredItem.name))
            return false
        end
    end
    
    return true
end

function RemoveRequiredItems(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    for _, requiredItem in ipairs(Config.MixRecipe) do
        exports["inventory"]:removeItemFromInventory(xPlayer, {name = requiredItem.name, type = requiredItem.type}, 
            Config.Mix.requiredEach, {type = "camper_cooking", id = plate, save = true}, function() end, true)
    end
    
    return true
end

function GiveCookedMeth(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    exports["inventory"]:addItemToInventory(xPlayer, {
        type = "item_standard",
        name = Config.Mix.outputItem,
        label = "Methamphetamin",
        index = 1,
        use = false,
        remove = false,
    }, Config.Mix.outputAmount, {type = "camper_cooking", id = plate, save = true}, function() end, true)

    return true
end

-- Cooking Functions
function StopCookingProcess(plate, vehicleNetId)
    print("^2[DEBUG]^7 Stopping cooking process for camper " .. plate)
    
    cookingStates[plate] = nil
    if cookingTimers[plate] then
        ClearTimeout(cookingTimers[plate])
        cookingTimers[plate] = nil
    end
    
    local playersInCamper = GetPlayersInCamper(plate)
    for _, playerId in ipairs(playersInCamper) do
        TriggerClientEvent('bc_camper:syncCooking', playerId, plate, false)
        TriggerClientEvent('esx:showNotification', playerId, Config.Lang.success.cooking_stopped)
    end
    
    if vehicleNetId then
        TriggerClientEvent('bc_camper:syncCookingVehicle', -1, vehicleNetId, false)
        camperVehicles[plate] = nil
    end
end

function StartCookingBatch(source, plate, vehicleNetId)
    if not source or not plate then return end
    
    if camperStates[source] ~= plate then 
        StopCookingProcess(plate, vehicleNetId)
        return 
    end
    
    if not HasRequiredItems(source, plate) then 
        StopCookingProcess(plate, vehicleNetId)
        return 
    end
    
    cookingStates[plate] = true
    local playersInCamper = GetPlayersInCamper(plate)
    
    for _, playerId in ipairs(playersInCamper) do
        TriggerClientEvent('bc_camper:syncCooking', playerId, plate, true, vehicleNetId)
    end
    
    cookingTimers[plate] = SetTimeout(Config.Mix.processTime, function()
        if not cookingStates[plate] then return end
        
        if camperStates[source] ~= plate then
            StopCookingProcess(plate, vehicleNetId)
            return
        end
        
        if not HasRequiredItems(source, plate) then
            StopCookingProcess(plate, vehicleNetId)
            return
        end
        
        GiveCookedMeth(source, plate)
        RemoveRequiredItems(source, plate)
        
        if cookingStates[plate] then
            StartCookingBatch(source, plate, vehicleNetId)
        end
    end)
end

-- Event Handlers
RegisterNetEvent('bc_camper:placeBeaker')
AddEventHandler('bc_camper:placeBeaker', function(plate)
    local source = source
    if not plate then return end
    
    if camperStates[source] ~= plate or placingBeakers[plate] ~= source then
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.wrong_camper, source))
        return
    end
    
    placingBeakers[plate] = nil
    camperBeakers[plate] = true
    
    local playersInCamper = GetPlayersInCamper(plate)
    for _, playerId in ipairs(playersInCamper) do
        TriggerClientEvent('bc_camper:syncBeaker', playerId, plate, true)
    end
end)

RegisterNetEvent('bc_camper:pickupBeaker')
AddEventHandler('bc_camper:pickupBeaker', function(plate)
    local source = source
    if not plate then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if camperStates[source] ~= plate then
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.wrong_camper, source))
        return
    end

    xPlayer.addInventoryItem(Config.StationItem, 1)
    
    camperBeakers[plate] = nil
    
    local playersInCamper = GetPlayersInCamper(plate)
    for _, playerId in ipairs(playersInCamper) do
        TriggerClientEvent('bc_camper:syncBeaker', playerId, plate, false)
    end
end)

RegisterNetEvent('bc_camper:stopCooking')
AddEventHandler('bc_camper:stopCooking', function(plate)
    local source = source
    if not plate then return end
    
    if camperStates[source] ~= plate then
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.wrong_camper, source))
        return
    end
    
    if cookingStates[plate] then
        StopCookingProcess(plate, camperVehicles[plate])
    end
end)

RegisterNetEvent('bc_camper:startCooking')
AddEventHandler('bc_camper:startCooking', function(plate, vehicleNetId)
    local source = source
    if not plate then return end
    
    if camperStates[source] ~= plate then
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.wrong_camper, source))
        return
    end
    
    if not camperBeakers[plate] then
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.no_beaker, plate))
        return
    end
    
    if cookingStates[plate] then
        TriggerClientEvent('esx:showNotification', source, Config.Lang.error.already_cooking)
        return
    end
    
    camperVehicles[plate] = vehicleNetId
    StartCookingBatch(source, plate, vehicleNetId)
    TriggerClientEvent('bc_camper:syncCookingVehicle', -1, vehicleNetId, true)
end)

-- ESX Callbacks
ESX.RegisterServerCallback('bc_camper:enterCamper', function(source, cb, plate)
    if not source or not plate then 
        cb(false)
        return 
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.player_not_found, source))
        cb(false)
        return
    end

    if camperStates[source] then
        xPlayer.showError(Config.Lang.error.already_in_camper)
        cb(false)
        return
    end

    local bucket = GetCamperBucket(plate)
    if not bucket then
        xPlayer.showError(Config.Lang.error.no_buckets)
        cb(false)
        return
    end

    camperStates[source] = plate
    SetPlayerRoutingBucket(source, bucket)
    
    cb(true, camperBeakers[plate] or false, cookingStates[plate] or false)
end)

ESX.RegisterServerCallback('bc_camper:leaveCamper', function(source, cb, plate)
    if not source or not plate then 
        cb(false)
        return 
    end

    if camperStates[source] ~= plate then
        print("^1[ERROR]^7 Player " .. source .. " tried to leave wrong camper")
        cb(false)
        return
    end

    camperStates[source] = nil
    SetPlayerRoutingBucket(source, 0)

    local playersInCamper = GetPlayersInCamper(plate)
    if #playersInCamper == 0 then
        FreeCamperBucket(plate)
        if cookingStates[plate] then
            if cookingTimers[plate] then
                ClearTimeout(cookingTimers[plate])
                cookingTimers[plate] = nil
            end
            cookingStates[plate] = nil
            TriggerClientEvent('bc_camper:syncCooking', source, plate, false)
            if camperVehicles[plate] then
                TriggerClientEvent('bc_camper:syncCookingVehicle', -1, camperVehicles[plate], false)
                camperVehicles[plate] = nil
            end
        end
    end
    
    cb(true)
end)

ESX.RegisterServerCallback('bc_camper:toggleLock', function(source, cb, plate)
    if not source or not plate then 
        cb(false)
        return 
    end
    cb(ToggleCamperLock(plate, source))
end)

ESX.RegisterServerCallback('bc_camper:checkLock', function(source, cb, plate)
    if not source or not plate then 
        cb(false)
        return 
    end
    cb(IsCamperLocked(plate))
end)

ESX.RegisterServerCallback('bc_camper:canPlaceBeaker', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.player_not_found, source))
        cb(false)
        return
    end

    if not source or not plate then 
        cb(false)
        return 
    end
    
    if camperStates[source] ~= plate then
        print("^1[ERROR]^7 " .. string.format(Config.Lang.error.wrong_camper, source))
        cb(false)
        return
    end
    
    if camperBeakers[plate] or placingBeakers[plate] then
        xPlayer.showError(Config.Lang.error.beaker_already_placed)
        cb(false)
        return
    end

    local requiredItem = xPlayer.getInventoryItem(Config.StationItem)
    if not requiredItem or requiredItem.count < 1 then
        xPlayer.showError(Config.Lang.error.no_station)
        cb(false)
        return
    end

    xPlayer.removeInventoryItem(Config.StationItem, 1)
    
    placingBeakers[plate] = source
    cb(true)
end)

ESX.RegisterUsableItem(Config.Mix.outputItem, function(source, item)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    xPlayer.removeInventoryItem(item.name, 1)
    TriggerClientEvent('bc_camper:usedMeth', source)
end)

-- Resource Management
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    for playerId, _ in pairs(camperStates) do
        SetPlayerRoutingBucket(playerId, 0)
    end
    
    camperBuckets = {}
    lockedCampers = {}
    camperStates = {}
    camperVehicles = {}
end)

AddEventHandler('playerDropped', function()
    local source = source
    if camperStates[source] then
        local plate = camperStates[source]
        camperStates[source] = nil
        SetPlayerRoutingBucket(source, 0)
        
        if placingBeakers[plate] == source then
            placingBeakers[plate] = nil
        end
        
        local playersInCamper = GetPlayersInCamper(plate)
        if #playersInCamper == 0 then
            FreeCamperBucket(plate)
            camperBeakers[plate] = nil
            if cookingStates[plate] and cookingTimers[plate] then
                ClearTimeout(cookingTimers[plate])
                cookingStates[plate] = nil
                cookingTimers[plate] = nil
            end
        end
    end
end) 