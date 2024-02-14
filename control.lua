--control.lua
require('event')
require('stringutils')
require('logging')
Logging.sasLog("Scooty's Armor Swap Setup")


-----------------------------
-- Event Handlers
-----------------------------

--[[ Register a function to be run on mod initialization. This is only called when a new save game 
is created or when a save file is loaded that previously didn't contain the mod. During it, the mod 
gets the chance to set up initial values that it will use for its lifetime. It has full access to 
LuaGameScript and the global table and can change anything about them that it deems appropriate. No 
other events will be raised for the mod until it has finished this step.
--]]
function on_init(event)
	Logging.sasLog("⚡️ on_init")
	global.armorColors = {}
	global.armorColorsBackup = {}
end

--[[
Register a function to be run on save load. This is only called for mods that have been part of the save previously, 
or for players connecting to a running multiplayer session.

It gives the mod the opportunity to rectify potential differences in local state introduced by the save/load cycle. 
Doing anything other than the following three will lead to desyncs, breaking multiplayer and replay functionality. 
Access to LuaGameScript is not available. The global table can be accessed and is safe to read from, but not write to, 
as doing so will lead to an error.

The only legitimate uses of this event are these:
- Re-setup metatables as they are not persisted through the save/load cycle.
- Re-setup conditional event handlers, meaning subscribing to an event only when some condition is met to save processing time.
- Create local references to data stored in the global table.
]]
function on_load(event)
	Logging.sasLog("⚡️ on_load")
	Logging.sasLog("global.armorColors: " .. StringUtils.toString(global.armorColors))
	Logging.sasLog("global.armorColorsBackup: " .. StringUtils.toString(global.armorColorsBackup))
end


function onKeyPressHandlerEquipNextArmorHandler(event)
	Logging.sasLog("⚡️ onKeyPressHandlerEquipNextArmorHandler")

	-- Get the player or bail
	luaPlayer = getLuaPlayerFromEvent(event)
	if luaPlayer == nil then
		return
	end

	-- Record the current armor's color for the next time it is equipped
	dyeArmorFromPlayer(luaPlayer)

	-- Equip the next armor
	equipNextArmor(luaPlayer)
end

function onKeyPressHandlerClearCacheHandler(event)
	Logging.sasLog("⚡️ onKeyPressHandlerClearCacheHandler")
	global.armorColors = {}
	global.armorColorsBackup = {}
	Logging.pLog(getLuaPlayerFromEvent(event), "All Armors have been un-dyed")
end

function onPlayerArmorInventoryChangedHandler(event)
	Logging.sasLog("⚡️ onPlayerArmorInventoryChangedHandler")

	-- Change the player's color based on the new armor  
	dyePlayerFromArmor(luaPlayer)
end

----------------------
-- API
----------------------
function equipNextArmor(luaPlayer)
	Logging.sasLog()

	armorItemNumber = getNextArmorItemNumber(luaPlayer)

	if armorItemNumber ~= nil then
		equipArmorWithItemNumber(luaPlayer, armorItemNumber)
	end
end

function dyeArmorFromPlayer(luaPlayer)
	Logging.sasLog()

	armorInfo = getArmorInfo(luaPlayer)
	if armorInfo == nil then
		return
	end	

	Logging.sasLog(
		"Dyeing armor "
		.. armorInfo.primaryKey 
		.. "/" 
		.. armorInfo.secondaryKey
		.. " to " 
		.. StringUtils.toString(luaPlayer.color)
	)
	
	-- Record color
	global.armorColors[armorInfo.primaryKey] = luaPlayer.color
	global.armorColorsBackup[armorInfo.secondaryKey] = luaPlayer.color	
end

