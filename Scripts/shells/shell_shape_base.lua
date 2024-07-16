-- Just for storing shell data and giving it to players

Shell = class()

function Shell:server_onCreate()
    self.interactable:setPublicData({})
end

function Shell.client_onInteract(self, character)
    self.network:sendToServer("sv_transfer_to_carry")
end

function Shell:sv_transfer_to_carry(data, player)
    local character = player.character


    sm.container.beginTransaction()
    sm.container.collect( player:getCarry(), sm.uuid.new("f8353f82-d9ae-4dc3-bc98-2517337ee188"), 1, true )
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
