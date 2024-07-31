-- Just for storing shell data and giving it to players

Shell = class()

function Shell:server_onCreate()
end

function Shell:client_onCreate()
    self.cl = {}
    self.cl.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/shell_customizer.layout", false)
    self.cl.gui:setOnCloseCallback( "cl_onGuiClosed" )
end

function Shell.client_onInteract(self, character)
    self.network:sendToServer("sv_transfer_to_carry")
end

function Shell:sv_transfer_to_carry(data, player)
    local character = player.character
    local uuid = #self.interactable:getPublicData() > 1 and sm.uuid.new("2c7363a7-0246-42f0-a95a-9b41ef55ca6b") or sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188")
    sm.container.beginTransaction()
    sm.container.collect( player:getCarry(), uuid, 1, true )
    if sm.container.endTransaction() then
        print("World -> Carry")
        local pd = character:getPublicData()
        pd.carried_shell = self.interactable:getPublicData()
        character:setPublicData(pd)
        self.shape:destroyShape()
    end

end

function Shell.client_canTinker(self,character)
    return true
end

function Shell.client_canInteract( self, character )
	return true --true or false, default true if onInteract is implemented
end


-- TODO: Move to shapeset
function Shell.server_canErase( self )
	return false --true or false, default true
end
function Shell.client_canErase( self )
	return false --true or false, default true
end

function Shell:cl_onGuiClosed()
    self.cl.gui:close()
    print("gui closed")
end

function Shell.client_onTinker( self, character, state ) --onUpgrade
    if state == true then
        self.cl.gui:open()
    end
    print("onTinker")
end
