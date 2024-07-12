dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"

Visualizer = class()


function Visualizer.server_onCreate( self )
end

function Visualizer.client_onCreate( self )
end

function Visualizer.client_onRefresh( self )
end

function Visualizer.cl_onEquipped( self )
end

function Visualizer.cl_onUneqipped( self )
    local path_amount = #sm.ACC.vis.paths
    for _, path in pairs(sm.ACC.vis.paths) do
        local lines = path.lines
        for line_id = 1, #lines do
            effect = lines[line_id][1]
            a = lines[line_id][2]
            effect:stop()
            a:stop()
        end
    end
end

function Visualizer.client_onEquip( self )
	self:cl_onEquipped()
end
function Visualizer.client_onUnequip( self )
	self:cl_onUneqipped()
end


function Visualizer.client_onEquippedUpdate( self, primaryState, secondaryState )
    local path_amount = #sm.ACC.vis.paths
    for _, path in pairs(sm.ACC.vis.paths) do
        local lines = path.lines
        for line_id = 1, #lines do
            effect = lines[line_id][1]
            a = lines[line_id][2]
            if not effect:isPlaying() then
                effect:start()
            end
            if not a:isPlaying() then
                a:start()
            end
        end
    end
	return true, true
end

function Visualizer.client_onUpdate( self, dt )
end
