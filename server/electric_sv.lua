-- Functions
local function GlobalTax(value)
	local tax = (value / 100 * Config.GlobalTax)
	return tax
end

-- Events
RegisterNetEvent("cdn-fuel:server:electric:OpenMenu", function(amount, inGasStation, hasWeapon, purchasetype, FuelPrice)
	local src = source
	if not src then lib.print.debug("SRC is nil!") return end
	local player = exports.qbx_core:GetPlayer(src)
	if not player then lib.print.debug("Player is nil!") return end
	local FuelCost = amount*FuelPrice
	local tax = GlobalTax(FuelCost)
	local total = tonumber(FuelCost + tax)
	if not amount then if Config.FuelDebug then lib.print.debug("Electric Recharge Amount is invalid!") end exports.qbx_core:Notify( src, locale("electric_more_than_zero"), 'error') return end
	Wait(50)
	if inGasStation and not hasWeapon then
		if Config.RenewedPhonePayment and purchasetype == "bank" then
			TriggerClientEvent("cdn-fuel:client:electric:phone:PayForFuel", src, amount)
		else
			TriggerClientEvent('cdn-electric:client:OpenContextMenu', src, math.ceil(total), amount, purchasetype)
		end
	end
end)