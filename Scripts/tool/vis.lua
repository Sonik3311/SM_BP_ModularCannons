dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"

Visualizer = class()


function Visualizer.server_onCreate( self )
end

function Visualizer.client_onCreate( self )
end

function Visualizer.client_onRefresh( self )
end

function Visualizer.cl_onEquipped( self )
	print("EQEQEEQEQ")
end

function Visualizer.cl_onUneqipped( self )
end

function Visualizer.client_onEquip( self )
	self:cl_onEquipped()
end
function Visualizer.client_onUnequip( self )
	self:cl_onUneqipped()
end


function Visualizer.client_onEquippedUpdate( self, primaryState, secondaryState )
	return true, true
end

function Visualizer.client_onUpdate( self, dt )
end
