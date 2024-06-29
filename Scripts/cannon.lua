--[[
    Class responsible for launching the projectile and
    for adjusting cannon's properties based on the connected modules
]]

-------------------------------------------------------------------------------
--[[                                Setup                                  ]]--
-------------------------------------------------------------------------------

local dprint_filename = "Cannon"

dofile "$CONTENT_DATA/Scripts/dprint.lua"
dofile "$CONTENT_DATA/Scripts/cannon_util.lua"
dofile "$CONTENT_DATA/Scripts/shell_sim.lua"

Cannon = class()

Cannon.maxParentCount = 1
Cannon.maxChildCount = 0
Cannon.connectionInput = sm.interactable.connectionType.logic
Cannon.connectionOutput = sm.interactable.connectionType.none

-------------------------------------------------------------------------------
--[[                                Create                                 ]]--
-------------------------------------------------------------------------------

function Cannon:server_onCreate()
    self.barrel_length, self.breech = construct_cannon(self.shape, 1)
    self.fired_shells = {}
end

function Cannon:client_onCreate()
end

-------------------------------------------------------------------------------
--[[                             Fixed Update                              ]]--
-------------------------------------------------------------------------------

function Cannon:server_onFixedUpdate(dt)
    if body_has_changed(self.shape) then
        self.barrel_length, self.breech = construct_cannon(self.shape, 1)
    end

    if input_active(self.interactable) then
        self:sv_fire(true)
    end

    update_shells(self.fired_shells, dt, self.network)
end

function Cannon:client_onFixedUpdate(dt)
end

-------------------------------------------------------------------------------
--[[                                Update                                 ]]--
-------------------------------------------------------------------------------

function Cannon:server_onUpdate(dt)
end

function Cannon:client_onUpdate(dt)
end

-------------------------------------------------------------------------------
--[[                               Destroy                                 ]]--
-------------------------------------------------------------------------------

function Cannon:server_onDestroy()
end

function Cannon:client_onDestroy()
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]]--
-------------------------------------------------------------------------------

function Cannon:sv_fire(is_debug_shell)
    if self.breech == nil then
        return
    end

    local breech_data = self.breech.interactable:getPublicData()

    if not breech_data.is_loaded then
        return
    end

    local bps = 20
    local propellant = 4 -- temp, move to breech.lua
    local high_pressure = math.min(self.barrel_length, propellant * 2.2)
    local low_pressure = math.max(0, self.barrel_length - propellant * 2.2)
    local speed = bps * high_pressure - bps / 10 * low_pressure

    dprint("Firing shell with the speed of "..tostring(speed), "info", dprint_filename, nil, "sv_fire")

    self.fired_shells[#self.fired_shells + 1] = {
        velocity = self.shape:getAt() * speed,
        position = self.shape:getWorldPosition() + self.shape:getAt() / 2,
        type = "APFSDS",
        parameters = {
            diameter = 27,
            penetrator_length = 150,
            penetrator_density = 17500
        }
    }

    if is_debug_shell then
        self.fired_shells[#self.fired_shells].debug = {
            path = {{self.shape:getWorldPosition(), self.shape:getWorldPosition() + self.shape:getAt() / 2}}
        }
    end

    self.breech.interactable:setPublicData({is_loaded = false})
end

-------------------------------------------------------------------------------
--[[                            Network Client                             ]]--
-------------------------------------------------------------------------------
