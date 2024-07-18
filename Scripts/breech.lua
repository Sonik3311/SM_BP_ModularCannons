--[[
    Class responsible for launching the projectile and
    for adjusting Breech's properties based on the connected modules
]]

-------------------------------------------------------------------------------
--[[                                Setup                                  ]]--
-------------------------------------------------------------------------------

local dprint_filename = "Breech"

dofile "$CONTENT_DATA/Scripts/dprint.lua"
dofile "$CONTENT_DATA/Scripts/breech_functions.lua"
dofile "$CONTENT_DATA/Scripts/pen_calc.lua"
dofile "$CONTENT_DATA/Scripts/shell_sim.lua"
dofile "$CONTENT_DATA/Scripts/effects.lua"

Breech = class()

Breech.maxParentCount = 1
Breech.maxChildCount = 0
Breech.connectionInput = sm.interactable.connectionType.logic
Breech.connectionOutput = sm.interactable.connectionType.none

-------------------------------------------------------------------------------
--[[                                Create                                 ]]--
-------------------------------------------------------------------------------

function Breech:server_onCreate()
    self.barrel_shapes = construct_cannon_new(self.shape, self.shape:getAt())

    self.barrel_length = #self.barrel_shapes
    self.muzzle_shape = self.barrel_length > 0 and self.barrel_shapes[#self.barrel_shapes] or nil
    self.barrel_diameter = 100 --mm
    update_barrel_diameter(self.barrel_shapes, self.barrel_diameter)
    self.fired_shells = {}

    --self.loaded_shell = {
    --    type = "APFSDS",
    --    parameters = {
    --        propellant = 7,
    --        projectile_mass = 12,
    --        diameter = 27,
    --        penetrator_length = 700,
    --        penetrator_density = 17800
    --    }
    --}

    --local volume_sphere = 0.5 * (4/3) * math.pi * (self.barrel_diameter / 2000)^3
    --local volume_cylinder = (self.barrel_diameter / 2000)^2 * math.pi * (2.5*self.barrel_diameter/1000 - self.barrel_diameter/2000)
    --local mass = (volume_sphere + volume_cylinder) * 7850
    --self.loaded_shell = {
    --    type = "AP",
    --    parameters = {
    --        propellant = 6,
    --        projectile_mass = mass,
    --        diameter = self.barrel_diameter,
    --        is_apcbc = true
    --    }
    --}

    local volume_sphere = 0.5 * (4/3) * math.pi * (self.barrel_diameter / 2000)^3
    local volume_cylinder = (self.barrel_diameter / 2000)^2 * math.pi * (2.5*self.barrel_diameter/1000 - self.barrel_diameter/2000)
    local mass = (volume_sphere + volume_cylinder) * 7850
    print(mass)
    self.loaded_shell = {
        type = "APHE",
        parameters = {
            propellant = 6,
            projectile_mass = mass,
            diameter = self.barrel_diameter,
            is_apcbc = true,

            explosive_mass = 5, --kg
        },
        fuse = {
            active = false,
            delay = 0.001, --seconds
            trigger_depth = 10 --mm
        }
    }

    --local volume_sphere = 0.5 * (4/3) * math.pi * (self.barrel_diameter / 2000)^3
    --local volume_cylinder = (self.barrel_diameter / 2000)^2 * math.pi * (2.5*self.barrel_diameter/1000 - self.barrel_diameter/2000)
    --local mass = (volume_sphere + volume_cylinder) * 6000

    --self.loaded_shell = {
    --    type = "HE",
    --    parameters = {
    --        propellant = 6,
    --        projectile_mass = 10,--mass,
    --        explosive_mass = 5.82, -- mass,
    --        diameter = self.barrel_diameter
    --    }
    --}
    self.interactable:setPower(1)
end

function Breech:client_onCreate()
    sm.ACC = {}
    sm.ACC.vis = {}
    sm.ACC.vis.paths = {}

    self.effects = {}
end

-------------------------------------------------------------------------------
--[[                             Fixed Update                              ]]--
-------------------------------------------------------------------------------

function Breech:server_onFixedUpdate(dt)
    if body_has_changed(self.shape) then
        self.barrel_shapes = construct_cannon_new(self.shape, self.shape:getAt())
        self.barrel_length = #self.barrel_shapes
        self.muzzle_shape = self.barrel_length > 0 and self.barrel_shapes[self.barrel_length] or nil
        update_barrel_diameter(self.barrel_shapes, self.barrel_diameter)
    end

    if input_active(self.interactable) then
        self:sv_fire_shell(true)
    end

    update_shells(self.fired_shells, dt, self.network)
end

function Breech:client_onFixedUpdate(dt)
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

function Breech:server_onUpdate(dt)
end

function Breech:client_onUpdate(dt)
end

-------------------------------------------------------------------------------
--[[                               Destroy                                 ]]--
-------------------------------------------------------------------------------

function Breech:server_onDestroy()
end

function Breech:client_onDestroy()
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]]--
-------------------------------------------------------------------------------

