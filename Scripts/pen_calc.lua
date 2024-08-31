-----------------------------------------------------------------------------------
--[[                      Shell penetration calculation                        ]] --
-----------------------------------------------------------------------------------

function calculate_shell_penetration(shell)
    if shell.type == "APFSDS" then
        local penetrator_length = shell.parameters.penetrator_length
        local penetrator_diameter = shell.parameters.diameter
        local penetrator_density = shell.parameters.penetrator_density
        local max_pen, min_velocity = calculate_rod_penetration(shell.velocity:length() / 1000, penetrator_length,
            penetrator_diameter, penetrator_density, 7850, 250)
        return max_pen
    elseif shell.type == "AP" then
        local mass = shell.parameters.projectile_mass
        local diameter = shell.caliber
        local is_apcbc = shell.parameters.is_apcbc
        local velocity = shell.velocity:length()
        return calculate_bullet_penetration(velocity, diameter, mass, 0, is_apcbc)
    elseif shell.type == "APHE" then
        local mass = shell.parameters.projectile_mass
        local ex_mass = shell.parameters.explosive_mass
        local diameter = shell.caliber
        local is_apcbc = shell.parameters.is_apcbc
        local velocity = shell.velocity:length()
        return calculate_bullet_penetration(velocity, diameter, mass, ex_mass, is_apcbc)
    end
end

function calculate_rod_penetration(impact_velocity, penetrator_length,
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

    local Vmin = math.sqrt(((c0 + c1 * B) * B) / (Pp * 1.8))
    local max_pen = a * (1 / math.tanh(b0 + b1 * (L / D))) * math.sqrt(Pp / Pt) * 2.718281828 ^ (-s / (V * V)) * L
    return max_pen, Vmin
end

function calculate_bullet_penetration(impact_velocity, shell_diameter, shell_mass, explosive_mass, is_apcbc)
    local kfbr = 1900
    local kf_apcbc = is_apcbc and 1 or 0.9
    local tnt = (explosive_mass / 5 / shell_mass) * 100

    -- blame War Thunder
    local knap
    if tnt < 0.65 then
        knap = 1;
    elseif (tnt < 1.6) then
        knap = 1 + ((tnt - 0.65) * (0.93 - 1)) / (1.6 - 0.65)
    elseif (tnt < 2) then
        knap = 0.93 + ((tnt - 1.6) * (0.9 - 0.93)) / (2 - 1.6)
    elseif (tnt < 3) then
        knap = 0.9 + ((tnt - 2) * (0.85 - 0.9)) / (3 - 2)
    elseif (tnt < 4) then
        knap = 0.85 + ((tnt - 3) * (0.75 - 0.85)) / (4 - 3)
    else
        knap = 0.75
    end

    return ((impact_velocity ^ 1.43) * (shell_mass ^ 0.71)) / ((kfbr ^ 1.43) * ((shell_diameter / 100) ^ 1.07)) * 100 *
    knap * kf_apcbc
end

-- TODO: Replace this shit
function calculate_heat_penetration(standoff_distance, shell_diameter, jet_density, armor_density)
    local Kdistance = 1 / (1 + ((standoff_distance - 7 * shell_diameter) / (14 * shell_diameter)) ^ 2)
    local k1 = 12
    local k2 = 0.3

    return shell_diameter * k1 * k2 * Kdistance * 1.3 * math.sqrt(jet_density / armor_density)
end
