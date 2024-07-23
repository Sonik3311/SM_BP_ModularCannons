dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$CONTENT_DATA/Scripts/effects.lua"

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
    for path_id, path in pairs(sm.ACC.vis.paths) do
        local lines = path.lines
        for line_id = 1, #lines do
            effect = lines[line_id][1]
            a = lines[line_id][2]
            if secondaryState ~= 0 then
                effect:stopImmediate()
                a:stopImmediate()
                effect:destroy()
                a:destroy()
                lines[line_id] = nil
            else
                if not effect:isPlaying() then
                    effect:start()
                end
                if not a:isPlaying() then
                    a:start()
                end
            end
        end
        if secondaryState ~= 0 then
            path[path_id] = nil
        end
    end
    if secondaryState ~= 0 then
        sm.gui.displayAlertText( "Debug paths cleared", 1.5 )
    end

	return true, true
end

function Visualizer.client_onUpdate( self, dt )
end
