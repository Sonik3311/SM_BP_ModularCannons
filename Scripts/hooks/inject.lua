g_customGame, gameClassName = false, "CreativeGame"
print("Custom Game:", g_customGame)

function hookToGameFunction( name )
	if _G[name] then
		local oldGameLoadingScreenLifted = _G[name].client_onLoadingScreenLifted or function() end

		function gameLoadingScreenLiftedHook( self )
			sm.log.info(name.." gameLoadingScreenLiftedHooked")
			sm.log.info("| Starting hook process...")

			oldGameLoadingScreenLifted( self )
			newScriptFunctions()
		end

		_G[name].client_onLoadingScreenLifted = gameLoadingScreenLiftedHook
	end
end

local gameClassName = "SurvivalGame"

if not g_customGame then
	if not _G[gameClassName] then
		gameClassName = "CreativeGame"
		local gameList = {"CreativeFlatGame", "ClassicCreativeGame", "CreativeCustomGame", "CreativeTerrainGame"}
		for k,name in pairs(gameList) do
			hookToGameFunction( name )
		end
	end
else
	customGame_config = sm.json.open("$CONTENT_DATA/config.json")
	gameClassName = customGame_config.gameScript.class or gameClassName
end

hookToGameFunction( gameClassName )



function newScriptFunctions()
	function HookCarry( class )
	    if not _G[class] then
			sm.log.warning("| - CarryTool not found, skipping")
			return
		end
		sm.log.info("| ├ Hooking cl_updateCarryRenderables")
		_G[class].cl_updateCarryRenderables = repl_cl_updateCarryRenderables
		sm.log.info("| ├ Hooking cl_loadAnimations")
		_G[class].cl_loadAnimations = repl_cl_loadAnimations
		sm.log.info("| ├ Hooking client_onEquippedUpdate")
		_G[class].client_onEquippedUpdate = repl_client_onEquippedUpdate
		sm.log.info("| ├ Hooking sv_n_dropCarry")
		_G[class].sv_n_dropCarry = repl_sv_n_dropCarry
		sm.log.info("| - CarryTool hooked")
	end

	sm.log.info("├ Hooking CarryTool")
	HookCarry("CarryTool")
end