function dyePlayerFromArmor(luaPlayer)
	Logging.sasLog()

	-- Get the currently worn armor
	armorInfo = getArmorInfo(luaPlayer)
	if armorInfo == nil then
		return
	end

	-- Try primary key
	colorNew = global.armorColors[armorInfo.primaryKey]
	if colorNew ~= nil then 
		Logging.sasLog("Found " .. armorInfo.primaryKey .. " in armorColors: " .. StringUtils.getKeys(global.armorColors) )
		luaPlayer.color = colorNew
		return
	end
	Logging.sasLog("Could not find next armor's key " .. armorInfo.primaryKey .. " in armorColors: " .. StringUtils.getKeys(global.armorColors) .. "")

	-- Try secondary key
	colorNew = global.armorColorsBackup[armorInfo.secondaryKey]
	if colorNew ~= nil then
		Logging.sasLog("Found " .. armorInfo.secondaryKey .. " in armorColorsBackup: " .. StringUtils.getKeys(global.armorColorsBackup) )
		luaPlayer.color = colorNew
		return
	end

	Logging.sasLog("Could not find next armor's backup key " .. armorInfo.secondaryKey .. " in armorColorsBackup: " .. StringUtils.getKeys(global.armorColorsBackup) .. ". Bailing.")
end



----------------------
-- Utility Functions
----------------------

function getArmorInfo(luaPlayer)
	Logging.sasLog()

	luaItemStackWornArmor = luaPlayer.get_inventory(defines.inventory.character_armor)[1]
	if not luaItemStackWornArmor.is_armor then
		Logging.sasLog("Not wearing armor")
		return nil
	end


	--[[
	Item numbers are usually a very stable way of "primary key"ing an item.
	However, some mods that teleport players like our beloved SE will destroy and re-create the player instead of physically transporting 
	them between surfaces. This has the unfortunate side effect of creating new item numbers for that player's armors.
	
	Given that, we make a secondary key by hashing the armor's name plus its grid contents.

	This is a much fuzzier match and will cause collisions if armor types and grids are exactly the same. 
	For example, if you and another player both have a power armor mk2 with nothing but jetpacks and theirs is red and yours is blue,
	they will both get the same hash. 

	These collisions are usually not the worst user experience since we don't usually care about dying armors with no grid or keeping armors
	with the exact same grid visually distinct, but it can get confusing.

	TODO: I'm considering making the fuzzy-match table somehow be based on the player?
	Perhaps have a personal secondary table that uses the player name/id, and a third that's global? 
	I'll have to think about it, but for now this is Good Enough.

	--]]

	hashInput = luaItemStackWornArmor.name
	if luaItemStackWornArmor.grid ~= nil then
		hashInput = hashInput .. StringUtils.toString(luaItemStackWornArmor.grid.get_contents())
	end
	armorHash = StringUtils.hash(hashInput)

	-- Return a table
	ret = {
		name = luaItemStackWornArmor.name,
		primaryKey = luaItemStackWornArmor.item_number,
		secondaryKey = armorHash
	}

	-- Log it
	Logging.sasLog(ret)

	return ret
end

-- TODO: Test for no armor in inventory and for no curently equipped armor
function getNextArmorItemNumber(luaPlayer) 
	Logging.sasLog()
	luaItemStackWornArmor = luaPlayer.get_inventory(defines.inventory.character_armor)[1]
	luaInventory = luaPlayer.get_main_inventory()
	freeSlots = luaInventory.count_empty_stacks()

	armorItemNumbers = {}

	-- Get the current armor info
	wornArmorItemNumber = 0
	currentInventorySizeBonus = 0
	if luaItemStackWornArmor.is_armor then
		wornArmorItemNumber = luaItemStackWornArmor.item_number
		currentInventorySizeBonus = luaItemStackWornArmor.prototype.inventory_size_bonus
	end

	-- Find all armors in inventory that wouldnt cause you to drop items if they were equipped
	for i=1, #luaInventory do
		luaItemStack = luaInventory[i]  
		if luaItemStack.valid_for_read then 
			if luaItemStack.is_armor then
				-- If equipping this armor would cause the player to drop items, don't consider it.
				inventorySizeBonusChange = luaItemStack.prototype.inventory_size_bonus - currentInventorySizeBonus
				if freeSlots + inventorySizeBonusChange >= 0 then
					table.insert(armorItemNumbers, luaItemStack.item_number)
				end
				end
		end
	end

	-- Bail if there are no armors in inventory
	if #armorItemNumbers == 0 then
		pLog(luaPlayer, "No valid armors in inventory")
		return nil
	end

	table.sort(armorItemNumbers)

	-- Find the next armor in sequence by comparing item numbers
	for i=1, #armorItemNumbers do
		if wornArmorItemNumber < armorItemNumbers[i] then
			return armorItemNumbers[i]
		end
	end

	return armorItemNumbers[1]
