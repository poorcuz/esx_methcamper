local stateTable = {
    previousPos = nil,
    isInCamper = false,
    currentCamperPlate = nil,
    isLocked = false,
    lastLockToggle = 0,
    hasPlacedBeaker = false,
    smokeEffect = nil,
    shouldKeepSmoke = false,
    isCooking = false,
    blockInteraction = false,
    externalSmokeEffects = {},
    runningSmokeEffects = {}
}

local cookingVehicles = {}

-- Event Handlers
RegisterNetEvent('bc_camper:lockState')
AddEventHandler('bc_camper:lockState', function(plate, isLocked)
    if stateTable.currentCamperPlate == plate then
        stateTable.isLocked = isLocked
    end
end)

RegisterNetEvent('bc_camper:syncBeaker')
AddEventHandler('bc_camper:syncBeaker', function(plate, hasBeaker)
    if stateTable.isInCamper and stateTable.currentCamperPlate == plate then
        if hasBeaker then
            SpawnBeaker()
        else
            RemoveBeaker()
        end
    end
end)

RegisterNetEvent('bc_camper:syncCooking')
AddEventHandler('bc_camper:syncCooking', function(plate, isCooking, vehicleNetId)
    if stateTable.isInCamper and stateTable.currentCamperPlate == plate then
        stateTable.isCooking = isCooking
        if isCooking then
            StartSmokeEffect()
        else
            StopSmokeEffect()
        end
    end
    
    if vehicleNetId then
        if isCooking then
            StartExternalSmokeEffect(vehicleNetId)
        else
            StopExternalSmokeEffect(vehicleNetId)
        end
    end
end)

RegisterNetEvent('bc_camper:syncCookingVehicle')
AddEventHandler('bc_camper:syncCookingVehicle', function(vehicleNetId, isCooking)
    if isCooking then
        if not cookingVehicles[vehicleNetId] then
            cookingVehicles[vehicleNetId] = true
            StartExternalSmokeEffect(vehicleNetId)
        end
    else
        if cookingVehicles[vehicleNetId] then
            cookingVehicles[vehicleNetId] = nil
            StopExternalSmokeEffect(vehicleNetId)
        end
    end
end)

-- Key Mapping
RegisterKeyMapping('toggleCamperLock', Config.Lang.keys.toggle_lock, 'keyboard', Config.Keys.toggleLock.key)
RegisterCommand('toggleCamperLock', function()
    local currentTime = GetGameTimer()
    if currentTime - stateTable.lastLockToggle < 1000 then return end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    if stateTable.isInCamper then
        if stateTable.currentCamperPlate then
            stateTable.lastLockToggle = currentTime
            ESX.TriggerServerCallback('bc_camper:toggleLock', function(success)
                if success then
                    stateTable.isLocked = not stateTable.isLocked
                    ESX.ShowNotification(stateTable.isLocked and Config.Lang.success.camper_locked or Config.Lang.success.camper_unlocked)
                end
            end, stateTable.currentCamperPlate)
        end
    else
        local vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0, 0, 71)
        if vehicle ~= 0 then
            local vehicleModel = GetEntityModel(vehicle)
            if vehicleModel == GetHashKey("journey") then
                local plate = GetVehicleNumberPlateText(vehicle)
                local doorCoords = GetWorldPositionOfEntityBone(vehicle, 35)
                local distance = Vdist(doorCoords, playerCoords)
                if distance < 1.5 then
                    ESX.TriggerServerCallback('bc_camper:toggleLock', function(success)
                        if success then
                            stateTable.isLocked = not stateTable.isLocked
                            ESX.ShowNotification(stateTable.isLocked and Config.Lang.success.camper_locked or Config.Lang.success.camper_unlocked)
                        end
                    end, plate)
                end
            end
        end
    end
end)

