dofile "$CONTENT_DATA/Scripts/armor_calc.lua"
dofile "$CONTENT_DATA/Scripts/spall.lua"
dofile "$CONTENT_DATA/Scripts/shell_util.lua"

local function get_spall_amount(shell)
    max_spall_amount = math.max(7, shell.parameters.diameter)
end

function process_apfsds_penetration (shell, hit_shape, hit_data, start_point, end_point, dt)

    local shell_direction = shell.velocity:normalize()

    local ricochet_dir = calculate_ricochet(shell_direction, hit_data.normalWorld, shell)
    local armor_thickness = calculate_armor_thickness(hit_shape, hit_data.pointWorld, shell_direction)
    local RHA_multiplier = material_to_RHA(hit_shape)
    local RHA_thickness = armor_thickness * 700 * RHA_multiplier

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
    --print(armor_thickness, RHA_thickness, shell_penetration)
    local exit_point = hit_data.pointWorld + shell_direction * (armor_thickness - math.max(RHA_thickness - shell_penetration, 0) / RHA_multiplier / 1000)
    print(RHA_thickness - shell_penetration, armor_thickness * 1000, RHA_thickness, armor_thickness * 1000 - math.max(RHA_thickness - shell_penetration, 0) / (1-RHA_multiplier))

    shell.max_pen = math.max(0, shell.max_pen - RHA_thickness)

    hit_shape:setColor(sm.color.new(math.random(), math.random(), math.random()))

    print("deleting")
    if hit_shape.isBlock then

        local p1 = hit_shape:getClosestBlockLocalPosition( exit_point )
        local p2 = hit_shape:getClosestBlockLocalPosition( hit_data.pointWorld )
        hit_shape:destroyBlock(p1)
        for _,block in pairs(voxel_trace(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z)) do
            hit_shape:destroyBlock(block)
        end
    else
        hit_shape:destroyShape()
    end

    local new_end_point = not is_penetrated and exit_point or end_point
    local new_start_point = hit_data.pointWorld + shell_direction * armor_thickness / 2

    if is_penetrated and is_exititing_body(new_start_point, shell_direction, hit_shape) then -- check if exiting body and create spall if we do
        for i=1, 20 do
            local spall_start, spall_end = process_spall(new_start_point, random_vector_in_cone(shell_direction, math.pi/6), hit_shape, shell)
            if shell.debug then
               shell.debug.path.spall[#shell.debug.path.spall + 1] = {spall_start, spall_end}
            end
        end
    end

    return is_penetrated, new_start_point, new_end_point, shell_direction
end
