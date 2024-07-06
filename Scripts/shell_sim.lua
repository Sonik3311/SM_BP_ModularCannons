-- hi there, watcha doin?
dofile "$CONTENT_DATA/Scripts/Shells/apfsds.lua"
dofile "$CONTENT_DATA/Scripts/Shells/ap.lua"
dofile "$CONTENT_DATA/Scripts/dprint.lua"
dofile "$CONTENT_DATA/Scripts/debug_path_draw.lua"

local dprint_filename = "shell_sim"


local function is_world_surface(object_type)
    return object_type == "terrainSurface" or object_type == "limiter"
end

function process_shell_collision (shell, dt)
    local raycast = sm.physics.raycast

    local shell_direction = shell.velocity:normalize()
    local start_point = shell.position
    local end_point = shell.position + shell.velocity * dt

    local is_hit, hit_data = raycast(start_point, end_point)

    while is_hit do
        local hit_shape = hit_data:getShape()
        local is_alive = true

        if is_world_surface(hit_data.type) then
            return false, end_point
        end

        if hit_data.type == "joint" then
            start_point = hit_data.pointWorld
            end_point = end_point
            goto skip_shape
        end

        is_alive, start_point, end_point, shell_direction = process_ap_penetration (shell, hit_shape, hit_data,
                                                                                        start_point, end_point, dt)
        if not is_alive then
           return false, end_point
        end

        ::skip_shape::
        if shell.debug then
            add_point_to_path(shell.debug.path.shell, start_point)
        end
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

        if shell.debug then
            add_point_to_path(shell.debug.path.shell, next_position)
        end

        if not alive then
            dprint("Shell (id: "..tostring(shell_id)..") has died", "info", dprint_filename, "sv", "update_shells")
            if shell.debug then
                net:sendToClients("cl_save_path", {path = shell.debug.path.shell, type = "shell"})
                net:sendToClients("cl_save_path", {path = shell.debug.path.spall, type = "spall"})
            end
            shells[shell_id] = nil
            goto next
        end

        shell.position = next_position

        ::next::
    end
end
