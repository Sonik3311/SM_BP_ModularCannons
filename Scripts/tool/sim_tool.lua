--[[
    Class responsible for processing projectiles
    and drawing their effects
]]

-------------------------------------------------------------------------------
--[[                                Setup                                  ]]--
-------------------------------------------------------------------------------

dofile "$CONTENT_DATA/Scripts/shell_sim.lua"
dofile "$CONTENT_DATA/Scripts/effects.lua"

SimTool = class()
SimTool.sv_instance = nil
SimTool.cl_instance = nil

local tick_time = 0.025

-------------------------------------------------------------------------------
--[[                                Create                                 ]]--
-------------------------------------------------------------------------------

function SimTool:server_onCreate()
    print("Trying to create Server")
    if SimTool.sv_instance ~= nil then
        return
    end
    SimTool.sv_instance = self
    sm.ACC = {}
    sm.ACC.shells = {}
    print("Server Created")
end

function SimTool:client_onCreate()
    print("Trying to create Client")
    if SimTool.cl_instance ~= nil then
        return
    end
    SimTool.cl_instance = self

    if not sm.ACC then
        sm.ACC = {}
    end
    sm.ACC.vis = {}
    sm.ACC.vis.paths = {}
    print("Client Created")
    self.time_since_last_tick = 0
    self.effects = {}
end

-------------------------------------------------------------------------------
--[[                             Fixed Update                              ]]--
-------------------------------------------------------------------------------

function SimTool:server_onFixedUpdate(dt)
    if SimTool.sv_instance ~= self then
        return
    end

    if not sm.ACC or not sm.ACC.shells then
        return
    end

    update_shells(sm.ACC.shells, dt, self.network)
end

function SimTool:client_onFixedUpdate(dt)
    if SimTool.cl_instance ~= self then
        return
    end

    for key, effect in pairs(self.effects) do
        if effect:isDone() then
            effect:destroy()
            self.effects[key] = nil
        end
    end
end

-------------------------------------------------------------------------------
--[[                                Update                                 ]]--
-------------------------------------------------------------------------------

function SimTool:server_onUpdate(dt)
end

function SimTool:client_onUpdate(dt)
    self.time_since_last_tick = self.time_since_last_tick + dt
    if self.time_since_last_tick >= tick_time then
       self.time_since_last_tick = self.time_since_last_tick % tick_time
    end

    local time_fraction = self.time_since_last_tick / tick_time
    --print(time_fraction)
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]]--
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--[[                            Network Client                             ]]--
-------------------------------------------------------------------------------

function SimTool:cl_play_entry_effect(data)
    if SimTool.cl_instance ~= self then
        return
    end

    local effect = get_entry_effect(data)
    effect:start()
    self.effects[#self.effects + 1] = effect
end

function SimTool:cl_save_path(data)
    dprint("recieved path with the length of "..tostring(#data.path.shell + #data.path.spall), "info", dprint_filename, nil, "cl_save_path")
    local spall_path = data.path.spall
    local shell_path = data.path.shell
    local hit_creations = data.path.creations
    local ACC_index = #sm.ACC.vis.paths + 1
    sm.ACC.vis.paths[ACC_index] = {}
    sm.ACC.vis.paths[ACC_index].lines = {}


    local is_spall = true
    for _,path in pairs({spall_path, shell_path}) do
        for line_id = 1, #path do
            local thickness = 0.025
            if not is_spall then
               thickness = 0.05
            end
            local line = path[line_id]

            if #line ~= 2 then
                goto next
            end

            local effect = sm.effect.createEffect("ShapeRenderable")
            effect:setParameter("uuid", sm.uuid.new("3e3242e4-1791-4f70-8d1d-0ae9ba3ee94c"))

            if not is_spall then effect:setParameter("color", sm.color.new("ffffff"))
            else effect:setParameter("color", sm.color.new(math.random(70,90)/90, math.random(40,60)/60, math.random(40,60)/60)) end

            effect:setScale( sm.vec3.one() * thickness )
            local delta = line[2] - line[1]
            local length = delta:length()

            if length < 0.0001 then goto next end

            local rot = sm.vec3.getRotation(sm.vec3.new(1,0,0), delta)

            local distance = sm.vec3.new(length, thickness, thickness)

            effect:setPosition(line[1] + delta * 0.5)
            effect:setScale(distance)
            effect:setRotation(rot)
            local a = sm.effect.createEffect("ShapeRenderable")
            a:setParameter("uuid", sm.uuid.new("3e3242e4-1791-4f70-8d1d-0ae9ba3ee94c"))
            a:setParameter("color", sm.color.new("ff0000"))
            a:setScale( sm.vec3.one() * (thickness * 1.5) )
            a:setPosition(line[1])
            local line_index = #sm.ACC.vis.paths[ACC_index].lines + 1
            sm.ACC.vis.paths[ACC_index].lines[line_index] = {effect, a}
            ::next::
        end
        is_spall = false
    end
end
