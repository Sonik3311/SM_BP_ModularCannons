function add_point_to_path(line, point)
    local last_line = line[#line]
    local last_point = last_line[2]
    line[#line + 1] = {
        last_point,
        point
    }
end

function is_world_surface(object_type)
    return object_type == "terrainSurface" or object_type == "limiter"
end

local raycast = sm.physics.raycast
function get_closest_shape_in_line(start_point, end_point, ignore_shape)
    local is_hit = true

    while true do -- if this gets stuck...
        local is_hit, hit_data = raycast(start_point, end_point, ignore_shape)

        if is_hit == false then
            return nil
        end

        if is_world_surface(hit_data.type) then
            return nil
        end

        if hit_data.type == "joint" then
           goto next
        end

        local hit_shape = hit_data:getShape()
        if hit_shape then
           return hit_data
        end

        ::next::
    end
end
