dofile "$CONTENT_DATA/Scripts/general_util.lua"

-----------------------------------------------------------------------------------
--[[                      Shell penetration calculation                        ]]--
-----------------------------------------------------------------------------------

function calculate_shell_penetration(shell, armor_material, armor_thickness)
    if shell.type == "APFSDS" then
        local penetrator_length = shell.parameters.penetrator_length
        local penetrator_diameter = shell.parameters.diameter
        local penetrator_density = shell.parameters.penetrator_density
        local max_pen = calculate_rod_penetration(shell.velocity:length() / 0.7, penetrator_length, penetrator_diameter, penetrator_density, 7850, 250)
        shell.parameters.penetrator_length = penetrator_length * (1 - (armor_thickness / max_pen))
        return max_pen
    end
end

function calculate_rod_penetration (impact_velocity, penetrator_length,
                                    penetrator_diameter, penetrator_density,
                                    armor_density, armor_brinell_scale)
    local L = penetrator_length
    local D = penetrator_diameter
    local V = impact_velocity
    local Pp = penetrator_density
    local Pt = armor_density
    local B = armor_brinell_scale

    local a = 0.921
    local b0 = 0.283
    local b1 = 0.0656
    local c0 = 138
    local c1 = -0.1

    local s = ((c0 + c1 * B) * B) / Pp
    return a * (1/math.tanh(b0 + b1 * (L/D))) * math.sqrt(Pp/Pt) * 2.718281828 ^ (-s/(V*V)) * L
end

function calculate_bullet_penetration (impact_velocity, shell_diameter, shell_mass, is_apcbc)
    local kfbr = 1900
    local knap = 1 -- tnt mass 0
    local kf_apcbc = 0.9; if is_apcbc then kf_apcbc = 1 end

    return (impact_velocity^1.43 * shell_mass^0.71) / (kfbr^1.43 * (shell_diameter/100^1.07)) * 100 * knap * kf_apcbc
end

-- TODO: Replace this shit
function calculate_heat_penetration (standoff_distance, shell_diameter, jet_density, armor_density)
    local Kdistance = 1 / (1 + ((standoff_distance - 7 * shell_diameter) / (14 * shell_diameter))^2)
    local k1 = 12
    local k2 = 0.3

    return shell_diameter * k1 * k2 * Kdistance * 1.3 * math.sqrt(jet_density / armor_density)
end

-----------------------------------------------------------------------------------
--[[                        Armor properties calculation                       ]]--
-----------------------------------------------------------------------------------

function calculate_ricochet (direction, normal, shell_type)
    local angle = math.acos(normal:dot(direction:normalize())) * 180/math.pi
    if angle > 90 then
        angle = 180 - angle
    end
    if shell_type == "APFSDS" then
        local chance = clamp(1, 0, 0.025 * (angle - 30))
        local choice = math.random()
        if choice <= chance then
            local random_dir = sm.vec3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5)
            local new_dir = random_dir:normalize() + direction:normalize()
            return Reflect(direction:normalize(), sm.vec3.lerp(normal,new_dir,0.2):normalize())
        end
        return nil
    end
end

function calculate_armor_thickness ( ro, rd, boxSize )
    local rdx = rd.x^-1
    local rdy = rd.y^-1
    local rdz = rd.z^-1

    -- gives division by zero error if left unattended
    rdx = rd.x and rd.x ~= 0 or 9999999
    rdy = rd.y and rd.y ~= 0 or 9999999
    rdz = rd.z and rd.z ~= 0 or 9999999

    local m = sm.vec3.new(rdx, rdy, rdz) -- can precompute if traversing a set of aligned boxes
    local n = m * ro   -- can precompute if traversing a set of aligned boxes
    local k = sm.vec3.new(math.abs(m.x),math.abs(m.y),math.abs(m.z)) * boxSize
    local t1 = -n - k;
    local t2 = -n + k;
    local tN = math.max( math.max( t1.x, t1.y ), t1.z );
    local tF = math.min( math.min( t2.x, t2.y ), t2.z );

    return (tF-tN)/2
end
