dofile "$CONTENT_DATA/Scripts/util.lua"
dofile "$CONTENT_DATA/Scripts/shell_sim.lua"

Cannon = class()
Cannon.maxParentCount = 1
Cannon.maxChildCount = 0
Cannon.connectionInput = sm.interactable.connectionType.logic
Cannon.connectionOutput = sm.interactable.connectionType.none

--[[ 
    Class responsible for adjusting cannon's properties 
    based on the connected modules and for launching the projectile
]]

function Cannon:server_onCreate()

    self.barrel_length, self.breech = Calculate_barrel_length(self.shape, 1)
    self.diameter = 1 -- cm

    self.fired_shells = {}
end

function Cannon:server_onFixedUpdate(dt)
    if self.shape:getBody():hasChanged(sm.game.getCurrentTick() - 1) then
        self.barrel_length, self.breech = Calculate_barrel_length(self.shape, 1)
    end

    if self:inputActive() then self:sv_attempt_to_fire() end

    update_shells(self.fired_shells, dt)
    for shell_id = 1, #self.fired_shells do
        local shell = self.fired_shells[shell_id]
        if shell then
            self.network:sendToClients("cl_visualize_shell", shell)
        end
    end
end

-----------------------------------------------------------------------------------------------

function Cannon:client_onCreate() end

function Cannon:client_onFixedUpdate(dt) end

function Cannon:client_onUpdate(dt) end

-----------------------------------------------------------------------------------------------

function Cannon:sv_attempt_to_fire()
    if self.breech == nil then return end

    local breech_data = self.breech.interactable:getPublicData()

    if not breech_data.is_loaded then return end

    print("Fire!")
    -- TEMP --
    local bps = 100
    local propellant = 4 -- optimal barrel length
    -- TEMP --

    local high_pressure = math.min(self.barrel_length, propellant * 2.2)
    local low_pressure = math.max(0, self.barrel_length - propellant * 2.2)
    -- print("length: "..tostring(self.barrel_length).." hp: "..tostring(high_pressure).." lp: "..tostring(low_pressure))
    local speed = bps * high_pressure - bps / 10 * low_pressure
    print(speed)
    self.fired_shells[#self.fired_shells + 1] = {
        velocity = self.shape:getAt() * speed,
        position = self.shape:getWorldPosition() + self.shape:getAt() / 2,
        type = "APFSDS",
        parameters = {
            diameter = 27,
            penetrator_length = 500,
            penetrator_density = 17500
        }
    }

    self.breech.interactable:setPublicData({is_loaded = false})

end

function Cannon.inputActive(self)
    local parent = self.interactable:getSingleParent();

    if parent then
        if parent:hasOutputType(sm.interactable.connectionType.logic) then
            return parent:isActive()
        end
    end
    return false
end

-----------------------------------------------------------------------------------------------

function Cannon:cl_visualize_shell(data)

    sm.effect.playEffect("SledgehammerHit - Default", data.position, nil,
                         sm.quat.identity(), sm.vec3.one())
end

function Cannon:cl_visualize_hit(data)

    sm.effect.playEffect("Explosion - Debris", data[1], nil, sm.quat.identity(),
                         sm.vec3.one())
end
