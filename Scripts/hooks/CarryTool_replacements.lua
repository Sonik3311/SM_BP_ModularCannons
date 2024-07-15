local scrapwoodRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_scrapwood.rend"
}

local stoneRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_stone.rend"
}

local scrapmetalRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_scrapmetal.rend"
}

local woodRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_wood.rend"
}

local metalRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_metal.rend"
}

local harvestItems =
{
	obj_harvest_wood,
	obj_harvest_wood2,
	obj_harvest_metal,
	obj_harvest_metal2,
	obj_harvest_stone
}

local heavyRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool.rend"
}

local wormRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp.rend"
}

local renderablesItemTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_item.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_tp_animlist.rend" }
local renderablesItemFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_item.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_fp_animlist.rend" }

local renderablesHeavyTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_heavytool.rend", "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_tp_animlist.rend" }
local renderablesHeavyFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_heavytool.rend", "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_fp_animlist.rend" }

local renderablesWormTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_toolgorp.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp_tp.rend" }
local renderablesWormFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_toolgorp.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp_fp.rend" }


CarryTool.emptyTpRenderables = {}
CarryTool.emptyFpRenderables = {}

sm.tool.preloadRenderables( scrapwoodRenderables )
sm.tool.preloadRenderables( stoneRenderables )
sm.tool.preloadRenderables( scrapmetalRenderables )
sm.tool.preloadRenderables( woodRenderables )
sm.tool.preloadRenderables( metalRenderables )
sm.tool.preloadRenderables( heavyRenderables )
sm.tool.preloadRenderables( wormRenderables )
sm.tool.preloadRenderables( renderablesItemTp )
sm.tool.preloadRenderables( renderablesItemFp )
sm.tool.preloadRenderables( renderablesHeavyTp )
sm.tool.preloadRenderables( renderablesHeavyFp )
sm.tool.preloadRenderables( renderablesWormTp )
sm.tool.preloadRenderables( renderablesWormFp )


