dofile "$CONTENT_DATA/Scripts/armor_calc.lua"
dofile "$CONTENT_DATA/Scripts/shell_util.lua"
dofile "$CONTENT_DATA/Scripts/spall.lua"

local function reflect(v, n)
    return v - n * 2 * v:dot(n)
end

function apx_equals(x, y, delta)
    return math.abs(x - y) <= delta
end

function isAnyOf(target, pool)
    for _, object in pairs(pool) do
        if object == target then
            return true
        end
    end

    return false
end

function is_visible(start_pos, end_pos, end_shape, ignore)
    local ray_start = start_pos
    local ray_end = end_pos
    local ignore_obj = nil
    local dir = (ray_end - ray_start):normalize()
    for i = 1, 1000 do
        local is_hit, hit_data = sm.physics.raycast(start_pos, end_pos)
        if not is_hit then
            return true
        end

        local hit_shape = hit_data:getShape()
        if not hit_shape then
            return false
        end

        if hit_shape == end_shape then
            return true
        end

        if hit_shape.uuid == ignore then
            ignore_obj = hit_shape
        end
    end
    sm.log.warning("func is_visible exceeded iteration limit")
    return false
end

local ammorack = sm.uuid.new("2d93cd84-6690-4eb0-8058-9c239dde0fbe")
function find_blowout_panels(position, ray_count, max_iter_count)
    local alive_rays = {}

    local iter_count = 0
    local volume_min_x, volume_min_y, volume_min_z = 99999999, 99999999, 99999999
    local volume_max_x, volume_max_y, volume_max_z = -99999999, -99999999, -99999999

    for ray_id = 1, ray_count do
        local ray_dir = random_vector_in_cone(sm.vec3.new(1, 0, 0), 180)
        alive_rays[ray_id] = {
            type       = "ray",
            startPoint = position,
            endPoint   = position + ray_dir * 10,
            direction  = ray_dir
        }
    end

    local blowout_panels = {}
    local found_air = 0
    local escaped_compartment = 0

    while #alive_rays > 0 and iter_count < (max_iter_count or math.huge) do
        local result = sm.physics.multicast(alive_rays)
        local new_rays = {}
        for ray_id = 1, #alive_rays do
            local ray, ray_result = alive_rays[ray_id], result[ray_id]
            local is_hit, hit_data = ray_result[1], ray_result[2]
            if not is_hit then
                found_air = found_air + 1
                goto next
            end

            local shape = hit_data:getShape()

            if not shape then
                goto next
            end

            if shape.uuid == ammorack then
                ray.startPoint = hit_data.pointWorld + ray.direction * 0.125
                new_rays[#new_rays + 1] = ray
                goto next
            end

            local durability = sm.item.getQualityLevel(shape.shapeUuid)
            if durability <= 5 then
                blowout_panels[shape.id] = { shape, hit_data.normalLocal, hit_data.normalWorld }
            end

            local new_dir = reflect(ray.direction, hit_data.normalWorld)

            ray.startPoint = hit_data.pointWorld
            ray.endPoint = ray.startPoint + new_dir * 10
            ray.direction = new_dir

            local x = hit_data.pointWorld.x
            local y = hit_data.pointWorld.y
            local z = hit_data.pointWorld.z
            volume_min_x = x < volume_min_x and x or volume_min_x
            volume_min_y = y < volume_min_y and y or volume_min_y
            volume_min_z = z < volume_min_z and z or volume_min_z
            volume_max_x = x > volume_max_x and x or volume_max_x
            volume_max_y = y > volume_max_y and y or volume_max_y
            volume_max_z = z > volume_max_z and z or volume_max_z

            new_rays[#new_rays + 1] = ray

            ::next::
        end
        iter_count = iter_count + 1
    end

    local volume_min = sm.vec3.new(volume_min_x, volume_min_y, volume_min_z)
    local volume_max = sm.vec3.new(volume_max_x, volume_max_y, volume_max_z)

    return blowout_panels, found_air, volume_min, volume_max, escaped_compartment
end

function fragments_explode(position, reflection_count, should_destroy_on_reflection, max_penetration, to_ignore)
    local alive_rays = {}

    local iter_count = 0

    for ray_id = 1, 200 do
        local ray_dir = random_vector_in_cone(sm.vec3.new(1, 0, 0), 180)
        alive_rays[ray_id] = {
            type       = "ray",
            startPoint = position,
            endPoint   = position + ray_dir * 10,
            direction  = ray_dir,
            max_pen    = max_penetration
        }
    end

    while #alive_rays > 0 and iter_count < 200 do
        local result = sm.physics.multicast(alive_rays)
        local new_rays = {}
        for ray_id = 1, #alive_rays do
            local ray, ray_result = alive_rays[ray_id], result[ray_id]
            local is_hit, hit_data = ray_result[1], ray_result[2]
            if not is_hit then
                goto next
            end

            local hit_shape = hit_data:getShape()

            if not hit_shape then
                goto next
            end

            if hit_shape.uuid == ammorack or isAnyOf(hit_shape, to_ignore or {}) then
                ray.startPoint = hit_data.pointWorld + ray.direction * 0.125
                new_rays[#new_rays + 1] = ray
                goto next
            end

            if iter_count < reflection_count then
                local new_dir = reflect(ray.direction, hit_data.normalWorld)

                ray.startPoint = hit_data.pointWorld
                ray.endPoint = ray.startPoint + new_dir * 10
                ray.direction = new_dir
            else -- penetrate
                local armor_thickness = calculate_armor_thickness(hit_shape, ray.startPoint, ray.direction)
                local RHA_multiplier = material_to_RHA(hit_shape)
                local RHA_thickness = armor_thickness * 1000 * RHA_multiplier

                local is_penetrated = (RHA_thickness - ray.max_pen) < 0
                if not is_penetrated then
                    goto next
                end
                ray.max_pen = math.max(0, ray.max_pen - RHA_thickness)

                local armor_penetrated = armor_thickness / math.max(1, RHA_thickness / ray.max_pen)
                local exit_point = hit_data.pointWorld + ray.direction * armor_penetrated
                penetrate_shape(hit_shape, hit_data.pointWorld, exit_point)

                if hit_shape.isBlock and is_penetrated then
                    hit_shape:destroyBlock(hit_shape:getClosestBlockLocalPosition(exit_point))
                end

                ray.startPoint = hit_data.pointWorld - ray.direction * 0.01
            end

            new_rays[#new_rays + 1] = ray

            ::next::
        end
        iter_count = iter_count + 1
    end
end

function is_shape_covered(shape, covering_shape)
    -- can just do X*Y amount of rays...
    -- BUT I DON't WANT TO
    -- may have to

    -- diagonal check

    --local delta = shape:getClosestBlockLocalPosition( covering_shape:getWorldPosition() )
    --print(delta, shape:getBoundingBox())

    local delta = shape:transformPoint(covering_shape:getWorldPosition())
    -- remove all those pesky near-zero values
    delta.x = math.abs(delta.x) < 0.001 and 0 or delta.x -- thank you axolot, very cool!
    delta.y = math.abs(delta.y) < 0.001 and 0 or delta.y -- thank you axolot, very cool!
    delta.z = math.abs(delta.z) < 0.001 and 0 or delta.z -- thank you axolot, very cool!

    local s_aabb = shape:getBoundingBox()
    local cs_aabb = covering_shape:getBoundingBox()

    local x_overlaps = apx_more_or_equals(cs_aabb.x / 2, math.abs(delta.x) + s_aabb.x / 2, 0.005) and
        apx_more_or_equals(math.abs(delta.z), (s_aabb.z / 2 + 0.125), 0.005)
    local y_overlaps = apx_more_or_equals(cs_aabb.y / 2, math.abs(delta.z) + s_aabb.z / 2, 0.005) and
        apx_more_or_equals(math.abs(delta.y), (s_aabb.y / 2 + 0.125), 0.005)
    local z_overlaps = cs_aabb.z / 2 >= (math.abs(delta.z) + s_aabb.z / 2)
    print(apx_more_or_equals(cs_aabb.z / 2, math.abs(delta.z) + s_aabb.z / 2, 0.005),
        apx_more_or_equals(math.abs(delta.y), (s_aabb.y / 2 + 0.125), 0.005),
        cs_aabb.z / 2, delta.z, s_aabb.z / 2, delta.y, s_aabb.y / 2 + 0.125)
    --if y_overlaps then sm.log.warning(y_overlaps) else print(y_overlaps) end
    print(y_overlaps)
    -- figure out on which side covering shape is placed
    -- why is it not in the sm api by default??? You guys literally have getNeighbours function and it does NOT sort by sides
    local point_cs = sm.vec3.zero()
    local cs_aabb = covering_shape:getBoundingBox()
    local point_s = sm.vec3.zero()
    local s_aabb = shape:getBoundingBox()

    point_cs.x = math.min(s_aabb.x / 2 - 0.125, math.abs(delta.x)) * (delta.x >= 0 and -1 or 1)
    point_cs.y = math.min(s_aabb.y / 2 - 0.125, math.abs(delta.y)) * (delta.y >= 0 and -1 or 1)
    point_cs.z = math.min(s_aabb.z / 2 - 0.125, math.abs(delta.z)) * (delta.z >= 0 and -1 or 1)

    point_cs = point_cs


    point_s.x = math.min(s_aabb.x / 2, math.abs(point_cs.x)) * (point_cs.x >= 0 and 1 or -1)
    point_s.y = math.min(s_aabb.y / 2, math.abs(point_cs.y)) * (point_cs.y >= 0 and 1 or -1)
    point_s.z = math.min(s_aabb.z / 2, math.abs(point_cs.z)) * (point_cs.z >= 0 and 1 or -1)
end
