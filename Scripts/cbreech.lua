--[[
    Class responsible for launching the projectile and
    for adjusting Cbreech's properties based on the connected modules
]]

-------------------------------------------------------------------------------
--[[                                Setup                                  ]]--
-------------------------------------------------------------------------------


Cbreech = class()
Cbreech.maxParentCount = 1
Cbreech.maxChildCount = 0
Cbreech.connectionInput = sm.interactable.connectionType.logic
Cbreech.connectionOutput = sm.interactable.connectionType.none

dofile "$CONTENT_DATA/Scripts/dprint.lua"
dofile "$CONTENT_DATA/Scripts/breech_functions.lua"
dofile "$CONTENT_DATA/Scripts/pen_calc.lua"
dofile "$CONTENT_DATA/Scripts/shell_uuid.lua"
dofile "$CONTENT_DATA/Scripts/effects.lua"
dofile "$CONTENT_DATA/Scripts/splashes.lua"

local dprint_filename = "Cbreech"

-------------------------------------------------------------------------------
--[[                                Create                                 ]]--
-------------------------------------------------------------------------------


function Cbreech:server_onCreate()
    local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, 1, 1 )
	end

	if self.data.is_autocannon then
	   container:setFilters( {obj_generic_acammo} )
	else
	   container:setFilters( cannon_shells )
	end

	self.barrel_shapes = construct_cannon_new(self.shape, self.shape:getAt())
	self.barrel_length = #self.barrel_shapes
	self.muzzle_shape = self.barrel_length > 0 and self.barrel_shapes[self.barrel_length] or nil
	self.barrel_diameter = (self.data.max_caliber + self.data.min_caliber) / 4
	update_barrel_diameter(self.barrel_shapes, self.barrel_diameter)

	self.loaded_projectile = {}
	self.fire_time_delay = 0
end

function Cbreech:client_onCreate()
    self.effects = {}

    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/breech_customizer.layout", false)
    self.gui:setOnCloseCallback( "cl_onGuiClosed" )
    self.gui:setSliderCallback( "CaliberSlider", "cl_onCaliberChange" )
    self.gui:setTextAcceptedCallback( "CaliberEditBox", "cl_onCaliberChange" )
    self.last_splash_index = 3
    self.l1 = 3
    self.l2 = 3
    self.l3 = 3
    self.gui:setText("Splash", splashes[self.last_splash_index])
end

-------------------------------------------------------------------------------
--[[                             Fixed Update                              ]]--
-------------------------------------------------------------------------------

function Cbreech:server_onFixedUpdate(dt)
    if body_has_changed(self.shape) then
        self.barrel_shapes = construct_cannon_new(self.shape, self.shape:getAt())
        self.barrel_length = #self.barrel_shapes
        self.muzzle_shape = self.barrel_length > 0 and self.barrel_shapes[self.barrel_length] or nil
        update_barrel_diameter(self.barrel_shapes, self.barrel_diameter)
    end

    self.fire_time_delay = self.fire_time_delay - dt

    if input_active(self.interactable) and self.muzzle_shape and self.fire_time_delay <= 0 then
        self:sv_fire_shell(true, dt)
    end
end

function Cbreech:client_onFixedUpdate(dt)
    for key, effect in pairs(self.effects) do
        if effect:isDone() then
            effect:destroy()
            self.effects[key] = nil
        end
    end

    if self.gui:isActive() then

    end
end

-------------------------------------------------------------------------------
--[[                                Update                                 ]]--
-------------------------------------------------------------------------------

function Cbreech:server_onUpdate(dt)
end

function Cbreech:client_onUpdate(dt)
end

-------------------------------------------------------------------------------
--[[                                Tinker                                 ]]--
-------------------------------------------------------------------------------

function Cbreech:client_canTinker(character)
    return true
end

function Cbreech:client_onTinker(character, state)
    if state == true then
        self.gui:open()
        -- update splash text
        local ind = math.random(#splashes)
        while ind == self.last_splash_index or ind == self.l1 or ind == self.l2 or ind == self.l3 do
            ind = math.random(#splashes)
        end
        print(ind)
        self.l3 = self.l2
        self.l2 = self.l1
        self.l1 = self.last_splash_index
        self.last_splash_index = ind
        self.gui:setText("Splash", splashes[self.last_splash_index])
    end
end

-------------------------------------------------------------------------------
--[[                               Destroy                                 ]]--
-------------------------------------------------------------------------------

function Cbreech:server_onDestroy()
end

function Cbreech:client_onDestroy()
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]]--
-------------------------------------------------------------------------------

