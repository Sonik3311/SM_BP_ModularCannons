dofile "$CONTENT_DATA/Scripts/util.lua"

local function calculate_Ricochet (direction, normal, shell_type)
    local angle = math.acos(normal:dot(direction:normalize())) * 180/math.pi
    if angle > 90 then
        angle = 180 - angle
    end
    if shell_type == "APFSDS" then
        local chance = clamp(1, 0, 0.025 * (angle - 30))
        local choice = math.random()
        --print(choice, chance,0.025 * (angle - 30), angle)
        if choice <= chance then
            local random_dir = sm.vec3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5)
            local new_dir = random_dir:normalize() + direction:normalize()
            return Reflect(direction:normalize(), sm.vec3.lerp(normal,new_dir,0.1):normalize())
        end
        return nil
    end
end

local function calculate_shell_penetration(shell, armor_material, armor_thickness)
    if shell.type == "APFSDS" then
        local penetrator_length = shell.parameters.penetrator_length
        local penetrator_diameter = shell.parameters.diameter
        local penetrator_density = shell.parameters.penetrator_density
        local max_pen = Calculate_rod_penetration(shell.velocity:length() / 0.7, penetrator_length, penetrator_diameter, penetrator_density, 7850, 250)
        shell.parameters.penetrator_length = penetrator_length * (1 - (armor_thickness / max_pen))
        return max_pen
    end
end

local function process_collision(shell, next_velocity, dt)
    local shell_direction = next_velocity:normalize()
    local start_point = shell.position
    local end_point = shell.position + next_velocity * dt

    local hit, hit_data = sm.physics.raycast(start_point, end_point)
    while hit and hit_data:getShape() do
        local hit_shape = hit_data:getShape()

        local hit_point = hit_shape:transformPoint(hit_data.pointWorld) --hit_data.pointLocal
        local hit_direction = hit_shape:transformDirection(shell_direction)
        local hit_shape_aabb = hit_shape:getBoundingBox()
        local armor_thickness = Calculate_armor_thickness(hit_point, hit_direction, hit_shape_aabb)
        local ricochet = calculate_Ricochet(shell_direction, hit_data.normalWorld, shell.type)
        if ricochet then
            print("rico")
            shell.position = hit_data.pointWorld
            shell.velocity = ricochet * next_velocity:length() / 2
            start_point = hit_data.pointWorld
            end_point = start_point + shell.velocity * dt
            shell_direction = ricochet
            
        else
            start_point = hit_data.pointWorld + shell_direction * armor_thickness / 2

            hit_shape:setColor(sm.color.new(math.random(), math.random(), math.random()))
            
            
            local shell_penetration = calculate_shell_penetration(shell, nil, armor_thickness * 100)
            local penetrated = (armor_thickness * 100 - shell_penetration) < 0
            print(shell_penetration)
            local exit_point = start_point + shell_direction * (armor_thickness - math.max(armor_thickness - shell_penetration / 100, 0))

            if hit_shape.isBlock then
                local p1 = hit_shape:getClosestBlockLocalPosition( exit_point )
                local p2 = hit_shape:getClosestBlockLocalPosition( hit_data.pointWorld )
                hit_shape:destroyBlock(p1)
                for _,block in pairs(raytrace(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z)) do
                    hit_shape:destroyBlock(block)
                end
            else
                hit_shape:destroyShape()
            end

            if not penetrated then
                return false, hit_data.pointWorld + shell_direction * (armor_thickness - shell_penetration / 100)
            end
        end

        hit, hit_data = sm.physics.raycast(start_point, end_point, hit_shape)
    end
    
    --if hit then -- ground hit
    --    
    --end
    return true, end_point
end

function update_shells (fired_shells, dt)
    for shell_id, shell in pairs(fired_shells) do
        if shell == nil then
            goto next
        end

        --local next_position = shell.position + shell.velocity * dt
        local next_velocity = shell.velocity - sm.vec3.new(0, 0, 9.8 * dt)
        shell.velocity = next_velocity
        local alive, next_position = process_collision(shell, next_velocity, dt)
        if not alive then
            fired_shells[shell_id] = nil
            print("ded")
        end
        shell.position = next_position
        
        ::next::
    end
end

