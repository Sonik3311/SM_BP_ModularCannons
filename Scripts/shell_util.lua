function is_exititing_body(position, direction, hit_shape)
    local hit, _ = sm.physics.raycast(position, position + direction * 0.125, hit_shape)
    return not hit
end

function voxel_trace(sx, sy, sz, dx, dy, dz)
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

function penetrate_shape(hit_shape, p1, p2)
    if hit_shape.isBlock then
        local p1 = hit_shape:getClosestBlockLocalPosition( p1 )
        local p2 = hit_shape:getClosestBlockLocalPosition( p2 )
        hit_shape:destroyBlock(p1)
        hit_shape:destroyBlock(p2)

        for _,block in pairs(voxel_trace(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z)) do
            hit_shape:destroyBlock(block)
        end
    else
        hit_shape:destroyShape()
    end
end
