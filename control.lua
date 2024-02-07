--control.lua
require('event')

-- Setup & Init Event
log("Scooty's Armor Swap Setup")
local ScootysArmorSwap = {}

function ScootysArmorSwap.on_init(event)
  log("Scooty's Armor Swap")
end

------------
-- Logging
------------

-- Recursively converts a table to a string
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Gets the keys of a table as a string
local function getKeys(t)
  local strKeys = "[\n"
  for key,_ in pairs(t) do
    strKeys = strKeys .. "\t" .. key .. ",\n"
  end
  strKeys = strKeys .. "]"
  return strKeys
end

-- Prints to player console
function pLog(player, message, obj)
  if player == nil then
    return
  end

  if obj ~= nil then
    message = message .. ": " .. type(obj) .. ": " .. dump(obj)
  end

  player.print(message)
end


-----------------------------
-- Key Press Event Handlers
-----------------------------

function ScootysArmorSwap.keyPressHandlerEquipNextArmor(event)
  log("keyPressHandlerEquipNextArmor")
  if event.player_index and game.players[event.player_index] and game.players[event.player_index].connected then
    local luaPlayer = game.players[event.player_index]
    if luaPlayer.character then
      armorItemNumber = ScootysArmorSwap.getNextArmorItemNumber(luaPlayer)

      if armorItemNumber ~= nil then
        ScootysArmorSwap.equipArmorWithItemNumber(luaPlayer, armorItemNumber)
      end
    end
  end
end

function ScootysArmorSwap.KeyPressHandlerClearCache(event)
  log("KeyPressHandlerClearCache")
  global.armorColors = {}
  global.armorColorsBackup = {}
end

----------------------
-- Utility Functions
----------------------

-- TODO: Test for no armor in inventory and for no curently equipped armor
function ScootysArmorSwap.getNextArmorItemNumber(luaPlayer) 

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

-- Used by equipArmorWithItemNumber to convert the inventory item number to the actual item stack
function ScootysArmorSwap.findArmorByItemNumber(luaInventory, armorItemNumber)
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

-- Swaps the the currently equipped armor with the specified item number in the inventory and updates player color
function ScootysArmorSwap.equipArmorWithItemNumber(luaPlayer, armorItemNumber) 

  --Get the armors
  luaItemStackWornArmor = luaPlayer.get_inventory(defines.inventory.character_armor)[1]
  luaItemStackNewArmor = ScootysArmorSwap.findArmorByItemNumber(luaPlayer.get_main_inventory(), armorItemNumber)

  if luaItemStackNewArmor == nil or not luaItemStackNewArmor.valid_for_read then
    log("Next armor can't be read")
    return
  end

  cyclePlayerColor(luaPlayer, luaItemStackWornArmor, luaItemStackNewArmor)

  --Switch armors
  --Normally, swapping armor briefly removes inventory bonus slots which can cause the player
  --to drop items on the ground. Briefly expand the inventory to prevent this.
  luaPlayer.character_inventory_slots_bonus = luaPlayer.character_inventory_slots_bonus + 1000
  luaItemStackNewArmor.swap_stack(luaItemStackWornArmor)
  luaPlayer.character_inventory_slots_bonus = luaPlayer.character_inventory_slots_bonus - 1000  
end

function cyclePlayerColor(luaPlayer, luaItemStackWornArmor, luaItemStackNewArmor)
    -- validate color caches
  if global.armorColors == nil then
    log("armorColors is nil, creating table")
    global.armorColors = {}
  end

  if global.armorColorsBackup == nil then
    log("armorColorsBackup is nil, creating table")
    global.armorColorsBackup = {}
  end


  if luaItemStackWornArmor.is_armor then
    log("Wearing armor")

    -- Save current color
    wornArmorKey = luaItemStackWornArmor.item_number
    wornArmorKeyBackup = ScootysArmorSwap.makeArmorBackupKey(luaItemStackWornArmor)

    global.armorColors[wornArmorKey] = luaPlayer.color
    global.armorColorsBackup[wornArmorKeyBackup] = luaPlayer.color
  end

  -- Load color for new armor
  newArmorKey = luaItemStackNewArmor.item_number
  newArmorKeyBackup = ScootysArmorSwap.makeArmorBackupKey(luaItemStackNewArmor)
  colorNew = global.armorColors[newArmorKey]

  if colorNew ~= nil then 
    log("Found " .. newArmorKey .. " in armorColors: " .. getKeys(global.armorColors) )
    luaPlayer.color = colorNew
    return
  end

  -- Try to get the color from the backup
  log("Could not find next armor's key " .. newArmorKey .. " in armorColors: " .. getKeys(global.armorColors) .. "")
  
  colorNew = global.armorColorsBackup[newArmorKeyBackup]

  if colorNew ~= nil then
    log("Found " .. newArmorKeyBackup .. " in armorColorsBackup: " .. getKeys(global.armorColorsBackup) )
    luaPlayer.color = colorNew
    return
  end

  log("Could not find next armor's backup key " .. newArmorKeyBackup .. " in armorColorsBackup: " .. dump(getKeys(global.armorColorsBackup)) .. ". Bailing.")
end


-- Item numbers are usually a very stable way of "primary key"ing an item
-- Sometimes as a shortcut, mods will clone items instead of physically transporting them. When this happens, the item number is no 
-- longer a valid primary key. Given that, we make a backup table of colors using a fuzzier match of the armor name plus its grid contents
function ScootysArmorSwap.makeArmorBackupKey(luaItemStackArmor)

  -- concat the armor's name to the contents of its grid
  gridContents = ""
  if luaItemStackArmor.grid ~= nil then
    gridContents = dump(luaItemStackArmor.grid.get_contents())
  end
  local hashInput = luaItemStackArmor.name .. gridContents

  -- Hash the string
  return hash(hashInput)
end

-- Gets a numerical hash of a string
local b = bit32 or try(require, 'bit') or error("No bitop lib found")
function hash(o)
  local t = type(o)
  if t ~= 'string' then
    return nil
  end

  local len = #o
  local h = len
  local step = b.rshift(len, 5) + 1

  for i=len, step, -step do
    h = b.bxor(h, b.lshift(h, 5) + b.rshift(h, 2) + string.byte(o, i))
  end
  return h
end

--------------------
-- Event Listeners 
--------------------

-- Note - these must be added last, after the funcs are defined
Event.addListener("on_init", ScootysArmorSwap.on_init, true)
Event.addListener("scootys-armor-swap-equip-next-armor", ScootysArmorSwap.keyPressHandlerEquipNextArmor)
Event.addListener("scootys-armor-swap-clear-cache", ScootysArmorSwap.KeyPressHandlerClearCache)

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