dofile "$CONTENT_DATA/Scripts/armor_calc.lua"

local function is_seat(hit_shape)
    local uuid_seat = {
        sm.uuid.new("42786777-c148-4e13-9bab-e460564e79c3"), -- seat
        sm.uuid.new("cf3fdcfc-a7e5-4497-b000-ffda67dd8db7"), -- driver's seat
        sm.uuid.new("2b9c6e87-1b75-4a57-8979-74d9f95668ba"), -- seat 2
        sm.uuid.new("3b972f2f-30c7-4a5e-a100-5e257e62295d"), -- seat 1
        sm.uuid.new("46465697-ed36-4720-ba8a-08c568b4e36c"), -- seat 4
        sm.uuid.new("703ca746-d802-4e76-b443-4881e83afb73"), -- seat 5
        sm.uuid.new("77c2687c-2e13-4df8-996a-96fb26d75ee0"), -- driver's seat 1
        sm.uuid.new("847daf20-02bf-4170-8699-9ab106acd29a"), -- scrap seat
        sm.uuid.new("8694192c-d91b-444c-a184-910911bbb354"), -- oily toilet seat
        sm.uuid.new("bd597ac9-6640-43ba-9bd8-ed584a794f13"), -- scrap driver's seat
        sm.uuid.new("c3ef3008-9367-4ab7-813a-24195d63e5a3"), -- driver's seat 3
        sm.uuid.new("d30dcd12-ec39-43b9-a115-44c08e1b9091"), -- driver's seat 4
        sm.uuid.new("ebe2782e-a4f5-4d91-83cc-db110179393b"), -- seat 3
        sm.uuid.new("efbf45f8-62ec-4541-9eb1-d529966f6a29"), -- driver's seat 2
        sm.uuid.new("ffa3a47e-fc0d-4977-802f-bd15683bbe5c"), -- driver's seat 5
    }
    for i = 1, #uuid_seat do
        if hit_shape.uuid == uuid_seat[i] then
           return true
        end
    end
    return false
end

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
                body = ignore_shape
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

                if hit_result.type == "joint" then -- joints have weird collisions, ignore them
                    ray.body = hit_shape
                    ray.startPoint = hit_result.pointWorld
                    new_casts[#new_casts + 1] = ray
                    return_paths[#return_paths + 1] = {ray.startPoint, hit_result.pointWorld}
                    goto next
                end
                -- penetrate if possible
                local armor_thickness = calculate_armor_thickness(hit_shape, ray.startPoint, ray.direction)
                local RHA_multiplier = material_to_RHA(hit_shape)
                local RHA_thickness = armor_thickness * 1000 * RHA_multiplier
                local is_penetrated = (RHA_thickness - ray.max_pen) < 0

                if not is_penetrated then
                    -- color the hit block black or smth
                    return_paths[#return_paths + 1] = {ray.startPoint, hit_result.pointWorld}

                    goto next
                end

                local armor_penetrated = armor_thickness / math.max(1, RHA_thickness / ray.max_pen)
                local exit_point = hit_result.pointWorld + ray.direction * armor_penetrated
                ray.max_pen = math.max(0, ray.max_pen - RHA_thickness)

                ray.startPoint = exit_point

                return_paths[#return_paths + 1] = {ray.startPoint, exit_point}
                new_casts[#new_casts + 1] = ray
                ::next::
            end
            iter_counter = iter_counter + 1
            casts = new_casts
        end
        print(iter_counter)
        if iter_counter > 99 then

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
