--[[
    Class responsible for storing/giving additional ammo to Auto cannon breech
]]

-------------------------------------------------------------------------------
--[[                                Setup                                  ]]--
-------------------------------------------------------------------------------

dofile "$CONTENT_DATA/Scripts/shell_uuid.lua"

local dprint_filename = "ACammo module"

ACammo_module = class()

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

function ACammo_module:server_onCreate()
    local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, 1, 1 )
	end
	container:setFilters( { obj_generic_acammo } )

	self.shape.interactable:setPublicData({})
	--self.sv.stored_shell = {}
end

function ACammo_module:client_onCreate()
    self.cl = {}
    self.cl.is_loaded = false

    self.cl.loaded_shell_effect = sm.effect.createEffect("ShapeRenderable", self.shape.interactable)
    self.cl.loaded_shell_effect:setParameter("uuid", obj_generic_acammo)
    self.cl.loaded_shell_effect:setScale(sm.vec3.one() / 4)
end

-------------------------------------------------------------------------------
--[[                             Fixed Update                              ]]--
-------------------------------------------------------------------------------

function ACammo_module:server_onFixedUpdate(dt)
    if #self.shape.interactable:getPublicData() == 0 then
        self.network:sendToClients("cl_recieve_isLoaded", {false})
        sm.container.beginTransaction()
        sm.container.spend( self.shape.interactable:getContainer(0), obj_generic_acammo, 1, true )
        sm.container.endTransaction()
    end
end

function ACammo_module:client_onFixedUpdate(dt)
end

-------------------------------------------------------------------------------
--[[                                Update                                 ]]--
-------------------------------------------------------------------------------

function ACammo_module:server_onUpdate(dt)
end

function ACammo_module:client_onUpdate(dt)

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

function ACammo_module:server_onDestroy(dt)
end

function ACammo_module:client_onDestroy(dt)
    self.cl.loaded_shell_effect:stopImmediate()
    self.cl.loaded_shell_effect:destroy()
end

-------------------------------------------------------------------------------
--[[                                 Misc                                  ]]--
-------------------------------------------------------------------------------

function ACammo_module.client_onInteract( self, character, state )
    local carried_uuid = sm.localPlayer.getCarry():getItem(0).uuid
    if (self.shape.interactable:getContainer(0):getItem(0).uuid == sm.uuid.getNil() or carried_uuid ~= sm.uuid.getNil()) then
        print("bad return", self.shape.interactable:getContainer(0):getItem(0).uuid, carried_uuid)
        return
    end
    self.network:sendToServer("sv_giveShell", {character = character, carryContainer = sm.localPlayer.getCarry(), uuid = obj_generic_acammo})
    self.cl.is_loaded = false
    self.cl.loaded_shell_effect:stopImmediate()
end

function ACammo_module.client_canInteract( self, character )
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

function ACammo_module:sv_sendTCL_isLoaded(data, client)
    self.network:sendToClient(client, "cl_recieve_isLoaded", {self.shape.interactable:getContainer(0):getItem(0).uuid ~= sm.uuid.getNil()})
end

function ACammo_module:sv_giveShell(params)
    sm.container.beginTransaction()
    sm.container.collect( params.carryContainer, params.uuid, 1, true )
    if sm.container.endTransaction() then
        print("ACammo module -> Carry")
        local pd = params.character:getPublicData()
        pd.carried_shell = deep_copy(self.shape.interactable:getPublicData())
        print(self.shape.interactable:getPublicData())
        params.character:setPublicData(pd)
        self.shape.interactable:setPublicData({})
        --self.sv.stored_shell = nil
        sm.container.beginTransaction()
        sm.container.spend( self.shape.interactable:getContainer(0), obj_generic_acammo, 1, true )
        sm.container.endTransaction()
    end
end

function ACammo_module:sv_e_receiveItem(data)
    local character = data.character
    local ammo = character:getPublicData().carried_shell
    sm.container.beginTransaction()
    sm.container.spend( data.playerCarry, data.itemUuid, 1, true )
    if sm.container.endTransaction() then
        print("Carry -> Acammo module:")
        self.shape.interactable:setPublicData(ammo)
        print(self.shape.interactable:getPublicData())
        local pd = character:getPublicData()
        pd.carried_shell = {}
        character:setPublicData(pd)
        sm.container.beginTransaction()
        sm.container.collect( self.shape.interactable:getContainer(0), obj_generic_acammo, 1, true )
        sm.container.endTransaction()
    end
end

-------------------------------------------------------------------------------
--[[                            Network Client                             ]]--
-------------------------------------------------------------------------------

function ACammo_module:cl_update_loadedState()
    self.network:sendToServer("sv_sendTCL_isLoaded", nil)
end

function ACammo_module:cl_recieve_isLoaded(data)
    self.cl.is_loaded = data[1]
end
