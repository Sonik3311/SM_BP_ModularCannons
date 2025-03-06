dofile "$CONTENT_DATA/Scripts/new_breech_functions.lua"


Breech = class()


---------------------------------------------------------------------------------
-- [[                                Create                                 ]] --
---------------------------------------------------------------------------------

function Breech:server_onCreate()
    self.modules = find_modules(self.shape)
    self.barrel = find_barrel(self.shape)
    self.loader = find_loader(self.shape)
end

---------------------------------------------------------------------------------
-- [[                             Fixed Update                              ]] --
---------------------------------------------------------------------------------

function Breech:server_onFixedUpdate()
    if self.shape.body:hasChanged(sm.game.getCurrentTick() - 1) then
        self.modules = find_modules(self.shape)
        self.barrel = find_barrel(self.shape)
        self.loader = find_loader(self.shape)
    end
end
