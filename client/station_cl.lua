if Config.PlayerOwnedGasStationsEnabled then -- This is so Player Owned Gas Stations are a Config Option, instead of forced. Set this option in shared/config.lua!
    -- Variables
    local QBCore = exports[Config.Core]:GetCoreObject()
    local PedsSpawned = false

    -- These are for fuel pickup:
    local CreatedEventHandler = false
    local locationSwapHandler
    local spawnedTankerTrailer
    local spawnedDeliveryTruck
    local ReservePickupData = {}

    -- Functions
    local function RequestAndLoadModel(model)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(5)
        end
    end

    local function UpdateStationInfo(info)
        if Config.FuelDebug then lib.print.debug("Fetching Information for Location #" ..CurrentLocation) end
        QBCore.Functions.TriggerCallback('cdn-fuel:server:fetchinfo', function(result)
            if result then
                for _, v in pairs(result) do
                    -- Reserves --
                    if info == "all" or info == "reserves" then
                        if Config.FuelDebug then lib.print.debug("Fetched Reserve Levels: "..v.fuel.." Liters!") end
                        Currentreserveamount = v.fuel
                        ReserveLevels = Currentreserveamount
                        if Currentreserveamount < Config.MaxFuelReserves then
                            ReservesNotBuyable = false
                        else
                            ReservesNotBuyable = true
                        end
                        if Config.UnlimitedFuel then ReservesNotBuyable = true if Config.FuelDebug then lib.print.debug("Reserves are not buyable, because Config.UnlimitedFuel is set to true.") end end
                    end
                    -- Fuel Price --
                    if info == "all" or info == "fuelprice" then
                        StationFuelPrice = v.fuelprice
                    end
                    -- Fuel Station's Balance --
                    if info == "all" or info == "balance" then
                        StationBalance = v.balance
                        if Config.FuelDebug then lib.print.debug("Successfully Fetched: Balance") end
                    end
                    ----------------
                end
            end
        end, CurrentLocation)
    end exports(UpdateStationInfo, UpdateStationInfo)

    local function SpawnGasStationPeds()
        if not Config.GasStations or not next(Config.GasStations) or PedsSpawned then return end
        for i = 1, #Config.GasStations do
            local current = Config.GasStations[i]
            current.pedmodel = type(current.pedmodel) == 'string' and joaat(current.pedmodel) or current.pedmodel
            RequestAndLoadModel(current.pedmodel)
            local ped = CreatePed(0, current.pedmodel, current.pedcoords.x, current.pedcoords.y, current.pedcoords.z, current.pedcoords.h, false, false)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        type = "client",
                        label = Lang:t("station_talk_to_ped"),
                        icon = "fas fa-building",
                        action = function()
                            TriggerEvent('cdn-fuel:stations:openmenu', CurrentLocation)
                        end,
                    },
                },
                distance = 2.0
            })
        end
        PedsSpawned = true
    end

    local function GenerateRandomTruckModel()
        local possibleTrucks = Config.PossibleDeliveryTrucks
        if possibleTrucks then
            return possibleTrucks[math.random(#possibleTrucks)]
        end
    end

    local function SpawnPickupVehicles()
        local trailer = GetHashKey('tanker')
        local truckToSpawn = GetHashKey(GenerateRandomTruckModel())
        if truckToSpawn then
            RequestAndLoadModel(truckToSpawn)
            RequestAndLoadModel(trailer)
            spawnedDeliveryTruck = CreateVehicle(truckToSpawn, Config.DeliveryTruckSpawns['truck'], true, false)
            spawnedTankerTrailer = CreateVehicle(trailer, Config.DeliveryTruckSpawns['trailer'], true, false)
            SetModelAsNoLongerNeeded(truckToSpawn) -- removes model from game memory as we no longer need it
            SetModelAsNoLongerNeeded(trailer) -- removes model from game memory as we no longer need it
            SetEntityAsMissionEntity(spawnedDeliveryTruck, 1, 1)
            SetEntityAsMissionEntity(spawnedTankerTrailer, 1, 1)
            AttachVehicleToTrailer(spawnedDeliveryTruck, spawnedTankerTrailer, 15.0)
            -- Now our vehicle is spawned.
            if spawnedDeliveryTruck ~= 0 and spawnedTankerTrailer ~= 0 then
                TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(spawnedDeliveryTruck))
                return true
            else
                return false
            end
        end
    end

    -- Events
    RegisterNetEvent('cdn-fuel:stations:updatelocation', function(updatedlocation)
        if Config.FuelDebug then if CurrentLocation == nil then CurrentLocation = 0 end
            if updatedlocation == nil then updatedlocation = 0 end
            lib.print.debug('Location: '..CurrentLocation..' has been replaced with a new location: ' ..updatedlocation)
        end
        CurrentLocation = updatedlocation or 0
    end)

    RegisterNetEvent('cdn-fuel:stations:client:buyreserves', function(data)
        local location = data.location
        local price = data.price
        local amount = data.amount
        TriggerServerEvent('cdn-fuel:stations:server:buyreserves', location, price, amount)
        if Config.FuelDebug then lib.print.debug("^5Attempting Purchase of ^2"..amount.. "^5 Fuel Reserves for location #"..location.."! Purchase Price: ^2"..price) end
    end)

    RegisterNetEvent('cdn-fuel:station:client:initiatefuelpickup', function(amountBought, finalReserveAmountAfterPurchase, location)
        if amountBought and finalReserveAmountAfterPurchase and location then
            ReservePickupData = nil
            ReservePickupData = {
                finalAmount = finalReserveAmountAfterPurchase,
                amountBought = amountBought,
                location = location,
            }

            if SpawnPickupVehicles() then
                exports.qbx_core:Notify(Lang:t("fuel_order_ready"), 'success')
                SetNewWaypoint(Config.DeliveryTruckSpawns['truck'].x, Config.DeliveryTruckSpawns['truck'].y)
                SetUseWaypointAsDestination(true)
                ReservePickupData.blip = CreateBlip(vector3(Config.DeliveryTruckSpawns['truck'].x, Config.DeliveryTruckSpawns['truck'].y, Config.DeliveryTruckSpawns['truck'].z), "Truck Pickup")
                SetBlipColour(ReservePickupData.blip, 5)

                -- Create Zone
                ReservePickupData.PolyZone = PolyZone:Create(Config.DeliveryTruckSpawns.PolyZone.coords, {
                    name = "cdn_fuel_zone_delivery_truck_pickup",
                    minZ = Config.DeliveryTruckSpawns.PolyZone.minz,
                    maxZ = Config.DeliveryTruckSpawns.PolyZone.maxz,
                    debugPoly = Config.PolyDebug
                })

                -- Setup onPlayerInOut Events for zone that is created.
                ReservePickupData.PolyZone:onPlayerInOut(function(isPointInside)
                    if isPointInside then
                        if Config.FuelDebug then
                            lib.print.debug("Player has arrived at the pickup location!")
                        end
                        RemoveBlip(ReservePickupData.blip)
                        ReservePickupData.blip = nil
                        CreateThread(function()
                            local ped = PlayerPedId()
                            local alreadyHasTruck = false
                            local hasArrivedAtLocation = false
                            local VehicleDelivered = false
                            local EndAwaitListener = false
                            local stopNotifyTemp = false
                            local AwaitingInput = false
                            while true do
                                Wait(100)
                                if VehicleDelivered then break end
                                if IsPedInAnyVehicle(ped, false) then
                                    if GetVehiclePedIsIn(ped, false) == spawnedDeliveryTruck then
                                        if Config.FuelDebug then
                                            lib.print.debug("Player is inside of the delivery truck!")
                                        end

                                        if not alreadyHasTruck then
                                            local loc = {}
                                            loc.x, loc.y = Config.GasStations[ReservePickupData.location].pedcoords.x, Config.GasStations[ReservePickupData.location].pedcoords.y
                                            SetNewWaypoint(loc.x, loc.y)
                                            SetUseWaypointAsDestination(true)
                                            alreadyHasTruck = true
                                        else
                                            if not CreatedEventHandler then
                                                local function AwaitInput()
                                                    if AwaitingInput then return end
                                                    AwaitingInput = true
                                                    if Config.FuelDebug then lib.print.debug("Executing function `AwaitInput()`") end
                                                    CreateThread(function()
                                                        while true do
                                                            Wait(0)
                                                            if EndAwaitListener or not hasArrivedAtLocation then
                                                                AwaitingInput = false
                                                                break
                                                            end
                                                            if IsControlJustReleased(2, 38) then
                                                                local distBetweenTruckAndTrailer = #(GetEntityCoords(spawnedDeliveryTruck) - GetEntityCoords(spawnedTankerTrailer))
                                                                if distBetweenTruckAndTrailer > 10.0 then
                                                                    distBetweenTruckAndTrailer = nil
                                                                    if not stopNotifyTemp then
                                                                        exports.qbx_core:Notify(Lang:t("trailer_too_far"), 'error', 7500)
                                                                    end
                                                                    stopNotifyTemp = true
                                                                    Wait(1000)
                                                                    stopNotifyTemp = false
                                                                else
                                                                    EndAwaitListener = true
                                                                    local ped = PlayerPedId()
                                                                    VehicleDelivered = true
                                                                    -- Handle Vehicle Dropoff
                                                                    -- Remove PolyZone --
                                                                    ReservePickupData.PolyZone:destroy()
                                                                    ReservePickupData.PolyZone = nil                                                       
                                                                    -- Get Ped Out of Vehicle if Inside --
                                                                    if IsPedInAnyVehicle(ped, true) and GetVehiclePedIsIn(ped, false) == spawnedDeliveryTruck then
                                                                        TaskLeaveVehicle(
                                                                            ped --[[ Ped ]], 
                                                                            spawnedDeliveryTruck --[[ Vehicle ]], 
                                                                            1 --[[ flags | integer ]]
                                                                        )
                                                                        Wait(5000)
                                                                    end

                                                                    lib.hideTextUI()

                                                                    -- Remove Vehicle --                                            
                                                                    DeleteEntity(spawnedDeliveryTruck)
                                                                    DeleteEntity(spawnedTankerTrailer)
                                                                    -- Send Data to Server to Put Into Station --
                                                                    TriggerServerEvent('cdn-fuel:station:server:fuelpickup:finished', ReservePickupData.location)
                                                                    -- Remove Handler
                                                                    RemoveEventHandler(locationSwapHandler)
                                                                    AwaitingInput = false
                                                                    CreatedEventHandler = false
                                                                    ReservePickupData = nil
                                                                    ReservePickupData = {}
                                                                    -- Break Loop
                                                                    break
                                                                end
                                                            end
                                                        end
                                                    end)
                                                    AwaitingInput = true
                                                end
                                                locationSwapHandler = AddEventHandler('cdn-fuel:stations:updatelocation', function(location)
                                                    if location == nil or location ~= ReservePickupData.location then
                                                        hasArrivedAtLocation = false

                                                        lib.hideTextUI()

                                                        -- Break Listener
                                                        EndAwaitListener = true
                                                        Wait(50)
                                                        EndAwaitListener = false
                                                    else
                                                        hasArrivedAtLocation = true

                                                        lib.showTextUI(Lang:t("draw_text_fuel_dropoff"), {
                                                            position = 'left-center'
                                                        })

                                                        -- Add Listner for Keypress
                                                        AwaitInput()
                                                    end
                                                end)
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    else

                    end
                end)
            else
                -- This is just a worst case scenario event, if the vehicles somehow do not spawn.
                TriggerServerEvent('cdn-fuel:station:server:fuelpickup:failed', location)
            end
        else
            if Config.FuelDebug then
                lib.print.debug("An error has occurred. The amountBought / finalReserveAmountAfterPurchase / location is nil: `cdn-fuel:station:client:initiatefuelpickup`")
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:purchaselocation', function(data)
        local location = data.location
        local CitizenID = QBX.PlayerData.citizenid
        CanOpen = false
        Wait(5)
        QBCore.Functions.TriggerCallback('cdn-fuel:server:locationpurchased', function(result)
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned!") end
                IsOwned = true
            else
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned.") end
                IsOwned = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)

        if not IsOwned then
            TriggerServerEvent('cdn-fuel:server:buyStation', location, CitizenID)
        elseif IsOwned then
            exports.qbx_core:Notify(Lang:t("station_already_owned"), 'error', 7500)
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:sellstation', function(data)
        local location = data.location
        local SalePrice = data.SalePrice
        local CitizenID = QBX.PlayerData.citizenid
        CanSell = false
        Wait(5)
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..location.." is owned by ID: "..CitizenID) end
                CanSell = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..location.." is not owned by ID: "..CitizenID) end
                CanSell = false
            end
        end, location)
        Wait(Config.WaitTime)
        if CanSell then
            if Config.FuelDebug then lib.print.debug("Attempting to sell for: $"..SalePrice) end
            TriggerServerEvent('cdn-fuel:stations:server:sellstation', location)
            if Config.FuelDebug then lib.print.debug("Event Triggered") end
        else
            exports.qbx_core:Notify(Lang:t("station_cannot_sell"), 'error', 7500)
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:purchasereserves:final', function(location, price, amount) -- Menu, seens after selecting the "purchase reserves" option.
        local location = location
        local price = price
        local amount = amount
        CanOpen = false
        Wait(5)
        if Config.FuelDebug then lib.print.debug("checking ownership of "..location) end
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..location.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..location.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, location)
        Wait(Config.WaitTime)
        if CanOpen then
            if Config.FuelDebug then lib.print.debug("Price: "..price.."<br> Amount: "..amount.." <br> Location: "..location) end

                lib.registerContext({
                    id = 'purchasereservesmenu',
                    title = Lang:t("menu_station_reserves_header")..Config.GasStations[location].label,
                    options = {
                        {
                            title = Lang:t("menu_station_reserves_purchase_header")..price,
                            description = Lang:t("menu_station_reserves_purchase_footer")..price.."!",
                            icon = "fas fa-usd",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:buyreserves',
                            args = {
                                location = location,
                                price = price,
                                amount = amount,
                            }
                        },
                        {
                            title = Lang:t("menu_header_close"),
                            description = Lang:t("menu_ped_close_footer"),
                            icon = "fas fa-times-circle",
                            arrow = false, -- puts arrow to the right
                            onSelect = function()
                                lib.hideContext()
                            end,
                        },
                    },
                })
                lib.showContext('purchasereservesmenu')
            
        else
            if Config.FuelDebug then lib.print.debug("Not showing menu, as the player doesn't have proper permissions.") end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:purchasereserves', function(data)
        local CanOpen = false
        local location = data.location
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, location)
        Wait(Config.WaitTime)
        if CanOpen then
            local bankmoney = QBX.PlayerData.money['bank']
            if Config.FuelDebug then lib.print.debug("Showing Input for Reserves!") end

            local reserves = lib.inputDialog('Purchase Reserves', {
                { type = "input", label = 'Current Price',
                default = '$'.. Config.FuelReservesPrice .. ' Per Liter',
                disabled = true },
                { type = "input", label = 'Current Reserves',
                default = Currentreserveamount,
                disabled = true },
                { type = "input", label = 'Required Reserves',
                default = Config.MaxFuelReserves - Currentreserveamount,
                disabled = true },
                { type = "slider", label = 'Full Reserve Cost: $' ..math.ceil(GlobalTax((Config.MaxFuelReserves - Currentreserveamount) * Config.FuelReservesPrice) + ((Config.MaxFuelReserves - Currentreserveamount) * Config.FuelReservesPrice)).. '',
                default = Config.MaxFuelReserves - Currentreserveamount,
                min = 0,
                max = Config.MaxFuelReserves - Currentreserveamount
                },
            })
            if not reserves then return end
            reservesAmount = tonumber(reserves[4])
            if reserves then
                if Config.FuelDebug then lib.print.debug("Attempting to buy reserves!") end
                Wait(100)
                local amount = reservesAmount
                if not reservesAmount then exports.qbx_core:Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                Reservebuyamount = tonumber(reservesAmount)
                if Reservebuyamount < 1 then exports.qbx_core:Notify(Lang:t("station_more_than_one"), 'error', 7500) return end
                if (Reservebuyamount + Currentreserveamount) > Config.MaxFuelReserves then
                    exports.qbx_core:Notify(Lang:t("station_reserve_cannot_fit"), "error")
                else
                    if math.ceil(GlobalTax(Reservebuyamount * Config.FuelReservesPrice) + (Reservebuyamount * Config.FuelReservesPrice)) <= bankmoney then
                        local price = math.ceil(GlobalTax(Reservebuyamount * Config.FuelReservesPrice) + (Reservebuyamount * Config.FuelReservesPrice))
                        if Config.FuelDebug then lib.print.debug("Price: "..price) end
                        TriggerEvent("cdn-fuel:stations:client:purchasereserves:final", location, price, amount)

                    else
                        exports.qbx_core:Notify(Lang:t("not_enough_money_in_bank"), 'error', 7500)
                    end
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:changefuelprice', function(data)
        CanOpen = false
        local location = data.location
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, location)
        Wait(Config.WaitTime)
        if CanOpen then
            if Config.FuelDebug then lib.print.debug("Showing Input for Fuel Price Change!") end

            local fuelprice = lib.inputDialog('Fuel Prices', {
                { type = "input", label = 'Current Price',
                default = '$'.. Comma_Value(StationFuelPrice) .. ' Per Liter',
                disabled = true },
                { type = "number", label = 'Enter New Fuel Price Per Liter',
                default = StationFuelPrice,
                min = Config.MinimumFuelPrice,
                max = Config.MaxFuelPrice
                },
            })
            if not fuelprice then return end
            fuelPrice = tonumber(fuelprice[2])
            if fuelprice then
                if Config.FuelDebug then lib.print.debug("Attempting to change fuel price!") end
                Wait(100)
                if not fuelPrice then exports.qbx_core:Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                NewFuelPrice = tonumber(fuelPrice)
                if NewFuelPrice < Config.MinimumFuelPrice then exports.qbx_core:Notify(Lang:t("station_price_too_low"), 'error', 7500) return end
                if NewFuelPrice > Config.MaxFuelPrice then
                    exports.qbx_core:Notify(Lang:t("station_price_too_high"), "error")
                else
                    TriggerServerEvent("cdn-fuel:station:server:updatefuelprice", NewFuelPrice, CurrentLocation)
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:sellstation:menu', function(data) -- Menu, seen after selecting the Sell this Location option.
        local location = data.location
        local CitizenID = QBX.PlayerData.citizenid
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)
        if CanOpen then
            local GasStationCost = Config.GasStations[location].cost + GlobalTax(Config.GasStations[location].cost)
            local SalePrice = math.percent(Config.GasStationSellPercentage, GasStationCost)

            lib.registerContext({
                id = 'sellstationmenu',
                title = Lang:t("menu_sell_station_header")..Config.GasStations[location].label,
                options = {
                    {
                        title = Lang:t("menu_sell_station_header_accept"),
                        description = Lang:t("menu_sell_station_footer_accept")..Comma_Value(SalePrice)..".",
                        icon = "fas fa-usd",
                        arrow = false, -- puts arrow to the right
                        event = 'cdn-fuel:stations:client:sellstation',
                        args = {
                            location = location,
                            SalePrice = SalePrice,
                        }
                    },
                    {
                        title = Lang:t("menu_header_close"),
                        description = Lang:t("menu_refuel_cancel"),
                        icon = "fas fa-times-circle",
                        arrow = false, -- puts arrow to the right
                        onSelect = function()
                            lib.hideContext()
                            end,
                    },
                },
            })
            lib.showContext('sellstationmenu')
            TriggerServerEvent("cdn-fuel:stations:server:stationsold", location)
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:changestationname', function() -- Menu for changing the label of the owned station.
        CanOpen = false
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)
        if CanOpen then
            if Config.FuelDebug then lib.print.debug("Showing Input for name Change!") end

            local NewName = lib.inputDialog('Name Changer', {
                { type = "input", label = 'Current Name',
                default = Config.GasStations[CurrentLocation].label,
                disabled = true },
                { type = "input", label = 'Enter New Station Name',
                placeholder = 'New Name'
                },
            })
            if not NewName then return end
            NewNameName = NewName[2]
            if NewName then
                if Config.FuelDebug then lib.print.debug("Attempting to alter stations name!") end
                if not NewNameName then exports.qbx_core:Notify(Lang:t("station_name_invalid"), 'error', 7500) return end
                NewName = NewNameName
                if type(NewName) ~= "string" then exports.qbx_core:Notify(Lang:t("station_name_invalid"), 'error') return end
                if Config.ProfanityList[NewName] then exports.qbx_core:Notify(Lang:t("station_name_invalid"), 'error', 7500)
                    -- You can add logs for people that put prohibited words into the name changer if wanted, and here is where you would do it.
                    return
                end
                if string.len(NewName) > Config.NameChangeMaxChar then exports.qbx_core:Notify(Lang:t("station_name_too_long"), 'error') return end
                if string.len(NewName) < Config.NameChangeMinChar then exports.qbx_core:Notify(Lang:t("station_name_too_short"), 'error') return end
                Wait(100)
                TriggerServerEvent("cdn-fuel:station:server:updatelocationname", NewName, CurrentLocation)
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:managemenu', function(location) -- Menu, seen after selecting the Manage this Location Option.
        location = CurrentLocation
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        UpdateStationInfo("all")
        if Config.PlayerControlledFuelPrices then CanNotChangeFuelPrice = false else CanNotChangeFuelPrice = true end
        Wait(5)
        Wait(Config.WaitTime)
        if CanOpen then
            local GasStationCost = (Config.GasStations[location].cost + GlobalTax(Config.GasStations[location].cost))

                lib.registerContext({
                    id = 'stationmanagemenu',
                    title = Lang:t("menu_manage_header")..Config.GasStations[location].label,
                    options = {
                        {
                            title = Lang:t("menu_manage_reserves_header"),
                            description = 'Buy your reserve fuel here!',
                            icon = "fas fa-info-circle",
                            arrow = true, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:purchasereserves',
                            args = {
                                location = location,
                            },
                            metadata = {
                                {label = 'Reserve Stock: ', value = ReserveLevels..Lang:t("menu_manage_reserves_footer_1")..Config.MaxFuelReserves},
                            },
                            disabled = ReservesNotBuyable,
                        },
                        {
                            title = Lang:t("menu_alter_fuel_price_header"),
                            description = "I want to change the price of fuel at my Gas Station!",
                            icon = "fas fa-usd",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:changefuelprice',
                            args = {
                                location = location,
                            },
                            metadata = {
                                {label = 'Current Fuel Price: ', value = "$"..Comma_Value(StationFuelPrice)..Lang:t("input_alter_fuel_price_header_2")},
                            },
                            disabled = CanNotChangeFuelPrice,
                        },
                        {
                            title = Lang:t("menu_manage_company_funds_header"),
                            description = Lang:t("menu_manage_company_funds_footer"),
                            icon = "fas fa-usd",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:managefunds'
                        },
                        {
                            title = Lang:t("menu_manage_change_name_header"),
                            description = Lang:t("menu_manage_change_name_footer"),
                            icon = "fas fa-pen",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:changestationname',
                            disabled = not Config.GasStationNameChanges,
                        },
                        {
                            title = Lang:t("menu_sell_station_header_accept"),
                            description = Lang:t("menu_manage_sell_station_footer")..Comma_Value(math.percent(Config.GasStationSellPercentage, GasStationCost)),
                            icon = "fas fa-usd",
                            arrow = false, -- puts arrow to the right
                            event = 'cdn-fuel:stations:client:sellstation:menu',
                            args = {
                                location = location,
                            },
                        },
                        {
                            title = Lang:t("menu_header_close"),
                            description = Lang:t("menu_refuel_cancel"),
                            icon = "fas fa-times-circle",
                            arrow = false, -- puts arrow to the right
                            onSelect = function()
                                lib.hideContext()
                              end,
                        },
                    },
                })
                lib.showContext('stationmanagemenu')
            
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:managefunds', function(location) -- Menu, seen after selecting the Manage this Location Option.
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        UpdateStationInfo("all")
        Wait(5)
        Wait(Config.WaitTime)
        if CanOpen then

            lib.registerContext({
                id = 'managefundsmenu',
                title = Lang:t("menu_manage_company_funds_header_2")..Config.GasStations[CurrentLocation].label,
                options = {
                    {
                        title = Lang:t("menu_manage_company_funds_withdraw_header"),
                        description = Lang:t("menu_manage_company_funds_withdraw_footer"),
                        icon = "fas fa-arrow-left",
                        arrow = false, -- puts arrow to the right
                        event = 'cdn-fuel:stations:client:WithdrawFunds',
                        args = {
                            location = location,
                        }
                    },
                    {
                        title = Lang:t("menu_manage_company_funds_deposit_header"),
                        description = Lang:t("menu_manage_company_funds_deposit_footer"),
                        icon = "fas fa-arrow-right",
                        arrow = false, -- puts arrow to the right
                        event = 'cdn-fuel:stations:client:DepositFunds',
                        args = {
                            location = location,
                        }
                    },
                    {
                        title = Lang:t("menu_manage_company_funds_return_header"),
                        description = Lang:t("menu_manage_company_funds_return_footer"),
                        icon = "fas fa-circle-left",
                        arrow = false, -- puts arrow to the right
                        event = 'cdn-fuel:stations:client:managemenu',
                        args = {
                            location = location,
                        }
                    },
                    {
                        title = Lang:t("menu_header_close"),
                        description = Lang:t("menu_refuel_cancel"),
                        icon = "fas fa-times-circle",
                        arrow = false, -- puts arrow to the right
                        onSelect = function()
                            lib.hideContext()
                            end,
                    },
                },
            })
            lib.showContext('managefundsmenu')
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:WithdrawFunds', function(data)
        if Config.FuelDebug then lib.print.debug("Triggered Event for: Withdraw!") end
        CanOpen = false
        local location = CurrentLocation
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)
        if CanOpen then
            if Config.FuelDebug then lib.print.debug("Showing Input for Withdraw!") end
            UpdateStationInfo("balance")
            Wait(50)

            local Withdraw = lib.inputDialog('Withdraw Funds', {
                { type = "input", label = 'Current Station Balance',
                default = '$'..Comma_Value(StationBalance),
                disabled = true },
                { type = "number", label = 'Withdraw Amount',
                },
            })
            if not Withdraw then return end
            WithdrawAmounts = tonumber(Withdraw[2])
            if Withdraw then
                if Config.FuelDebug then lib.print.debug("Attempting to Withdraw!") end
                Wait(100)
                local amount = tonumber(WithdrawAmounts)
                if not WithdrawAmounts then exports.qbx_core:Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                if amount < 1 then exports.qbx_core:Notify(Lang:t("station_withdraw_too_little"), 'error', 7500) return end
                if amount > StationBalance then exports.qbx_core:Notify(Lang:t("station_withdraw_too_much"), 'error', 7500) return end
                WithdrawAmount = tonumber(amount)
                if (StationBalance - WithdrawAmount) < 0 then
                    exports.qbx_core:Notify(Lang:t("station_withdraw_too_much"), 'error', 7500)
                else
                    TriggerServerEvent('cdn-fuel:station:server:Withdraw', amount, location, StationBalance)
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:DepositFunds', function(data)
        if Config.FuelDebug then lib.print.debug("Triggered Event for: Deposit!") end
        CanOpen = false
        local location = CurrentLocation
        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                CanOpen = true
            else
                exports.qbx_core:Notify(Lang:t("station_not_owner"), 'error', 7500)
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                CanOpen = false
            end
        end, CurrentLocation)
        Wait(Config.WaitTime)
        if CanOpen then
            local bankmoney = QBX.PlayerData.money['bank']
            if Config.FuelDebug then lib.print.debug("Showing Input for Deposit!") end
            UpdateStationInfo("balance")
            Wait(50)

            local Deposit = lib.inputDialog('Deposit Funds', {
                { type = "input", label = 'Current Station Balance',
                default = '$'..Comma_Value(StationBalance),
                disabled = true },
                { type = "number", label = 'Deposit Amount',
                },
            })
            if not Deposit then return end
            DepositAmounts = tonumber(Deposit[2])
            if Deposit then
                if Config.FuelDebug then lib.print.debug("Attempting to Deposit!") end
                Wait(100)
                local amount = tonumber(DepositAmounts)
                if not DepositAmounts then exports.qbx_core:Notify(Lang:t("station_amount_invalid"), 'error', 7500) return end
                if amount < 1 then exports.qbx_core:Notify(Lang:t("station_deposit_too_little"), 'error', 7500) return end
                DepositAmount = tonumber(amount)
                if (DepositAmount) > bankmoney then
                    exports.qbx_core:Notify(Lang:t("station_deposity_too_much"), "error")
                else
                    TriggerServerEvent('cdn-fuel:station:server:Deposit', amount, location, StationBalance)
                end
            end
        end
    end)

    RegisterNetEvent('cdn-fuel:stations:client:Shutoff', function(location)
        TriggerServerEvent("cdn-fuel:stations:server:Shutoff", location)
    end)

    RegisterNetEvent('cdn-fuel:stations:client:purchasemenu', function(location) -- Menu, seen after selecting the purchase this location option.
        local bankmoney = QBX.PlayerData.money['bank']
        local costofstation = Config.GasStations[location].cost + GlobalTax(Config.GasStations[location].cost)

        if Config.OneStationPerPerson == true then
            QBCore.Functions.TriggerCallback('cdn-fuel:server:doesPlayerOwnStation', function(result)
                if result then
                    if Config.FuelDebug then lib.print.debug("Player already owns a station, so disallowing purchase.") end
                    PlayerOwnsAStation = true
                else
                    if Config.FuelDebug then lib.print.debug("Player doesn't own a station, so continuing purchase checks.") end
                    PlayerOwnsAStation = false
                end
            end)

            Wait(Config.WaitTime)

            if PlayerOwnsAStation == true then
                exports.qbx_core:Notify('You can only buy one station, and you already own one!', 'error')
                return
            end
        end


        if bankmoney < costofstation then
            exports.qbx_core:Notify(Lang:t("not_enough_money_in_bank").." $"..costofstation, 'error', 7500) return
        end

        lib.registerContext({
            id = 'purchasemenu',
            title = Config.GasStations[location].label,
            options = {
                {
                    title = Lang:t("menu_purchase_station_confirm_header"),
                    description = 'I am interested in purchasing this station!',
                    icon = "fas fa-usd",
                    arrow = true, -- puts arrow to the right
                    event = 'cdn-fuel:stations:client:purchaselocation',
                    args = {
                        location = location,
                    },
                    metadata = {
                        {label = 'Station Cost: $', value = Comma_Value(costofstation)..Lang:t("menu_purchase_station_header_2")},
                    },
                },
                {
                    title = Lang:t("menu_header_close"),
                    description = Lang:t("menu_refuel_cancel"),
                    icon = "fas fa-times-circle",
                    arrow = false, -- puts arrow to the right
                    onSelect = function()
                        lib.hideContext()
                        end,
                },
            },
        })
        lib.showContext('purchasemenu')
    end)

    RegisterNetEvent('cdn-fuel:stations:openmenu', function() -- Menu #1, the first menu you see.
        DisablePurchase = true
        DisableOwnerMenu = true
        ShutOffDisabled = false

        QBCore.Functions.TriggerCallback('cdn-fuel:server:locationpurchased', function(result)
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned.") end
                DisablePurchase = true
            else
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned.") end
                DisablePurchase = false
                DisableOwnerMenu = true
            end
        end, CurrentLocation)

        QBCore.Functions.TriggerCallback('cdn-fuel:server:isowner', function(result)
            local CitizenID = QBX.PlayerData.citizenid
            if result then
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is owned by ID: "..CitizenID) end
                DisableOwnerMenu = false
            else
                if Config.FuelDebug then lib.print.debug("The Location: "..CurrentLocation.." is not owned by ID: "..CitizenID) end
                DisableOwnerMenu = true
            end
        end, CurrentLocation)

        if Config.EmergencyShutOff then
            QBCore.Functions.TriggerCallback('cdn-fuel:server:checkshutoff', function(result)
                if result == true then
                    PumpState = "disabled."
                elseif result == false then
                    PumpState = "enabled."
                else
                    PumpState = "nil"
                end

                if Config.FuelDebug then lib.print.debug("The result from Callback: Config.GasStations["..CurrentLocation.."].shutoff = "..PumpState) end
            end, CurrentLocation)
        else
            PumpState = "enabled."
            ShutOffDisabled = true
        end

        Wait(Config.WaitTime)


        lib.registerContext({
            id = 'stationmainmenu',
            title = Config.GasStations[CurrentLocation].label,
            options = {
                {
                    title = Lang:t("menu_ped_manage_location_header"),
                    description = Lang:t("menu_ped_manage_location_footer"),
                    icon = "fas fa-gas-pump",
                    arrow = false, -- puts arrow to the right
                    event = 'cdn-fuel:stations:client:managemenu',
                    args = CurrentLocation,
                    disabled = DisableOwnerMenu,
                },
                {
                    title = Lang:t("menu_ped_purchase_location_header"),
                    description = Lang:t("menu_ped_purchase_location_footer"),
                    icon = "fas fa-usd",
                    arrow = false, -- puts arrow to the right
                    event = 'cdn-fuel:stations:client:purchasemenu',
                    args = CurrentLocation,
                    disabled = DisablePurchase,
                },
                {
                    title = Lang:t("menu_ped_emergency_shutoff_header"),
                    description = Lang:t("menu_ped_emergency_shutoff_footer")..PumpState,
                    icon = "fas fa-gas-pump",
                    arrow = false, -- puts arrow to the right
                    event = 'cdn-fuel:stations:client:Shutoff',
                    args = CurrentLocation,
                    disabled = ShutOffDisabled,
                },
                {
                    title = Lang:t("menu_header_close"),
                    description = Lang:t("menu_refuel_cancel"),
                    icon = "fas fa-times-circle",
                    arrow = false, -- puts arrow to the right
                    onSelect = function()
                        lib.hideContext()
                        end,
                },
            },
        })
        lib.showContext('stationmainmenu')
    end)

    -- Threads
    CreateThread(function() -- Spawn the Peds for Gas Stations when the resource starts.
        SpawnGasStationPeds()
    end)
end -- For Config.PlayerOwnedGasStationsEnabled check, don't remove!