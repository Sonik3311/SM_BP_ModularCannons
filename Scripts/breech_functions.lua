function body_has_changed(shape)
    return shape:getBody():hasChanged(sm.game.getCurrentTick() - 1)
end

-----------------------------------------------------------------------------------------------

function isAnyOf(target, pool)
    for _, object in pairs(pool) do
        if object == target then
           return true
        end
    end

    return false
end

-----------------------------------------------------------------------------------------------

function deep_copy( tbl )
    local copy = {}
    for key, value in pairs( tbl ) do
        local var_type = type(value)
        if var_type ~= 'table' then
            if var_type == "Vec3" then
				copy[key] = sm.vec3.new(value.x, value.y, value.z)
			elseif var_type == "Quat" then
				copy[key] = sm.quat.new(value.x, value.y, value.z, value.w)
			elseif var_type == "Color" then
				copy[key] = sm.color.new(value.r, value.g, value.b)
			elseif var_type == "Uuid" then
				copy[key] = sm.uuid.new(tostring(value))
            else
                copy[key] = value
            end
        else
            copy[key] = deep_copy( value )
        end
    end
    return copy
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

-----------------------------------------------------------------------------------------------

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

-----------------------------------------------------------------------------------------------

function update_barrel_diameter(segments, diameter)
    for i=1, #segments do
        segments[i].interactable:setPublicData({diameter = diameter})
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

-----------------------------------------------------------------------------------------------

function calculate_muzzle_velocity(barrel_length, barrel_diameter, shell)
    local A = math.pi * (barrel_diameter / 2)^2
    local k = 0.5 * 1.225 * A
    local v = math.sqrt((2 * 9.8 * barrel_length) / (1 + (2 * k * barrel_length / shell.parameters.projectile_mass)))
    return v
end

-----------------------------------------------------------------------------------------------

function calculate_recoil_force(projectile_mass, projectile_velocity, powder_charge_mass, powder_charge_velocity)
    return (projectile_mass * projectile_velocity + powder_charge_mass * powder_charge_velocity) ^0.985
end
