-----------------------------------------------------------------------------------
--[[                      Shell penetration calculation                        ]]--
-----------------------------------------------------------------------------------

function calculate_shell_penetration(shell)
    if shell.type == "APFSDS" then
        local penetrator_length = shell.parameters.penetrator_length
        local penetrator_diameter = shell.parameters.diameter
        local penetrator_density = shell.parameters.penetrator_density
        local max_pen, min_velocity = calculate_rod_penetration(shell.velocity:length() / 1000, penetrator_length, penetrator_diameter, penetrator_density, 7850, 250)
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

    local Vmin = math.sqrt(((c0 + c1 * B) * B)/(Pp*1.8))
    local max_pen = a * (1/math.tanh(b0 + b1 * (L/D))) * math.sqrt(Pp/Pt) * 2.718281828 ^ (-s/(V*V)) * L
    return max_pen, Vmin
end

function calculate_bullet_penetration (impact_velocity, shell_diameter, shell_mass, is_apcbc)
    local kfbr = 1900
    local knap = 1 -- tnt mass 0
    local kf_apcbc = is_apcbc and 1 or 0.9

    return (impact_velocity^1.43 * shell_mass^0.71) / (kfbr^1.43 * (shell_diameter/100^1.07)) * 100 * knap * kf_apcbc
end

-- TODO: Replace this shit
function calculate_heat_penetration (standoff_distance, shell_diameter, jet_density, armor_density)
    local Kdistance = 1 / (1 + ((standoff_distance - 7 * shell_diameter) / (14 * shell_diameter))^2)
    local k1 = 12
    local k2 = 0.3

    return shell_diameter * k1 * k2 * Kdistance * 1.3 * math.sqrt(jet_density / armor_density)
end
