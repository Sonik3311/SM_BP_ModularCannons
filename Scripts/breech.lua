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
dofile "$CONTENT_DATA/Scripts/shell_uuid.lua"
dofile "$CONTENT_DATA/Scripts/effects.lua"

local function deep_copy( tbl )
    local copy = {}
    for key, value in pairs( tbl ) do
        local var_type = type(value)
        if var_type ~= 'table' then
            if var_type == "Vec3" then
				copy[key] = sm.vec3.new(value.x, value.y, value.z)
			elseif var_type == "Quat" then
				copy[key] = sm.quat.new(value.x, value.y, value.z, value.w)
			elseif var_type == "Color" then
				copy[key] = sm.color.new(value.r, value.g, value.b)
			elseif var_type == "Uuid" then
				copy[key] = sm.uuid.new(tostring(value))
            else
                copy[key] = value
            end
        else
            copy[key] = deep_copy( value )
        end
    end
    return copy
end

Breech = class()
Breech.maxParentCount = 1
Breech.maxChildCount = 0
Breech.connectionInput = sm.interactable.connectionType.logic
Breech.connectionOutput = sm.interactable.connectionType.none

-------------------------------------------------------------------------------
--[[                                Create                                 ]]--
-------------------------------------------------------------------------------

function Breech:server_onCreate()
    local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, 1, 1 )
	end
	container:setFilters( { obj_generic_apfsds } )

	sm.container.beginTransaction()
    sm.container.collect( container, obj_generic_apfsds, 1, true )
    sm.container.endTransaction()

    self.barrel_shapes = construct_cannon_new(self.shape, self.shape:getAt())
    self.barrel_length = #self.barrel_shapes
    self.muzzle_shape = self.barrel_length > 0 and self.barrel_shapes[#self.barrel_shapes] or nil
    self.barrel_diameter = 300 --mm
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
    local mass = (volume_sphere + volume_cylinder) * 6000
    --print(mass)
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
end

function Breech:client_onCreate()
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
        self:sv_fire_shell(true, dt)
    end

    --update_shells(self.fired_shells, dt, self.network)
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
        sm.container.beginTransaction()
        sm.container.collect( self.shape.interactable:getContainer(0), obj_generic_apfsds, 1, true )
        sm.container.endTransaction()
    end
end

function Breech:sv_fire_shell(is_debug, dt)
    if not self.loaded_shell then
        return false
    end

    local projectile_mass = self.loaded_shell.parameters.projectile_mass

    local propellant = self.loaded_shell.parameters.propellant
    local propellant_power = propellant * self.barrel_diameter / (projectile_mass/2)
    local high_pressure = math.min(self.barrel_length, propellant * 2.2)
    local low_pressure = math.max(0, self.barrel_length - propellant * 2.2)
    local speed = propellant_power * high_pressure - propellant_power / 10 * low_pressure
    --print(#self.barrel_shapes * 0.25, self.barrel_diameter / 1000, self.loaded_shell.parameters.projectile_mass)
    speed = calculate_muzzle_velocity(#self.barrel_shapes * 0.25, self.barrel_diameter / 1000, self.loaded_shell) * propellant

    local accuracy_factor = math.min(math.max(((self.barrel_length / 10) + speed / 30000)^0.4, 0.99), 1) --crude approximation
    local direction = sm.vec3.lerp(sm.vec3.new(math.random(), math.random(), math.random()), -self.shape:getAt(), accuracy_factor):normalize()

    self.loaded_shell.position = self.muzzle_shape:getWorldPosition() - self.shape:getAt() * 0.126
    self.loaded_shell.velocity = direction * speed
    self.loaded_shell.next_position = self.loaded_shell.position + self.loaded_shell.velocity * dt
    self.loaded_shell.max_pen = self.loaded_shell.type ~= "HE" and calculate_shell_penetration(self.loaded_shell) or 1
    self.loaded_shell.barrel_diameter = self.barrel_diameter

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

    local recoil_force = calculate_recoil_force(self.loaded_shell.parameters.projectile_mass, speed, 0, 0)
    print(recoil_force, self.loaded_shell.parameters.projectile_mass, speed)
    sm.physics.applyImpulse(self.muzzle_shape, -direction * recoil_force, true)
    self.muzzle_shape:setColor(sm.color.new("0000ff"))
    --self.fired_shells[#self.fired_shells] = self.loaded_shell
    local index = math.random(100000)
    while sm.ACC.shells[index] do
        index = math.random(100000)
    end
    sm.ACC.shells[index] = deep_copy(self.loaded_shell)
    self.loaded_shell = nil
    sm.container.beginTransaction()
    sm.container.spend( self.shape.interactable:getContainer(0), obj_generic_apfsds, 1, true )
    sm.container.endTransaction()
    self.network:sendToClients("cl_play_launch_effect", {breech = self.shape, muzzle = self.muzzle_shape, diameter = self.barrel_diameter, is_short = low_pressure == 0})
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
