--[[
    Class responsible for storing/customizing shell
]]

-------------------------------------------------------------------------------
--[[                                Setup                                  ]]--
-------------------------------------------------------------------------------

local dprint_filename = "Ammorack"

Ammorack = class()
Ammorack.maxChildCount = 0

-------------------------------------------------------------------------------
--[[                                Create                                 ]]--
-------------------------------------------------------------------------------

function Ammorack:server_onCreate()
    self.sv = {}
    self.sv.stored_shell = {
        type = "APFSDS",
        parameters = {
            propellant = 7,
            projectile_mass = 12,
            diameter = 27,
            penetrator_length = 700,
            penetrator_density = 17800
        }
    }
end

function Ammorack:client_onCreate()
    self.cl = {}
    self.cl.is_loaded = true
    self.cl.loaded_shell_effect = sm.effect.createEffect("ShapeRenderable", self.shape.interactable)
    self:cl_update_visualization()
    self:cl_update_loadedState()
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
    if not self.cl.loaded_shell_effect:isPlaying() and self.cl.is_loaded then
        self.cl.loaded_shell_effect:start()
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
    if (not self.cl.is_loaded and carried_uuid ~= sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188")) then
        return
    end
    print("interact")
    self.network:sendToServer("sv_takeShell", {carryContainer = sm.localPlayer.getCarry(), uuid = sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188")})
    self.cl.is_loaded = false
    self.cl.loaded_shell_effect:stopImmediate()
end

function Ammorack.client_canInteract( self, character )
    local carried_uuid = sm.localPlayer.getCarry():getItem(0).uuid
	return (not self.cl.is_loaded and carried_uuid == sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188")) or self.cl.is_loaded --true or false, default true if onInteract is implemented
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]]--
-------------------------------------------------------------------------------

function Ammorack:sv_sendTCL_isLoaded(data, client)
    self.network:sendToClient(client, "cl_recieve_isLoaded", {self.sv.stored_shell ~= nil})
end

function Ammorack:sv_takeShell(params)
    sm.container.beginTransaction()
    sm.container.collect( params.carryContainer, params.uuid, 1, true )
    if sm.container.endTransaction() then
        print("Successful transaction")
        self.sv.stored_shell = nil
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
    --self.cl.loaded_shell_effect:setPosition(self.shape:getWorldPosition() + self.shape:getUp()/3)
    --self.cl.loaded_shell_effect:setRotation(self.shape:getWorldRotation())
    self.cl.loaded_shell_effect:setScale(sm.vec3.one() / 4)
end
