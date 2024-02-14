StringUtils = {}

-- Gets a numerical hash of a string
local b = bit32 or try(require, 'bit') or error("No bitop lib found")
function StringUtils.hash(o)
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

-- Converts anything to a string
function StringUtils.toString(val)
  if not val then
  	return "nil"
  end

  

  -- Tables
  if type(val) == 'table' then

  	-- Factorio's classes are tables that only have {__self = "userdata"}
  	-- According to https://forums.factorio.com/viewtopic.php?t=33877 you can look up their properties here: https://lua-api.factorio.com/latest/classes.html
  	-- We're not about to write and maintain a gigantic mapping of all the possible members on all possible LuaEntities so that we can generically print them 
  	-- to the log.
  	-- Thankfully, almost all classes have an object_name field, typically inherited from LuaEntity or LuaPlayer
  	if type(val.__self) == 'userdata' then
        ret = val.object_name
        if ret then
          	return "[Factorio." .. ret .. "]"
        end
  	end

    -- Uses https://github.com/pkulchenko/serpent
    return serpent.block(val)

    -- Regular table
    -- local ret = '{ '
    -- for k,v in pairs(val) do
    --   if type(k) ~= 'number' then 
    --     k = '"'..k..'"' 
    --   end
    --   
    --   -- Recursively convert values
    --   ret = ret .. '['..k..'] = ' .. StringUtils.toString(v) .. ','
    -- end

    -- return ret .. '} '

  end




  return tostring(val)
end

-- Gets the keys of a table as a string
function StringUtils.getKeys(t)
  local strKeys = "[\n"
  for key,_ in pairs(t) do
    strKeys = strKeys .. "\t" .. key .. ",\n"
  end
  strKeys = strKeys .. "]"
  return strKeys
end

return StringUtils