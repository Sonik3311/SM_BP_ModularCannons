-- PRAISE BE TO THE RAGER'S TOOLS

--[[
    you know that you chose a wrong game to mod
    if you have to break it's rules to add a single little model
]]

--Hook script
g_currentModUuid = sm.json.open("$CONTENT_DATA/description.json").localId
local filePath = "$CONTENT_".. g_currentModUuid

isGameHooked = isGameHooked or false

function hook_dofile( name, bool )
	local openFile
	if not bool then
		bool = true
		openFiles = {
			dofile(filePath.. "/Scripts/hooks/CarryTool_replacements.lua"),
			dofile(filePath.. "/Scripts/hooks/"..name..".lua")
		}
	end
	return openFile, bool
end

--Creative Client Game Hook
local oldBindCommand = sm.game.bindChatCommand

function bindCommandHook(command, params, callback, help)
	oldBindCommand(command, params, callback, help)
	local openFiles, bool = hook_dofile( "inject", isGameHooked )
	isGameHooked = bool
	return openFiles
end

sm.game.bindChatCommand = bindCommandHook