-- Menu Functions
function OpenCookingMenu()
    local elements = {}
    
    if not stateTable.isCooking then
        table.insert(elements, {
            label = "Inhalt verwalten",
            value = "ingredients"
        })
        table.insert(elements, {
            label = 'Kochen starten',
            value = 'startCooking'
        })
    else
        table.insert(elements, {
            label = 'Kochen abbrechen',
            value = 'stopCooking'
        })
    end
    
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'cooking_menu', {
        title = 'Kochmenü',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'startCooking' then
            menu.close()
            local vehicleNetId = stateTable.currentCamperVehicleNetId
            if vehicleNetId then
                TriggerServerEvent('bc_camper:startCooking', stateTable.currentCamperPlate, vehicleNetId)
            end
        elseif data.current.value == 'stopCooking' then
            menu.close()
            TriggerServerEvent('bc_camper:stopCooking', stateTable.currentCamperPlate)
        elseif data.current.value == 'ingredients' then
            menu.close()
            print(stateTable.currentCamperPlate)
            TriggerEvent("inventory:open", {
                type = "camper_cooking",
                id = stateTable.currentCamperPlate,
                title = Config.Lang.menu.cooking_station,
                delay = 1000,
                weight = 200,
                save = true,
                preset = Config.MixRecipe,
                allowedItems = Config.MixRecipe
            })
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- Effect Functions
function StartSmokeEffect()
    if stateTable.smokeEffect then return end
    
    local coords = vector3(Config.BeakerCoords.x, Config.BeakerCoords.y, Config.BeakerCoords.z)
    local particleDict = "core"
    local particleName = "exp_grd_flare"
    
    RequestNamedPtfxAsset(particleDict)
    while not HasNamedPtfxAssetLoaded(particleDict) do
        Citizen.Wait(0)
    end
    
    UseParticleFxAssetNextCall(particleDict)
    stateTable.smokeEffect = StartParticleFxLoopedAtCoord(particleName, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
    SetParticleFxLoopedAlpha(stateTable.smokeEffect, 0.5)
end

function StopSmokeEffect()
    if stateTable.smokeEffect then
        StopParticleFxLooped(stateTable.smokeEffect, false)
        stateTable.smokeEffect = nil
    end
end

function StartExternalSmokeEffect(vehicleNetId)
    if stateTable.externalSmokeEffects[vehicleNetId] then return end
    
    Citizen.CreateThread(function()
        local lastCoords = vector3(0, 0, 0)
        stateTable.runningSmokeEffects[vehicleNetId] = true
        
        while stateTable.runningSmokeEffects[vehicleNetId] do
            local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
            if vehicle and DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(vehicle)
                
                if #(coords - lastCoords) > 0.1 then
                    lastCoords = coords
                    
                    if stateTable.externalSmokeEffects[vehicleNetId] then
                        StopParticleFxLooped(stateTable.externalSmokeEffects[vehicleNetId], false)
                    end
                    
                    local particleDict = "core"
                    local particleName = "ent_amb_smoke_scrap"
                    
                    RequestNamedPtfxAsset(particleDict)
                    while not HasNamedPtfxAssetLoaded(particleDict) do
                        Citizen.Wait(0)
                    end
                    
                    UseParticleFxAssetNextCall(particleDict)
                    stateTable.externalSmokeEffects[vehicleNetId] = StartParticleFxLoopedAtCoord(particleName, 
                        coords.x, coords.y, coords.z + 2.0,
                        0.0, 0.0, 0.0, 
                        1.0, false, false, false, false)
                    SetParticleFxLoopedAlpha(stateTable.externalSmokeEffects[vehicleNetId], 0.5)
                end
            else
                stateTable.runningSmokeEffects[vehicleNetId] = false
                break
            end
            Citizen.Wait(100)
        end
    end)
end

function StopExternalSmokeEffect(vehicleNetId)
    if stateTable.externalSmokeEffects[vehicleNetId] then
        StopParticleFxLooped(stateTable.externalSmokeEffects[vehicleNetId], false)
        stateTable.externalSmokeEffects[vehicleNetId] = nil
    end
    if stateTable.runningSmokeEffects[vehicleNetId] then
        stateTable.runningSmokeEffects[vehicleNetId] = false
    end
end

function CheckForCookingVehicles()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicles = GetGamePool('CVehicle')
    
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehicleModel = GetEntityModel(vehicle)
            if vehicleModel == GetHashKey("journey") then
                local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
                if cookingVehicles[vehicleNetId] and not stateTable.externalSmokeEffects[vehicleNetId] then
                    StartExternalSmokeEffect(vehicleNetId)
                end
            end
        end
    end
end

-- Main Thread
Citizen.CreateThread(function()
    local lastLockCheck = 0
    local lastLockState = false
    local lastVehicleCheck = 0
    
    while true do
        local sleepTimer = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local currentTime = GetGameTimer()
        
        if currentTime - lastVehicleCheck > 5000 then
            lastVehicleCheck = currentTime
            CheckForCookingVehicles()
        end
        
        if stateTable.isInCamper then
            local exitDistance = Vdist(playerCoords, Config.InteriorCoords)
            if exitDistance < 1.5 and not stateTable.blockInteraction then
                sleepTimer = 0
                Config.functions.SendHelpNotification(Config.Lang.help.leave_camper)
                if IsControlJustPressed(0, 38) then
                    LeaveCamper()
                end
            end

            local distanceToBeakerSpot = Vdist(playerCoords, Config.BeakerCoords)
            if distanceToBeakerSpot < 1.3 and not stateTable.blockInteraction then
                sleepTimer = 0
                Config.functions.SendHelpNotification(Config.Lang.help.cooking_menu)
                if IsControlJustPressed(0, 38) then
                    OpenBeakerMenu()
                    sleepTimer = 1000
                end
            end
        else
            local vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0, 0, 71)
            if vehicle ~= 0 then
                local vehicleModel = GetEntityModel(vehicle)
                if vehicleModel == GetHashKey("journey") then
                    local plate = GetVehicleNumberPlateText(vehicle)
                    local doorCoords = GetWorldPositionOfEntityBone(vehicle, 35)
                    local distance = Vdist(doorCoords, playerCoords)

                    if distance < 1.5 then
                        sleepTimer = 0
                        
                        if currentTime - lastLockCheck > 1000 then
                            lastLockCheck = currentTime
                            ESX.TriggerServerCallback('bc_camper:checkLock', function(isLocked)
                                lastLockState = isLocked
                                stateTable.isLocked = isLocked
                            end, plate)
                        end
                        
                        if not lastLockState then
                            Config.functions.SendHelpNotification(Config.Lang.help.enter_camper)
                            if IsControlJustPressed(0, 38) then
                                EnterCamper(vehicle, plate)
                                sleepTimer = 1000
                            end
                        end
                    end
                end
            end
        end
        
        Citizen.Wait(sleepTimer)
    end
end)

-- Camper Functions
function EnterCamper(vehicle, plate)
    if not stateTable.isInCamper and not stateTable.blockInteraction then
        local playerPed = PlayerPedId()
        stateTable.previousPos = GetEntityCoords(playerPed)
        stateTable.currentCamperPlate = plate
        stateTable.currentCamperVehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
        
        DoScreenFadeOut(500)
        Citizen.Wait(500)
        
        ESX.TriggerServerCallback('bc_camper:enterCamper', function(success, hasBeaker, isCooking)
            if success then
                stateTable.isInCamper = true
                TriggerServerEvent('esx:updateLastPosition', stateTable.previousPos.x, stateTable.previousPos.y, stateTable.previousPos.z)
                SetEntityCoords(playerPed, Config.InteriorCoords.x, Config.InteriorCoords.y, Config.InteriorCoords.z)
                SetEntityHeading(playerPed, Config.InteriorCoords.w)
                
                if hasBeaker then
                    SpawnBeaker()
                end
                
                stateTable.isCooking = isCooking
                if isCooking then
                    StartSmokeEffect()
                end
                                
                Citizen.Wait(500)
                DoScreenFadeIn(500)
            else
                Citizen.Wait(500)
                DoScreenFadeIn(500)
            end
        end, plate)
    end
end

function LeaveCamper()
    if stateTable.isInCamper then
        local playerPed = PlayerPedId()
        stateTable.blockInteraction = true
        
        DoScreenFadeOut(500)
        Citizen.Wait(500)
        
        ESX.TriggerServerCallback('bc_camper:leaveCamper', function(success)
            if success then
                stateTable.isInCamper = false
                stateTable.currentCamperPlate = nil
                stateTable.currentCamperVehicleNetId = nil
                stateTable.isCooking = false
                stateTable.hasPlacedBeaker = false
                
                if stateTable.smokeEffect then
                    StopSmokeEffect()
                end
                
                SetEntityCoords(playerPed, stateTable.previousPos.x, stateTable.previousPos.y, stateTable.previousPos.z)
                stateTable.previousPos = nil
                
                Citizen.Wait(500)
                DoScreenFadeIn(500)
            end
        end, stateTable.currentCamperPlate)
        
        stateTable.blockInteraction = false
    end
end

-- Resource Management
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    if stateTable.hasPlacedBeaker then
        RemoveBeaker()
    end
    
    for vehicleNetId, _ in pairs(stateTable.externalSmokeEffects) do
        StopExternalSmokeEffect(vehicleNetId)
    end
    
    stateTable.externalSmokeEffects = {}
    stateTable.runningSmokeEffects = {}
    cookingVehicles = {}
    
    local beakerModel = GetHashKey("xm3_prop_xm3_lsd_beaker")
    local beaker = GetClosestObjectOfType(Config.BeakerCoords.x, Config.BeakerCoords.y, Config.BeakerCoords.z, 100.0, beakerModel, false, false, false)
    while DoesEntityExist(beaker) do
        DeleteEntity(beaker)
        beaker = GetClosestObjectOfType(Config.BeakerCoords.x, Config.BeakerCoords.y, Config.BeakerCoords.z, 100.0, beakerModel, false, false, false)
    end
    
    if stateTable.smokeEffect then
        StopParticleFxLooped(stateTable.smokeEffect, false)
        stateTable.smokeEffect = nil
    end
    
    stateTable = {
        previousPos = nil,
        isInCamper = false,
        currentCamperPlate = nil,
        isLocked = false,
        lastLockToggle = 0,
        hasPlacedBeaker = false,
        smokeEffect = nil,
        shouldKeepSmoke = false,
        isCooking = false,
        blockInteraction = false,
        externalSmokeEffects = {},
        runningSmokeEffects = {}
    }
    
    ESX.UI.Menu.CloseAll()
    
    if stateTable.isInCamper and stateTable.previousPos then
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, stateTable.previousPos.x, stateTable.previousPos.y, stateTable.previousPos.z)
    end
    
    ClearPedTasks(PlayerPedId())