function repl_cl_loadAnimations( self, activeUid )
    local harvestItems = {
        obj_harvest_wood,
        obj_harvest_wood2,
        obj_harvest_metal,
        obj_harvest_metal2,
        obj_harvest_stone
    }

	if isAnyOf( activeUid, harvestItems ) or activeUid == sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188") then
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "item_idle", { looping = true } },
				sprint = { "item_sprint_idle" },
				pickup = { "item_pickup", { nextAnimation = "idle" } },
				putdown = { "item_putdown" }

			}
		)
		local movementAnimations = {

			idle = "item_idle",

			runFwd = "item_run",
			runBwd = "item_runbwd",

			sprint = "item_sprint_idle",

			jump = "item_jump",
			jumpUp = "item_jump_up",
			jumpDown = "item_jump_down",

			land = "item_jump_land",
			landFwd = "item_jump_land_fwd",
			landBwd = "item_jump_land_bwd",

			crouchIdle = "item_crouch_idle",
			crouchFwd = "item_crouch_run",
			crouchBwd = "item_crouch_runbwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "item_idle", { looping = true } },

					sprintInto = { "item_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "item_sprint_idle", { looping = true } },
					sprintExit = { "item_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					equip = { "item_pickup", { nextAnimation = "idle" } },
					unequip = { "item_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	elseif activeUid == obj_character_worm then
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "toolgorp_idle", { looping = true } },
				sprint = { "toolgorp_sprint" },
				pickup = { "toolgorp_pickup", { nextAnimation = "idle" } },
				putdown = { "toolgorp_putdown" }

			}
		)
		local movementAnimations = {

			idle = "toolgorp_idle",

			runFwd = "toolgorp_run_fwd",
			runBwd = "toolgorp_run_bwd",

			sprint = "toolgorp_sprint",

			jump = "toolgorp_jump",
			jumpUp = "toolgorp_jump_up",
			jumpDown = "toolgorp_jump_down",

			land = "toolgorp_jump_land",
			landFwd = "toolgorp_jump_land_fwd",
			landBwd = "toolgorp_jump_land_bwd",

			crouchIdle = "toolgorp_crouch_idle",
			crouchFwd = "toolgorp_crouch_fwd",
			crouchBwd = "toolgorp_crouch_bwd",

			swimIdle = "toolgorp_swim_idle",
			swimFwd = "toolgorp_swim_fwd",
			swimBwd = "toolgorp_swim_bwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "toolgorp_idle", { looping = true } },

					sprintInto = { "toolgorp_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "toolgorp_sprint_idle", { looping = true } },
					sprintExit = { "toolgorp_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					jump = { "toolgorp_jump", { nextAnimation = "idle" } },
					land = { "toolgorp_jump_land", { nextAnimation = "idle" } },

					equip = { "toolgorp_pickup", { nextAnimation = "idle" } },
					unequip = { "toolgorp_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	elseif activeUid ~= nil and activeUid ~= sm.uuid.getNil() then
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "heavytool_idle", { looping = true } },
				sprint = { "heavytool_sprint_idle" },
				pickup = { "heavytool_pickup", { nextAnimation = "idle" } },
				putdown = { "heavytool_putdown" }

			}
		)
		local movementAnimations = {

			idle = "heavytool_idle",

			runFwd = "heavytool_run",
			runBwd = "heavytool_runbwd",

			sprint = "heavytool_sprint_idle",

			jump = "heavytool_jump",
			jumpUp = "heavytool_jump_up",
			jumpDown = "heavytool_jump_down",

			land = "heavytool_jump_land",
			landFwd = "heavytool_jump_land_fwd",
			landBwd = "heavytool_jump_land_bwd",

			crouchIdle = "heavytool_crouch_idle",
			crouchFwd = "heavytool_crouch_run",
			crouchBwd = "heavytool_crouch_runbwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "heavytool_idle", { looping = true } },

					sprintInto = { "heavytool_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "heavytool_sprint_idle", { looping = true } },
					sprintExit = { "heavytool_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					equip = { "heavytool_pickup", { nextAnimation = "idle" } },
					unequip = { "heavytool_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	end
end

function repl_cl_updateCarryRenderables( self, activeUid, activeColor ) -- REPLACE

	local obj_generic_apfsds = sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188")
	local genericAPFSDSrenderables = {"$CONTENT_c1518670-9e34-4dbc-84d3-86ccbcd50a25/Objects/Renderables/APFSDS_template.rend"}

    local carryRenderables = {}
	local animationRenderablesTp = {}
	local animationRenderablesFp = {}

	if activeUid == sm.uuid.getNil() or activeUid == nil then
		animationRenderablesTp = self.emptyTpRenderables
		animationRenderablesFp = self.emptyFpRenderables
		self.emptyTpRenderables = {}
		self.emptyFpRenderables = {}
	elseif activeUid == obj_harvest_wood then
		carryRenderables = scrapwoodRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_harvest_metal then
		carryRenderables = scrapmetalRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_harvest_stone then
		carryRenderables = stoneRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif  activeUid == obj_harvest_wood2 then
		carryRenderables = woodRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif  activeUid == obj_harvest_metal2 then
		carryRenderables = metalRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_character_worm then
		carryRenderables = wormRenderables
		animationRenderablesTp = renderablesWormTp
		animationRenderablesFp = renderablesWormFp
	elseif activeUid == obj_generic_apfsds then
	    print("APFSFPS")
        carryRenderables = genericAPFSDSrenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	else
		carryRenderables = heavyRenderables
		animationRenderablesTp = renderablesHeavyTp
		animationRenderablesFp = renderablesHeavyFp
	end

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	for k,v in pairs( animationRenderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( animationRenderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.emptyTpRenderables = shallowcopy( animationRenderablesTp )
	self.emptyFpRenderables = shallowcopy( animationRenderablesFp )

	for k,v in pairs( carryRenderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( carryRenderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.tool:setTpRenderables( currentRenderablesTp )
	self.tool:setTpColor( activeColor )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
		self.tool:setFpColor( activeColor )
	end

end
