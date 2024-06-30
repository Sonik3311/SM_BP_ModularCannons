function add_point_to_line(line, point)
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
