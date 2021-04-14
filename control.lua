--control.lua

require('event')

local ScootysArmorSwap = {}

-- TODO: Test for no armor in inventory and for no curently equipped armor
function ScootysArmorSwap.getNextArmorId(player) 
	wornArmor = player.get_inventory(defines.inventory.character_armor)[1]
	mainInventory = player.get_main_inventory()

	armorIds = {}

	-- Find all armors in inventory and get item_numbers from each
	for i=1, #mainInventory do
		stack = mainInventory[i]	
		if stack.valid_for_read then 
			if stack.is_armor then
				table.insert(armorIds, stack.item_number)
		  	end
		end
	end

	table.sort(armorIds)

	for i=1, #armorIds do
		if wornArmor.item_number < armorIds[i] then
			return armorIds[i]
		end
	end

	return armorIds[1]
end

function ScootysArmorSwap.findArmorById(inventory, armorId)
	for i=1, #inventory do
		stack = inventory[i]	
		if stack.valid_for_read then 
			if stack.is_armor and stack.item_number == armorId then
				return stack
		  	end
		else 
			break
		end
	end
	return nil
end

function ScootysArmorSwap.equipArmorWithId(player, armorId) 

	--Get the armors
	wornArmor = player.get_inventory(defines.inventory.character_armor)[1]
	newArmor = ScootysArmorSwap.findArmorById(player.get_main_inventory(), armorId)
	
	--Normally, swapping armor briefly removes inventory bonus slots which can cause the player
	--to drop items on the ground. Briefly expand the inventory to prevent this.
	player.character_inventory_slots_bonus = player.character_inventory_slots_bonus + 1000
	newArmor.swap_stack(wornArmor)
	player.character_inventory_slots_bonus = player.character_inventory_slots_bonus - 1000
end

function ScootysArmorSwap.onKeyPress (event)
  if event.player_index and game.players[event.player_index] and game.players[event.player_index].connected then
    local player = game.players[event.player_index]
    if player.character then
		armorId = ScootysArmorSwap.getNextArmorId(player)
		ScootysArmorSwap.equipArmorWithId(player, armorId)
    end
  end
end

Event.addListener("scootys-armor-swap", ScootysArmorSwap.onKeyPress)


