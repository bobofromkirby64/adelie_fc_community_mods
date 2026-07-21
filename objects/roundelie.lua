-- objects/roundelie.lua
-- v0.6.1

-- Movement Documentation:
-- Z to jump, left and right arrow keys to move
-- X + Up causes a small midair "bounce" slightly smaller than a jump. 
--   Can be done up to 3 times before touching the ground
--   Was changed to have no cooldown between uses (but the parameter to adjust cooldown time was not removed)
-- X + Down causes roundelie to accelerate downward quickly while held
--   Has a top speed higher than the regular terminal velocity
--   Has a hitbox that pushes opponents downward, which may "trap" them as they fall
--     - There's a 1f delay before the hitbox comes out, and an initial burst of speed is applied after the delay
--     - The hitbox remains active as long as the input is held, or until roundelie collides a wall or with the ground
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
--   Has a hitbox that sends opponents in the direction held 1f after the teleport (not necessarily the teleport direction)
--      TODO: ^ I don't think this is actually true? I never switch input during or immediately after teleport but I regularly send opponent flying in the opposite direction
--   Roundelie is invulnerable for the first two frames of the teleport, and the hitbox is also active for those first two frames
--   There's a 3f delay before roundelie can act out of a teleport, e.g. buffering a grace-jump
-- Jump + Down lets roundelie fall through any semisolids it interacts with
--   Falling through semisolids which roundelie is standing on requires pressing jump, like other characters
-- Snowball interactions:
--   Roundelie can dive into a snowball to bounce off of it, and the resulting bounce is higher than a bounce off of the ground
--   Roundelie can teleport into a snowball to launch it in the direction that it's facing
--   Roundelie can knock a snowball into the air with the ground-slam/shockwave attack
--   Roundelie can stop a snowball from rolling either by diving into it or by knocking it into the air with the ground-slam

