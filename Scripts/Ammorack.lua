--[[
    Class responsible for storing/customizing shell
]]

-------------------------------------------------------------------------------
--[[                                Setup                                  ]]--
-------------------------------------------------------------------------------
dofile "$CONTENT_DATA/Scripts/shell_uuid.lua"

local dprint_filename = "Ammorack"

Ammorack = class()

local function is_container_created(shape)
    if not shape.interactable then
        return false
    end

    if not shape.interactable:getContainer(0) then
       return false
    end

    return true
end

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

-------------------------------------------------------------------------------
--[[                                Create                                 ]]--
-------------------------------------------------------------------------------

function Ammorack:server_onCreate()

    local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, 1, 1 )
	end
	container:setFilters( { obj_generic_apfsds } )

    self.sv = {}
    --self.sv.stored_shell = {
    --    type = "APFSDS",
    --    parameters = {
    --        propellant = 200,
    --        projectile_mass = 12,
    --        diameter = 27,
    --        penetrator_length = 700,
    --        penetrator_density = 17800
    --    }
    --}
    self.barrel_diameter = 100

    local volume_sphere = 0.5 * (4/3) * math.pi * (self.barrel_diameter / 2000)^3
    local volume_cylinder = (self.barrel_diameter / 2000)^2 * math.pi * (2.5*self.barrel_diameter/1000 - self.barrel_diameter/2000)
    local mass = (volume_sphere + volume_cylinder) * 7850
    self.sv.stored_shell = {
        type = "AP",
        parameters = {
            propellant = 130,
            projectile_mass = mass,
            diameter = self.barrel_diameter,
            is_apcbc = true
        }
    }

    --local volume_sphere = 0.5 * (4/3) * math.pi * (self.barrel_diameter / 2000)^3
    --local volume_cylinder = (self.barrel_diameter / 2000)^2 * math.pi * (2.5*self.barrel_diameter/1000 - self.barrel_diameter/2000)
    --local mass = (volume_sphere + volume_cylinder) * 6000
    --print(mass)
    --self.sv.stored_shell = {
    --    type = "APHE",
    --    parameters = {
    --        propellant = 100,
    --        projectile_mass = mass,
    --        diameter = self.barrel_diameter,
    --        is_apcbc = true,

    --        explosive_mass = 0.365, --kg
    --    },
    --    fuse = {
    --        active = false,
    --        delay = 0.001, --seconds
    --        trigger_depth = 10 --mm
    --    }
    --}

    --self.sv.stored_shell = {
    --    type = "HE",
    --    parameters = {
    --        propellant = 40,
    --        projectile_mass = 15,--mass,
    --        explosive_mass = 2, -- mass,
    --        diameter = 100
    --    }
    --}

    sm.container.beginTransaction()
    sm.container.collect( container, obj_generic_apfsds, 1, true )
    sm.container.endTransaction()


end

function Ammorack:client_onCreate()
    self.cl = {}
    --self.cl.is_loaded = true
    self.cl.loaded_shell_effect = sm.effect.createEffect("ShapeRenderable", self.shape.interactable)
    self:cl_update_loadedState()
    self:cl_update_visualization()
end

-------------------------------------------------------------------------------
--[[                             Fixed Update                              ]]--
-------------------------------------------------------------------------------

function Ammorack:server_onFixedUpdate(dt)
end

function Ammorack:client_onFixedUpdate(dt)

end

-------------------------------------------------------------------------------
--[[                                Update                                 ]]--
-------------------------------------------------------------------------------

function Ammorack:server_onUpdate(dt)
end

function Ammorack:client_onUpdate(dt)

    if not is_container_created(self.shape) then
        return
    end

    if not self.cl.loaded_shell_effect:isPlaying() and self.shape.interactable:getContainer(0):getItem(0).uuid ~= sm.uuid.getNil() then
        self.cl.loaded_shell_effect:start()
    elseif self.cl.loaded_shell_effect:isPlaying() and self.shape.interactable:getContainer(0):getItem(0).uuid == sm.uuid.getNil() then
        self.cl.loaded_shell_effect:stop()
    end
end

-------------------------------------------------------------------------------
--[[                               Destroy                                 ]]--
-------------------------------------------------------------------------------

function Ammorack:server_onDestroy(dt)
end

function Ammorack:client_onDestroy(dt)
    self.cl.loaded_shell_effect:stopImmediate()
    self.cl.loaded_shell_effect:destroy()
end

-------------------------------------------------------------------------------
--[[                                 Misc                                  ]]--
-------------------------------------------------------------------------------

function Ammorack.client_onInteract( self, character, state )
    local carried_uuid = sm.localPlayer.getCarry():getItem(0).uuid
    if (self.shape.interactable:getContainer(0):getItem(0).uuid == sm.uuid.getNil() and carried_uuid ~= sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188")) then
        return
    end
    self.network:sendToServer("sv_giveShell", {character = character, carryContainer = sm.localPlayer.getCarry(), uuid = sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188")})
    --self.cl.is_loaded = false
    self.cl.loaded_shell_effect:stopImmediate()
end

function Ammorack.client_canInteract( self, character )
    self:cl_update_loadedState()
    local carried_uuid = sm.localPlayer.getCarry():getItem(0).uuid
    if not is_container_created(self.shape) then
        return false
    end
    local can_unload = self.shape.interactable:getContainer(0):getItem(0).uuid ~= sm.uuid.getNil() and carried_uuid == sm.uuid.getNil()
	return can_unload
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]]--
-------------------------------------------------------------------------------

function Ammorack:sv_sendTCL_isLoaded(data, client)
    self.network:sendToClient(client, "cl_recieve_isLoaded", {self.shape.interactable:getContainer(0):getItem(0).uuid ~= sm.uuid.getNil()})
end

function Ammorack:sv_giveShell(params)
    sm.container.beginTransaction()
    sm.container.collect( params.carryContainer, params.uuid, 1, true )
    if sm.container.endTransaction() then
        print("Ammorack -> Carry [success]")
        local pd = params.character:getPublicData()
        pd.carried_shell = deep_copy(self.sv.stored_shell)
        params.character:setPublicData(pd)
        self.sv.stored_shell = nil
        sm.container.beginTransaction()
        sm.container.spend( self.shape.interactable:getContainer(0), obj_generic_apfsds, 1, true )
        sm.container.endTransaction()
    end
end

function Ammorack:sv_e_receiveItem(data)
    local character = data.character
    local ammo = character:getPublicData().carried_shell
    sm.container.beginTransaction()
    sm.container.spend( data.playerCarry, data.itemUuid, 1, true )
    if sm.container.endTransaction() then
        print("Carry -> Ammorack:")
        self.sv.stored_shell = ammo
        local pd = character:getPublicData()
        pd.carried_shell = {}
        character:setPublicData(pd)
        sm.container.beginTransaction()
        sm.container.collect( self.shape.interactable:getContainer(0), obj_generic_apfsds, 1, true )
        sm.container.endTransaction()
    end
end

-------------------------------------------------------------------------------
--[[                            Network Client                             ]]--
-------------------------------------------------------------------------------

function Ammorack:cl_update_loadedState()
    self.network:sendToServer("sv_sendTCL_isLoaded", nil)
end

function Ammorack:cl_recieve_isLoaded(data)
    self.cl.is_loaded = data[1]
end

function Ammorack:cl_update_visualization(data)
    self.cl.loaded_shell_effect:setParameter("uuid", sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188"))
    self.cl.loaded_shell_effect:setScale(sm.vec3.one() / 4)

end
