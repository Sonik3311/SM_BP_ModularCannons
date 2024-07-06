function add_point_to_path(path, point)
    local last_line = path[#path]
    local last_point = last_line[2]
    path[#path + 1] = {
        last_point,
        point
    }
end
