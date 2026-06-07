-- maddy_cpu.lua

maddy_cpu = {
    timer = 0,
    is_stalling = 0,

    getInputForFrame = function()
        local this, opp
        for _, o in ipairs(objects) do
            if o.connectionID == cpuID then this = o
            elseif o.connectionID ~= nil and o.type ~= snowball and o.type ~= goldstool then opp = o end
        end
        if not this or not opp then
            return {up=false, down=false, left=false, right=false, b1=false, b2=false}
        end

        maddy_cpu.timer = maddy_cpu.timer + 1

        -- useful stuff
        local cx = this.x + 4
        local ground_obj = this:is_solid(0, 1)
        local grounded = ground_obj ~= false
        local on_semisolid = ground_obj and (ground_obj.type == "semisolid" or ground_obj.semisolid)

        local wall_l_obj = this:is_solid(-2, 0)
        local wall_r_obj = this:is_solid(2, 0)
        local wall_left = wall_l_obj and wall_l_obj.type ~= "semisolid" and not wall_l_obj.semisolid
        local wall_right = wall_r_obj and wall_r_obj.type ~= "semisolid" and not wall_r_obj.semisolid

        if grounded or wall_left or wall_right or this.dash_cooldown == 0 then
            maddy_cpu.is_stalling = 0
        end

        -- bounds & safe dir
        local over_solid = false
        local target_safe_x = 120
        local min_dist = 9999

        if stage and stage.platforms then
            for _, p in ipairs(stage.platforms) do
                if cx >= p.x and cx <= p.x + p.w and p.y >= this.y then over_solid = true end
                if p.type ~= "semisolid" and p.y < (stage.blastZone and stage.blastZone.b - 10 or 150) then
                    local inset = math.min(p.w / 2, 6)
                    local p_closest_x = math.max(p.x + inset, math.min(cx, p.x + p.w - inset))
                    local dist = math.abs(cx - p_closest_x)

                    if dist < min_dist then
                        min_dist = dist
                        target_safe_x = p_closest_x
                    end
                end
            end
        end
        local safe_dir = (cx < target_safe_x) and 1 or -1

        -- actions
        local actions = {
            {name="wait",   inps={up=false, down=false, left=false, right=false, b1=false, b2=false}},
            {name="move_l", inps={up=false, down=false, left=true,  right=false, b1=false, b2=false}},
            {name="move_r", inps={up=false, down=false, left=false, right=true,  b1=false, b2=false}},
            {name="drop",   inps={up=false, down=true,  left=false, right=false, b1=true,  b2=false}},
            {name="jump",   inps={up=false, down=false, left=false, right=false, b1=true,  b2=false}},
            {name="jump_l", inps={up=false, down=false, left=true,  right=false, b1=true,  b2=false}},
            {name="jump_r", inps={up=false, down=false, left=false, right=true,  b1=true,  b2=false}},
            {name="k_u",    inps={up=true,  down=false, left=false, right=false, b1=false, b2=true}},
            {name="d_d",    inps={up=false, down=true,  left=false, right=false, b1=false, b2=true}},
            {name="d_l",    inps={up=false, down=false, left=true,  right=false, b1=false, b2=true}},
            {name="d_r",    inps={up=false, down=false, left=false, right=true,  b1=false, b2=true}},
            {name="d_ul",   inps={up=true,  down=false, left=true,  right=false, b1=false, b2=true}},
            {name="d_ur",   inps={up=true,  down=false, left=false, right=true,  b1=false, b2=true}},
            {name="d_dl",   inps={up=false, down=true,  left=true,  right=false, b1=false, b2=true}},
            {name="d_dr",   inps={up=false, down=true,  left=false, right=true,  b1=false, b2=true}},
            {name="dodge",  inps={up=false, down=false, left=false, right=false, b1=false, b2=true}},
        }

        local in_danger = not over_solid and not grounded
        local in_narrow_gap = false
        if in_danger then
            local left_wall_dist = 999
            local right_wall_dist = 999
            if stage and stage.platforms then
                for _, p in ipairs(stage.platforms) do
                    -- check for vertical overlap with the wall
                    if p.type ~= "semisolid" and p.y <= this.y + 15 and p.y + p.h >= this.y - 15 then
                        if p.x + p.w <= cx then
                            left_wall_dist = math.min(left_wall_dist, cx - (p.x + p.w))
                        elseif p.x >= cx then
                            right_wall_dist = math.min(right_wall_dist, p.x - cx)
                        end
                    end
                end
            end
            -- center gap
            if left_wall_dist < 50 and right_wall_dist < 50 then
                in_narrow_gap = true
                -- override safe dir to nearest wall
                safe_dir = (left_wall_dist < right_wall_dist) and -1 or 1
            end
        end

        local dx = (opp.x + (opp.vx or 0)*4) - this.x
        local dy = (opp.y + (opp.vy or 0)*4) - this.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local b1_held = this.p_jump or this.input_jump
        local b2_held = this.p_dash or this.input_grapple

        local best_score = -math.huge
        local best_action = actions[1]

        for _, action in ipairs(actions) do
            local score = 0
            local inps = action.inps

            -- vetoes
            if inps.b1 and b1_held and this.vy >= 0 then score = -100000 end
            if inps.b2 and b2_held then score = -100000 end
            if inps.b2 and this.djump == 0 and this.vy < 0.5 then score = -math.huge end
            if action.name == "drop" and not on_semisolid then score = -100000 end

            if in_danger then
                -- recovery
                local towards_stage = (safe_dir == 1 and inps.right) or (safe_dir == -1 and inps.left)
                if towards_stage then score = score + 20000 end

                if wall_left or wall_right then
                    if inps.b1 then score = score + 50000 end
                else
                    if this.djump == 0 and this.dash_cooldown == 0 and maddy_cpu.is_stalling == 0 then
                        local stall_obj = this:is_solid(safe_dir * 5, 0)
                        if stall_obj and stall_obj.type ~= "semisolid" and not stall_obj.semisolid and this.vy > 1.2 and inps.b2 and towards_stage and not inps.up and not inps.down then
                            score = score + 80000
                        end
                    end
                    if this.djump > 0 and this.y > 110 and inps.up and inps.b2 then score = score + 40000 end
                end
            else
                -- fight
                if not grounded and this.djump == 0 then
                    -- evade
                    if dy > -10 and math.abs(dx) < 45 then
                        local evade_dir = (dx < 0) and 1 or -1
                        if stage and stage.blastZone then
                            if evade_dir == -1 and cx < stage.blastZone.l + 80 then evade_dir = 1 end
                            if evade_dir == 1 and cx > stage.blastZone.r - 80 then evade_dir = -1 end
                        end
                        if (evade_dir == 1 and inps.right) or (evade_dir == -1 and inps.left) then score = score + 80000 end
                        if (evade_dir == -1 and inps.right) or (evade_dir == 1 and inps.left) then score = score - 80000 end
                    else
                        -- retreat
                        local towards_land = (safe_dir == 1 and inps.right) or (safe_dir == -1 and inps.left)
                        if towards_land then score = score + 50000 end
                    end
                    if inps.b1 or inps.b2 then score = -100000 end
                else
                    -- pursuit
                    score = score + (800 - dist) * 10

                    -- gap closing
                    if math.abs(dx) > 15 then
                        if dx < 0 and inps.left then score = score + 5000 end
                        if dx > 0 and inps.right then score = score + 5000 end
                    else
                        if action.name == "wait" then score = score + 6000 end
                    end

                    -- grounded behavior
                    if grounded then
                        if math.abs(dy) < 15 and (inps.left or inps.right or action.name == "wait") then score = score + 4000
                        elseif dy < -15 and inps.b1 then score = score + 12000 end
                        if dy > 20 and action.name == "drop" then score = score + 60000 end
                        if math.abs(dx) < 24 and action.name == "d_d" then score = score + 45000 end
                    end

                    -- dodge
                    if action.name == "dodge" and dist < 30 and this.dash_cooldown == 0 and love.math.random() < 0.05 then
                        score = score + 70000
                    end

                    -- dashes
                    if inps.b2 and action.name ~= "dodge" and this.dash_cooldown == 0 then
                        local act_x = (inps.right and 1 or 0) - (inps.left and 1 or 0)
                        local act_y = (inps.down and 1 or 0) - (inps.up and 1 or 0)
                        local magnitude = math.max(1, math.sqrt(dx*dx + dy*dy))

                        if (act_x * (dx/magnitude)) + (act_y * (dy/magnitude)) > 0.85 then score = score + 25000 end
                        if not grounded and dy > 15 and inps.down then score = score + 35000 end
                    end

                    -- gap guard
                    if action.name == "drop" then
                        local safe_land = false
                        if stage and stage.platforms then
                            for _, p in ipairs(stage.platforms) do
                                if cx >= p.x and cx <= p.x + p.w and p.y > this.y + 5 then safe_land = true end
                            end
                        end
                        if not safe_land then score = -100000 end

                    elseif (inps.left or inps.right) and not inps.up then
                        local act_x = (inps.right and 1 or 0) - (inps.left and 1 or 0)
                        local proj_dist = inps.b2 and 24 or (inps.b1 and 24 or 12)
                        local proj_x = cx + (act_x * proj_dist)

                        local safe_land = false
                        if stage and stage.platforms then
                            for _, p in ipairs(stage.platforms) do
                                if proj_x >= p.x and proj_x <= p.x + p.w and p.y >= this.y - 15 then safe_land = true end
                            end
                        end
                        if not safe_land then score = -100000 end
                    end

                    -- avoid side blast zones
                    if stage and stage.blastZone then
                        local act_x = (inps.right and 1 or 0) - (inps.left and 1 or 0)
                        if act_x == 0 and inps.b2 and not inps.up and not inps.down then
                            act_x = this.facing
                        end
                        if act_x < 0 then
                            local dist = cx - stage.blastZone.l
                            if dist < 100 then score = score - ((100 - dist) * 1000) end
                        elseif act_x > 0 then
                            local dist = stage.blastZone.r - cx
                            if dist < 100 then score = score - ((100 - dist) * 1000) end
                        end
                        local proj_dist = inps.b2 and 48 or (inps.b1 and 24 or 12)
                        local proj_x = cx + (act_x * proj_dist) + (this.vx * 4)
                        if proj_x <= stage.blastZone.l + 8 or proj_x >= stage.blastZone.r - 8 then
                            score = -100000
                        end
                    end
                end
            end

            score = score + love.math.random(0, 20)
            if score > best_score then
                best_score = score
                best_action = action
            end
        end

        if best_action.inps.b2 and this.djump == 0 then maddy_cpu.is_stalling = 1 end
        return best_action.inps
    end
}
