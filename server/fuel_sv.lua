-- Variables
local QBCore = exports[Config.Core]:GetCoreObject()

-- Functions
local function GlobalTax(value)
	local tax = (value / 100 * Config.GlobalTax)
	return tax
end

--- Events
if Config.RenewedPhonePayment then
	RegisterNetEvent('cdn-fuel:server:phone:givebackmoney', function(amount)
		local src = source
		local player = exports.qbx_core:GetPlayer(src)
		player.Functions.AddMoney("bank", math.ceil(amount), Lang:t("phone_refund_payment_label"))
	end)
end

RegisterNetEvent("cdn-fuel:server:OpenMenu", function(amount, inGasStation, hasWeapon, purchasetype, FuelPrice)
	local src = source
	if not src then return end
	local player = exports.qbx_core:GetPlayer(src)
	if not player then return end
	if not amount then if Config.FuelDebug then lib.print.debug("Amount is invalid!") end exports.qbx_core:Notify( src, Lang:t("more_than_zero"), 'error') return end
	local FuelCost = amount*FuelPrice
	local tax = GlobalTax(FuelCost)
	local total = tonumber(FuelCost + tax)
	if inGasStation == true and not hasWeapon then
		if Config.RenewedPhonePayment and purchasetype == "bank" then
			TriggerClientEvent("cdn-fuel:client:phone:PayForFuel", src, amount)
		else
			if Config.FuelDebug then lib.print.debug("going to open the context menu (OX)") end
			TriggerClientEvent('cdn-fuel:client:OpenContextMenu', src, total, amount, purchasetype)
		end
	end
end)

RegisterNetEvent("cdn-fuel:server:PayForFuel", function(amount, purchasetype, FuelPrice, electric)
	local src = source
	if not src then return end
	local Player = exports.qbx_core:GetPlayer(src)
	if not Player then return end
	local total = math.ceil(amount)
	if amount < 1 then
		total = 0
	end
	local moneyremovetype = purchasetype
	if Config.FuelDebug then lib.print.debug("Player is attempting to purchase fuel with the money type: " ..moneyremovetype) end
	if Config.FuelDebug then lib.print.debug("Attempting to charge client: $"..total.." for Fuel @ "..FuelPrice.." PER LITER | PER KW") end
	if purchasetype == "bank" then
		moneyremovetype = "bank"
	elseif purchasetype == "cash" then
		moneyremovetype = "cash"
	end
	local cash = Player.PlayerData.money['cash']
        local bank = Player.PlayerData.money['bank']
	local payString = Lang:t("menu_pay_label_1") ..FuelPrice..Lang:t("menu_pay_label_2")
	if electric then payString = Lang:t("menu_electric_payment_label_1") ..FuelPrice..Lang:t("menu_electric_payment_label_2") end
	if (purchasetype ~= "full") then 
		Player.Functions.RemoveMoney(moneyremovetype, total, payString)
	else
		if (total <= cash) then 
			Player.Functions.RemoveMoney("cash", total, payString)
		elseif (total > cash) then 
			-- Need to take money from bank
			total = total - cash;
			Player.Functions.RemoveMoney("cash", cash, payString)
			Player.Functions.RemoveMoney("bank", total, payString)
		end
	end
end)

RegisterNetEvent("cdn-fuel:server:purchase:jerrycan", function(purchasetype)
	local src = source if not src then return end
	local Player = exports.qbx_core:GetPlayer(src) if not Player then return end
	local tax = GlobalTax(Config.JerryCanPrice) local total = math.ceil(Config.JerryCanPrice + tax)
	local moneyremovetype = purchasetype
	if purchasetype == "bank" then
		moneyremovetype = "bank"
	elseif purchasetype == "cash" then
		moneyremovetype = "cash"
	end

	local info = {cdn_fuel = tostring(Config.JerryCanGas)}
	exports.ox_inventory:AddItem(src, 'jerrycan', 1, info)
	local hasItem = exports.ox_inventory:GetItem(src, 'jerrycan', info, 1)
	if hasItem then
		Player.Functions.RemoveMoney(moneyremovetype, total, Lang:t("jerry_can_payment_label"))
	end
end)

