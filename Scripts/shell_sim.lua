dofile "$CONTENT_DATA/Scripts/pen_calc_util.lua"
dofile "$CONTENT_DATA/Scripts/pen_proc_util.lua"
dofile "$CONTENT_DATA/Scripts/shell_sim_util.lua"

local function process_shell_collision (shell, dt)
    local raycast = sm.physics.raycast

    local shell_direction = shell.velocity:normalize()
    local start_point = shell.position
    local end_point = shell.position + shell.velocity * dt

    local is_hit, hit_data = raycast(start_point, end_point)

    while is_hit do
        local hit_shape = hit_data:getShape()

        if not hit_shape then -- ground
            return false, end_point
        end
        local is_alive
        is_alive, start_point, end_point, shell_direction = process_apfsds_penetration (shell, hit_shape, hit_data,
                                                                                              start_point, end_point, dt)
        if not is_alive then
           return false, end_point
        end
        add_point_to_line(shell.debug.path, start_point)
        is_hit, hit_data = raycast(start_point, end_point, hit_shape)
    end

    return true, end_point
end



function update_shells (shells, dt, net)
    for shell_id, shell in pairs(shells) do
        if shell == nil then
            goto next
        end

        shell.velocity = shell.velocity - sm.vec3.new(0, 0, 9.8 * dt)

        local alive, next_position = process_shell_collision(shell, dt, net)

        add_point_to_line(shell.debug.path, next_position)

        if not alive then
            net:sendToClients("cl_save_path", shell.debug.path)
            shells[shell_id] = nil
            goto next
        end

        shell.position = next_position

        ::next::
    end
end
