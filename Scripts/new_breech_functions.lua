dofile "$CONTENT_DATA/Scripts/modules_uuid.lua"
dofile "$CONTENT_DATA/Scripts/barrels_uuid.lua"
dofile "$CONTENT_DATA/Scripts/loaders_uuid.lua"


function apx_equals(x, y, delta) -- FUCK IEEE754, FUUUUCK
    return math.abs(x - y) <= delta
end

function isAnyOf(target, pool)
    for _, object in pairs(pool) do
        if object == target then
            return true
        end
    end
    return false
end

function find_modules(breech_shape)
    local function dfs(root_shape, found_modules, is_visited, distance)
        is_visited[root_shape.id] = true
        local neighbours = root_shape:getNeighbours()
        for _, neighbour in pairs(neighbours) do
            if not is_visited[neighbour.id] and neighbour.uuid == mod_extender then
                found_modules, is_visited = dfs(neighbour, found_modules, is_visited, distance + 1)
            end
            if isAnyOf(neighbour.uuid, g_modules) then
                if found_modules[neighbour.id] then
                    local old_distance = found_modules[neighbour.id][2]
                    found_modules[neighbour.id][2] = math.min(old_distance, distance)
                else
                    found_modules[neighbour.id] = { neighbour, distance }
                end
            end
        end
        return found_modules, is_visited
    end

    local modules = {}
    local shapes_to_search = { breech_shape }

    for _, neighbour in pairs(breech_shape:getNeighbours()) do
        if neighbour.uuid == mod_extender then
            shapes_to_search[#shapes_to_search + 1] = neighbour
        end
    end

    for i, shape in pairs(shapes_to_search) do
        local found_modules, _ = dfs(shape, {}, {}, math.min(i - 1, 1))
        for id, module in pairs(found_modules) do
            if modules[id] then
                local old_distance = modules[id][2]
                modules[id][2] = math.min(old_distance, module[2])
            else
                modules[id] = module
            end
        end
    end
    return modules
end

function find_barrel(shape, global_dir, last)
    local neighbours = shape:getNeighbours()
    for neighbour_id = 1, #neighbours do
        local neighbour_shape = neighbours[neighbour_id]

        if not isAnyOf(neighbour_shape.uuid, g_barrels) then
            goto next
        end

        if last == neighbour_shape then
            goto next
        end

        local neighbour_shape_position = neighbour_shape:getWorldPosition()
        local shape_position = shape:getWorldPosition()
        local to_neighbour_dir = (neighbour_shape_position - shape_position):normalize()

        if not apx_equals(math.abs(to_neighbour_dir:dot(neighbour_shape:getAt())), 1, 0.01) then
            goto next
        end

        if last == nil and not apx_equals(to_neighbour_dir:dot(-shape:getRight()), 1, 0.01) then
            goto next
        end

        do
            if neighbour_shape.uuid == muzzle_shape then
                return { neighbour_shape }
            end

            local c = find_barrel(neighbour_shape, global_dir, shape)
            table.insert(c, 1, neighbour_shape)
            return c
        end

        ::next::
    end
    return {}
end

function find_loader(breech_shape)
    local dir = breech_shape:getRight()
    for _, neighbour in pairs(breech_shape:getNeighbours()) do
        local to_neighbour_dir = (neighbour:getWorldPosition() - breech_shape:getWorldPosition()):normalize()
        if apx_equals(to_neighbour_dir:dot(dir), 1, 0.01) and isAnyOf(neighbour.uuid, g_loaders) then
            return neighbour
        end
    end
    return nil
end
