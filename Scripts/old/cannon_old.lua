dofile "$CONTENT_DATA/Scripts/util.lua"
dofile "$CONTENT_DATA/Scripts/new_shell_sim.lua"

Cannon = class()
Cannon.maxParentCount = 1
Cannon.maxChildCount = 0
Cannon.connectionInput = sm.interactable.connectionType.logic
Cannon.connectionOutput = sm.interactable.connectionType.none

--[[
    Class responsible for launching the projectile and
    for adjusting cannon's properties based on the connected modules
]]

function Cannon:server_onCreate()

    self.barrel_length, self.breech = Calculate_barrel_length(self.shape, 1)

    self.fired_shells = {}
end

function Cannon:server_onFixedUpdate(dt)
    if self.shape:getBody():hasChanged(sm.game.getCurrentTick() - 1) then
        self.barrel_length, self.breech = Calculate_barrel_length(self.shape, 1)
    end

    if self:inputActive() then self:sv_attempt_to_fire() end

    update_shells(self.fired_shells, dt, self.network)
    for shell_id = 1, #self.fired_shells do
        local shell = self.fired_shells[shell_id]
        if shell then
            --self.network:sendToClients("cl_visualize_shell", shell)
        end
    end
end

-----------------------------------------------------------------------------------------------

function Cannon:client_onCreate()
    self.paths = {}
    self.lines = {}
end

function Cannon:client_onFixedUpdate(dt) end

function Cannon:client_onUpdate(dt)
    for line_id = 1, # self.lines do
        effect = self.lines[line_id][1]
        a = self.lines[line_id][2]
        b = self.lines[line_id][3]
        if not effect:isPlaying() then
            effect:start()
        end
        if not a:isPlaying() then
            a:start()
        end
        if not b:isPlaying() then
            b:start()
        end
    end
end

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
            penetrator_length = 150,
            penetrator_density = 17500
        },
        debug = {
            path = {{self.shape:getWorldPosition(), self.shape:getWorldPosition() + self.shape:getAt() / 2}}
        }
    }
    self.breech.interactable:setPublicData({is_loaded = false})
    print("[create] :: ", self.fired_shells[#self.fired_shells].debug)
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

function Cannon:cl_visualize_path(path)
    print("[cl_visualize_path] :: recieved a path with a length of", #path)
    self.paths[#self.paths + 1] = path
    for line_id = 1, #path do
        local thickness = 0.025
        local line = path[line_id]
        local effect = sm.effect.createEffect("ShapeRenderable")
        effect:setParameter("uuid", sm.uuid.new("3e3242e4-1791-4f70-8d1d-0ae9ba3ee94c"))
        effect:setParameter("color", sm.color.new("ffffff"))
        effect:setScale( sm.vec3.one() * thickness )
        local delta = line[2] - line[1]
        local length = delta:length()

        if length < 0.0001 then return end

        local rot = sm.vec3.getRotation(sm.vec3.new(1,0,0), delta)

        local distance = sm.vec3.new(length, thickness, thickness)

        effect:setPosition(line[1] + delta * 0.5)
        effect:setScale(distance)
        effect:setRotation(rot)
        --effect:setAutoPlay( true )
        --effect:start()
        local a = sm.effect.createEffect("SledgehammerHit - Default")
        a:setPosition(line[1])
        local b = sm.effect.createEffect("SledgehammerHit - Default")
        b:setPosition(line[2])
        self.lines[#self.lines + 1] = {effect, a,b}
    end
end

function Cannon:cl_visualize_hit(data)

    sm.effect.playEffect("Explosion - Debris", data[1], nil, sm.quat.identity(),
                         sm.vec3.one())
end
