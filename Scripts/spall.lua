function random_vector_in_cone(dir, angle)
    local axis1 = dir:cross(sm.vec3.new(0, 0, 1))

    if axis1:length2() < 0.01 then
        axis1 = dir:cross(sm.vec3.new(0, 1, 0))
    end
    axis1 = axis1:normalize()

    local gamma = math.random(0, 2 * math.pi * 1000) / 1000
    local theta = math.random(0, angle * 1000) / 1000


    local vec = dir:rotate(theta, axis1)
    vec = vec:rotate(gamma, dir)

    return vec
end



function process_spall(position, direction, amount, ignore_shape)
    local end_point = position + direction * 20
    local hit, hit_data = sm.physics.raycast(position, end_point, ignore_shape)
    local hit_shape = hit_data:getShape()
    if hit and hit_shape and hit_shape.isBlock then
        local voxel = hit_shape:getClosestBlockLocalPosition( hit_data.pointWorld )
        hit_shape:destroyBlock(voxel)
    elseif hit and hit_shape then
        hit_shape:destroyShape()
    end

    return position, hit_data.pointWorld:length2() ~= 0 and hit_data.pointWorld or end_point
end
