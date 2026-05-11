-- objects/roundelie.lua

roundelie = {
    name="roundelie",
    init = function(this, skin)
        this.connectionID = nil

        local player_skins = {
            {sprites["characters/roundelie_1"], {1,1,1,1}}, -- roundelie (add more skins later?)
            {sprites["characters/roundelie_2"], {1,1,1,1}},
            {sprites["characters/roundelie_3"], {1,1,1,1}},
        }

        this.spritesheet, this.nothing = unpack(player_skins[tonumber(skin)])
        this.skin = skin
        this.spr = this.spritesheet[7]
        print(this.spr)
        this.damage = 0
        this.stocks = 3
        this.facing = 1
        this.hitstun = 0
        this.active = true

        -- Override the base hurtbox
        this.hurtbox = {x = 1, y = 3, w = 6, h = 5}

        this.grace = 0
        this.jbuffer = 0
        this.bjump = 3
        this.dash_time = 0
        this.dash_target_x = 0
        this.dash_target_y = 0
        this.dash_accel_x = 0
        this.dash_accel_y = 0

        this.p_jump = false
        this.p_dash = false
        this.was_on_ground = false

        this.animations = {
            idle = {frames = {1}, speed = 1},
            run = {frames = {1, 2, 3, 4}, speed = 5},
            jump = {frames = {5}, speed = 1},
            wallslide = {frames = {5}, speed = 1},
            crouch = {frames = {6}, speed = 1}, --TODO: Crouch in midair is a separate sprite I think --what was I talking about
            up = {frames = {7}, speed = 1},
            conk = {frames = {9}, speed = 1}
        }
        this.current_anim = "idle"
        this.anim_frame = 1
        this.anim_timer = 0

        this.respawn_timer = 0
        this.invincible_timer = 0
        this.dash_cooldown = 0
        this.bump_cooldown = 0
        this.freeze = 0
        this.conk = 0
        this.conkdir = 0
        this.maxrun = 2

        this.check_snowballs = function(this)
            if this.hitstun > 0 then return end
            for _, o in ipairs(objects) do
                if o.type and o.type.name == "snowball" and not o.destroyed and o.throwerID ~= this.connectionID and not o.held then
                    if this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                        local function snap()
                            this:move(0, o.y-8-this.y)
                            if this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                                this:move(0, this.y+8-o.y)
                            end
                        end

                        if this.dash_time > 0 then
                            -- dash redirect
                            if this.dash_target_x == 0 then
                                o.vx = 3 * util.sign(o.vx)
                                o.stop = true
                            else
                                o.vx = 3 * util.sign(this.dash_target_x)
                            end

                            if this.dash_target_y > 0 then
                                local k = this.dash_target_x == 0 and 1 or 0.7071
                                snap()
                                this.vy = -k * 4.7
                                o.vy = -k * 2
                                this.bjump = 3
                            else
                                this.vy = this.dash_target_x == 0 and 0 or -2
                                o.vy = this.dash_target_x == 0 and -3 or -2
                            end

                            this.vx = util.sign(this.vx) * -4
                            this.dash_cooldown = 4
                            this.dash_time = 0

                            o.throwerID = this.connectionID
                            o.thrown_timer = 10
                            love.audio.play("hit", "static")

                        elseif this.vy > 0 and this:bottom() <= o:top() + 4 then
                            -- bounce on top
                            snap()
                            this.bjump = 3
                            this.jbuffer = 0
                            this.dash_cooldown = 0

                            if this.p_jump or inputSource.getKeyDown(this.connectionID, "b1") then
                                this.vy = -3.36
                                love.audio.play("maddy_jump", "static")
                            else
                                this.vy = -1.5
                            end

                            o.vy = o:is_solid(0, 1) and -1 or -0.5
                        end
                    end
                end
            end
        end
    end,

    update = function(this)
        if this.conk > 0 then
            this.conk = this.conk - 1
        end
        local id = this.connectionID

        -- iframes
        if this.invincible_timer > 0 then
            this.invincible_timer = this.invincible_timer - 1
        end

        -- dash cd
        if this.dash_cooldown > 0 then
            this.dash_cooldown = this.dash_cooldown - 1
        end
        if this.bump_cooldown > 0 then
            this.bump_cooldown = this.bump_cooldown - 1
        end

        -- respawn
        if this.respawn_timer > 0 then
            this.respawn_timer = this.respawn_timer - 1

            if this.respawn_timer == 0 then
                love.audio.play("spawn", "static")
                this.x = 120 - this.hurtbox.x - (this.hurtbox.w / 2)
                this.y = 20

                this.vx = 0
                this.vy = 0
                this.bjump = 3
                this.hitstun = 0
                this.invincible_timer = 60

                local spawn_offset_x = this.facing == 1 and 1 or 6
            end
            return
        end

        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
        -- hitstun --TODO: is "hitstun" ever used anywhere?
        if this.hitstun > 0 then
            this.dash_time = 0
            this.hitstun = this.hitstun - 1
            this.vy = util.appr(this.vy, 3, 0.15)
            this.vx = util.appr(this.vx, 0, 0.143)
        else

            local jump_btn = inputSource.getKeyDown(id, "b1")
            local dash_btn = inputSource.getKeyDown(id, "b2")

            local jump = jump_btn and not this.p_jump
            local dash = dash_btn and not this.p_dash and this.dash_cooldown == 0
            local bump = dash_btn and (not this.p_dash) and this.bump_cooldown == 0
            this.p_jump = jump_btn
            this.p_dash = dash_btn

            local ground_hit = this:is_solid(0, 1)
            local on_ground = ground_hit ~= false
            local on_semisolid = ground_hit and (ground_hit.type == "semisolid" or ground_hit.semisolid)

            if on_ground and not this.was_on_ground then
                game.init_smoke(this.x, this.y + 4)
            end

            if on_semisolid and v_input == 1 and not (this.was_on_ground) and jump_btn then --very hacky fix and I don't like it but I don't want to edit the move function since it breaks compatibility (would be very easy though). Maybe better fix? Or at least a hacky fix that's identical to the ideal case
                if not this:is_solid(0, 1, true) then
                    this.y = this.y + 1
                    on_ground = false
                    jump = false
                    this.jbuffer = 0
                    this.vy = this.was_vy
                end
            end

            if on_ground and this.vy > 0 then
                this.vy = 0
                this.rem.y=0
            end

            -- semisolid fall through
            if on_semisolid and v_input == 1 and jump then -- can definitely be combined with above part, but want to keep hacky and normal stuff separate for now
                if not this:is_solid(0, 1, true) then
                    this.y = this.y + 1
                    on_ground = false
                    jump = false
                    --this.jbuffer = 0 might add this back if necessary
                end
            end

            if jump then this.jbuffer = 4 elseif this.jbuffer > 0 then this.jbuffer = this.jbuffer - 1 end

            if on_ground then
                if this.down_attack then
                    this.conk = 15
                    this.down_attack = false
                    this.conkdir = (h_input == 1 or (h_input == 0 and this.facing == 1)) and -1 or 1
                    if this.was_vy == 5 then
                        hitbox.create(this.connectionID, (this.x - 25) + (-5 * this.conkdir), this.y + 4, 60, 4, 3, -2 * this.conkdir, -5, 2)
                        for i = -25,20,10 do
                            game.init_smoke(this.x + i + (-5 * this.conkdir), this.y + 8)  --could be better lol
                        end
                    else
                        hitbox.create(this.connectionID, (this.x - 15) + (-5 * this.conkdir), this.y + 4, 40, 4, 3, -2 * this.conkdir, -3, 2)
                        for i = -15,10,10 do
                            game.init_smoke(this.x + i + (-5 * this.conkdir), this.y + 8)  --could be better lol
                        end
                    end
                    
                end
                if this.vy < 0 then
                    this.bump_cooldown = 0;
                    love.audio.play("maddy_clip", "static")
                end
                this.grace = 6
                this.bjump = 3
            elseif this.grace > 0 then
                this.grace = this.grace - 1
            end

            if this.dash_time > 0 then
                this.dash_time = this.dash_time - 1
                if this.dash_time == 0 then
                    hitbox.create(this.connectionID, (this.x  - 1), (this.y  - 1), 10, 10, 3, 5 * this.facing, 0, 2)
                end
                game.init_smoke(this.x, this.y)

                if this.dash_time > 0 then
                    this.vx = 0 -- "dash" is just teleporting for roundelie (TODO edited for a test)
                end
                local hb_w, hb_h = 24, 24 --TODO: I think these are unused now
                local cx = this:hmid(this.vx, 0)
                local cy = this:vmid(0, this.vy)
                local hb_x = cx - (hb_w / 2)
                local hb_y = cy - (hb_h / 2)
            end
            if dash_btn and h_input == 0 and v_input == 0 and on_ground then
                this.maxrun = 4
            else
                this.maxrun = h_input == util.sign(this.vx) and util.appr(this.maxrun, 2, 0.05) or util.appr(this.maxrun,2,0.4) --TODO: change and vary
            end
            local accel = on_ground and 0.93 or 0.80
            local deccel = 0.16

            this.vx = math.abs(this.vx) <= this.maxrun and util.appr(this.vx, h_input * this.maxrun, accel) or util.appr(this.vx, util.sign(this.vx) * this.maxrun, deccel)
            if this.vx ~= 0 then this.facing = util.sign(this.vx) end

            local maxfall = 3
            if not on_ground then
                this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
            end

            if this.jbuffer > 0 then
                if this.grace > 0 then
                    this.jbuffer = 0
                    this.grace = 0
                    this.vy = -3.36

                    love.audio.play("maddy_jump", "static")
                    game.init_smoke(this.x, this.y + 4)
                end
            end

            local hb_w, hb_h = 10, 10
            local targetX = this.x + this.vx
            local targetY = this.y + this.vy
            local cx = targetX + this.hurtbox.x + (this.hurtbox.w / 2)
            local cy = targetY + this.hurtbox.y + (this.hurtbox.h / 2)
            local hb_x = cx - (hb_w / 2)
            local hb_y = cy - (hb_h / 2)
            if v_input == 1 and dash_btn and not on_ground and this.conk < 1 then
                this.down_attack = true
                this.vy = util.appr(this.vy, 5, 0.75) --TODO: tweak (significantly less powerful than in ra2)
                if (this:is_solid(-3,0) or this:is_solid(3,0)) then --TODO: attack from conking against the ground?
                    this.conk = 15
                    this.conkdir = (h_input == 1 or (h_input == 0 and this.facing == 1)) and -1 or 1
                    this.was_vy = 0
                end
                hitbox.create(this.connectionID, hb_x, hb_y, hb_w, hb_h, 3, util.sign(this.vx), 4.5, 2)
            else
                this.down_attack = false
            end
            if this.conk>0 then
                this.conk = this.conk - 1
		        if this.conk==14 then
                    if this.was_vy == 5 then --TODO: camera.shake
                        this.vy = -3.75
                        camera.shake(2, 2, 5)
                    else
                        this.vy = -2
                    end
		        end
		        this.vx = .1 * this.conk * this.conkdir
            elseif v_input == -1 and bump and this.bjump > 0 then
                this.invincible_timer = 10
                this.bump_cooldown = 20
                this.vy = -3
                love.audio.play("maddy_nodash", "static")
                this.bjump = this.bjump - 1
            elseif dash then
                if v_input == 0 and this.maxrun < 4 then
                    this.dash_time = 2
                    this.dash_cooldown = 61
                    this.invincible_timer = 2
                    this.vx = 30 * h_input
                end

                love.audio.play(this.down_attack and "maddy_downdash" or "maddy_dash", "static")
                game.init_smoke(this.x, this.y)
            end
            this.was_on_ground = on_ground
            this.was_vy = this.vy -- part of the hacky semisolid fix
        end

        this:move(this.vx, this.vy)
        this:check_snowballs()

        -- sprite stuff
        local anim_on_ground = this.vy >= 0 and this:is_solid(0, 1)

        local next_anim = "idle"
        if this.conk > 0 then
            next_anim = "conk"
        elseif not anim_on_ground then
            next_anim = "jump"
        elseif this.dash_time > 0 and this.vx == 0 then --whar
            next_anim = "crouch"
        elseif v_input == -1 then
            next_anim = "up"
        elseif v_input == 1 then
            next_anim = "crouch"
        elseif math.abs(this.vx) > 0.1 then
            next_anim = "run"
        end

        if next_anim ~= this.current_anim then
            this.current_anim = next_anim
            this.anim_frame = 1
            this.anim_timer = 0
        end

        local anim = this.animations[this.current_anim]
        this.anim_timer = this.anim_timer + 1

        if this.anim_timer >= anim.speed then
            this.anim_timer = 0
            this.anim_frame = this.anim_frame + 1
            if this.anim_frame > #anim.frames then
                this.anim_frame = 1
            end
        end


        -- blast zones and stocks (maybe move elsewhere?)
        if this:oob(0, 0) then
            love.audio.play("kill", "static")
            camera.shake(3, 3, 15)

            game.spawnExplosion(math.max(0, math.min(240, this:hmid())),
                math.max(0, math.min(135, this:vmid())),
                this:right() < stage.blastZone.l and "left" or
                this:left() > stage.blastZone.r and "right" or
                this:bottom() < stage.blastZone.t and "top" or
                "bottom",
                {41/255, 173/255, 255/255})

            this.stocks = this.stocks - 1
            this.damage = 0
            this.vx = 0
            this.vy = 0
            this.hitstun = 0
            this.rem.x = 0
            this.rem.y = 0

            if this.stocks > 0 then
                this.x = -1000
                this.y = -1000
                this.respawn_timer = 30
            else
                this.x = -1000
                this.y = -1000
                this.active = false
            end
        end
    end,

    on_hit_confirm = function(this, target, hb)
        -- stuff to do on hit confirm (e.g., pogoing?)
        camera.shake(1.5, 1.5, 2)
    end,

    draw = function(this)
        if not this.active and this.stocks <= 0 then return end
        if this.respawn_timer > 0 then return end

        local isBlinking = this.invincible_timer > 0 and (math.floor(this.invincible_timer / 4) % 2 == 0 or debugEnabled)
        local tint = this.skin == 3 and 1 or 0

        -- sprite hitstun tint
        if this.hitstun > 0 then
            love.graphics.setColor(255 / 255, 119 / 255, 168 / 255)
        else
            love.graphics.setColor(1, 1, 1)
        end

        local anim = this.animations[this.current_anim]
        local frame_idx = anim.frames[this.anim_frame]
        this.spr = this.spritesheet[frame_idx]
        local cx = this.hurtbox.x + (this.hurtbox.w / 2)

        -- apply pal swaps
        if isBlinking then
            love.graphics.setShader(whiteShader)
            love.graphics.setColor(1, 1, 1)
        elseif this.dash_cooldown > 0 then
            if this.skin == 3 then
                love.graphics.setShader(paletteSwapShader)
                paletteSwapShader:send("color_find", {171/255, 82/255, 54/255, 1.0})
                paletteSwapShader:send("color_replace", {255/255, 119/255, 168/255, 1.0})
            else
                love.graphics.setShader(paletteSwapShader)
                paletteSwapShader:send("color_find", {255/255, 163/255, 0/255, 1.0})
                paletteSwapShader:send("color_replace", {95/255, 87/255, 79/255, 1.0})
            end
            
        end

        sprites.draw(this.spr, this.x + cx, this.y, 0, this.facing, 1, cx, 0)

        if this.connectionID == connectionID then
            local px = math.floor(this.x)
            local py = math.floor(this.y)
            love.graphics.rectangle("fill", px + 3, py - 6, 3, 1)
            love.graphics.rectangle("fill", px + 4, py - 5, 1, 1)
        end

        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1)
    end
}
