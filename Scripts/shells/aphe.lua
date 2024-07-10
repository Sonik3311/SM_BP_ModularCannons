dofile "$CONTENT_DATA/Scripts/armor_calc.lua"
dofile "$CONTENT_DATA/Scripts/spall.lua"
dofile "$CONTENT_DATA/Scripts/shell_util.lua"

function process_aphe_fuse(shell, start_point, end_point)

    local distance = (start_point - end_point):length()
    local time = distance / shell.velocity:length()
    local fuse_time = shell.fuse.delay
    local delta_time = fuse_time - time
    if delta_time > 0 then -- there's still time left
        shell.fuse.delay = fuse_time - time
        return nil
    end
    --explosion

    local explosion_time = fuse_time
    local explosion_point = start_point + shell.velocity * explosion_time
    print(explosion_point)

    local spall_paths = process_multi_spall(explosion_point, shell.velocity:normalize(), {{100, 150, 10}}, nil)

    if shell.debug then
        for path_id = 1, #spall_paths do
            local path = spall_paths[path_id]
            shell.debug.path.spall[#shell.debug.path.spall + 1] = {path[1], path[2]}
        end
    end
    return explosion_point
end

function process_aphe_penetration (shell, hit_shape, hit_data, start_point, end_point, dt)

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

    if is_penetrated and not shell.fuse.active and RHA_thickness >= shell.fuse.trigger_depth then
        -- fuse ignition
        print("IGNITION")
        shell.fuse.active = true
        local time_to_travel_shape = armor_thickness / shell.velocity:length()

        if shell.fuse.delay - time_to_travel_shape <= 0 then
            print("exploded in armor", time_to_travel_shape)
            return false, start_point, hit_data.pointWorld + shell.velocity * shell.fuse.delay
        end
        shell.fuse.delay = shell.fuse.delay - time_to_travel_shape
    elseif shell.fuse.active then
        print(armor_thickness)
        local time_to_travel_shape = armor_thickness / shell.velocity:length()
        if shell.fuse.delay - time_to_travel_shape <= 0 then
            print("exploded in armor 2", time_to_travel_shape, shell.fuse.delay)
            return false, start_point, hit_data.pointWorld + shell.velocity * shell.fuse.delay
        end
        shell.fuse.delay = shell.fuse.delay - time_to_travel_shape
    end

    hit_shape:setColor(sm.color.new(math.random(), math.random(), math.random()))

    local new_end_point = not is_penetrated and exit_point or end_point
    local new_start_point = hit_data.pointWorld + shell_direction * armor_thickness / 2

    penetrate_shape(hit_shape, hit_data.pointWorld, exit_point)
    if hit_shape.isBlock and is_penetrated then
        hit_shape:destroyBlock(hit_shape:getClosestBlockLocalPosition(new_start_point))
    end

    --[[if is_penetrated and (not is_seat(hit_shape)) and is_exititing_body(new_start_point, shell_direction, hit_shape) then
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
        print(#spall_cones, spall_cones)

        local spall_paths = process_multi_spall(exit_point, shell_direction, spall_cones, hit_shape)

        if shell.debug then
            for path_id = 1, #spall_paths do
                local path = spall_paths[path_id]
                shell.debug.path.spall[#shell.debug.path.spall + 1] = {path[1], path[2]}
            end
        end
        end]]

    return is_penetrated, new_start_point, new_end_point, shell_direction
end
