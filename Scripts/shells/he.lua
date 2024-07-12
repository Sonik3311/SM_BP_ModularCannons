dofile "$CONTENT_DATA/Scripts/armor_calc.lua"
dofile "$CONTENT_DATA/Scripts/spall.lua"
dofile "$CONTENT_DATA/Scripts/shell_util.lua"

local function get_fragment_config(shell)
    local shell_mass = shell.parameters.projectile_mass
    local explosive_mass = shell.parameters.explosive_mass
    local shell_diameter = shell.parameters.diameter
    local shell_velocity = shell.velocity:length()

    --local fragment_mass = (explosive_mass / shell_mass) * shell_diameter
    local fragment_pen = explosive_mass * shell_diameter

    local fragment_amount = math.max(math.min(shell_diameter^1.2, 450), 50)

    local fragment_angle = 150
    print(fragment_pen)
    return fragment_amount, fragment_pen, fragment_angle
end

function process_he_penetration (shell, hit_shape, hit_data, start_point, end_point, dt)

    local shell_direction = shell.velocity:normalize()
    local ricochet_dir = calculate_ricochet(shell_direction, hit_data.normalWorld, shell)
    if ricochet_dir then
        shell.position = hit_data.pointWorld
        shell.velocity = ricochet_dir * shell.velocity:length() / 1.3
        shell_direction = ricochet_dir
        new_start_point = hit_data.pointWorld
        new_end_point = new_start_point + shell.velocity * dt
        return true, new_start_point, new_end_point, shell_direction
    end

    local shape = hit_data:getShape()
    --sm.physics.applyImpulse( shape, shell_direction * 10 * shape.body.mass, true )

    local f_amount, f_pen, f_angle = get_fragment_config(shell)
    local spall_paths = process_multi_spall(hit_data.pointWorld - shell_direction / 10, shell.velocity:normalize(), {{f_angle, f_amount, f_pen}}, nil)

    if shell.debug then
        for path_id = 1, #spall_paths do
            local path = spall_paths[path_id]
            shell.debug.path.spall[#shell.debug.path.spall + 1] = {path[1], path[2]}
        end
    end

    return false, new_start_point, hit_data.pointWorld, shell_direction
end
