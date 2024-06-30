dofile "$CONTENT_DATA/Scripts/pen_calc_util.lua"


local function voxel_trace(sx, sy, sz, dx, dy, dz)
    local steps = math.max(math.abs(sx - dx), math.abs(sy - dy),
                           math.abs(sz - dz))
    local lx, ly, lz = sx, sy, sz

    local voxels = {}
    local voxel_count = 0

    for step = 1, steps do
        local x = math.floor((sx + ((dx - sx) * step / steps)) + 0.5)
        local y = math.floor((sy + ((dy - sy) * step / steps)) + 0.5)
        local z = math.floor((sz + ((dz - sz) * step / steps)) + 0.5)

        if x ~= lx and y ~= ly then
            voxel_count = voxel_count + 1
            voxels[voxel_count] = sm.vec3.new(lx,y,z)
        end

        if y ~= ly and z ~= lz then
            voxel_count = voxel_count + 1
            voxels[voxel_count] = sm.vec3.new(x,ly,z)
        end

        if z ~= lz and x ~= lx then
            voxel_count = voxel_count + 1
            voxels[voxel_count] = sm.vec3.new(x,y,lz)
        end
        voxel_count = voxel_count + 1
        voxels[voxel_count] = sm.vec3.new(x,y,z)
        lx, ly, lz = x, y, z
    end
    return voxels
end


-- must return:
-- is_alive, new_start_point, new_end_point, shell_direction

function process_apfsds_penetration (shell, hit_shape, hit_data, start_point, end_point, dt)
    local new_start_point = start_point
    local new_end_point = end_point

    local shell_direction = shell.velocity:normalize()
    local hit_point = hit_shape:transformPoint(hit_data.pointWorld) --hit_data.pointLocal
    local hit_direction = hit_shape:transformDirection(shell_direction)
    local hit_shape_aabb = hit_shape:getBoundingBox()

    local ricochet_dir = calculate_ricochet(shell_direction, hit_data.normalWorld, shell)
    local armor_thickness = calculate_armor_thickness(hit_point, hit_direction, hit_shape_aabb)

    if ricochet_dir then
        shell.position = hit_data.pointWorld
        shell.velocity = ricochet_dir * shell.velocity:length() / 1.3
        shell_direction = ricochet_dir
        new_start_point = hit_data.pointWorld
        new_end_point = new_start_point + shell.velocity * dt
        return true, new_start_point, new_end_point, shell_direction
    end

    local shell_penetration = calculate_shell_penetration(shell, nil, armor_thickness * 100)
    local is_penetrated = (armor_thickness * 100 - shell_penetration) < 0

    if not is_penetrated then
        new_end_point = hit_data.pointWorld + shell_direction * (armor_thickness - shell_penetration / 100)
    end
    new_start_point = hit_data.pointWorld + shell_direction * armor_thickness / 2

    local new_pen_length = shell.parameters.penetrator_length * (1 - (armor_thickness * 100 / shell_penetration))
    shell.parameters.penetrator_length = new_pen_length

    hit_shape:setColor(sm.color.new(math.random(), math.random(), math.random()))
    local exit_point = hit_data.pointWorld + shell_direction * (armor_thickness - math.max(armor_thickness - shell_penetration / 100, 0))

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

    return is_penetrated, new_start_point, new_end_point, shell_direction
end
