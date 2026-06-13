-- objects/roundelie.lua
-- v0.5.1

-- Movement Documentation:
-- Z to jump, left and right arrow keys to move
-- X + Up causes a small midair "bounce" slightly smaller than a jump. 
--   Can be done up to 3 times before touching the ground
--   Was changed to have no cooldown between uses (but the parameter to adjust cooldown time was not removed)
-- X + Down causes roundelie to accelerate downward quickly while held
--   Has a top speed higher than the regular terminal velocity
--   Has a hitbox that pushes opponents downward, which may "trap" them as they fall
--   If X + Down is held when roundelie hits a wall, roundelie bounces back and upward off the wall
--   (ie in the direction opposite roundelie's facing direction, not necessarily away from the wall)
--   If X + Down is held when roundelie hits ground, roundelie bounces back and upward off the ground and sends out a shockwave
--     Roundelie's bounce and the shockwave are larger if roundelie hits the ground at the max speed of the down + x attack
--     The shockwave does upward knockback to all opponents at ground height and somewhat close to roundelie laterally
--     The shockwave is slightly offset laterally in the direction roundelie was facing when they hit the ground
--     This hitbox is also marked by particles for clarity
-- X + Left/Right/Nothing causes roundelie to teleport in the held direction
--   Zeros roundelie's x speed, but does not change its y speed
--   Has a 2 second cooldown before roundelie can teleport again
--   This is indicated by the color of roundelie's beak, which changes when the teleport is unavailable
--   Has a hitbox that sends opponent in the direction Roundelie is facing
--   Roundelie is invulnerable for the first two frames of the teleport, and the hitbox is also active for those first two frames
--   Roundelie can act out of teleport immediately e.g. by buffering a jump
--   ...
-- Jump + Down lets roundelie fall through any semisolids it interacts with
--   Falling through semisolids which roundelie is standing on requires pressing jump, like other characters

roundelie = {
    name="roundelie",
    init = function(this, skin)
        this.connectionID = nil
        
        local player_skins = {
            {sprites["characters/roundelie_1"], {1,1,1,1}}, -- roundelie (default)
            {sprites["characters/roundelie_2"], {1,1,1,1}}, -- delaughter (purple/red)
            {sprites["characters/roundelie_3"], {1,1,1,1}}, -- statue (golden) ... is wip, so in the meantime ~> nintendo-style palette (light blue)
        }
        
        this.spritesheet, this.nothing = unpack(player_skins[tonumber(skin)]) --TODO: using this.nothing as a placeholder since this is what the stools do
        this.skin = tonumber(skin)
        this.spr = this.spritesheet[7]
        this.damage = 0
        this.stocks = 3
        this.facing = 1
        this.hitstun = 0
        this.active = true
        
        -- Override the base hurtbox
        this.hurtbox = {x = 1, y = 3, w = 6, h = 5}
        
        this.prev_x = this.x
        this.prev_y = this.y

        this.grace = 0
        this.jbuffer = 0
        this.bjump = 3
        this.dash_time = 0
        
        this.p_jump = false
        this.p_dash = false
        this.was_on_ground = false
        this.was_big_conk = false
        -- messy?
        this.start_teleport = false
        this.start_teleport_h = false
        
        -- TODO:: probably want to add on-hit effects for at least the shockwave also
        this.teleport_hb  = nil
        
        this.animations = {
            -- TODO:: messy?
            idle1 = {frames = {1},  speed = 1}, -- up
            idle2 = {frames = {14}, speed = 1}, -- right
            idle3 = {frames = {15}, speed = 1}, -- down
            idle4 = {frames = {16}, speed = 1}, -- left
            -- TODO::
            --  - roll doesn't handle direction changes properly (sprite shouldn't flip, and instead it should decrement anim_frame)
            --  - the different idle poses should start animation from corresponding roll frames (rather than the roll always starting from the top position)
            roll = {frames = {10, 2, 3, 4}, speed = 3}, -- up -> right -> down -> left ...
            -- TODO::
            --  - puff probably shouldn't activate e.g. out of knockback or from the bounce after down+x
            --  - maaaybe only use puff for bjumps and have different pose for grounded jumps/moving up in the air?
            --  - also maybe should tie animation speed to xspeed? but idk how this would work with the current system
            jump1 = {frames = {11}, speed = 1}, -- inflate
            -- TODO:: maybe change jump2 => jump3 be an animation instead of based on y-speed?
            jump2 = {frames = {12}, speed = 1},
            jump3 = {frames = {5}, speed = 1},
            dive1 = {frames = {9}, speed = 1},  -- down+x pose
            dive2 = {frames = {13}, speed = 1}, -- down+x pose *when large shockwave will trigger upon landing
            crouch = {frames = {6}, speed = 1},
            up = {frames = {7}, speed = 1},
            -- TODO:: maaaybe add alternate/random conk poses? could reuse the roll sprites...
            conk = {frames = {8}, speed = 1},  -- disoriented pose used after down+x collides with ground to trigger large shockwave
            -- TODO:: add fill color to sprites for sadface/tears/sroundelie during hitstun?
            -- pain = {...
        }
        this.idle_poses = { "idle1", "idle2", "idle3", "idle4" }
        this.current_anim = "idle1"
        this.anim_frame = 1
        this.anim_timer = 0
        
        this.respawn_timer = 0
        this.invincible_timer = 0
        this.dash_cooldown = 0
        this.bump_cooldown = 0
        this.freeze = 0
        this.conk = 0
        this.conkdir = 0
        
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
                            o.vx = 3 * this.facing
                            o.stop = false --TODO: probably not?
                            this.vy = -1
                            o.vy = -3
                            
                            this.vx = this.facing * -4
                            this.dash_cooldown = 4
                            this.dash_time = 0
                            
                            o.throwerID = this.connectionID
                            o.thrown_timer = 10
                            love.audio.play("hit", "static")
                            
                        elseif this.vy > 0 and this:bottom() <= o:top() + 4 then
                            -- bounce on top
                            snap()
                            this.bjump = 3
                            if this.p_jump or inputSource.getKeyDown(this.connectionID, "b1") or this.down_attack then
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

        
        -- this.init_sparkburst = function(this, angle)
            -- for i = 1, 8 do
                -- local angle2 = angle + (2 * math.pi * math.random() * 0.5)-- * 0.5)
                -- local cx = this.hurtbox.x + (this.hurtbox.w / 2)
                -- local cy = this.hurtbox.y + (this.hurtbox.h / 2)
                -- table.insert(particles_fg, {
                    -- x = this.x + cx,
                    -- y = this.y + cy,
                    -- speed = 1.05,--0.85,
                    -- drag = 0.05,
                    -- vx = math.sin(angle2) * (math.random(12,13) * 0.1) * 3 * 1.1,--(math.random(10,12) * 0.1),
                    -- vy = math.cos(angle2) * (math.random(12,13) * 0.1) * 3 * 1.1,--(math.random(10,12) * 0.1),
                    -- -- vx = math.sin(angle2) * (math.random() + 1),
                    -- -- vy = math.cos(angle2) * (math.random() + 1),
                    -- --vx = math.sin(angle2) * (math.random() * 8 - 4) + this.facing * 1.5,
                    -- --vy = math.cos(angle2) * (math.random() * 8 - 4) - 1,
                    -- timer = 0,
                    -- duration = 5 + math.random(0, 5),
                    -- update = function(p)
                        -- p.x = p.x + p.vx
                        -- p.y = p.y + p.vy
                        -- p.vx = p.vx * p.speed
                        -- p.vy = p.vy * p.speed
                        -- p.timer = p.timer + 1
                        -- return p.timer >= p.duration
                    -- end,
                    -- draw = function(p)
                        -- local fade = 1 - (p.timer / p.duration)
                        -- if (p.vx * p.vx + p.vy * p.vy) > 1.5 then
                            -- love.graphics.setColor(255/255, 163/255, 0/255, 1)--fade * p.drag)
                            -- love.graphics.setLineStyle("rough")
                            -- love.graphics.line(math.floor(p.x), math.floor(p.y), math.floor(p.x - p.vx * p.drag), math.floor(p.y - p.vy * p.drag))
                            -- love.graphics.line(math.floor(1 + p.x), math.floor(1 + p.y), math.floor(1 + p.x - p.vx * p.drag), math.floor(1 + p.y - p.vy * p.drag))
                            -- --love.graphics.rectangle("fill", math.floor(p.x - p.vx * p.drag), math.floor(p.y - p.vy * p.drag), 1, 1)
                            -- --love.graphics.rectangle("fill", math.floor(1 + p.x - p.vx * p.drag), math.floor(1 + p.y - p.vy * p.drag), 1, 1)
                            -- -- if (p.vx * p.vx + p.vy * p.vy) > 2.5 then
                                -- -- love.graphics.rectangle("fill", math.floor(p.x - 2 * p.vx * p.drag), math.floor(p.y - 2 * p.vy * p.drag), 1, 1)
                                -- -- love.graphics.rectangle("fill", math.floor(1 + p.x - 2 * p.vx * p.drag), math.floor(1 + p.y - 2 * p.vy * p.drag), 1, 1)
                            -- -- end
                            -- if p.timer < 4 then
                                -- love.graphics.setColor(1, 0, 0, 1)--fade)
                            -- else
                                -- love.graphics.setColor(255/255, 236/255, 39/255, 1)--, fade)
                            -- end
                            -- love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), 1, 1)
                            -- love.graphics.rectangle("fill", math.floor(1 + p.x), math.floor(1 + p.y), 1, 1)
                        -- end
                        -- love.graphics.setColor(1, 1, 1, 1)
                    -- end
                -- })
            -- end
        this.init_sparkburst = function(this, angle)
            for i = 1, 7 do
                local angle2 = angle + (2 * math.pi * math.random() * 0.5)-- * 0.5)
                local cx = this.hurtbox.x + (this.hurtbox.w / 2)
                local cy = this.hurtbox.y + (this.hurtbox.h / 2) - 1
                table.insert(particles_fg, {
                    x = this.x + cx,
                    y = this.y + cy,
                    speed = 4 + math.random(6,14) * 0.1,--1.10,--0.85,
                    drag = 0.5,--0.6,
                    vx = math.sin(angle2),-- * (math.random(11,12) * 0.1),--(math.random(10,12) * 0.1),
                    vy = math.cos(angle2),-- * (math.random(11,12) * 0.1),--(math.random(10,12) * 0.1),
                    -- vx = math.sin(angle2) * (math.random() + 1),
                    -- vy = math.cos(angle2) * (math.random() + 1),
                    --vx = math.sin(angle2) * (math.random() * 8 - 4) + this.facing * 1.5,
                    --vy = math.cos(angle2) * (math.random() * 8 - 4) - 1,
                    timer = 0,
                    duration = 7 + math.random(0, 3),
                    update = function(p)
                        p.x = p.x + p.vx * p.speed
                        p.y = p.y + p.vy * p.speed
                        if p.timer == 0 then
                            p.x = p.x + p.vx * p.speed
                            p.y = p.y + p.vy * p.speed
                        end
                        p.vx = p.vx * p.drag-- * p.speed
                        p.vy = p.vy * p.drag-- * p.speed
                        if p.is_frozen then
                            p.timer = p.timer + 0.5
                        else
                            p.timer = p.timer + 1
                        end
                        return p.timer >= p.duration
                    end,
                    draw = function(p)
                        local fade = 1 - (p.timer / (p.duration + 5))
                        love.graphics.setColor(1, 1, 1, 1)
                        if p.timer <= 2 then
                            love.graphics.setColor(1, 1, 1, 1)--fade)
                        else
                            --love.graphics.setColor(1, 0, 0, 1)
                            -- was 236
                            love.graphics.setColor((245*fade*1.95)/255, (186*fade*1.95)/255, (39*fade*1.8)/255, 1)--, fade)
                            --love.graphics.setColor((255*fade*1.99)/255, (196*fade*1.85)/255, (39*fade*1.5)/255, 1)--, fade)
                        end
                        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), 1, 1)
                        love.graphics.setColor((255*fade*1.95)/255, (153*fade*1.95)/255, 0/255, 1)--fade * p.drag)
                        if p.timer >= 1 and (p.x - p.vx * p.speed >= 1.5) then
                        --if (p.vx * p.vx + p.vy * p.vy) >= 1.5 then --> 1.5 then
                            --love.graphics.setColor(255/255, 163/255, 0/255, 1)--fade * p.drag)
                            love.graphics.rectangle("fill", math.floor(p.x - p.vx * p.speed), math.floor(p.y - p.vy * p.speed), 1, 1)
                            if (p.x - p.vx * p.speed >= 2.5) then
                                -- I don't think this even happens with current config
                                love.graphics.rectangle("fill", math.floor(p.x - p.vx * p.speed - ((p.vx / p.drag) * p.speed)), math.floor(p.y - p.vy * p.speed - ((p.vy/p.drag) * p.speed)), 1, 1)
                            end
                        end
                        -- if (p.vx * p.vx + p.vy * p.vy) >= 1.5 then
                            -- love.graphics.rectangle("fill", math.floor(p.x - 2 * p.vx * p.speed), math.floor(p.y - 2 * p.vy * p.speed), 1, 1)
                        -- end
                        love.graphics.setColor(1, 1, 1, 1)
                    end
                })
            end
        end
        
        -- TODO: clean-up
        -- this.init_sparkburst = function(this, angle)
            -- -- (ty @ Lazy Devs on youtube, lol)
            -- --local angle = 2 * math.pi * math.random()
            -- local cx = this.hurtbox.x + (this.hurtbox.w / 2)
            -- local cy = this.hurtbox.y + (this.hurtbox.h / 2)
            -- local init_delay = 1
            
            -- for i=1,6 do
                -- -- lua cos/sin functions expect radians not "% of a circle" like pico8
                -- -- 0.4 is the range of possible angles
                -- local angle2 = angle + (2 * math.pi * math.random() * 0.4)-- * 0.5)
                -- --local spark_color = math.random(1,3)
                -- table.insert(
                    -- particles_fg, {
                        -- -- range of 
                        -- --angle = ref_angle + math.random() * 0.5,
                        
                        -- x = this.x + cx,
                        -- y = this.y + cy,
                        -- vx = math.sin(angle2) * (math.random(10,12) * 0.2),
                        -- vy = math.cos(angle2) * (math.random(10,12) * 0.2),
                        -- drag = 0.2,
                        -- speed = math.random(4,5),--math.random(4, 6),
                        
                        -- timer = 0,
                        -- duration = 6 - math.random(-1, 0) + init_delay, -- messy!
                        
                        -- update = function(p)
                            -- if p.timer < init_delay then
                                -- p.timer = p.timer + 1
                                -- return false -- ?
                            -- end
                            
                            -- -- if you uncomment watch for s
                            -- -- if p.timer > p.duration - init_delay - 2 then
                                -- -- -- messy
                                -- -- p.s = p.s - 1
                            -- -- end
                            
                            -- p.x = p.x - p.vx * p.speed
                            -- p.y = p.y - p.vy * p.speed
                            
                            -- p.vx = p.vx * p.drag -- min 1
                            -- p.vy = p.vy * p.drag -- min 1
                            
                            -- if p.is_frozen then
                                -- p.timer = p.timer + 0.5
                            -- else
                                -- p.timer = p.timer + 1
                            -- end
                            -- return p.timer >= p.duration
                        -- end,
                        
                        -- draw = function(p)
                            
                            -- love.graphics.setLineStyle("rough")
                            -- love.graphics.setLineWidth(2)
                            -- -- if spark_color == 1 then
                                -- -- love.graphics.setColor(1, 1, 0)
                            -- -- elseif spark_color == 2 then
                                -- -- love.graphics.setColor(1, 0, 1)
                            -- -- else
                                -- -- love.graphics.setColor(0, 1, 1)
                            -- -- end
                            -- if p.timer - init_delay <= (p.duration - init_delay) / 2 then
                                -- love.graphics.setColor(1, 1, 1)
                            -- else
                                -- love.graphics.setColor(0.5, 0.5, 0.5)
                            -- end
                            -- love.graphics.line(p.x, p.y, p.x - p.vx * p.speed, p.y - p.vy * p.speed)
                            -- if p.timer - init_delay <= (p.duration - init_delay) / 2 then
                                -- love.graphics.setColor(1, 1, 0)
                            -- else
                                -- love.graphics.setColor(0.8, 0.8, 0.8)
                            -- end
                            -- --love.graphics.setColor(0.8, 0.8, 0.8)
                            -- love.graphics.line(p.x+1, p.y+1, p.x - p.vx * p.speed, p.y - p.vy * p.speed)
                            -- love.graphics.setColor(1, 1, 1) -- idk if this is needed or not
                        -- end
                    -- })
            -- end
        -- end
    end,
    
    update = function(this)
        local id = this.connectionID
        
        if this.freeze > 0 then
            this.freeze = this.freeze - 1
            if this.freeze == 0 then
                this:move(this.vx, this.vy)
                this:check_snowballs()
            end
            return
        end
        
        -- bonk timer
        if this.conk > 0 then
            this.conk = this.conk - 1
        end
        
        -- iframes
        if this.invincible_timer > 0 then
            this.invincible_timer = this.invincible_timer - 1
        end
        
        -- dash cd
        if this.dash_cooldown > 0 then
            this.dash_cooldown = this.dash_cooldown - 1
        end
        
        -- bump cd
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
                this.dash_cooldown = 0
                this.bump_cooldown = 0
                --
                if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
            end
            return
        end
        
        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
        -- hitstun (set by hitbox.lua)
        if this.hitstun > 0 then
            this.dash_time = 0
            this.hitstun = this.hitstun - 1
            this.vy = util.appr(this.vy, 3, 0.15)
            this.vx = util.appr(this.vx, 0, 0.143)
            --
            if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
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
            
            -- weird semisolid fall through
            if on_semisolid and v_input == 1 and not (this.was_on_ground) and jump_btn then --very hacky fix and I don't like it but I don't want to edit the move function since it breaks interoperability (would be very easy though). Maybe better fix? Or at least a hacky fix that's identical to the ideal case
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
                this.rem.y = 0
            end
            
            -- regular semisolid fall through
            if on_semisolid and v_input == 1 and jump then -- can definitely be combined with above part, but want to keep hacky and normal stuff separate for now
                if not this:is_solid(0, 1, true) then
                    this.y = this.y + 1
                    on_ground = false
                    jump = false
                end
            end
            
            if jump then this.jbuffer = 4 elseif this.jbuffer > 0 then this.jbuffer = this.jbuffer - 1 end
            
            if on_ground then
                if this.down_attack then
                    this.conk = 15
                    this.down_attack = false
                    this.conkdir = (h_input == 1 or (h_input == 0 and this.facing == 1)) and -1 or 1
                    -- shockwaves
                    if this.was_vy == 5 then
                        hitbox.create(this.connectionID, (this.x - 25) + (-5 * this.conkdir), this.y + 4, 60, 4, 3, -2 * this.conkdir, -4, 2)
                        for i = -25,20,10 do
                            game.init_smoke(this.x + i + (-5 * this.conkdir), this.y + 8)  --could be better
                        end
                    else
                        hitbox.create(this.connectionID, (this.x - 15) + (-5 * this.conkdir), this.y + 4, 40, 4, 2, -2 * this.conkdir, -3, 2)
                        for i = -15,10,10 do
                            game.init_smoke(this.x + i + (-5 * this.conkdir), this.y + 8)  --could be better
                        end
                    end
                    if this.was_vy == 5 then
                        this.was_big_conk = true
                        this.vy = -3.75
                        camera.shake(2, 2, 5)
                    else
                        this.vy = -2
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
                if this.dash_time == 2 then
                    --
                    this.freeze = 3 -- half of the on-hit value
                    this.teleport_hb = hitbox.create(this.connectionID, (this.x  - 1), (this.y  - 1), 10, 10, 3, 5 * this.facing, 0, 2)
                    this.teleport_hb.telefrag = true
                    this.teleport_hb.hit_sfx = "zap" -- generic "crit" sfx used for big hits, e.g. Lani's tipper and body slam
                end
                this.dash_time = this.dash_time - 1
                
                if this.dash_time > 0 then
                    hitbox.create(this.connectionID, (this.x  - 1), (this.y  - 1), 10, 10, 3, 5 * this.facing, 0, 2)
                    this.vx = 0 -- "dash" is just teleporting for roundelie
                end
            else
                if this.teleport_hb then
                    this.teleport_hb.active = false
                    this.teleport_hb = nil
                end
            end
            local maxrun = 2 -- different from ra2, but the speed building doesn't fit well with the character and is overcomplicated
            local accel = on_ground and 0.93 or 0.80
            local deccel = 0.16
            
            this.vx = math.abs(this.vx) <= maxrun and util.appr(this.vx, h_input * maxrun, accel) or util.appr(this.vx, util.sign(this.vx) * maxrun, deccel)
            if this.vx ~= 0 then this.facing = util.sign(this.vx) end
            
            local maxfall = 3
            if not on_ground then
                this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
            end
            
            if this.jbuffer > 0 then
                if this.grace > 0 then
                    this.jbuffer = 0
                    -- this.grace = 0
                    this.vy = -3.36
                    
                    love.audio.play("maddy_jump", "static")
                    game.init_smoke(this.x, this.y + 4)
                end
            end
            -- might be overcomplicated; left over from maddy code
            local hb_w, hb_h = 10, 10
            local targetX = this.x + this.vx
            local targetY = this.y + this.vy
            local cx = targetX + this.hurtbox.x + (this.hurtbox.w / 2)
            local cy = targetY + this.hurtbox.y + (this.hurtbox.h / 2)
            local hb_x = cx - (hb_w / 2)
            local hb_y = cy - (hb_h / 2)
            if v_input == 1 and dash_btn and not on_ground and this.conk < 1 then
                this.down_attack = true
                this.was_big_conk = false
                this.vy = util.appr(this.vy, 5, 0.75)
                if (this:is_solid(-3,0) or this:is_solid(3,0)) then
                    this.conk = 15
                    this.conkdir = (h_input == 1 or (h_input == 0 and this.facing == 1)) and -1 or 1
                    this.vy = -2
                end
                hitbox.create(this.connectionID, hb_x, hb_y, hb_w, hb_h, 1, util.sign(this.vx), 4.5, 2)
            else
                this.down_attack = false
            end
            if this.conk > 0 then
                this.conk = this.conk - 1
                this.vx = .1 * this.conk * this.conkdir
            elseif v_input == -1 and bump and this.bjump > 0 then
                this.bump_cooldown = 0 --TODO: different from main branch, update documentation and code neatness if you want to keep
                this.vy = -3
                love.audio.play("maddy_nodash", "static")
                if this.bjump >= 1 then
                    game.init_smoke(this.x, this.y)
                    this.bjump = this.bjump - 1
                end
            elseif dash then
                if v_input == 0 then
                    this.dash_time = 2
                    -- TEST TEST TEST (DASH COOLDOWN)
                    this.dash_cooldown = 10--61
                    -- TEST TEST TEST (DASH COOLDOWN)
                    this.invincible_timer = 2
                    -- 30 -> 32
                    this.vx = 32 * h_input
                    this.start_teleport = true
                    this.start_teleport_h = h_input ~= 0
                end
                
                love.audio.play("maddy_dash", "static")
            end
            this.was_on_ground = on_ground
            this.was_vy = this.vy -- part of the hacky semisolid fix
        end
        
        -- used for teleport effects which are drawn after movement/collision is calculated
        this.prev_x = this.x
        this.prev_y = this.y
        
        this:move(this.vx, this.vy)
        this:check_snowballs()
        
        -- teleport visuals effects
        -- TODO: should probably move this elsewhere?
        if this.start_teleport then
            
            local x_step = (this.x - this.prev_x) / 5
            local y_step = (this.y - this.prev_y) / 5
            local test_cx = this.hurtbox.x + (this.hurtbox.w / 2)
            local test_cy = this.hurtbox.y + (this.hurtbox.h / 2)
            local offset = this.hurtbox.w / 2 + 1
            
            -- 1/3 of a circle in radians
            local r = 2 * math.pi / 3
            -- use offset for diameter
            
            -- poof out (startpoint)
            if this.start_teleport_h then
                table.insert(
                    particles_fg, {
                        
                        facing = this.facing,
                        is_frozen = this.freeze > 0,
                        cx = test_cx,
                        cy = test_cy,
                        --
                        ax = this.prev_x,
                        ay = this.prev_y,
                        bx = this.x,
                        by = this.y,
                        
                        x = this.prev_x,
                        y = this.prev_y,
                        
                        -- coords = {
                            -- this.prev_x,
                            -- this.prev_y,
                            -- this.x,
                            -- this.y,
                        -- },
                        
                        timer = 0,
                        duration = 15,
                        -- TODO: messy?
                        smoke = false,
                        
                        update = function(p)
                            -- p.x_tele_a = p.x_tele_a + p.vx
                            -- p.y_tele_a = p.y_tele_a + p.vy
                            -- p.x_tele_b = p.x_tele_b + p.vx
                            -- p.y_tele_b = p.y_tele_b + p.vy
                            
                            if p.is_frozen then
                                p.timer = p.timer + 0.5
                            else
                                p.timer = p.timer + 1
                            end
                            return p.timer >= p.duration
                        end,
                        
                        draw = function(p)
                            local frame = math.floor(p.timer / p.duration * 3) + 1
                            -- local fade = 1
                            -- if p.timer >= p.duration / 2 then
                                -- fade = 1 - (p.timer / p.duration)
                            -- end
                            if frame > 3 then frame = 3 end
                            
                            -- smoke
                            -- local dx, dy = math.floor(p.x_tele_a), math.floor(p.y_tele_a)
                            -- sprites.draw(sprites.smoke[frame], p.flipX == -1 and dx + 8 or dx, p.flipY == -1 and dy + 8 or dy, 0, p.flipX, p.flipY, 0, 0)
                            -- dx, dy = math.floor(p.x_tele_b), math.floor(p.y_tele_b)
                            -- sprites.draw(sprites.smoke[frame], p.flipX == -1 and dx + 8 or dx, p.flipY == -1 and dy + 8 or dy, 0, p.flipX, p.flipY, 0, 0)
                            
                             love.graphics.setColor(1, 1, 1)
                            
                            --smoke
                            if (not p.smoke) and p.timer >= 0 then
                                p.smoke = true
                                local angle = 1 * r  + 2 * math.pi * math.random() * 0.3
                                game.init_smoke(p.x + math.sin(angle) * 4, p.y + math.cos(angle) * 4 + 1)
                                angle = 2 * r + 2 * math.pi * math.random() * 0.3
                                game.init_smoke(p.x + math.sin(angle) * 4, p.y + math.cos(angle) * 4 + 1)
                                angle = 3 * r + 2 * math.pi * math.random() * 0.3
                                game.init_smoke(p.x + math.sin(angle) * 4, p.y + math.cos(angle) * 4 + 1)
                                
                                --game.init_smoke(p.ax + offset, p.ay + math.random(-4, 4))
                                --game.init_smoke(p.ax - offset, p.ay + math.random(-4, 4))
                                --game.init_smoke(p.ax + math.random(-4, 4), p.ay + offset)
                                --
                                --game.init_smoke(p.ax + math.random(-4, 4), p.ay - offset)
                            end
                            
                            -- afterimage formed in smoke :0
                            sprites.draw(sprites.roundelie_teleport_afterimage[frame], p.ax + p.cx, p.ay, 0, p.facing, 1, p.cx, 0)
                            
                            --sprites.draw(sprites.roundelie_teleport_afterimage[frame], p.coords[3] + p.cx, p.coords[4], 0, p.facing, 1, p.cx, 0)
                            
                            -- TODO:: basic concept for the full effect:
                            -- - add magic-y spark-y particles around the two afterimages, and maybe a scattering in between
                            -- - add short "explosion" at endpoint (quick burst -> dust settling); maybe play around with making the initial burst/explosion a sprite anim?
                            -- - ...
                            -- this move is a bit strange... to me it reads as a "blip" (...out of existence and suddenly appear elsewhere) more than a "zip" (sudden violent burst of speed),
                            -- but the knockback seems more fitting for a "zip" => opponent in knocked back in the direction of a movement rather than them being blown away by a burst?
                            -- could play around with knockback, maybe? I think neutral teleport should absolutely behave like a "burst", at least
                        end
                    })
            end
            
            -- burst/pop in (endpoint)

            
            
            table.insert(
                
                particles_fg, {
                    x = this.x,
                    y = this.y,
                    cx = this.hurtbox.x + (this.hurtbox.w / 2),
                    cy = this.hurtbox.y + (this.hurtbox.h / 2),
                    
                    timer = 0,
                    duration = 15,
                    
                    is_frozen = this.freeze > 0,
                    smoke = false,
                    burst = false,

                    update = function(p)
                        if p.is_frozen then
                            p.timer = p.timer + 0.5
                        else
                            p.timer = p.timer + 1
                        end
                        return p.timer >= p.duration
                    end,
                    
                    draw = function(p)
                        -- messy?
                        if p.smoke and p.burst then return end
                        
                        -- smoke
                        if (not p.smoke) and p.timer >= 2 then
                            p.smoke = true
                            --game.init_smoke(p.x, p.y)
                            local angle = 1 * r  + 2 * math.pi * math.random() * 0.3
                            game.init_smoke(p.x + math.sin(angle) * 2, p.y + math.cos(angle) * 2 + 1)
                            angle = 2 * r + 2 * math.pi * math.random() * 0.3
                            game.init_smoke(p.x + math.sin(angle) * 2, p.y + math.cos(angle) * 2 + 1)
                            angle = 3 * r + 2 * math.pi * math.random() * 0.3
                            game.init_smoke(p.x + math.sin(angle) * 2, p.y + math.cos(angle) * 2 + 1)
                        end
                        -- burst
                        if p.timer <= 2 then
                            -- hitbox is size 10x10 and centered on roundelie => 12-diameter circle fits well enough
                            love.graphics.setColor(1, 1, 1)
                            love.graphics.circle("fill", p.x + p.cx, p.y + p.cy, 6)
                        end
                        if (not p.burst) then
                            p.burst = true
                            
                            local angle = r * 1
                            this:init_sparkburst(angle)
                            angle = r * 2
                            this:init_sparkburst(angle)
                            angle = r * 3
                            this:init_sparkburst(angle)
                            
                            love.graphics.setColor(1, 1, 1) -- not sure if needed
                        end
                    end
                })
            
            -- messy?
            this.start_teleport = false
            this.start_teleport_h = false

        end
        
        -- sprite stuff
        local anim_on_ground = this.vy >= 0 and this:is_solid(0, 1)
        local next_anim = "idle1"
        -- [to-do]:: bit messy?
        if this.current_anim == "idle2" or this.current_anim == "idle3" or this.current_anim == "idle4" then
            next_anim = this.current_anim
        elseif this.current_anim == "roll" then
            next_anim = this.idle_poses[this.anim_frame]
        end
        
        if this.conk > 0 then
            -- a different sprite is drawn after the big bounce
            if this.was_big_conk then
                next_anim = "conk"
            else
                next_anim = "jump2"
            end
        --elseif anim_on_ground and not this.was_on_ground then
        --    next_anim = "crouch"
        
        -- [to-do]:: magic numbers
        elseif not anim_on_ground then
            if this.down_attack and this.vy == 5 then
                next_anim = "dive2"
            elseif this.down_attack then
                next_anim = "dive1"
            elseif this.vy <= -0.7 then
                next_anim = "jump1"
            elseif this.vy >= 0.3 then
                next_anim = "jump3"
            else
                next_anim = "jump2"
            end
        elseif this.dash_time > 0 and this.vx == 0 then --whar
            next_anim = "crouch"
        elseif v_input == -1 then
            next_anim = "up"
        elseif v_input == 1 then
            next_anim = "crouch"
        -- [to-do]:: magic numbers
        elseif (this.current_anim == roll and math.abs(this.vx) >= 1.2) or (this.current_anim ~= roll and math.abs(this.vx) > 0.1) then
            next_anim = "roll"
        end

        if next_anim ~= this.current_anim then
            this.current_anim = next_anim
            this.anim_frame = 1
            this.anim_timer = 0
        end

        local anim = this.animations[this.current_anim]
        this.anim_timer = this.anim_timer + 1
        
        -- [to-do]:: add special logic for roll animations here ~

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
            
            if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
            
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
        camera.shake(1.5, 1.5, 2) -- TODO: probably don't want screenshake on every attack?
        
        if hb.telefrag then
            -- telefrag (sorta?)
            -- // mostly copied over from Lani's body slam)
            this.freeze = 6
            target.freeze = 6
            camera.shake(3, 3, 5)
            table.insert(particles_fg, {
                x = target:hmid(), y = target:vmid(),
                timer = 0,
                duration = 8,
                update = function(p)
                    p.timer = p.timer + 1
                    return p.timer >= p.duration
                end,
                draw = function(p)
                    local fade = 1 - (p.timer / p.duration)
                    local len = p.timer * 4
                    love.graphics.setColor(1, 1, 1, fade)
                    love.graphics.rectangle("fill", math.floor(p.x - len / 2), math.floor(p.y - 1), len, 2)
                    love.graphics.rectangle("fill", math.floor(p.x - 1), math.floor(p.y - len), 2, len * 2)
                    love.graphics.setColor(1, 1, 1, 1)
                end
            })
        end
    end,
    
    draw = function(this)
        if not this.active and this.stocks <= 0 then return end
        if this.respawn_timer > 0 then return end
        
        local isBlinking = this.invincible_timer > 0 and (math.floor(this.invincible_timer / 4) % 2 == 0 or debugEnabled)
        
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