--[[
TODO: ((?) => "maybe")

(core/moveset)
    - shockwave/ground-slam rework
        - current range is too large for an attack that is immediately active, and it also extends past the edge of platforms in an unintuitive way
        - roundelie desperately wants a way to threaten space in front of it, and would also really benefit from another way to knock opponents horizontally that isn't the teleport
    - the combination of being able to cancel jump momentum with dive and being able to grace jump after cancelling out of jump with dive makes for some very silly movement; maybe experiment with having roundelie unable to interrupt a dive for the first few frames after input? or if we like the silly movement, we should at least make it so it's less of a mess of smoke when you press the dive button over and over
    - (?) extend dive hitbox (? maybe at a certain speed threshhold) so that e.g. it can trade with maddy dive rather than losing to it outright
    - (?) experiment with teleport knockback (imo current knockback doesn't really fit with the concept of a teleport, it should be a bit more chaotic or at least have variance relative to roundelie's position?)
    - (?) let roundelie influence horizontal speed slightly (but still not dive, teleport, or bjump) during conk state
    - ...
 
(visual)
    - redraw portraits for the other skins in the new style
    - experiment with alternative "teleport is on cooldown" effects
    - take another pass at the rosetta skin but more in the style of the gold skin (=> ball of stone that doesn't change shape) (and also experiment with the "square" idea)
    - sprite adjustments (mainly the idle poses, the "look up" pose, and the middle/transitional jump pose have been bugging me)
    - implement the first-frame roll anim for jump explicitly (atm it's just a side-effect of the current midair roll anim logic)
    - add skid/turn-around effect for roll
    - use inflate pose when grace jumping out of a dive bounce
    - (?) for the statue/gold skin, idle1 sprite looks strange after ending a roll => use the upright roll sprite instead of idle1 out of a roll, or have idle poses for diff orientations that aren't just the roll poses
    - (?) take another pass at the teleport vfx (mainly want to experiment with replacing the bulk of the "single-pixel" particles with sprites)
    - (?) clean up spritesheets
    - (?) add a "tumble" anim after a long enough fall
        - mainly because the "falling" jump pose looks strange when it's been out for too long
        - could try reusing the roll but a transition pose might be needed? but could also maybe reuse a different sprite for that, like of the jump sprites and just rotate it, maybe?
        - NOTE: roll looks strange, for this; can revisit later
    - (?) experiment with adding alternate/random conk poses (could reuse the roll sprites...)
    - (?) experiment with adding fill color to sprites for sadface/tears/sroundelie during hitstun
    - (?) upside-down crouch :3
    - (?) sweat drops for empty bjump (out of uses)
    - ...

(other)
    - sfx pass (shockwave/ground-slam, teleport, unique sounds for roundelie in general)
    - ...
]]--

roundelie = {
    name="roundelie",
    init = function(this, skin)
        this.connectionID = nil
        
        local player_skins = {
            {sprites["characters/roundelie_1"], {1,1,1,1}}, -- roundelie (default)
            {sprites["characters/roundelie_2"], {1,1,1,1}}, -- delaughter (purple/red)
            {sprites["characters/roundelie_3"], {1,1,1,1}}, -- statue (golden)
            {sprites["characters/roundelie_4"], {1,1,1,1}}, -- ancient monument (from rosetta)
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
        
        this.grace = 0
        this.jbuffer = 0
        this.bjump = 2
        this.dash_time = 0
        
        this.p_jump = false
        this.p_dash = false
        this.is_start_of_jump = false  -- => is roundelie starting a jump or bjump (up+x)
        this.was_on_ground = false
        this.was_big_conk = false
        this.should_draw_dive_vfx = false
        
        this.teleport_info = {
            init = false,       -- true if teleport has started (=> flag used to trigger vfx)
            horizontal = false, -- true if teleport has an input direction (i.e. not a neutral input)
            on_hit = false      -- true if teleport has hit the opponent
        }
        this.teleport_hb  = nil  -- hitbox created by left/right+x and neutral+x attacks
        -- hitboxes created by diving (down+x) into the ground
        this.divebomb_slam_hb  = nil
        this.divebomb_shockwave_l_hb = nil
        this.divebomb_shockwave_r_hb = nil
        
        this.animations = {
            idle1 = {frames = {1},  speed = 1},  -- upright
            idle2 = {frames = {14}, speed = 1},  -- right (CW 90 degrees)
            idle3 = {frames = {15}, speed = 1},  -- upside-down
            idle4 = {frames = {16}, speed = 1},  -- left (CW 270 degrees)
            roll = {frames = {10, 2, 3, 4}, speed = 3}, -- up -> right -> down -> left ...
            jump1 = {frames = {11}, speed = 1},  -- inflate
            jump2 = {frames = {12}, speed = 1},  --
            jump3 = {frames = {5}, speed = 1},   --
            dive1 = {frames = {9}, speed = 1},   -- down+x pose
            dive2 = {frames = {13}, speed = 1},  -- down+x pose *when large shockwave will be created upon landing
            crouch = {frames = {6}, speed = 1},
            up = {frames = {7}, speed = 1},
            conk = {frames = {8}, speed = 1},    -- disoriented used for after down+x collides with ground and creates a large shockwave
        }
        this.idle_poses = { "idle1", "idle2", "idle3", "idle4" }
        this.idle_poses_idx = 1
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
        this.dive_start = 0
        this.dive_smoketrail = 0
        this.dribble_window = 0
        
        this.prev_x = 0
        this.prev_y = 0
        this.prev_vx = 0
        this.prev_vy = 0
        this.prev_facing = 1
        
        this.check_snowballs = function(this)
            if this.hitstun > 0 then return end
            for _, o in ipairs(objects) do
                if o.type and o.type.name == "snowball" and not o.destroyed and not o.held then
                    -- check for collision with the snowball in the path of the dive to determine whether to draw the dive's smoke-trail effect
                    if (this.should_draw_dive_vfx and this.dive_start == 3 and this.dribble_window > 0) then -- TODO: "dive_start == 3" is a messy check
                        local h_input = (inputSource.getKeyDown(this.connectionID, "right") and 1 or 0) - (inputSource.getKeyDown(this.connectionID, "left") and 1 or 0)
                        local temp_x = this.x
                        local temp_y = this.y
                        -- roundelie's position is temporarily updated in order to make use of the existing `bottom`, `right`, etc. functions
                        this.x = this.x + 2 * this.vx + (3 * h_input)  -- bit hacky, but works well enough to determine whether roundelie is going to bounce on top of a snowball
                        this.y = this.y + 2 * this.vy + 8              -- ^
                        snowball_collision_check = this:bottom() <= o:top() + 4 and this:bottom() >= o:top() and this:top() <= o:bottom() and this:left() <= o:right() and this:right() >= o:left()
                        this.should_draw_dive_vfx = this.should_draw_dive_vfx and (not (snowball_collision_check))
                        -- reset position
                        this.x = temp_x
                        this.y = temp_y
                    end
                    
                    if (this.divebomb_slam_hb and this.divebomb_slam_hb.active and
                        this.divebomb_slam_hb.x < o:right() and o:left() < this.divebomb_slam_hb.x + this.divebomb_slam_hb.w and
                        this.divebomb_slam_hb.y < o:bottom() and o:top() < this.divebomb_slam_hb.y + this.divebomb_slam_hb.h) then
                        -- dive-bomb quake launches snowball
                        o.vy = this.divebomb_slam_hb.big_dive_slam and -2.75 or -2.0
                        o.throwerID = this.connectionID
                        o.thrown_timer = 10
                        o.stop = true
                        
                    elseif o.throwerID ~= this.connectionID and this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                        local function snap()
                            this:move(0, o.y-8-this.y)
                            if this:right() >= o:left() and this:left() <= o:right() and this:bottom() >= o:top() and this:top() <= o:bottom() then
                                this:move(0, this.y+8-o.y)
                            end
                        end
                        
                        if this.dash_time > 0 then
                            -- teleport into snowball
                            o.vx = 5.15 * this.facing  -- teleport is stronger than maddy dash => should launch snowball with higher speed
                            o.vy = -1.75
                            o.stop = false
                            o.throwerID = this.connectionID
                            o.thrown_timer = 10
                            love.audio.play("zap", "static")
                            this.teleport_info.on_hit = true
                            
                        elseif ((this.down_attack and this.conk == 0) or this.vy > 0) and this:bottom() <= o:top() + 4 then
                            snap()
                            this.bjump = 2
                            
                            -- dive into snowball
                            if this.down_attack then
                                -- TODO: probably a bit messy to have code repeated here when it's basically just copy-pasted from the update function...
                                if (this.prev_vy == 4.5 and this.dive_start == 0) then
                                    -- big bounce
                                    this.vy = -3.75 - 0.75  -- snowball is bouncy => dive bounce should rebound higher than it would off the ground
                                    this.was_big_conk = true
                                    this.conk = 10
                                    o.vy = -2.25
                                    o.vx = o.vx * 0.5
                                else
                                    -- small bounce
                                    this.vy = -2.0 - 0.75
                                    this.conk = 8
                                    o.vy = -1.75
                                    o.vx = o.vx * 0.75
                                end
                                
                                this.dive_smoketrail = 0
                                this.down_attack = false
                                this.vx = 0.15 * this.conk * this.conkdir
                                love.audio.play("maddy_jump", "static")
                                
                                o.stop = true
                                o.throwerID = this.connectionID
                                o.thrown_timer = 10
                                
                            -- bounce on top of snowball
                            else
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
        end
        
        -- (( honestly this was a whole lot of work for a not-very-interesting effect LOL ))
        -- (( granted it was a fun learning experience for working with particles but I won't be sad if it's replaced ))
        -- TODO: experiment with a new effect using sprites for the particles (similar to how smoke is drawn)
        this.draw_teleport_vfx = function(this)
            
            local prev_x, prev_y = this.prev_x, this.prev_y
            this.teleport_info.init = false
            
            -- (1) poof out / start-point
            if this.teleport_info.horizontal then
                -- (( commented out the entire effect for now since it's a bit of a mess ))
                -- TODO: either rework the afterimage sprites to behave more like the existing smoke, OR
                --  experiment with "stencil" to have the afterimage smoke effect and existing smoke combine a bit more neatly
                game.init_smoke(prev_x, prev_y)
            end
            -- if this.teleport_info.horizontal then
                -- local d = 3--5  -- base distance to draw smoke from the center of the circle
                -- local n = 2--3  -- split circle into `n` partitions
                -- local r = 2 * math.pi / n  -- radians
                
                -- for i = 1, n do
                    -- local angle = (i * r)  + (2 * math.pi * math.random()) * 0.3
                    -- game.init_smoke(prev_x + math.sin(angle) * d, prev_y + math.cos(angle) * d + 1)
                -- end
            
                -- -- after-image formed in smoke
                -- table.insert(
                    -- particles_fg, {
                        -- x = prev_x,
                        -- y = prev_y,
                        -- cx = this.hurtbox.x + (this.hurtbox.w / 2),
                        -- facing = this.facing,
                        -- timer = 0,
                        -- duration = 15,
                        
                        -- update = function(p)
                            -- p.timer = p.timer + 1
                            -- return p.timer >= p.duration
                        -- end,
                        
                        -- draw = function(p)
                            -- local frame = math.floor(p.timer / p.duration * 3 - 0.4) + 1
                            -- if frame < 1 then frame = 1 end
                            -- if frame > 3 then frame = 3 end
                            -- love.graphics.setColor(1, 1, 1)
                            -- -- TODO: might be able to use a stencil to prevent the standard smoke from covering the after-image on the first two frames?
                            -- sprites.draw(sprites["characters/roundelie_teleport_afterimage"][frame], p.x + p.cx, p.y, 0, p.facing, 1, p.cx, 0)
                        -- end
                    -- })
            -- end
            
            -- (2) pop in / end-point
            local cx = this.hurtbox.x + (this.hurtbox.w / 2)
            local cy = this.hurtbox.y + (this.hurtbox.h / 2) - 1
            
            local n = 3  -- split circle into `n` partitions
            local r = 2 * math.pi / n -- radians
            
            -- groups of randomly distributed "spark" particles
            for i = 1, n do
                -- each group has a base angle within equal partitions of a circle centered on the teleport hitbox
                for i = 1, 7 do
                    local angle = (i * r) + (2 * math.pi * math.random() * 0.5)  -- angle is further randomized for each particle
                    -- (( ty @meep @lazydevs on youtube for the refs, lol ))
                    table.insert(
                        particles_fg, {
                            x = this.x + cx,
                            y = this.y + cy,
                            vx = math.sin(angle),
                            vy = math.cos(angle),
                            speed = 3.5 + math.random(8,14) * 0.095,  -- magnitude for movement vector
                            drag = 0.5,  -- i.e. deceleration applied on each tick
                            
                            timer = 0,
                            duration = 7 + math.random(0, 3),
                            
                            tp_info = this.teleport_info,
                            on_hit_flag = false,
                            
                            update = function(p)
                                if p.timer > 0 and (not p.on_hit_flag) and p.tp_info.on_hit then
                                    p.on_hit_flag = true
                                    p.speed = p.speed * 1.35  --
                                    p.drag  = p.drag * 1.35   --
                                end
                                p.x = p.x + p.vx * p.speed
                                p.y = p.y + p.vy * p.speed
                                p.vx = p.vx * p.drag
                                p.vy = p.vy * p.drag
                                
                                p.timer = p.timer + 1
                                return p.timer >= p.duration
                            end,
                            
                            draw = function(p)
                                local fade = 1 - (p.timer / (p.duration + (p.duration/2)))
                                local scalar = 1.95
                                love.graphics.setColor(1, 1, 1, 1)
                                
                                if p.timer <= 2 then  -- meant to match up with initial "burst" (white circle drawn over the hitbox for 1f)
                                    love.graphics.setColor(1, 1, 1, 1)
                                else
                                    -- TODO: messy, and I don't think the "scalar" is doing what I think it's' doing...
                                    if p.on_hit_flag then
                                        love.graphics.setColor((255*fade*scalar)/255, (156*fade*scalar)/255, (39*fade*scalar)/255, 1)
                                    else
                                        love.graphics.setColor((229*fade*scalar)/255, (229*fade*scalar)/255, (229*fade*scalar)/255, fade)
                                    end
                                end
                                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), 1, 1)
                                if p.on_hit_flag then
                                    love.graphics.setColor((255*fade*scalar)/255, (116*fade*scalar)/255, (39*fade*scalar)/255, 1)
                                else
                                    love.graphics.setColor((215*fade*scalar)/255, (215*fade*scalar)/255, (215*fade*scalar)/255, fade)
                                end
                                if p.timer >= 1 and (p.x - p.vx * p.speed >= 1.5) then
                                    love.graphics.rectangle("fill", math.floor(p.x - p.vx * p.speed), math.floor(p.y - p.vy * p.speed), 1, 1)
                                    if (p.x - p.vx * p.speed >= 3.5) then
                                        love.graphics.rectangle("fill", math.floor(p.x - p.vx * p.speed - ((p.vx / p.drag) * p.speed)), math.floor(p.y - p.vy * p.speed - ((p.vy/p.drag) * p.speed)), 1, 1)
                                    end
                                end
                                love.graphics.setColor(1, 1, 1, 1)
                            end
                        })
                end
            end
            
            -- smoke and initial burst frame(s)
            table.insert(
                particles_fg, {
                    x = this.x,
                    y = this.y,
                    cx = this.hurtbox.x + (this.hurtbox.w / 2),
                    cy = this.hurtbox.y + (this.hurtbox.h / 2),
                    timer = 0,
                    duration = 3,
                    draw_smoke = true,
                    
                    update = function(p)
                        p.timer = p.timer + 1
                        return p.timer >= p.duration
                    end,
                    
                    draw = function(p)
                        -- smoke
                        if p.draw_smoke and p.timer >= 2 then -- slight delay before drawing smoke so that the smoke at the startpoint dissipates first
                            -- TODO: probably shouldn't have particles creating other particles?
                            local d = 2  -- base distance to draw smoke from the center of the circle
                            local n = 2  -- split circle into `n` partitions
                            local r = 2 * math.pi / n  -- radians
                            
                            for i = 1, n do
                                local angle = (i * r)  + (2 * math.pi * math.random()) * 0.3
                                game.init_smoke(p.x + math.sin(angle) * d, p.y + math.cos(angle) * d + 1)
                            end
                            p.draw_smoke = false
                        end
                        
                        -- initial burst
                        if p.timer <= 2 then
                            love.graphics.setColor(1, 1, 1)
                            -- hitbox is size 10x10 and centered on roundelie => 12-diameter circle fits well enough
                            love.graphics.circle("fill", p.x + p.cx, p.y + p.cy, 6)
                        end
                    end
                })
        end
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
        
        --
        if this.dribble_window > 0 then
            this.dribble_window = this.dribble_window - 1
        end
        if this.conk > 1 then this.dribble_window = 0; elseif this.conk == 1 then this.dribble_window = 8; end  -- messy?
        
        -- # of ticks until roundelie is able to act after bouncing
        if this.conk > 0 then
            this.conk = this.conk - 1
        end
        
        -- # of ticks after starting a dive before roundelie is able to perform a big bounce
        if this.dive_start > 0 then
            this.dive_start = this.dive_start - 1
        end
        
        -- dive vfx
        if this.dive_smoketrail > 0 then
            this.dive_smoketrail = this.dive_smoketrail - 1
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
                this.bjump = 2
                this.hitstun = 0
                this.invincible_timer = 60
                this.dash_cooldown = 0
                this.bump_cooldown = 0
                
                if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
                if this.divebomb_slam_hb then this.divebomb_slam_hb.active = false; this.divebomb_slam_hb = nil end
                if this.divebomb_shockwave_l_hb then this.divebomb_shockwave_l_hb.active = false; this.divebomb_shockwave_l_hb = nil end
                if this.divebomb_shockwave_r_hb then this.divebomb_shockwave_r_hb.active = false; this.divebomb_shockwave_r_hb = nil end
            end
            return
        end
        
        -- update dynamic hitboxes
        local hb = this.divebomb_slam_hb
        -- divebomb slam is active near the ground for the first 2 frames, then pieces of the ground shoot out for the next 3 frames
        --  and the hitbox travels upward with the ground pieces
        if hb and hb.active and hb.duration <= 3 then
            if hb.duration == 3 then
                hb.y = hb.y - 5  -- hitbox suddenly grows to the height of a full tile on tick 3
                hb.h = hb.h + 4
            elseif hb.duration == 2 then
                hb.y = hb.y - 3
                hb.h = hb.h - 4
                hb.kx = hb.kx / 2  -- knockback is significantly weaker on ticks 4 and 5
                hb.kx = hb.ky / 2
            elseif hb.duration == 1 then
                hb.y = hb.y - 2
                hb.h = hb.h - 3
                hb.kx = hb.kx / 2
                hb.kx = hb.ky / 2
            end
        end
        hb = this.divebomb_shockwave_l_hb
        if hb and hb.active then
            hb.vx = util.appr(hb.vx, 1.0, 0.3)
            util.appr(this.vy, 3, 0.15)
            hb.x = hb.x - hb.vx -- - 2.5
            hb.y = hb.h == 8 and hb.y or hb.y - 0.8
            hb.h = util.appr(hb.h, 8, 0.8)
        end
        hb = this.divebomb_shockwave_r_hb
        if hb and hb.active then
            hb.vx = util.appr(hb.vx, 1.0, 0.3)
            hb.x = hb.x + hb.vx -- + 2.5
            hb.y = hb.h == 8 and hb.y or hb.y - 0.8
            hb.h = util.appr(hb.h, 8, 0.8)
        end
        
        --
        this.prev_facing = this.facing
        
        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
        -- hitstun (set by hitbox.lua)
        if this.hitstun > 0 then
            this.dash_time = 0
            this.hitstun = this.hitstun - 1
            this.vy = util.appr(this.vy, 3, 0.15)
            this.vx = util.appr(this.vx, 0, 0.143)
            
            if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
            if this.divebomb_slam_hb then this.divebomb_slam_hb.active = false; this.divebomb_slam_hb = nil end
            if this.divebomb_shockwave_l_hb then this.divebomb_shockwave_l_hb.active = false; this.divebomb_shockwave_l_hb = nil end
            if this.divebomb_shockwave_r_hb then this.divebomb_shockwave_r_hb.active = false; this.divebomb_shockwave_r_hb = nil end
        else
            
            local jump_btn = inputSource.getKeyDown(id, "b1")
            local dash_btn = inputSource.getKeyDown(id, "b2")
            
            local jump = jump_btn and not this.p_jump
            local dash = dash_btn and not this.p_dash and this.dash_cooldown == 0
            local bump = dash_btn and (not this.p_dash) and this.bump_cooldown == 0
            this.p_jump = jump_btn
            this.p_dash = dash_btn
            this.is_start_of_jump = jump or bump
            
            local ground_hit = this:is_solid(0, 1)
            local on_ground = ground_hit ~= false
            local on_semisolid = ground_hit and (ground_hit.type == "semisolid" or ground_hit.semisolid)
            
            if on_ground and not this.was_on_ground and not this.down_attack then
                -- down_attack (dive) already creates smoke when it lands, so no need to draw extra
                game.init_smoke(this.x, this.y + 4)
            end
            
            -- weird semisolid fall through
            if on_semisolid and v_input == 1 and not (this.was_on_ground) and jump_btn then --very hacky fix and I don't like it but I don't want to edit the move function since it breaks interoperability (would be very easy though). Maybe better fix? Or at least a hacky fix that's identical to the ideal case
                if not this:is_solid(0, 1, true) then
                    this.y = this.y + 1
                    on_ground = false
                    jump = false
                    this.jbuffer = 0
                    this.vy = this.prev_vy
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
                -- dive -> bounce off of the ground
                if this.down_attack then
                    this.dive_smoketrail = 0
                    this.down_attack = false
                    this.conkdir = (h_input == 1 or (h_input == 0 and this.facing == 1)) and -1 or 1
                    
                    -- dive-bomb ground-slam attack and follow-up shockwave ...
                    local check_is_big_slam = this.prev_vy == 4.5 and this.dive_start == 0
                    local cx = this.hurtbox.x + (this.hurtbox.w / 2)
                    local hb_x, hb_w
                    if check_is_big_slam then
                        hb_x, hb_w = (this.x + cx - 18) + (-1.0 * this.conkdir) + (3.0 * h_input), 36
                        this.conk = 10
                        this.was_big_conk = true
                        this.vy = -3.75
                        camera.shake(2, 2, 4)
                    else
                        hb_x, hb_w = (this.x  + cx - 12) + (-0.75 * this.conkdir) + (1.75 * h_input), 24
                        this.conk = 9
                        this.vy = -2.0
                    end
                    
                    -- ground can be composed of multiple platforms
                    --   => we need to find the left-most and right-most platforms within the attack range
                    local platform_left, platform_right = ground_hit, ground_hit
                    -- find left-most platform
                    while hb_x < platform_left.x do
                        local new_platform = this:is_solid(platform_left.x - this.x - this.hurtbox.w - 1, 1)
                        if new_platform then platform_left = new_platform; else break; end
                    end
                    -- find right-most platform
                    while (hb_x + hb_w) > (platform_right.x + platform_right.w) do
                        local new_platform = this:is_solid(platform_right.x + platform_right.w - this.x + this.hurtbox.w + 1, 1)
                        if new_platform then platform_right = new_platform; else break; end
                    end
                    
                    -- the ground-slam hitbox is constrained to the size of the ground roundelie is diving into, + 1/2 the width of a tile
                    local prev_hb_x = hb_x
                    hb_x = math.max(hb_x, platform_left.x - 4)
                    hb_w = math.min((prev_hb_x + hb_w - hb_x), (platform_right.x + platform_right.w + 4) - hb_x)
                    
                    if check_is_big_slam then
                        this.divebomb_slam_hb = hitbox.create(this.connectionID, hb_x, this.y + 4, hb_w, 4, 3, -2 * this.conkdir, -4, 5)
                        this.divebomb_slam_hb.big_dive_slam = true
                        -- shockwaves
                        -- id, x, y, w, h, dmg, kbx, kby, duration
                        this.divebomb_shockwave_l_hb = hitbox.create(this.connectionID, this.x, this.y + 7, 3, 1, 1, -2.0, -1.5, 12)
                        this.divebomb_shockwave_l_hb.vx = 3.5
                        this.divebomb_shockwave_r_hb = hitbox.create(this.connectionID, this.x + 3, this.y + 7, 3, 1, 1,  2.0, -1.5, 12)
                        this.divebomb_shockwave_r_hb.vx = 3.5
                    else
                        this.divebomb_slam_hb = hitbox.create(this.connectionID, hb_x, this.y + 4, hb_w, 4, 2, -2 * this.conkdir, -3, 2)
                        this.divebomb_slam_hb.small_dive_slam = true
                        if h_input == -1 then
                            this.divebomb_shockwave_l_hb = hitbox.create(this.connectionID, this.x, this.y + 7, 3, 1, 1, -2.0, -1.5, 12)
                            this.divebomb_shockwave_l_hb.vx = 2.5
                        elseif h_input == 1 then
                            this.divebomb_shockwave_r_hb = hitbox.create(this.connectionID, this.x + 3, this.y + 7, 3, 1, 1,  2.0, -1.5, 12)
                            this.divebomb_shockwave_r_hb.vx = 2.5
                        end
                    end
                    
                    -- draw placeholder visual over hitbox
                    -- TODO: actual vfx will be pieces shooting out from the ground with colors picked from the stage fg
                    --  (see https://love2d.org/wiki/ImageData:getPixel)
                    table.insert(
                        particles_fg, {
                            hb = this.divebomb_slam_hb,  -- ref to table -> particle has access to updated values
                            
                            update = function(p)
                                return (not (p.hb and p.hb.active))
                            end,
                            
                            draw = function(p)
                                love.graphics.setColor(1, 0, 0, 0.5)
                                love.graphics.rectangle("fill", p.hb.x, p.hb.y, p.hb.w, p.hb.h)
                                love.graphics.setColor(1, 1, 1, 1)
                            end
                        })
                    -- temp
                    table.insert(
                        particles_fg, {
                            hb_l = this.divebomb_shockwave_l_hb,  -- ref to table -> particle has access to updated values\
                            hb_r = this.divebomb_shockwave_r_hb,  -- ^
                            
                            update = function(p)
                                return (not (p.hb_l and p.hb_l.active)) and (not (p.hb_r and p.hb_r.active))
                            end,
                            
                            draw = function(p)
                                love.graphics.setColor(1, 1, 0, 0.6)
                                if p.hb_l and p.hb_l.active then
                                    love.graphics.rectangle("fill", p.hb_l.x, p.hb_l.y, p.hb_l.w, p.hb_l.h)
                                end
                                if p.hb_r and p.hb_r.active then
                                    love.graphics.rectangle("fill", p.hb_r.x, p.hb_r.y, p.hb_r.w, p.hb_r.h)
                                end
                                love.graphics.setColor(1, 1, 1, 1)
                            end
                        })
                    
                    -- draw smoke over ground-slam hitbox
                    game.init_smoke(hb_x - 1, this.divebomb_slam_hb.y + 1)
                    game.init_smoke(hb_x + hb_w - 6, this.divebomb_slam_hb.y + 1)
                    
                    local step_count = math.floor((hb_w - 4) / 8)
                    local base_amt = math.floor((hb_w - 4) / step_count)
                    local leftover = (hb_w - 4) % step_count
                    
                    local curr_x = (hb_x - 1)
                    for i = 1, step_count - 1 do
                        curr_x = curr_x + base_amt + (i <= leftover and 1 or 0)
                        game.init_smoke(curr_x, this.divebomb_slam_hb.y + 1)
                    end
                end
                if this.vy < 0 then
                    this.bump_cooldown = 0;
                    love.audio.play("maddy_clip", "static")
                end
                this.grace = 6
                this.bjump = 2
            elseif this.grace > 0 then
                this.grace = this.grace - 1
            end
            
            if this.dash_time > 0 then
                if this.dash_time == 2 then  -- TODO: messy
                    this.freeze = 3  -- half of the value applied on-hit
                    this.teleport_hb = hitbox.create(this.connectionID, (this.x  - 1), (this.y  - 1), 10, 10, 3, 5 * this.facing, 0, 2)
                    this.teleport_hb.telefrag = true
                    this.teleport_hb.hit_sfx = "zap"  -- generic "crit" sfx used for big hits, e.g. Lani's tipper and body slam
                    this.vx = 0
                end
                this.dash_time = this.dash_time - 1
                this.vx = 0
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
                if not this.down_attack then 
                    -- dive has a 1f delay before the hitbox comes out and an initial burst of speed after the delay
                    this.freeze = 1
                    this.vy = util.appr(this.vy, 4.5, 1.95)
                    
                    -- a bit hacky, but this helps prevent the smoke-trail effect from being drawn when roundelie starts diving right before bouncing (e.g., while dribbling or wall-climbing)
                    this.should_draw_dive_vfx = this.dribble_window == 0 or
                                                (not ((this:is_solid(this.vx + (h_input * 3), this.vy)) or
                                                      (this.p_jump and (not this:is_solid(this.vx, this.vy + 4, true))) or
                                                      (this:is_solid(this.vx, this.vy + 4))))
                    this.dive_start = 3  -- currently set to line up with the dive smoke-trail effect
                else
                    -- the dive hitbox remains active as long as the input (down+x) is held
                    hitbox.create(this.connectionID, hb_x, hb_y, hb_w, hb_h, 1, util.sign(this.vx), 4.5, 2)
                    this.vy = util.appr(this.vy, 4.5, 0.60)
                    if this.dive_smoketrail > 0 then game.init_smoke(this.x, this.y) end
                end

                this.down_attack = true
                this.was_big_conk = false
                this.conkdir = (h_input == 1 or (h_input == 0 and this.facing == 1)) and -1 or 1  -- needs to be kept updated for snowball logic
                
                -- dive -> bounce off of a wall
                if (this:is_solid(-3,0) or this:is_solid(3,0)) then
                    this.conk = 8
                    this.dive_smoketrail = 0
                    this.vy = -2.0
                    game.init_smoke(this.x - this.conkdir * 6, this.y)  -- same as maddy wall-jump
                end
            else
                this.down_attack = false
            end
            if this.conk > 0 then
                this.vx = 0.15 * this.conk * this.conkdir
            elseif v_input == -1 and bump and this.bjump > 0 then
                this.bump_cooldown = 0 --TODO: different from main branch, update documentation and code neatness if you want to keep
                this.vy = -3.0
                love.audio.play("maddy_nodash", "static")
                if this.bjump >= 1 then
                    game.init_smoke(this.x, this.y)
                    this.bjump = this.bjump - 1
                end
            elseif dash then
                if v_input == 0 then
                    this.dash_time = 2
                    this.dash_cooldown = 31
                    this.invincible_timer = 2
                    this.vx = 32 * h_input
                    this.teleport_info.init = true
                    this.teleport_info.horizontal = h_input ~= 0
                    this.teleport_info.on_hit = false
                end
                
                love.audio.play("maddy_dash", "static")
            end
            this.was_on_ground = on_ground
            this.prev_x = this.x  -- need to keep track of original position for some visual effects drawn after movement/collision is calculated
            this.prev_y = this.y  --
            this.prev_vx = this.vx
            this.prev_vy = this.vy -- part of the hacky semisolid fix
        end
        
        this:move(this.vx, this.vy)
        this:check_snowballs()
        
        -- teleport vfx
        if this.teleport_info.init then
            this:draw_teleport_vfx()
        end
        
        -- dive vfx
        if this.should_draw_dive_vfx then
            this.dive_smoketrail = 3
            game.init_smoke(this.prev_x, this.prev_y - 4)
            love.audio.play("maddy_downdash", "static")  -- TODO: placeholder
            this.should_draw_dive_vfx = false
        end
        
        -- sprite stuff
        local anim_on_ground = this.vy >= 0 and this:is_solid(0, 1)
        local next_anim = this.idle_poses[this.idle_poses_idx]
        
        -- TODO: I have a feeling putting this here is making it messier but I need to look into it a bit more
        if this.current_anim == "roll" then
           
            if this.prev_facing ~= this.facing then
                -- when roundelie's direction changes mid-roll, the flipped sprite makes the "right" rolling pose becomes "left", and vice versa
                -- i.e. [up->right->down->left] becomes [up->left->down->right]
                if this.anim_frame == 2 then this.anim_frame = 4 elseif this.anim_frame == 4 then this.anim_frame = 2 end  -- TODO: messy
            end
            this.idle_poses_idx = this.anim_frame
            next_anim = this.idle_poses[this.idle_poses_idx]
            
        elseif this.prev_facing ~= this.facing and (this.current_anim == "idle2" or this.current_anim == "idle4") then
            -- also need to account for current pose being idle for the roll orientation issue (related `TODO` at the start of this conditional block)
            if this.idle_poses_idx == 2 then this.idle_poses_idx = 4 elseif this.idle_poses_idx == 4 then this.idle_poses_idx = 2 end   -- TODO: messy
        end
        
        if this.hitstun > 0 then
            -- animations are paused during hitstun
            next_anim = this.current_anim
        elseif this.conk > 0 then
            if this.was_big_conk then next_anim = "conk" else next_anim = "jump2" end
        elseif not anim_on_ground then
            if this.down_attack then 
                next_anim = (this.vy == 4.5 and "dive2" or "dive1")
            elseif (this.is_start_of_jump or this.current_anim == "jump1") and this.vy <= -0.7 then
                -- "inflate" pose is only drawn after a jump or bjump (up+x)
                next_anim = "jump1"
            -- roll continues in midair, but stops if roundelie isn't moving quickly enough in the same direction
            elseif this.current_anim == "roll" and ((this.prev_facing == 1 and this.vx >= 1.0) or (this.prev_facing == -1 and this.vx <= -1.0)) then
                -- TODO: buffer/first-frame jump => roll animation plays instead of inflate for the jump
                --       need to implement this explicitly rather than have it exist as a side-effect of the current midair roll logic
                next_anim = "roll"
            elseif this.vy >= 0.3 then
                next_anim = "jump3"
            else
                -- bit hacky? point is to avoid getting knocked into the air and have sprites quickly change from jump3->jump2->jump3 after hitstun ends
                next_anim = this.current_anim ~= "jump3" and "jump2" or "jump3"
            end
        elseif v_input == -1 then
            next_anim = "up"
        elseif v_input == 1 then
            next_anim = "crouch"
        elseif (this.current_anim == roll and math.abs(this.vx) >= 1.2) or (this.current_anim ~= roll and math.abs(this.vx) > 0.1) then
            next_anim = "roll"
        end

        if next_anim ~= this.current_anim then
            if next_anim ~= "roll" and next_anim ~= "idle2" and next_anim ~= "idle3" and next_anim ~= "idle4" then  -- TODO: messy
                -- `idle_poses_idx` is used to keep track of roundelie's orientation
                -- but whenever a sprite that is NOT an idle or rolling pose is drawn, then the current orientation resets to the default (upright) position
                this.idle_poses_idx = 1
                
            end
            
            this.current_anim = next_anim
            
            if next_anim == "roll" then
                this.anim_frame = this.idle_poses_idx  -- starting frame of the roll anim is determined by roundelie's orientation
                -- speeding up the animation immediately after direction changes helps the roll appear more natural
                this.anim_timer = (this.prev_facing ~= this.facing) and math.floor(this.animations[next_anim].speed / 2) or 0
            else
                this.anim_frame = 1
                this.anim_timer = 0
            end
        end

        local anim = this.animations[this.current_anim]
        -- animations are paused during hitstun
        if this.hitstun == 0 then this.anim_timer = this.anim_timer + 1 end
        
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
            if this.divebomb_slam_hb then this.divebomb_slam_hb.active = false; this.divebomb_slam_hb = nil end
            if this.divebomb_shockwave_l_hb then this.divebomb_shockwave_l_hb.active = false; this.divebomb_shockwave_l_hb = nil end
            if this.divebomb_shockwave_r_hb then this.divebomb_shockwave_r_hb.active = false; this.divebomb_shockwave_r_hb = nil end
            
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
        -- the large shockwave already applies camera shake
        if (not hb.big_dive_slam) then camera.shake(1.5, 1.5, 2) end
        
        if hb.big_dive_slam then
            --target.freeze = 2
        elseif hb.small_dive_slam then
            --target.freeze = 1
        elseif hb.telefrag then
            this.teleport_info.on_hit = true
            
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
            
            this.freeze = 6
            target.freeze = 6
            camera.shake(3, 3, 5)
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
            love.graphics.setShader(paletteSwapShader)
            if this.skin == 3 then
                -- eyes swap from default (gold) -> "deactivated" (dark blue)
                paletteSwapShader:send("color_find", {203/255, 136/255, 4/255, 1.0})
                paletteSwapShader:send("color_replace", {29/255, 43/255, 83/255, 1.0})    
            elseif this.skin == 4 then
                -- ...
                paletteSwapShader:send("color_find", {171/255, 82/255, 54/255, 1.0})
                paletteSwapShader:send("color_replace", {255/255, 119/255, 168/255, 1.0})
            else
                -- TODO: swap out placeholder effect
                paletteSwapShader:send("color_find", {255/255, 163/255, 0/255, 1.0})
                paletteSwapShader:send("color_replace", {95/255, 87/255, 79/255, 1.0})
            end
            
        end
        
        if this.skin == 3 then
            -- roundelie's face and belly for the statue (gold) skin are drawn on top of a "base" sprite that does not flip
            local base_spr = sprites[ this.current_anim == "crouch" and "characters/roundelie_3_base_crouch" or "characters/roundelie_3_base_default" ]
            sprites.draw(base_spr, this.x + cx, this.y, 0, 1, 1, cx, 0)
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
