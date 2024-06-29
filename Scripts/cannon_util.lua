function body_has_changed(shape)
    return shape:getBody():hasChanged(sm.game.getCurrentTick() - 1)
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

-----------------------------------------------------------------------------------------------

function construct_cannon(shape, length)
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
        local to_neighbour_dir = (neighbour_shape_position - shape_position):normalize()

        if to_neighbour_dir:dot(shape:getAt()) > -0.4 then
            goto next
        end

        do return construct_cannon(neighbour_shape, length + 1) end

        ::next::
    end
    return length, nil
end
