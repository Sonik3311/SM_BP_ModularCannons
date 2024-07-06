function body_has_changed(shape)
    return shape:getBody():hasChanged(sm.game.getCurrentTick() - 1)
end

-----------------------------------------------------------------------------------------------

function construct_cannon(shape)
    local neighbours = shape:getNeighbours()
    local barrel_shape = sm.uuid.new("90e6714d-e105-476f-875b-4b69b8c7802e")
    local muzzle_shape = sm.uuid.new("98212a7d-eac1-45a9-8e5b-3e36319b9b29")

    for neighbour_id = 1, #neighbours do
        local neighbour_shape = neighbours[neighbour_id]

        if neighbour_shape.uuid ~= barrel_shape and neighbour_shape.uuid ~= muzzle_shape then
            goto next
        end

        local neighbour_shape_position = neighbour_shape:getWorldPosition()
        local shape_position = shape:getWorldPosition()
        local to_neighbour_dir = (neighbour_shape_position - shape_position):normalize()

        if to_neighbour_dir:dot(shape:getAt()) > -0.8 then
            goto next
        end

        do
            if neighbour_shape.uuid == muzzle_shape then
                return {neighbour_shape}
            end

            local c = construct_cannon(neighbour_shape)
            table.insert(c, 1, neighbour_shape)
            return c
        end

        ::next::
    end
    return {}
end

-----------------------------------------------------------------------------------------------

function input_active(interactable)
    local parent = interactable:getSingleParent()

    if parent == nil then
       return false
    end

    if not parent:hasOutputType(sm.interactable.connectionType.logic) then
       return false
    end

    return parent:isActive()
end