function Breech:sv_e_receiveItem(data)
    local character = data.character
    local ammo = character:getPublicData().carried_shell
    print("Carry -> Breech:",ammo)
    sm.container.beginTransaction()
    sm.container.spend( data.playerCarry, data.itemUuid, 1, true )
    if sm.container.endTransaction() then
        print("Breech Loaded")
        self.loaded_shell = ammo
        local pd = character:getPublicData()
        pd.carried_shell = {}
        character:setPublicData(pd)
        self.interactable:setPower(1)
    end
end

function Breech:sv_fire_shell(is_debug)
    if not self.loaded_shell then
        return false
    end

    local projectile_mass = self.loaded_shell.parameters.projectile_mass

    local propellant = self.loaded_shell.parameters.propellant
    local propellant_power = propellant * self.barrel_diameter / (projectile_mass/2)
    local high_pressure = math.min(self.barrel_length, propellant * 2.2)
    local low_pressure = math.max(0, self.barrel_length - propellant * 2.2)
    local speed = propellant_power * high_pressure - propellant_power / 10 * low_pressure

    local accuracy_factor = math.min(math.max(((self.barrel_length / 10) + speed / 30000)^0.4, 0.99), 1) --crude approximation
    local direction = sm.vec3.lerp(sm.vec3.new(math.random(), math.random(), math.random()), -self.shape:getAt(), accuracy_factor):normalize()
    print(accuracy_factor)


    self.loaded_shell.position = self.muzzle_shape:getWorldPosition() - self.shape:getAt() * 0.126
    self.loaded_shell.velocity = direction * speed
    self.loaded_shell.max_pen = self.loaded_shell.type ~= "HE" and calculate_shell_penetration(self.loaded_shell) or 1

    if is_debug then
        self.loaded_shell.debug = {
            path = {
                shell = {{self.loaded_shell.position, self.loaded_shell.position + direction}},
                spall = {},
                creations = {}
            }
        }
    end

    dprint("Firing shell ("..self.loaded_shell.type..") with the speed of "..tostring(speed), "info", dprint_filename, nil, "sv_fire_shell")
    dprint("Fired shell has "..tostring(self.loaded_shell.max_pen).." mm pen of RHA", "info", dprint_filename, nil, "sv_fire_shell")

    self.muzzle_shape:setColor(sm.color.new("0000ff"))
    self.fired_shells[#self.fired_shells] = self.loaded_shell
    self.loaded_shell = nil
    self.interactable:setPower(0)
    self.network:sendToClients("cl_play_launch_effect", {breech = self.shape, muzzle = self.muzzle_shape, diameter = self.barrel_diameter, is_short = low_pressure == 0})
end

function Breech:cl_save_path(data)
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

function Breech:cl_play_launch_effect(data)
    local effect = get_launch_effect(data)
    effect:start()
    self.effects[#self.effects + 1] = effect
end

function Breech:cl_play_entry_effect(data)
    local effect = get_entry_effect(data)
    effect:start()
    self.effects[#self.effects + 1] = effect
end
