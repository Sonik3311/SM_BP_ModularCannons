dofile "$CONTENT_DATA/Scripts/armor_calc.lua"
dofile "$CONTENT_DATA/Scripts/shell_util.lua"

local function is_soft_shape(hit_shape)
    local materials = {
        Plastic = true,
        Rock = false,
        Metal = false,
        Mechanical = false,
        Wood = false,
        Sand = true,
        Glass = true,
        Grass = true,
        Cardboard = true,
        Steering = false,
        Fruit = true,
        Default = false,
    }
    return materials[hit_shape.material]
end

function random_vector_in_cone(dir, angle)
    local axis1 = dir:cross(sm.vec3.new(0, 0, 1))

    if axis1:length2() < 0.01 then
        axis1 = dir:cross(sm.vec3.new(0, 1, 0))
    end
    axis1 = axis1:normalize()

    local gamma = math.random(0, 2 * math.pi * 1000) / 1000
    local theta = math.random(0, angle * 1000) / 1000


    local vec = dir:rotate(theta, axis1)
    vec = vec:rotate(gamma, dir)

    return vec
end

function process_multi_spall(position, direction, angles_amounts, ignore_shape)
    local hit_shapes_blocks = {}
    local return_paths = {}

    for spall_cone_id = 1, #angles_amounts do
        local config = angles_amounts[spall_cone_id]
        local cone_angle = config[1] * math.pi / 180
        local spall_amount = config[2]
        local spall_penetration = config[3]

        local casts = {}
        for i = 1, spall_amount do
            local dir = random_vector_in_cone(direction, cone_angle)
            casts[i] = {
                type        =  "ray",
                startPoint  =   position,
                endPoint    =   position + dir * 10,
                direction   =   dir,
                max_pen = spall_penetration,
                mask = 1 + 2,
            }
        end

        local iter_counter = 0
        while #casts > 0 and iter_counter < 100 do
            local new_casts = {}
            local results = sm.physics.multicast(casts)
            for i = 1, #casts do
                local ray = casts[i]
                local result = results[i]
                local hit, hit_result = result[1], result[2]

                if not hit then
                    return_paths[#return_paths + 1] = {ray.startPoint, ray.endPoint}
                    goto next
                end

                local hit_shape = hit_result:getShape()

                if not hit_shape then
                    return_paths[#return_paths + 1] = {ray.startPoint, hit_result.pointWorld}
                    goto next
                end

                -- penetrate if possible
                local armor_thickness = calculate_armor_thickness(hit_shape, ray.startPoint, ray.direction)
                local RHA_multiplier = material_to_RHA(hit_shape)
                local RHA_thickness = armor_thickness * 1000 * RHA_multiplier
                local is_penetrated = (RHA_thickness - ray.max_pen) < 0
                ray.max_pen = math.max(0, ray.max_pen - RHA_thickness)

                if not is_penetrated then
                    -- color the hit block black or smth
                    return_paths[#return_paths + 1] = {ray.startPoint, hit_result.pointWorld}

                    goto next
                end

                local armor_penetrated = armor_thickness / math.max(1, RHA_thickness / ray.max_pen)
                local exit_point = hit_result.pointWorld + ray.direction * armor_penetrated


                penetrate_shape(hit_shape, hit_result.pointWorld, exit_point)
                if hit_shape.isBlock and is_penetrated then
                    hit_shape:destroyBlock(hit_shape:getClosestBlockLocalPosition(exit_point))
                end

                return_paths[#return_paths + 1] = {ray.startPoint, exit_point}
                ray.startPoint = exit_point
                new_casts[#new_casts + 1] = ray
                ::next::
            end
            iter_counter = iter_counter + 1
            casts = new_casts
        end
    end
    return return_paths
end

function process_spall(position, direction, amount, ignore_shape)
    local end_point = position + direction * 20
    local hit, hit_data = sm.physics.raycast(position, end_point, ignore_shape)
    local hit_shape = hit_data:getShape()
    if hit and hit_shape and hit_shape.isBlock then
        local voxel = hit_shape:getClosestBlockLocalPosition( hit_data.pointWorld )
        hit_shape:destroyBlock(voxel)
    elseif hit and hit_shape then
        hit_shape:destroyShape()
    end

    return position, hit_data.pointWorld:length2() ~= 0 and hit_data.pointWorld or end_point
end
