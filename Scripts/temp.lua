-- help
-- best left alone and forgotten, use made-up values
function calculate_initial_jet_length()
    local n = 50 --number of elements
    local p = 20 --number of elements with inverse velocity gradient in between
    local np = n - p --number of elements with velocity gradient in between
    local dt = 5 -- amount of time it took for p to reach jet formed by np

    local L1j = 10 --length of p-elements
    local L2j = 57 --length of np-elements

    local V0 = 100 --speed of first p-element
    local Vmax = 600 -- maximum speed of the jet
    local d = -5 -- how much speed is changed between each p-element

    local Lj1 = p * L1j + p * (V0 - (V0 + d * (p - 1))) * dt
    local Lj2 = n * L2j + n * (Vmax - d * (n - 1))
    return Lj1 + Lj2
end

function calculate_jet_pen_simple(jet_length, jet_density, target_density)
    return jet_length * (jet_density / target_density)^(0.5)
end
