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
dofile "$CONTENT_DATA/Scripts/general_util.lua"

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
    self.paths = {}
    self.lines = {}
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
    --[[
    local bodies = sm.body.getAllBodies()
    for _, body in pairs(bodies) do
        local shapes = body:getShapes()
        local shape = shapes[1]
        if shape.isBlock then
            local neighbours = shape:getNeighbours()
            local colors = {
                sm.color.new("aa5555"),
                sm.color.new("55aa55"),
                sm.color.new("aaaa55"),
                sm.color.new("5555aa"),
                sm.color.new("aa55aa"),
                sm.color.new("55aaaa"),
                sm.color.new("aaaaaa")
            }
            local pos = shape:getWorldPosition()
            for i, n in pairs(neighbours) do

                local n_aabb = n:getBoundingBox()
                local n_pos_local = shape:transformPoint(n:getWorldPosition())
                -- we want to make go to 0,0,0 as close as possible
                local delta_x = clamp(n_aabb.x/2, -n_aabb.x/2, n_pos_local.x)
                local delta_y = clamp(n_aabb.y/2, -n_aabb.y/2, n_pos_local.y)
                local delta_z = clamp(n_aabb.z/2, -n_aabb.z/2, n_pos_local.z)
                local close_point_local = n_pos_local - sm.vec3.new(delta_x, delta_y, delta_z)
                local p = n:getClosestBlockLocalPosition(shape:transformLocalPoint(close_point_local))

                print(close_point_local, print(p))
            end
        end
    end]]
end

function Cannon:client_onFixedUpdate(dt)
end

-------------------------------------------------------------------------------
--[[                                Update                                 ]]--
-------------------------------------------------------------------------------

function Cannon:server_onUpdate(dt)
end

function Cannon:client_onUpdate(dt)
    for line_id = 1, # self.lines do
        effect = self.lines[line_id][1]
        a = self.lines[line_id][2]
        if not effect:isPlaying() then
            effect:start()
        end
        if not a:isPlaying() then
            a:start()
        end
    end
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

    local bps = 200
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
            penetrator_length = 600,
            penetrator_density = 19050
        }
    }

    if is_debug_shell then
        self.fired_shells[#self.fired_shells].debug = {
            path = {shell = {{self.shape:getWorldPosition(), self.shape:getWorldPosition() + self.shape:getAt() / 2}},
                    spall={}
            }
        }
    end

    self.breech.interactable:setPublicData({is_loaded = false})
end

-------------------------------------------------------------------------------
--[[                            Network Client                             ]]--
-------------------------------------------------------------------------------

function Cannon:cl_save_path(data)
    dprint("recieved path with the length of "..tostring(#data.path).." and type "..data.type, "info", dprint_filename, nil, "cl_save_path")
    self.paths[#self.paths + 1] = path
    for line_id = 1, #data.path do
        local thickness = 0.025
        local line = data.path[line_id]
        local effect = sm.effect.createEffect("ShapeRenderable")
        effect:setParameter("uuid", sm.uuid.new("3e3242e4-1791-4f70-8d1d-0ae9ba3ee94c"))
        if data.type == "shell" then effect:setParameter("color", sm.color.new("ffffff"))
        else effect:setParameter("color", sm.color.new("ffaa55")) end
        effect:setScale( sm.vec3.one() * thickness )
        local delta = line[2] - line[1]
        local length = delta:length()

        if length < 0.0001 then goto next end

        local rot = sm.vec3.getRotation(sm.vec3.new(1,0,0), delta)

        local distance = sm.vec3.new(length, thickness, thickness)

        effect:setPosition(line[1] + delta * 0.5)
        effect:setScale(distance)
        effect:setRotation(rot)
        local a = sm.effect.createEffect("ShapeRenderable")
        a:setParameter("uuid", sm.uuid.new("3e3242e4-1791-4f70-8d1d-0ae9ba3ee94c"))
        a:setParameter("color", sm.color.new("ff0000"))
        a:setScale( sm.vec3.one() * (thickness * 1.5) )
        a:setPosition(line[1])
        self.lines[#self.lines + 1] = {effect, a}
        ::next::
    end
end
