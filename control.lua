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
	tryCatchPrint(
		function()
			Logging.sasLog("⚡️ on_init")
			global.armorColors = {}
			global.armorColorsBackup = {}
		end
	)
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
	tryCatchPrint(
		function()
			Logging.sasLog("⚡️ on_load")
			Logging.sasLog("global.armorColors: " .. tablelength(global.armorColors) .. " entries")
			Logging.sasLog("global.armorColorsBackup: " .. tablelength(global.armorColorsBackup) .. " entries")
		end
	)
end


function onKeyPressHandlerEquipNextArmorHandler(event)
	tryCatchPrint(
		function()	
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
		end,
		event
	)
end

function onKeyPressHandlerClearCacheHandler(event)
	tryCatchPrint(
		function()
			Logging.sasLog("⚡️ onKeyPressHandlerClearCacheHandler")
			global.armorColors = {}
			global.armorColorsBackup = {}
			Logging.pLog(getLuaPlayerFromEvent(event), "All Armors have been un-dyed")
		end,
		event
	)
end

function onPlayerArmorInventoryChangedHandler(event)
	tryCatchPrint(
		function()
			Logging.sasLog("⚡️ onPlayerArmorInventoryChangedHandler")

			luaPlayer = getLuaPlayerFromEvent(event)
			if luaPlayer == nil then
				return
			end

			-- Change the player's color based on the new armor
			dyePlayerFromArmor(luaPlayer)

			-- Record the current armor's color for the next time it is equipped
			-- Note: this is to update the fuzzy match, since at the time of this writing
			-- it is suddenly obvious that that the fuzzy match is the one that is used most 
			-- frequently due to jetpack creating new item IDs.
			dyeArmorFromPlayer(luaPlayer)
		end, 
		event
	)
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
	
	-- Try secondary key
	if colorNew == nil then 
		Logging.sasLog("Could not find next armor's key " .. armorInfo.primaryKey .. " in armorColors.")
		colorNew = global.armorColorsBackup[armorInfo.secondaryKey]
	end

	-- Bail if not found
	if colorNew == nil then
		Logging.sasLog("Could not find next armor's backup key " .. armorInfo.secondaryKey .. " in armorColorsBackup. Bailing.")
		return
	end

	-- Apply Color
	luaPlayer.color = colorNew

	-- Apply Jetpack tint fix
	tryCatchPrint(jetpackTintFix, luaPlayer)
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
	However, some mods that teleport players like our beloved SE and Jetpack will destroy and re-create the player, which has the 
	unfortunate side effect of creating new item numbers for that player's armors.
	
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
	-- TODO: Refactor this to calculate a minimum number of free slots
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

	-- Bail if there are no valid armors in inventory
	if #armorItemNumbers == 0 then
		Logging.pLog(luaPlayer, "No valid armors in inventory")
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

	mainInventory = luaPlayer.get_main_inventory()

	--Get the armors
	luaItemStackWornArmor = luaPlayer.get_inventory(defines.inventory.character_armor)[1]
	luaItemStackNewArmor = findArmorByItemNumber(mainInventory, armorItemNumber)

	Logging.sasLog("Worn armor: " .. StringUtils.toString(luaItemStackWornArmor))
	Logging.sasLog("New armor: " .. StringUtils.toString(luaItemStackNewArmor))

	-- Validate armors
	if luaItemStackNewArmor == nil then
		Logging.sasLog("New armor nil: " .. StringUtils.toString(luaItemStackNewArmor))
		return
	end

	if luaItemStackWornArmor == nil then
		Logging.sasLog("Worn armor nil: " .. StringUtils.toString(luaItemStackWornArmor))
		return
	end

	-- If we're not wearing armor, simply put on the new one and bail
	if not luaItemStackWornArmor.valid_for_read then
		Logging.sasLog("Not wearing armor")
		if not luaItemStackWornArmor.swap_stack(luaItemStackNewArmor) then
			Logging.sasLog("Putting on new armor " .. luaItemStackNewArmor.name .. " failed")
		end
		return
	end


	putWornArmorHere = mainInventory.find_empty_stack(luaItemStackWornArmor.name)

	-- Bail if full
	if putWornArmorHere == nil then
		Logging.sasLog("Nowhere to put worn armor")
		return
	end	

	--Switch armors
	--Normally, swapping armor briefly removes inventory bonus slots which can cause the player
	--to drop items on the ground. Briefly expand the inventory to prevent this.
	luaPlayer.character_inventory_slots_bonus = luaPlayer.character_inventory_slots_bonus + 1000

	
	if not luaItemStackWornArmor.swap_stack(putWornArmorHere) then
		Logging.sasLog("Taking off armor failed")
		return
	end

	if not luaItemStackNewArmor.swap_stack(luaItemStackWornArmor) then
		Logging.sasLog("Putting on new armor failed")
		return
	end

	-- Reset character_inventory_slots_bonus 
	luaPlayer.character_inventory_slots_bonus = luaPlayer.character_inventory_slots_bonus - 1000  		

end

-- Used by equipArmorWithItemNumber to convert the inventory item number to the actual item stack
function findArmorByItemNumber(luaInventory, armorItemNumber)
	Logging.sasLog()
	for i=1, #luaInventory do
		luaItemStack = luaInventory[i]  
		if luaItemStack.is_armor and luaItemStack.item_number == armorItemNumber then
			return luaItemStack
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

function jetpackTintFix(luaPlayer)
	Logging.sasLog()

	-- Since this talks to another mod, put it into a try catch
	tryCatchPrint(
		function()
			if remote.interfaces["jetpack"] == nil then
				Logging.sasLog("Jetpack not installed, bailing")
				return
			end

			Logging.sasLog("Applying jetpack tint fix...")

			local jetpack = remote.call("jetpack", "get_jetpack_for_character", {character=luaPlayer.character})
			if jetpack ~= nil then
				rendering.set_color(jetpack.animation_mask, jetpack.character.player and jetpack.character.player.color or jetpack.character.color)
			end
		end, 
		luaPlayer
	)
end

-- Wrapper for pcall
function tryCatchPrint(aFunction, arg)
	success, error = pcall(aFunction, arg)
	if not success then
		Logging.sasLog("🚨 Error: " .. StringUtils.toString(error))
	end
end

-- Gets the number of entries in a table
function tablelength(T)
  local count = 0
  if T then
	  for _ in pairs(T) do 
	  	count = count + 1 
	  end
	end
  return count
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