end)

function OpenBeakerMenu()
    local elements = {}
    
    if not stateTable.hasPlacedBeaker then
        table.insert(elements, {
            label = Config.Lang.menu.place_beaker,
            value = 'place'
        })
    else
        table.insert(elements, {
            label = Config.Lang.menu.open_cooking,
            value = 'openCookingMenu'
        })
        if not stateTable.isCooking then
            table.insert(elements, {
                label = Config.Lang.menu.pickup_beaker,
                value = 'pickup'
            })
        end
    end
    
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'beaker_menu', {
        title = Config.Lang.menu.beaker_title,
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'place' then
            menu.close()
            PlaceBeaker()
        elseif data.current.value == 'pickup' then
            menu.close()
            PickupBeaker()
        elseif data.current.value == 'openCookingMenu' then
            menu.close()
            OpenCookingMenu()
        end
    end, function(data, menu)
        menu.close()
    end)
end

function PlaceBeaker()
    local playerPed = PlayerPedId()
    
    ESX.TriggerServerCallback('bc_camper:canPlaceBeaker', function(canPlace)
        if not canPlace then
             --ESX.ShowNotification("Es ist bereits ein Becher platziert oder jemand platziert gerade einen.")
            return
        end
        
        local beakerCoords = vector3(Config.BeakerCoords.x, Config.BeakerCoords.y, Config.BeakerCoords.z)
        local playerCoords = GetEntityCoords(playerPed)
        local heading = GetHeadingFromVector_2d(beakerCoords.x - playerCoords.x, beakerCoords.y - playerCoords.y)
        SetEntityHeading(playerPed, heading)
        
        stateTable.blockInteraction = true
        RequestAnimDict("anim@heists@ornate_bank@grab_cash")
        while not HasAnimDictLoaded("anim@heists@ornate_bank@grab_cash") do
            Citizen.Wait(0)
        end
        
        TaskPlayAnim(playerPed, "anim@heists@ornate_bank@grab_cash", "grab", 8.0, -8.0, -1, 1, 0, false, false, false)
        
        Citizen.Wait(4000)
        
        ClearPedTasks(playerPed)
        
        TriggerServerEvent('bc_camper:placeBeaker', stateTable.currentCamperPlate)
        
        stateTable.hasPlacedBeaker = true
        stateTable.blockInteraction = false
        ESX.ShowNotification(Config.Lang.success.beaker_placed)
    end, stateTable.currentCamperPlate)
