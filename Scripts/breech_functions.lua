function body_has_changed(shape)
    return shape:getBody():hasChanged(sm.game.getCurrentTick() - 1)
end

-----------------------------------------------------------------------------------------------
local barrel_shape = sm.uuid.new("90e6714d-e105-476f-875b-4b69b8c7802e")
local muzzle_shape = sm.uuid.new("98212a7d-eac1-45a9-8e5b-3e36319b9b29")
function construct_cannon_new(shape, global_dir, last)
    local neighbours = shape:getNeighbours()
    for neighbour_id = 1, #neighbours do
        local neighbour_shape = neighbours[neighbour_id]

        if neighbour_shape.uuid ~= barrel_shape and neighbour_shape.uuid ~= muzzle_shape then
            goto next
        end

        if last == neighbour_shape then
            goto next
        end

        local neighbour_shape_position = neighbour_shape:getWorldPosition()
        local shape_position = shape:getWorldPosition()
        local to_neighbour_dir = (neighbour_shape_position - shape_position):normalize()
        --print(to_neighbour_dir:dot(neighbour_shape:getAt()))
        if math.abs(to_neighbour_dir:dot(neighbour_shape:getUp())) == 1 then
            goto next
        end

        do
            if neighbour_shape.uuid == muzzle_shape then
                return {neighbour_shape}
            end

            local c = construct_cannon_new(neighbour_shape, global_dir, shape)
            table.insert(c, 1, neighbour_shape)
            return c
        end

        ::next::
    end
    return {}
end

function create_barrel_effect(segments, diameter_mm, breech)
    local effect = sm.effect.createEffect("ShapeRenderable", breech.interactable)
    effect:setParameter("uuid", sm.uuid.new("084f7d27-576a-4728-9e1e-81b6fa9f6d59"))

    local middle_pos = sm.vec3.zero()
    for i=1,#segments do
        middle_pos = middle_pos + segments[i]:getWorldPosition()
    end
    middle_pos = middle_pos / #segments
    dist = (middle_pos - breech:getWorldPosition()):length()
    local diameter = diameter_mm / 100

    effect:setOffsetPosition(sm.vec3.new(0,-dist,0))
    effect:setScale(sm.vec3.new(diameter/4,#segments/4,diameter/4))
    return effect
end

function update_barrel_diameter(segments, diameter)
    for i=1, #segments do
        segments[i].interactable:setPower(diameter)
    end
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
