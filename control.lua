--control.lua

require('event')

local ScootysArmorSwap = {}

-- TODO: Test for no armor in inventory and for no curently equipped armor
function ScootysArmorSwap.getNextArmorItemNumber(player) 
	wornArmor = player.get_inventory(defines.inventory.character_armor)[1]
	mainInventory = player.get_main_inventory()
	freeSlots = mainInventory.count_empty_stacks()

	armorItemNumbers = {}


	-- Find all armors in inventory and get item_numbers from each
	for i=1, #mainInventory do
		stack = mainInventory[i]	
		if stack.valid_for_read then 
			if stack.is_armor then
				-- If equipping this armor would cause the player to drop items, don't consider it.
				inventorySizeBonusChange = stack.prototype.inventory_size_bonus - wornArmor.prototype.inventory_size_bonus
				if freeSlots + inventorySizeBonusChange >= 0 then
					table.insert(armorItemNumbers, stack.item_number)
				end
		  	end
		end
	end

	-- Bail if there are no armors in inventory
	if #armorItemNumbers == 0 then 
		return nil
	end

	table.sort(armorItemNumbers)

	-- If not wearing any armor treat the item_number as 0
	wornArmorItemNumber = 0
	if wornArmor.is_armor then
		wornArmorItemNumber = wornArmor.item_number
	end

	-- Find the next armor in sequence by comparing item numbers
	for i=1, #armorItemNumbers do
		if wornArmorItemNumber < armorItemNumbers[i] then
			return armorItemNumbers[i]
		end
	end

	return armorItemNumbers[1]
end

function ScootysArmorSwap.findArmorByItemNumber(inventory, armorItemNumber)
	for i=1, #inventory do
		stack = inventory[i]	
		if stack.valid_for_read then 
			if stack.is_armor and stack.item_number == armorItemNumber then
				return stack
		  	end
		else 
			break
		end
	end
	return nil
end

function ScootysArmorSwap.equipArmorWithItemNumber(player, armorItemNumber) 

	--Get the armors
	wornArmor = player.get_inventory(defines.inventory.character_armor)[1]
	newArmor = ScootysArmorSwap.findArmorByItemNumber(player.get_main_inventory(), armorItemNumber)
	
	--Bail if no armor in inventory
	if newArmor == nil or wornArmor == nil then
		return
	end

	--Switch colors
	global.armorColors[tostring(wornArmor.item_number)] = player.color
	newColor = global.armorColors[tostring(armorItemNumber)]

	if newColor ~= nil then 
		player.color = newColor
	end

	--Switch armors
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
		armorItemNumber = ScootysArmorSwap.getNextArmorItemNumber(player)
		ScootysArmorSwap.equipArmorWithItemNumber(player, armorItemNumber)
    end
  end
end
Event.addListener("scootys-armor-swap", ScootysArmorSwap.onKeyPress)



function ScootysArmorSwap.on_init(event)
  global.armorColors = {}
end
Event.addListener("on_init", ScootysArmorSwap.on_init, true)


-- Helpful for debugging
--[[

/c	local player = game.player
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