function Cbreech:sv_e_receiveItem(data)
    local character = data.character
    print("Carry -> Cbreech:", ammo)
    -- check for autocannon ammo
    local is_ac = self.data.is_autocannon
    local is_shell = isAnyOf(data.itemUuid, cannon_shells)
    if is_ac and is_shell then
        print("Autocannon rejected shell")
        return
    end

    if not is_ac and not is_shell then
        print("Cannon rejected clip")
        return
    end
    local ammo = character:getPublicData().carried_shell
    sm.container.beginTransaction()
    sm.container.spend( data.playerCarry, data.itemUuid, 1, true )
    if sm.container.endTransaction() then
        print("Cbreech Loaded")
        self.loaded_projectile = ammo
        local pd = character:getPublicData()
        pd.carried_shell = {}
        character:setPublicData(pd)
        sm.container.beginTransaction()
        sm.container.collect( self.shape.interactable:getContainer(0), data.itemUuid, 1, true )
        sm.container.endTransaction()
    end
end

function Cbreech:sv_fire_shell(is_debug, dt)
    if #self.loaded_projectile == 0 then
        return false
    end

    local shell = self.loaded_projectile[#self.loaded_projectile]

    local projectile_mass = shell.parameters.projectile_mass

    local propellant = shell.parameters.propellant
    --local propellant_power = propellant * self.barrel_diameter / (projectile_mass/2)
    --local high_pressure = math.min(self.barrel_length, propellant * 2.2)
    --local low_pressure = math.max(0, self.barrel_length - propellant * 2.2)
    --local speed = propellant_power * high_pressure - propellant_power / 10 * low_pressure
    --print(#self.barrel_shapes * 0.25, self.barrel_diameter / 1000, self.loaded_shell.parameters.projectile_mass)
    local speed = calculate_muzzle_velocity(#self.barrel_shapes * 0.3333, self.barrel_diameter / 1000, shell) * propellant

    local accuracy_factor = math.min(math.max(((self.barrel_length / 10) + speed / 30000)^0.4, 0.99), 1) --crude approximation
    local direction = sm.vec3.lerp(sm.vec3.new(math.random(), math.random(), math.random()), -self.shape:getAt(), accuracy_factor):normalize()

    shell.position = self.muzzle_shape:getWorldPosition() - self.shape:getAt() * 0.126
    shell.velocity = direction * speed
    shell.next_position = shell.position + shell.velocity * dt
    shell.max_pen = shell.type ~= "HE" and calculate_shell_penetration(shell) or 1
    shell.barrel_diameter = self.barrel_diameter

    if is_debug then
        shell.debug = {
            path = {
                shell = {{shell.position, shell.position + direction}},
                spall = {},
                creations = {}
            }
        }
    end

    dprint("Firing shell ("..shell.type..") with the speed of "..tostring(speed), "info", dprint_filename, nil, "sv_fire_shell")
    dprint("Fired shell has "..tostring(shell.max_pen).." mm pen of RHA", "info", dprint_filename, nil, "sv_fire_shell")


    local recoil_force = calculate_recoil_force(shell.parameters.projectile_mass, speed, 0, 0)
    if self.data.is_autocannon then
        recoil_force = recoil_force / 3
    end

    print(recoil_force, shell.parameters.projectile_mass, speed)
    sm.physics.applyImpulse(self.muzzle_shape, -direction * recoil_force, true)
    self.muzzle_shape:setColor(sm.color.new("0000ff"))
    --self.fired_shells[#self.fired_shells] = self.loaded_shell
    local index = math.random(100000)
    while sm.ACC.shells[index] do
        index = math.random(100000)
    end
    --sm.ACC.shells[index] = deep_copy(self.loaded_shell)
    self.network:sendToClients("cl_add_shell_to_sim", shell)
    --self.loaded_projectile[#self.loaded_projectile] = nil
    self.network:sendToClients("cl_play_launch_effect", {breech = self.shape, muzzle = self.muzzle_shape, diameter = self.barrel_diameter, is_short = low_pressure == 0})
    self.fire_time_delay = self.data.fire_delay
    if #self.loaded_projectile == 0 then
        sm.container.beginTransaction()
        sm.container.spend( self.shape.interactable:getContainer(0), obj_generic_apfsds, 1, true )
        sm.container.endTransaction()
    end
end

-------------------------------------------------------------------------------
--[[                            Network Client                             ]]--
-------------------------------------------------------------------------------

function Cbreech:cl_onGuiClosed()
end

function Cbreech:cl_onCaliberChange(name, position)
    local converted_pos = tonumber(position) + 4
    if name ~= "CaliberEditBox" then
        self.gui:setText( "CaliberEditBox", tostring(converted_pos) )
    else
        print("set")
        self.gui:setSliderData( "CaliberSlider", 50, converted_pos )
    end
    print(name,position, converted_pos)
end

function Cbreech:cl_add_shell_to_sim(shell)
    local index = math.random(100000)
    while sm.ACC.shells[index] do
        index = math.random(100000)
    end
    sm.ACC.shells[#sm.ACC.shells + 1] = deep_copy(shell)
end

function Cbreech:cl_play_launch_effect(data)
    local effect = get_launch_effect(data)
    effect:start()
    self.effects[#self.effects + 1] = effect
end

function Cbreech:cl_play_entry_effect(data)
    local effect = get_entry_effect(data)
    effect:start()
    self.effects[#self.effects + 1] = effect
end