end

-- Swaps the the currently equipped armor with the specified item number in the inventory and updates player color
function equipArmorWithItemNumber(luaPlayer, armorItemNumber) 
	Logging.sasLog()
	--Get the armors
	luaItemStackWornArmor = luaPlayer.get_inventory(defines.inventory.character_armor)[1]
	luaItemStackNewArmor = findArmorByItemNumber(luaPlayer.get_main_inventory(), armorItemNumber)

	if luaItemStackNewArmor == nil or not luaItemStackNewArmor.valid_for_read then
		Logging.sasLog("Next armor can't be read")
		return
	end

	--Switch armors
	--Normally, swapping armor briefly removes inventory bonus slots which can cause the player
	--to drop items on the ground. Briefly expand the inventory to prevent this.
	luaPlayer.character_inventory_slots_bonus = luaPlayer.character_inventory_slots_bonus + 1000
	luaItemStackNewArmor.swap_stack(luaItemStackWornArmor)
	luaPlayer.character_inventory_slots_bonus = luaPlayer.character_inventory_slots_bonus - 1000  
end

-- Used by equipArmorWithItemNumber to convert the inventory item number to the actual item stack
function findArmorByItemNumber(luaInventory, armorItemNumber)
	Logging.sasLog()
	for i=1, #luaInventory do
		luaItemStack = luaInventory[i]  
		if luaItemStack.valid_for_read then 
			if luaItemStack.is_armor and luaItemStack.item_number == armorItemNumber then
				return luaItemStack
				end
		end
	end
	return nil
end

function getLuaPlayerFromEvent(event)
	Logging.sasLog()
	if event.player_index and game.players[event.player_index] and game.players[event.player_index].connected then
		local luaPlayer = game.players[event.player_index]
		if luaPlayer.character then
			return luaPlayer
		end
	end

	Logging.sasLog("No player in event!!")
	return nil
end

--------------------
-- Event Listeners 
--------------------

-- Note - these must be added last, after the funcs are defined
Event.addListener("on_init", on_init, true)
Event.addListener("on_load", on_load, true)
Event.addListener("scootys-armor-swap-equip-next-armor", onKeyPressHandlerEquipNextArmorHandler)
Event.addListener("scootys-armor-swap-clear-cache", onKeyPressHandlerClearCacheHandler)
Event.addListener(defines.events.on_player_armor_inventory_changed, onPlayerArmorInventoryChangedHandler)



-- Helpful for debugging
--[[

/c  local player = game.player
player.insert{name="power-armor-mk2", count = 1}
local p_armor = player.get_inventory(5)[1].grid
	p_armor.put({name = "fusion-reactor-equipment"})
	p_armor.put({name = "fusion-reactor-equipment"})
	p_armor.put({name = "fusion-reactor-equipment"})
	p_armor.put({name = "exoskeleton-equipment"})
	p_armor.put({name = "exoskeleton-equipment"})
	p_armor.put({name = "exoskeleton-equipment"})
	p_armor.put({name = "exoskeleton-equipment"})
	p_armor.put({name = "energy-shield-mk2-equipment"})
	p_armor.put({name = "energy-shield-mk2-equipment"})
	p_armor.put({name = "personal-roboport-mk2-equipment"})
	p_armor.put({name = "night-vision-equipment"})
	p_armor.put({name = "battery-mk2-equipment"})
	p_armor.put({name = "battery-mk2-equipment"})


player.insert{name="iron-plate", count = 5000}

player.print(serpent.block(global) )

]]