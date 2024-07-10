dofile "$CONTENT_DATA/Scripts/armor_calc.lua"
dofile "$CONTENT_DATA/Scripts/spall.lua"
dofile "$CONTENT_DATA/Scripts/shell_util.lua"

local function get_spall_amount(shell, hit_shape)
    local material_multiplier = {
        Plastic = 0.4,
        Rock = 0.7,
        Metal = 1,
        Mechanical = 1.1,
        Wood = 0.15,
        Sand = 0.05,
        Glass = 0.3,
        Grass = 0.05,
        Cardboard = 0.05,
        Steering = 0.8,
        Fruit = 0.05,
        Default = 0.8,
    }

    local max_spall_amount = math.max(7, math.min(shell.parameters.diameter, 60))
    return math.ceil(max_spall_amount * material_multiplier[hit_shape.material])
end

function process_apfsds_penetration (shell, hit_shape, hit_data, start_point, end_point, dt)

    local shell_direction = shell.velocity:normalize()

    local ricochet_dir = calculate_ricochet(shell_direction, hit_data.normalWorld, shell)
    local armor_thickness = calculate_armor_thickness(hit_shape, start_point, shell_direction)
    local RHA_multiplier = material_to_RHA(hit_shape)
    local RHA_thickness = armor_thickness * 1000 * RHA_multiplier

    if ricochet_dir then
        shell.position = hit_data.pointWorld
        shell.velocity = ricochet_dir * shell.velocity:length() / 1.3
        shell_direction = ricochet_dir
        new_start_point = hit_data.pointWorld
        new_end_point = new_start_point + shell.velocity * dt
        return true, new_start_point, new_end_point, shell_direction
    end

    local shell_penetration = shell.max_pen
    local is_penetrated = (RHA_thickness - shell_penetration) < 0

    local armor_penetrated = armor_thickness / math.max(1, RHA_thickness / shell_penetration)
    local exit_point = hit_data.pointWorld + shell_direction * armor_penetrated
    shell.max_pen = math.max(0, shell.max_pen - RHA_thickness)

    hit_shape:setColor(sm.color.new(math.random(), math.random(), math.random()))

    local new_end_point = not is_penetrated and exit_point or end_point
    local new_start_point = hit_data.pointWorld + shell_direction * armor_thickness / 2

    penetrate_shape(hit_shape, hit_data.pointWorld, exit_point)
    if hit_shape.isBlock and is_penetrated then
        hit_shape:destroyBlock(hit_shape:getClosestBlockLocalPosition(new_start_point))
    end


    if is_penetrated and (not is_seat(hit_shape)) and is_exititing_body(new_start_point, shell_direction, hit_shape) then -- check if exiting body and create spall if we do
        local spall_amount = get_spall_amount(shell, hit_shape)
        local big_spall_amount = math.ceil(spall_amount / 10)
        local med_spall_amount = math.ceil(spall_amount / 5)
        local low_spall_amount = spall_amount
        local spall_paths = process_multi_spall(exit_point, shell_direction, {{10, big_spall_amount, 70}, {20, med_spall_amount, 40}, {30, low_spall_amount, 20}}, hit_shape)

        if shell.debug then
            for path_id = 1, #spall_paths do
                local path = spall_paths[path_id]
                shell.debug.path.spall[#shell.debug.path.spall + 1] = {path[1], path[2]}
            end
        end
    end

    return is_penetrated, new_start_point, new_end_point, shell_direction
end
