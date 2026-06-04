-- stepstools_cpu.lua

stepstools_cpu = {
    timer = 0,
    is_stalling = 0,

    getInputForFrame = function()
        local this, opp
        for _, o in ipairs(objects) do
            if o.connectionID == cpuID then this = o
            elseif o.connectionID ~= nil and o.type ~= snowball then opp = o end
        end
        if not this or not opp then
            return {up=false, down=false, left=false, right=false, b1=false, b2=false}
        end

        stepstools_cpu.timer = stepstools_cpu.timer + 1

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
            stepstools_cpu.is_stalling = 0
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
            {name="k_l",    inps={up=false, down=false, left=true,  right=false, b1=false, b2=true}},
            {name="k_r",    inps={up=false, down=false, left=false, right=true,  b1=false, b2=true}},
            {name="k_ul",   inps={up=true,  down=false, left=true,  right=false, b1=false, b2=true}},
            {name="k_ur",   inps={up=true,  down=false, left=false, right=true,  b1=false, b2=true}},
            {name="fly_wait",    inps={up=false, down=true,  left=false, right=false, b1=false, b2=true}},
            {name="fly_move_l",   inps={up=false, down=true,  left=true,  right=false, b1=false, b2=true}},
            {name="fly_move_r",   inps={up=false, down=true,  left=false, right=true,  b1=false, b2=true}},
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

            

            score = score + love.math.random(0, 20)
            if score > best_score then
                best_score = score
                best_action = action
            end
        end

        if best_action.inps.b2 and this.djump == 0 then stepstools_cpu.is_stalling = 1 end
        return best_action.inps
    end
}
