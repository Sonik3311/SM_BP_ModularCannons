--dofile "$CONTENT_DATA/Scripts/hooks/CarryTool_replacements.lua"

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

	--[[function HookPlayer( class )

		old_onInteract = _G[class].client_onInteract or function() end
		function new_onInteract( self, character, state )
			local old_return = old_onInteract( self, character, state ) or false

			player_state_onInteract = state
			print("Interact")
			return old_return
		end
		_G[class].client_onInteract = new_onInteract


		old_onReload = _G[class].client_onReload or function() end
		function new_onReload( self )
			local old_return = old_onReload(self) or false
			return old_return
		end
		_G[class].client_onReload = new_onReload

	end

	HookPlayer("CreativePlayer")]]

	function HookCarry( class )
	    if not _G[class] then
			sm.log.warning("| | CarryTool not found, skipping")
			return
		end
		_G[class].cl_updateCarryRenderables = repl_cl_updateCarryRenderables
		_G[class].cl_loadAnimations = repl_cl_loadAnimations
		sm.log.info("| - CarryTool hooked")
	end
	sm.log.info("├ Hooking CarryTool")
	HookCarry("CarryTool")


	--Harvestables event - hooks to hit them by events
	--if WoodHarvestable then
	--	function WoodHarvestable.sv_e_onHit( self, params )
	--		self:sv_onHit( params.damage, params.position )
	--	end
	--end
	--if StoneHarvestable then
	--	function StoneHarvestable.sv_e_onHit( self, params )
	--		self:sv_onHit( params.damage, params.position )
	--	end
	--end
end
