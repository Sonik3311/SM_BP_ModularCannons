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
    local rotation = sm.vec3.getRotation(sm.vec3.new(0,1,0), dir)
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

function get_spall_impact_effect(data)
    local effect = sm.effect.createEffect("Debris_impact")
    effect:setPosition(data.pointWorld)
    effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0,1,0), data.normalWorld))
    return effect
end