end

function PickupBeaker()
    local playerPed = PlayerPedId()
    
    RequestAnimDict("anim@heists@ornate_bank@grab_cash")
    while not HasAnimDictLoaded("anim@heists@ornate_bank@grab_cash") do
        Citizen.Wait(0)
    end

    local beakerCoords = vector3(Config.BeakerCoords.x, Config.BeakerCoords.y, Config.BeakerCoords.z)
    local playerCoords = GetEntityCoords(playerPed)
    local heading = GetHeadingFromVector_2d(beakerCoords.x - playerCoords.x, beakerCoords.y - playerCoords.y)
    SetEntityHeading(playerPed, heading)
    
    stateTable.blockInteraction = true
    TaskPlayAnim(playerPed, "anim@heists@ornate_bank@grab_cash", "grab", 8.0, -8.0, -1, 1, 0, false, false, false)
    
    Citizen.Wait(4000)
    
    ClearPedTasks(playerPed)
    
    TriggerServerEvent('bc_camper:pickupBeaker', stateTable.currentCamperPlate)
    
    stateTable.blockInteraction = false
    stateTable.hasPlacedBeaker = false
    ESX.ShowNotification(Config.Lang.success.beaker_picked_up)
end

RegisterNetEvent('bc_camper:usedMeth', function()
    local playerPed = GetPlayerPed(-1)
    local playerPed = PlayerPedId()
  
    RequestAnimSet("move_m@drunk@slightlydrunk") 
    while not HasAnimSetLoaded("move_m@drunk@slightlydrunk") do
      Citizen.Wait(0)
    end    
    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_SMOKING_POT", 0, 1)
    Citizen.Wait(3000)
    ClearPedTasksImmediately(playerPed)
    SetPedMotionBlur(playerPed, true)
    SetPedMovementClipset(playerPed, "move_m@drunk@slightlydrunk", true)
    SetPedIsDrunk(playerPed, true)
    SetTimecycleModifier("spectator5")
    AnimpostfxPlay("SuccessMichael", 10000001, true)
    ShakeGameplayCam("DRUNK_SHAKE", 1.5)
	
    SetEntityHealth(GetPlayerPed(-1), 200)
    Citizen.Wait(100000)
    SetPedMoveRateOverride(PlayerId(),1.0)
    SetRunSprintMultiplierForPlayer(PlayerId(),1.0)
    SetPedIsDrunk(GetPlayerPed(-1), false)		
    SetPedMotionBlur(playerPed, false)
    ResetPedMovementClipset(GetPlayerPed(-1))
    AnimpostfxStopAll()
    ShakeGameplayCam("DRUNK_SHAKE", 0.0)
    SetTimecycleModifierStrength(0.0)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    stateTable = {
        previousPos = nil,
        isInCamper = false,
        currentCamperPlate = nil,
        isLocked = false,
        lastLockToggle = 0,
        hasPlacedBeaker = false,
        smokeEffect = nil,
        shouldKeepSmoke = false,
        isCooking = false,
        blockInteraction = false,
        externalSmokeEffects = {},
        runningSmokeEffects = {}
    }
    
    ESX.UI.Menu.CloseAll()
    
    ClearPedTasks(PlayerPedId())
end)

function SpawnBeaker()
    local beakerModel = GetHashKey("xm3_prop_xm3_lsd_beaker")
    RequestModel(beakerModel)
    while not HasModelLoaded(beakerModel) do
        Citizen.Wait(0)
    end
    
    local beaker = CreateObject(beakerModel, Config.BeakerCoords.x, Config.BeakerCoords.y, Config.BeakerCoords.z, false, false, false)
    SetEntityHeading(beaker, -44.1)
    SetEntityAsMissionEntity(beaker, true, true)
    stateTable.hasPlacedBeaker = true
end

function RemoveBeaker()
    local beakerModel = GetHashKey("xm3_prop_xm3_lsd_beaker")
    local beaker = GetClosestObjectOfType(Config.BeakerCoords.x, Config.BeakerCoords.y, Config.BeakerCoords.z, 1.0, beakerModel, false, false, false)
    if DoesEntityExist(beaker) then
        DeleteEntity(beaker)
    end
    
    if stateTable.smokeEffect then
        StopParticleFxLooped(stateTable.smokeEffect, false)
        stateTable.smokeEffect = nil
    end
    
    stateTable.hasPlacedBeaker = false
end