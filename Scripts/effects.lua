local function get_rotation(v1,v2)
    local d = v1:dot(v2)
    if d > 0.9999 then
        return sm.quat.new(0,0,0,1)
    end
    if d < -0.9999 then
        return sm.quat.new(1,0,0,0)
    end

    local q = sm.quat.angleAxis(math.acos(d), v1:cross(v2))
    local l = math.sqrt(q.x^2 + q.y^2 + q.z^2 + q.w^2)
    q.x = q.x / l
    q.y = q.y / l
    q.z = q.z / l
    q.w = q.w / l
    return q
end

function get_entry_effect(data)
    local entry_effects = {
        APFSDS = "APFSDS_entry_ferrium",
        HE = "HE_willturn",
        APHE = "APHE_willturn",
        AP = "APHE_willturn",
    }
    local shell_type = data.type
    local position = data.position
    local velocity = data.velocity
    local dir = data.direction
    local rotation = get_rotation(sm.vec3.new(0,1,0), dir)
    local effect = sm.effect.createEffect(entry_effects[shell_type])
    effect:setPosition(position)
    effect:setRotation(rotation)
    effect:setVelocity(velocity)
    return effect
end

function get_launch_effect(data)
    local breech_pos = data.breech:getWorldPosition()
    local muzzle_pos = data.muzzle:getWorldPosition()
    local caliber = data.diameter
    local is_with_fire = data.is_short
    local effect = sm.effect.createEffect("Medium_caliber_fire", data.breech.interactable)
    effect:setOffsetPosition(sm.vec3.new(0,-(muzzle_pos - breech_pos):length(),0))
    return effect
end
