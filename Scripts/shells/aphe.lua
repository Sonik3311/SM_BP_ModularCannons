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

    local max_spall_amount = math.max(7, math.min(shell.parameters.diameter, 90))
    return math.ceil(max_spall_amount * material_multiplier[hit_shape.material])
end

local function get_fragment_config(shell)
    local shell_mass = shell.parameters.projectile_mass
    local explosive_mass = shell.parameters.explosive_mass
    local shell_diameter = shell.parameters.diameter
    local shell_velocity = shell.velocity:length()

    local fragment_mass = (explosive_mass / shell_mass) * shell_diameter
    local fragment_pen = fragment_mass * shell_mass

    local fragment_amount = math.max(math.min(explosive_mass / shell_mass * 300, 250), 20)

    local min_angle = 70
    local max_angle = 135
    local fragment_angle = math.max(math.min(max_angle - shell_velocity * (2/3/10), max_angle), min_angle)
    return fragment_amount, fragment_pen, fragment_angle
end

local function get_spall_cones(shell)
    local velocity = shell.velocity:length()
    local diameter = shell.parameters.diameter

    local hi_velocity_cone = math.max(math.min(velocity, 30), 10)
    local me_velocity_cone = hi_velocity_cone * 2
    local lo_velocity_cone = hi_velocity_cone * 3

    if velocity > 400 and diameter >= 40 then
        return {hi_velocity_cone, me_velocity_cone, lo_velocity_cone}
    end
    if velocity > 300 and diameter >= 20 then
        return {hi_velocity_cone, me_velocity_cone, nil}
    end

    return {hi_velocity_cone, nil, nil}
end

function process_collision_aphe_inject(shell, start_pos, is_hit, end_point, hit_point)
    local end_pos = is_hit and hit_point or end_point
    local explosion_point = process_aphe_fuse(shell, start_pos, end_pos)
    if explosion_point then
        return false, explosion_point
    end
    return true, nil
end

function process_aphe_fuse(shell, start_point, end_point)
    local distance = (start_point - end_point):length()
    local time = distance / shell.velocity:length()
    local fuse_time = shell.fuse.delay

    local delta_time = fuse_time - time
    if delta_time > 0 then
        shell.fuse.delay = delta_time
        return nil
    end

    local explosion_point = start_point + shell.velocity * fuse_time
    local fragment_amount, fragment_pen, fragment_angle = get_fragment_config(shell)
    local spall_paths = process_multi_spall(explosion_point, shell.velocity:normalize(), {{fragment_angle, fragment_amount, fragment_angle}}, nil)

    if shell.debug then
        for path_id = 1, #spall_paths do
            local path = spall_paths[path_id]
            shell.debug.path.spall[#shell.debug.path.spall + 1] = {path[1], path[2]}
        end
    end
    return explosion_point
end

function process_aphe_penetration (shell, hit_shape, hit_data, start_point, end_point, dt, net)

    if shell.fuse.active then
        local is_alive, explosion_point = process_collision_aphe_inject(shell, start_point, true, end_point, hit_data.pointWorld)
        if not is_alive then
            return false, false, start_point, explosion_point, nil
        end
    end

    local shell_direction = shell.velocity:normalize()
    local is_world_surface = is_world_surface(hit_data.type)
    if is_world_surface then
        return false, false, start_point, end_point,shell_direction
    end

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
        return true, false, new_start_point, new_end_point, shell_direction
    end

    local shell_penetration = shell.max_pen
    local is_penetrated = (RHA_thickness - shell_penetration) < 0

    local armor_penetrated = armor_thickness / math.max(1, RHA_thickness / shell_penetration)
    local exit_point = hit_data.pointWorld + shell_direction * armor_penetrated
    shell.max_pen = math.max(0, shell.max_pen - RHA_thickness)

    if is_penetrated and not shell.fuse.active and RHA_thickness >= shell.fuse.trigger_depth then
        shell.fuse.active = true
    end

    if shell.fuse.active then
        local time_to_travel_shape = armor_thickness / shell.velocity:length()
        if shell.fuse.delay - time_to_travel_shape <= 0 then
            return false, start_point, hit_data.pointWorld + shell.velocity * shell.fuse.delay, nils
        end
        shell.fuse.delay = shell.fuse.delay - time_to_travel_shape
    end

    hit_shape:setColor(sm.color.new(math.random(), math.random(), math.random()))

    local new_end_point = not is_penetrated and exit_point or end_point
    local new_start_point = hit_data.pointWorld - shell_direction * 0.01

    penetrate_shape(hit_shape, hit_data.pointWorld, exit_point)
    if hit_shape.isBlock and is_penetrated then
        hit_shape:destroyBlock(hit_shape:getClosestBlockLocalPosition(new_start_point))
    end

    local is_exiting = is_exititing_body(new_start_point, shell_direction, hit_shape)
    if is_penetrated and (not is_seat(hit_shape)) and is_exiting then
        local spall_amount = get_spall_amount(shell, hit_shape)
        local big_spall_amount = math.ceil(spall_amount / 10)
        local med_spall_amount = math.ceil(spall_amount / 5)
        local low_spall_amount = spall_amount

        local spall_angles = get_spall_cones(shell)

        local spall_cones = {
            spall_angles[1] and {spall_angles[1], big_spall_amount, 70} or nil,
            spall_angles[2] and {spall_angles[2], big_spall_amount, 50} or nil,
            spall_angles[3] and {spall_angles[3], big_spall_amount, 30} or nil,
        }

        local spall_paths, spall_effect_data = process_multi_spall(exit_point, shell_direction, spall_cones, hit_shape)

        local clamped_spall_data = {}
        for i = 1, #spall_effect_data, math.max(math.floor(#spall_effect_data / 100 + 0.5),1) do
            clamped_spall_data[#clamped_spall_data + 1] = spall_effect_data[i]
        end
        net:sendToClients("cl_play_spall_effects", clamped_spall_data)

        if shell.debug then
            for path_id = 1, #spall_paths do
                local path = spall_paths[path_id]
                shell.debug.path.spall[#shell.debug.path.spall + 1] = {path[1], path[2]}
            end
        end
    end

    return is_penetrated, is_exititing, new_start_point, new_end_point, shell_direction
end
