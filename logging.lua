Logging = {
	debugBuildTime = "DEBUG_BUILD_TIME"
} 

--[[ sasLog
Wrapper for log. Adds a header with:
An emoji to help find stuff in ~/Library/Application\ Support/factorio/factorio-current.log
The function name
The time of the last deploy to help make sure the most recent version is the one being tested.

Note: It would be preferable to just bump the build number in info.json on every deploy but sadly
factorio doesn't recognize changes to info.json unless you re-launch the app.
--]]
function Logging.sasLog(message)

  -- If DEBUG_BUILD_TIME hasn't been set then this is likely an install from the mod finder
  -- Don't log anything to keep the log from filling up with debug messages
  if Logging.debugBuildTime == "DEBUG_BUILD_TIME" then
    return
  end

	-- Get all debug info (See https://www.lua.org/pil/23.1.html)
	local debugInfo = debug.getinfo(2, "Sln") or {}

	local header = "🛡️  Deployed " 
		.. (Logging.debugBuildTime or "[DEBUG_BUILD_TIME nil]") 
		.. " " 
		.. (debugInfo.source or "[source file nil]") 
		.. " " 
		.. (debugInfo.name or "[function name nil]")
		.. " ["
		.. (debugInfo.currentline or "[line number nil]")
		.. "]"

	-- Add a colon if neccessary
	if message then
		message = header .. ": " .. StringUtils.toString(message)
	else
		message = header
	end

	-- Write to log
	log(message)
end

-- Prints to player console
function Logging.pLog(luaPlayer, message)

	local message = StringUtils.toString(message)
	Logging.sasLog("Messaging " .. StringUtils.toString(luaPlayer) .. " named \"" .. (luaPlayer.name or "nil") .. "\": " .. message)

	if luaPlayer and luaPlayer.print then
		-- Write to player screen
		luaPlayer.print(message)
	else
		Logging.sasLog("Invalid luaPlayer")
	end

end

return Logging