function Update_shells (fired_shells, dt, net)
    for shell_id, shell in pairs(fired_shells) do
        --local shell = fired_shells[shell_id]
        if shell then
            local next_position = shell.position + shell.velocity * dt
            local next_velocity = sm.vec3.new(shell.velocity.x, shell.velocity.y, shell.velocity.z - 9.8*dt)
            
            
            local start_point = shell.position
            local end_point = shell.position + next_velocity * dt
            local ignore = nil

            local hit, hit_data = sm.physics.raycast(start_point, end_point, ignore)
            if hit and hit_data:getShape() then
                ignore = hit_data:getShape()
                hit_data:getShape():setColor(sm.color.new(1,1,1))
                net:sendToClients("cl_visualize_shell", {position=start_point})

                start_point = hit_data.pointWorld + next_velocity:normalize() * Calculate_armor_thickness(ignore:transformPoint(shell.position), ignore:transformDirection(next_velocity:normalize()), ignore:getBoundingBox())
                hit, hit_data = sm.physics.raycast(start_point, end_point, ignore)
                if hit and hit_data:getShape() then

                    net:sendToClients("cl_visualize_shell", {position=start_point})
                    ignore = hit_data:getShape()
                    ignore:setColor(sm.color.new(1,1,0))
                    start_point = hit_data.pointWorld + next_velocity:normalize() * Calculate_armor_thickness(ignore:transformPoint(shell.position), ignore:transformDirection(next_velocity:normalize()), ignore:getBoundingBox())
                    hit, hit_data = sm.physics.raycast(start_point, end_point, ignore)

                    net:sendToClients("cl_visualize_shell", {position=start_point})
                    if hit and hit_data:getShape() then
                        
                        hit_data:getShape():setColor(sm.color.new(1,0,0))
                    end
                end
                net:sendToClients("cl_visualize_shell", {position=end_point})
            end
                --local ricochet = Calculate_Ricochet(next_direction:normalize(), hit_data.normalWorld, "APHE")
                --if hit_shape and ricochet == nil then
                    --local cd = hit_shape:transformDirection(next_direction:normalize())
                    --local to_penetrate = Calculate_armor_thickness(hit_shape:transformPoint(shell.position), cd, hit_shape:getBoundingBox()*4) / 0.04
                    ----print(to_penetrate)
                    --if to_penetrate > 0 then
                    --    --print("good")
                    --    if shell.type == "APFSDS" then
                    --        local penetrator_length = shell.parameters.penetrator_length
                    --        local penetrator_diameter = shell.parameters.diameter
                    --        local penetrator_density = shell.parameters.penetrator_density
                    --        local max_pen = Calculate_rod_penetration(shell.direction:length() / 500, penetrator_length, penetrator_diameter, penetrator_density, 7850, 250)
                    --        print(to_penetrate, max_pen,shell.direction:length())
                    --        local new_pen_length = penetrator_length * (1 - (to_penetrate / max_pen))
                    --        shell.parameters.penetrator_length = new_pen_length
                    --        max_pen = Calculate_rod_penetration(shell.direction:length() / 500, new_pen_length, penetrator_diameter, penetrator_density, 7850, 250)
                    --        if max_pen >= to_penetrate then
                    --            print("destroy")
                    --            hit_shape:destroyShape()
                    --            next_position = hit_data.pointWorld
                    --            next_direction = shell.direction
                    --        end
                    --        --print(max_pen)
                    --    end
                    --else
                    --    print(hit_shape:transformPoint(shell.position), shell.position - hit_shape:getWorldPosition())
                    --end
            
  
                --if ricochet and next_direction:length2() > 5 then
                --    next_position = shell.position + next_direction * dt * hit_data.fraction--next_position + hit_data.normalWorld/10
                --    next_direction = ricochet * next_direction:length()/2
                --    print("rico")
                --end
            
            shell.position = next_position
            shell.velocity = next_velocity
        end
    end
end

function clamp(mx, mn, t)
	if t > mx then return mx end
	if t < mn then return mn end
	return t
end


function Reflect (v,n)
    return v - n*2*(v:dot(n))
end
-- TODO: Remake with a table
function Calculate_Ricochet (direction, normal, shell_type)
    local angle = math.acos(normal:dot(direction:normalize())) * 180/math.pi
    if angle > 90 then
        angle = 180 - angle
    end
    if shell_type == "APFSDS" then
        local chance = clamp(1, 0, 0.025 * (angle - 30))
        local choice = math.random()
        --print(choice, chance,0.025 * (angle - 30), angle)
        if choice <= chance then
            local random_dir = sm.vec3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5)
            local new_dir = random_dir:normalize() + direction:normalize()
            return Reflect(direction:normalize(), sm.vec3.lerp(normal,new_dir,0.2):normalize())
        end
        return nil
    end
end

function Calculate_armor_thickness ( ro, rd, boxSize ) 
    local rdx = rd.x^-1
    if rd.x == 0 then
        rdx = 999999999
    end
    local rdy = rd.y^-1
    if rd.y == 0 then
        rdy = 999999999
    end
    local rdz = rd.z^-1
    if rd.z == 0 then
        rdz = 999999999
    end
    local m = sm.vec3.new(rdx, rdy, rdz) -- can precompute if traversing a set of aligned boxes
    local n = m*ro   -- can precompute if traversing a set of aligned boxes
    local k = sm.vec3.new(math.abs(m.x),math.abs(m.y),math.abs(m.z))*boxSize
    local t1 = -n - k;
    local t2 = -n + k;
    local tN = math.max( math.max( t1.x, t1.y ), t1.z );
    local tF = math.min( math.min( t2.x, t2.y ), t2.z );
    
    if tF < 0 or tN < 0 then
        --print("MINUS", ro, rd, boxSize, tF, tN)
    end
    return (tF-tN)/2
end

-- Lanz-Odermatt
function Calculate_rod_penetration (impact_velocity, penetrator_length, penetrator_diameter, penetrator_density, armor_density, armor_brinell_scale)
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

function Calculate_bullet_penetration (impact_velocity, shell_diameter, shell_mass, is_apcbc)
    local kfbr=1900
    local knap = 1 -- tnt mass 0
    local kf_apcbc = 0.9; if is_apcbc then kf_apcbc = 1 end
    return (impact_velocity^1.43 * shell_mass^0.71) / (kfbr^1.43 * (shell_diameter/100^1.07)) * 100 * knap * kf_apcbc
end

function Calculate_heat_penetration (standoff_distance, shell_diameter, jet_density, armor_density)
    local Kdistance = 1 / (1 + ((standoff_distance - 7 * shell_diameter) / (14 * shell_diameter))^2)
    local k1 = 12
    local k2 = 0.3

    return shell_diameter * k1 * k2 * Kdistance * 1.3 * math.sqrt(jet_density / armor_density)
end 