--- Jerry Can
if Config.UseJerryCan then
	QBCore.Functions.CreateUseableItem("jerrycan", function(source, item)
		local src = source
		TriggerClientEvent('cdn-fuel:jerrycan:refuelmenu', src, item)
	end)
end

--- Syphoning
if Config.UseSyphoning then
	QBCore.Functions.CreateUseableItem("syphoningkit", function(source, item)
		local src = source
		if item.metadata.cdn_fuel == nil then
			item.metadata.cdn_fuel = '0'
			exports.ox_inventory:SetMetadata(src, item.slot, item.metadata)
		end
		TriggerClientEvent('cdn-syphoning:syphon:menu', src, item)
	end)
end

RegisterNetEvent('cdn-fuel:info', function(type, amount, srcPlayerData, itemdata)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local srcPlayerData = srcPlayerData
	local ItemName = itemdata.name


	if itemdata == "jerrycan" then
		if amount < 1 or amount > Config.JerryCanCap then if Config.FuelDebug then lib.print.debug("Error, amount is invalid (< 1 or > "..Config.SyphonKitCap..")! Amount:" ..amount) end return end
	elseif itemdata == "syphoningkit" then
		if amount < 1 or amount > Config.SyphonKitCap then if Config.SyphonDebug then lib.print.debug("Error, amount is invalid (< 1 or > "..Config.SyphonKitCap..")! Amount:" ..amount) end return end
	end
	if ItemName ~= nil then
		-- Ignore --
		itemdata.metadata = itemdata.metadata
		itemdata.slot = itemdata.slot
		if ItemName == 'jerrycan' then
			local fuel_amount = tonumber(itemdata.metadata.cdn_fuel)
			if type == "add" then
				fuel_amount = fuel_amount + amount
				itemdata.metadata.cdn_fuel = tostring(fuel_amount)
				exports.ox_inventory:SetMetadata(src, itemdata.slot, itemdata.metadata)
			elseif type == "remove" then
				fuel_amount = fuel_amount - amount
				itemdata.metadata.cdn_fuel = tostring(fuel_amount)
				exports.ox_inventory:SetMetadata(src, itemdata.slot, itemdata.metadata)
			else
				if Config.FuelDebug then lib.print.debug("error, type is invalid!") end
			end
		elseif ItemName == 'syphoningkit' then
			local fuel_amount = tonumber(itemdata.metadata.cdn_fuel)
			if type == "add" then
				fuel_amount = fuel_amount + amount
				itemdata.metadata.cdn_fuel = tostring(fuel_amount)
				exports.ox_inventory:SetMetadata(src, itemdata.slot, itemdata.metadata)
			elseif type == "remove" then
				fuel_amount = fuel_amount - amount
				itemdata.metadata.cdn_fuel = tostring(fuel_amount)
				exports.ox_inventory:SetMetadata(src, itemdata.slot, itemdata.metadata)
			else
				if Config.SyphonDebug then lib.print.debug("error, type is invalid!") end
			end
		end
	else
		if Config.FuelDebug then
			lib.print.debug("ItemName is invalid!")
		end
	end
end)

RegisterNetEvent('cdn-syphoning:callcops', function(coords)
    TriggerClientEvent('cdn-syphoning:client:callcops', -1, coords)
end)

--- Update Alerts
local updatePath
local resourceName

local function checkVersion(err, responseText, headers)
    local curVersion = LoadResourceFile(GetCurrentResourceName(), "version")
	if responseText == nil then lib.print.debug("^1"..resourceName.." check for updates failed ^7") return end
    if curVersion ~= nil and responseText ~= nil then
		if curVersion == responseText then Color = "^2" else Color = "^1" end
        lib.print.debug("\n^1----------------------------------------------------------------------------------^7")
        lib.print.debug(resourceName.."'s latest version is: ^2"..responseText.."!\n^7Your current version: "..Color..""..curVersion.."^7!\nIf needed, update from https://github.com"..updatePath.."")
        lib.print.debug("^1----------------------------------------------------------------------------------^7")
    end
end

CreateThread(function()
	updatePath = "/CodineDev/cdn-fuel"
	resourceName = "cdn-fuel ("..GetCurrentResourceName()..")"
	PerformHttpRequest("https://raw.githubusercontent.com"..updatePath.."/master/version", checkVersion, "GET")
end)
