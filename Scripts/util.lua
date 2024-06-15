-----------------------------------------------------------------------------------------------
function Calculate_barrel_length(shape, length)
    local neighbours = shape:getNeighbours()
    local barrel_shape = sm.uuid.new("90e6714d-e105-476f-875b-4b69b8c7802e")
    local breech_shape = sm.uuid.new("ed93a54c-6c5d-4a8e-ade4-4bd4544cfefb")

    for neighbour_id = 1, #neighbours do
        local neighbour_shape = neighbours[neighbour_id]

        if neighbour_shape.uuid == breech_shape then
            return length, neighbour_shape
        end

        if neighbour_shape.uuid ~= barrel_shape then goto next end

        local neighbour_shape_position = neighbour_shape:getWorldPosition()
        local shape_position = shape:getWorldPosition()
        local to_neighbour_dir =
            (neighbour_shape_position - shape_position):normalize()

        if to_neighbour_dir:dot(shape:getAt()) > -0.4 then goto next end

        do return Calculate_barrel_length(neighbour_shape, length + 1) end

        ::next::
    end
    return length, nil
end

-----------------------------------------------------------------------------------------------

function raytrace(sx, sy, sz, dx, dy, dz)
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
