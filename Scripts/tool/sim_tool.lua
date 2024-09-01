--[[
    Class responsible for processing projectiles
    and drawing their effects
]]

-------------------------------------------------------------------------------
--[[                                Setup                                  ]] --
-------------------------------------------------------------------------------

dofile "$CONTENT_DATA/Scripts/shell_sim.lua"
dofile "$CONTENT_DATA/Scripts/effects.lua"
dofile "$CONTENT_DATA/Scripts/dprint.lua"

SimTool = class()
SimTool.sv_instance = nil
SimTool.cl_instance = nil

local tick_time = 0.025
local dprint_filename = "SimTool"

-------------------------------------------------------------------------------
--[[                                Create                                 ]] --
-------------------------------------------------------------------------------

function SimTool:server_onCreate()
    dprint("Trying to create Server", "info", dprint_filename, "sv", "onCreate")
    if SimTool.sv_instance ~= nil then
        return
    end
    SimTool.sv_instance = self
    sm.ACC = {}
    sm.ACC.shells = {}
    sm.ACC.debug = true
    dprint("Server successfuly created", "info", dprint_filename, "sv", "onCreate")
end

function SimTool:client_onCreate()
    dprint("Trying to create Client", "info", dprint_filename, "cl", "onCreate")
    if SimTool.cl_instance ~= nil then
        return
    end
    SimTool.cl_instance = self
    dprint("Client successfuly created", "info", dprint_filename, "cl", "onCreate")
    if not sm.ACC then
        sm.ACC = {}
        sm.ACC.shells = {}
    end
    sm.ACC.vis = {}
    sm.ACC.vis.paths = {}
    self.time_since_last_tick = 0
    self.effects = {}
    self.tracers_per_projectile = {}
end

-------------------------------------------------------------------------------
--[[                             Fixed Update                              ]] --
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

    if not sm.isHost then
        for shell_id, shell in pairs(sm.ACC.shells) do
            shell.velocity = shell.velocity - sm.vec3.new(0, 0, 20 * dt)
            shell.position = shell.next_position
            shell.next_position = shell.position + shell.velocity * dt
        end
    end

    for key, effect in pairs(self.effects) do
        if effect:isDone() then
            effect:destroy()
            self.effects[key] = nil
        end
    end

    for tracer_id, tracer in pairs(self.tracers_per_projectile) do
        if not sm.ACC.shells[tracer_id] then
            tracer:stopImmediate()
            tracer:destroy()
            self.tracers_per_projectile[tracer_id] = nil
        end
    end
end

-------------------------------------------------------------------------------
--[[                                Update                                 ]] --
-------------------------------------------------------------------------------

function SimTool:server_onUpdate(dt)
end

function SimTool:client_onUpdate(dt)
    if SimTool.cl_instance ~= self then
        return
    end
    self.time_since_last_tick = self.time_since_last_tick + dt
    if self.time_since_last_tick >= tick_time then
        self.time_since_last_tick = self.time_since_last_tick % tick_time
    end

    local time_fraction = self.time_since_last_tick / tick_time
    for shell_id, shell in pairs(sm.ACC.shells) do
        if self.tracers_per_projectile[shell_id] == nil then
            self.tracers_per_projectile[shell_id] = sm.effect.createEffect("ShapeRenderable")
            self.tracers_per_projectile[shell_id]:setParameter("uuid",
                sm.uuid.new("01246ab4-e30c-4d77-a15a-8fc110a29723")) --"01246ab4-e30c-4d77-a15a-8fc110a29723"
            local diameter_factor = (shell.barrel_diameter / 150)
            local sp = math.max(1, shell.velocity:length() / 100)
            print(sp)
            self.tracers_per_projectile[shell_id]:setScale(sm.vec3.new(diameter_factor, 4 * diameter_factor * sp,
                diameter_factor))
            self.tracers_per_projectile[shell_id]:start()
        end
        local effect = self.tracers_per_projectile[shell_id]
        if not effect:isPlaying() then
            effect:start()
        end
        local rotation = sm.vec3.getRotation(sm.vec3.new(0, 1, 0), shell.velocity:normalize())
        effect:setRotation(rotation)
        effect:setPosition(sm.vec3.lerp(shell.position, shell.next_position, time_fraction))
    end
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]] --
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--[[                            Network Client                             ]] --
-------------------------------------------------------------------------------

function SimTool:cl_kill_client_shell(shell_id)
    sm.ACC.shells[shell_id] = nil
end

function SimTool:cl_play_entry_effect(data)
    if SimTool.cl_instance ~= self then
        return
    end

    local effect = get_entry_effect(data)
    effect:start()
    self.effects[#self.effects + 1] = effect
end

function SimTool:cl_play_spall_effects(data)
    if SimTool.cl_instance ~= self then
        return
    end
    dprint("Creating " .. tostring(#data) .. " effects for spall", "info", dprint_filename, nil, "cl_play_spall_effects")
    for effect_data_id = 1, #data do
        local effect_data = data[effect_data_id]
        local position = effect_data[1]
        local direction = effect_data[2]
        local color = effect_data[3]
        local effect = sm.effect.createEffect("Debris impact")

        effect:setPosition(position)
        effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0, 1, 0), -direction))
        effect:setParameter("Color", color)
        effect:start()

        self.effects[#self.effects + 1] = effect
    end
end

function SimTool:cl_save_path(data)
    if SimTool.cl_instance ~= self then
        return
    end

    if not sm.ACC.debug then
        return
    end
    dprint("recieved path with the length of " .. tostring(#data.path.shell + #data.path.spall), "info", dprint_filename,
        nil, "cl_save_path")
    local spall_path = data.path.spall
    local shell_path = data.path.shell
    local hit_creations = data.path.creations
    local ACC_index = #sm.ACC.vis.paths + 1
    sm.ACC.vis.paths[ACC_index] = {}
    sm.ACC.vis.paths[ACC_index].lines = {}

    local is_spall = true
    for _, path in pairs({ spall_path, shell_path }) do
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

            if not is_spall then
                effect:setParameter("color", sm.color.new("ffffff"))
            else
                effect:setParameter("color",
                    sm.color.new(math.random(70, 90) / 90, math.random(40, 60) / 60, math.random(40, 60) / 60))
            end

            effect:setScale(sm.vec3.one() * thickness)
            local delta = line[2] - line[1]
            local length = delta:length()

            if length < 0.0001 then goto next end

            local rot = sm.vec3.getRotation(sm.vec3.new(1, 0, 0), delta)

            local distance = sm.vec3.new(length, thickness, thickness)

            effect:setPosition(line[1] + delta * 0.5)
            effect:setScale(distance)
            effect:setRotation(rot)
            local a = sm.effect.createEffect("ShapeRenderable")
            a:setParameter("uuid", sm.uuid.new("3e3242e4-1791-4f70-8d1d-0ae9ba3ee94c"))
            a:setParameter("color", sm.color.new("ff0000"))
            a:setScale(sm.vec3.one() * (thickness * 1.5))
            a:setPosition(line[1])
            local line_index = #sm.ACC.vis.paths[ACC_index].lines + 1
            sm.ACC.vis.paths[ACC_index].lines[line_index] = { effect, a }
            ::next::
        end
        is_spall = false
    end
end
