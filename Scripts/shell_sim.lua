-- hi there, watcha doin?
-- Dev note 11.07.24: APHE and other HE rounds really fucked this up huh
dofile "$CONTENT_DATA/Scripts/Shells/apfsds.lua"
dofile "$CONTENT_DATA/Scripts/Shells/ap.lua"
dofile "$CONTENT_DATA/Scripts/Shells/aphe.lua"
dofile "$CONTENT_DATA/Scripts/Shells/he.lua"

dofile "$CONTENT_DATA/Scripts/dprint.lua"
dofile "$CONTENT_DATA/Scripts/debug_path_draw.lua"

local dprint_filename = "shell_sim"

local function is_world_surface(object_type)
    return object_type == "terrainSurface" or object_type == "terrainAsset" or object_type == "limiter" or object_type == "harvestable" or object_type == "lift" or object_type == "character"
end

local function get_penetration_function(shell)
    local functions = {
        AP = process_ap_penetration,
        APHE = process_aphe_penetration,
        APFSDS = process_apfsds_penetration,
        HE = process_he_penetration
    }
    return functions[shell.type]
end

function process_shell_collision (shell, dt, net, client)
    local raycast = sm.physics.raycast

    local shell_direction = shell.velocity:normalize()
    local start_point = shell.position
    local end_point = shell.position + shell.velocity * dt

    local is_hit, hit_data = raycast(start_point, end_point)
    local is_entering = true

    while is_hit do
        local hit_shape = hit_data:getShape()
        local is_alive = true

        --if is_world_surface(hit_data.type) then
        --    return false, end_point
        --end

        local penetration_function = get_penetration_function(shell)
        local last_direction = shell_direction
        local is_ricochet

        if hit_data.type == "joint" then
            start_point = hit_data.pointWorld
            end_point = end_point
            goto skip_shape
        end


        is_alive, is_exiting, start_point, end_point, shell_direction = penetration_function (shell, hit_shape, hit_data,
                                                                                    start_point, end_point, dt, net)

        is_ricochet = last_direction ~= shell_direction

        if is_entering and not is_ricochet then
            net:sendToClients("cl_play_entry_effect", {type = shell.type,
                                                       position = hit_data.pointWorld,
                                                       direction = (-hit_data.normalWorld):normalize(),
                                                       velocity = sm.vec3.zero()}) --hit_shape:getVelocity()
            dprint("Sending request to play "..shell.type.." entry effect", "info", dprint_filename, "sv", "process_shell_collision")
            is_entering = false
        end

        is_entering = is_exiting
        if is_exiting then
            -- play exit effect here
        end

        if not is_alive then
           return false, end_point
        end

        ::skip_shape::
        if shell.debug then
            add_point_to_path(shell.debug.path.shell, start_point)
        end

        is_hit, hit_data = raycast(start_point, end_point, hit_shape)
    end

    if shell.type == "APHE" and shell.fuse.active then
        local is_alive, explosion_point = process_collision_aphe_inject(shell, start_point, is_hit, end_point, hit_data.pointWorld)
        if not is_alive then
            return false, explosion_point
        end
    end

    return true, end_point
end

function update_shells (shells, dt, net)
    for shell_id, shell in pairs(shells) do
        if shell == nil then
            goto next
        end

        shell.velocity = shell.velocity - sm.vec3.new(0, 0, 20 * dt)

        local alive, next_position = process_shell_collision(shell, dt, net)

        if shell.debug then
            add_point_to_path(shell.debug.path.shell, next_position)
        end

        if not alive then
            dprint("Shell (id: "..tostring(shell_id)..", type: "..shell.type..") has died", "info", dprint_filename, "sv", "update_shells")
            if shell.debug then
                net:sendToClients("cl_save_path", {path = shell.debug.path, type = "shell"})
            end
            shells[shell_id] = nil
            goto next
        end

        shell.position = next_position
        shell.next_position = shell.position + shell.velocity * dt

        ::next::
    end
end
