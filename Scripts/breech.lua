dofile "$CONTENT_DATA/Scripts/util.lua"

Breech = class()
Breech.maxParentCount = 0
Breech.maxChildCount = 0

--[[
    Class responsible for reloading the Breach
]]

function Breech:server_onCreate()
    self.loaded = true
    self.interactable:setPublicData({is_loaded = self.loaded})
end

function Breech:server_onFixedUpdate(dt)
    self.loaded = self.interactable:getPublicData().is_loaded
    if not self.loaded then
        self.loaded = true
        self.interactable:setPublicData({is_loaded = self.loaded})
    end
end

-----------------------------------------------------------------------------------------------

function Breech:client_onCreate() end

function Breech:client_onFixedUpdate(dt) end

function Breech:client_onUpdate(dt) end
