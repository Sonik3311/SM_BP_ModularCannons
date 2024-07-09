-----------------------------------------------------------------------------------
--[[                                    Util                                   ]]--
-----------------------------------------------------------------------------------

function clamp(mx, mn, t)
	if t > mx then return mx end
	if t < mn then return mn end
	return t
end

local function ray_box_intersection ( ro, rd, boxSize )
    local rdx = rd.x^-1
    local rdy = rd.y^-1
    local rdz = rd.z^-1

    -- gives division by zero error if left unattended
    rdx = rd.x ~= 0 and rd.x^-1 or 9999999999
    rdy = rd.y ~= 0 and rd.y^-1 or 9999999999
    rdz = rd.z ~= 0 and rd.z^-1 or 9999999999

    local m = sm.vec3.new(rdx, rdy, rdz) -- can precompute if traversing a set of aligned boxes
    local n = m * ro   -- can precompute if traversing a set of aligned boxes
    local k = sm.vec3.new(math.abs(m.x),math.abs(m.y),math.abs(m.z)) * boxSize
    local t1 = -n - k
    local t2 = -n + k
    local tN = math.max(math.max( math.max( t1.x, t1.y ), t1.z ), 0)
    local tF = math.min( math.min( t2.x, t2.y ), t2.z )
    --print("tN:",tN,"tF:",tF)
    return (tF - tN) / 2
end

local function reflect (v,n)
    return v - n * 2 * v:dot(n)
end

-----------------------------------------------------------------------------------
--[[                        Armor properties calculation                       ]]--
-----------------------------------------------------------------------------------

function is_seat(hit_shape)
    local interactable = hit_shape.interactable
    if not interactable then
        return false
    end

    if interactable.type == "seat" or interactable.type == "scripted" then
        return true
    end

    return false
end

function calculate_ricochet (direction, normal, shell)
    local angle = math.acos(normal:dot(direction:normalize())) * 180/math.pi
    if angle > 90 then
        angle = 180 - angle
    end
    if shell.type == "APFSDS" then
        local chance = clamp(1, 0, -0.005*angle^2 + 0.9*angle - 39.5)
        local choice = math.random()
        if choice <= chance then
            local random_dir = sm.vec3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5):normalize() / 10
            return reflect(direction:normalize(), (normal + random_dir):normalize())
        end
        return nil
    elseif shell.type == "AP" then
        local chance = clamp(1,0, 0.03*angle - 45 * 0.03)
        local choice = math.random()
        if choice <= chance then
            local random_dir = sm.vec3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5):normalize() / 10
            return reflect(direction:normalize(), (normal + random_dir):normalize())
        end
    end
end

function calculate_armor_thickness(hit_shape, hit_point, hit_direction)
    local ro = hit_shape:transformPoint(hit_point)
    local rd = hit_shape:transformDirection(hit_direction)
    local box_size = hit_shape:getBoundingBox()
    return ray_box_intersection(ro, rd, box_size)
end

function material_to_RHA(hit_shape)
    if not hit_shape.isBlock then
        if is_seat(hit_shape) then
            return 0.01
        end
    end

    local multipliers = {
        Plastic = 0.15,
        Rock = 0.7,
        Metal = 1,
        Mechanical = 0.99,
        Wood = 0.07,
        Sand = 0.04,
        Glass = 0.4,
        Grass = 0.03,
        Cardboard = 0.03,
        Steering = 0.8,
        Fruit = 0.04,
        Default = 0.8,
    }
    local material = hit_shape.material
    return multipliers[material] / 1.5
end
