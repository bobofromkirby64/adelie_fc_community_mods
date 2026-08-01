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
    - add min delay between bjump uses
        (spamming input should still work to buffer bjumps, but it'll feel better if every bjump gains some height)
    - the combination of being able to cancel jump momentum with dive and being able to grace jump after cancelling out of jump with dive makes for some very silly movement; maybe experiment with having roundelie unable to interrupt a dive for the first few frames after input? or if we like the silly movement, we should at least make it so it's less of a mess of smoke when you press the dive button over and over
    - (?) experiment with teleport knockback (imo current knockback doesn't really fit with the concept of a teleport, it should be a bit more chaotic or at least have variance relative to roundelie's position?)
    - (?) let roundelie influence horizontal speed slightly (but still not dive, teleport, or bjump) during conk state
    - (?) small speed boost when starting a roll or when changing roll direction
    - (?) slight bounce off of the ground after landing a midair roll at max fall-speed
 
(visual)
    - * rosetta skin rework
    - draw dust cloud for gold skin on landing
    - gold skin needs SOMETHING for inflate equivalent effect
    - fix rolling infinitely into a wall (lol)
    - (?) upside-down crouch :3
        need a new sprite for crouch; squash pose can (probably?) be flipped
    - (?) experiment with 8x16 width sprite for crouch
    - update orientation for different poses, e.g. dive should set orientation to DOWN
    - draw dust cloud at the start of a roll as well as when a roll changes directions
    - experiment with using an anim to smoothly transition to the fall/jump3 pose, rather than have it entirely speed based
    - experiment with adding an anim to transition to the look up pose from different orientations
    - * roll animation should be tied to speed, both vx and vy
    - midair roll should continue until roll is at an orientation that will transition smoothly into the fall pose
        i.e. shouldn't go from DOWN -> fall, it should roll back to upright position first
    - small teleport changes
        roundelie should disappear completely while invulnerable
        roundelie should exit teleport in inflate pose
    - (?) take another pass at teleport vfx
        picturing sparks with bolts shooting between them for on-hit
        + a much more explicit poof of smoke for the standard effect
            (can also experiment with drawing an after-image in the origin point smoke, again, but this time using stencil?)
    - (?) use squash anim to transition out of crouching in more situations
        (e.g. from diff orientations of idle pose -> look up)
    - (?) experiment with drawing sadface/tears/sroundelie during hitstun
    - (?) experiment with sweat drops for empty bjump (out of uses)
        (could also use the "tears" effect for this, in addition to the sweat drops)
    - ...

(other)
    - * audio bugs
        - diving when on the ground shouldn't play a sound effect, and similarly sound effects should only play when the action is performed
        - sfx should play on action, not queue when there's multiple sound effects in a row e.g. when dribbling
    - * sfx pass (shockwave/ground-slam, teleport, unique sounds for roundelie in general)
    - ...
]]--

roundelie = {
    name="roundelie",
    init = function(this, skin)
        this.connectionID = nil
        
        local player_skins = {
            {sprites["characters/roundelie_1"], { 29/255,  43/255,  83/255, 1}}, -- roundelie (default)
            {sprites["characters/roundelie_2"], {126/255,  37/255,  83/255, 1}}, -- delaughter (purple/red)
            {sprites["characters/roundelie_3"], {255/255,  29/255,   0/255, 1}}, -- statue (golden)
            -- TODO: rosetta skin is broken until it's reworked
            {sprites["characters/roundelie_4"], {1,1,1,1}}, -- ancient monument (from rosetta)
        }
        
        this.spritesheet, this.base_color = unpack(player_skins[tonumber(skin)])
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
        this.is_first_frame_jump = false  -- is roundelie jumping off the ground on the first possible tick after landing
        this.was_on_ground = false
        this.was_big_conk = false
        this.was_big_fall = false
        this.should_draw_dive_vfx = false
        
        this.teleport_info = {
            init = false,       -- true if teleport has started (=> flag used to trigger vfx)
            horizontal = false, -- true if teleport has an input direction (i.e. not a neutral input)
            on_hit = false      -- true if teleport has hit the opponent
        }
        this.teleport_hb  = nil  -- created by left/right+x and neutral+x attack
        this.shockwave_hb = nil  -- hitbox created by diving (down+x attack) into the ground
        
        this.animations = {
            idle1 =  {frames = {1}, speed = 1},  -- upright
            idle2 =  {frames = {2}, speed = 1},  -- facing right (CW 90)
            idle3 =  {frames = {3}, speed = 1},  -- upside-down
            idle4 =  {frames = {4}, speed = 1},  -- facing left (CCW 90)
            crouch = {frames = {5}, speed = 1},  --
            up =     {frames = {6}, speed = 1},  -- looking up
            -- sprite is rotated by frame_idx * 90 degrees, and base sprite is facing left, so animation => facing up -> right -> down -> left
            roll  =  {frames = {7, 7, 7, 7}, speed = 3},
            jump1 =  {frames = {8}, speed = 1},  -- rising
            jump2 =  {frames = {9}, speed = 1},  --
            jump3 =  {frames = {10}, speed = 1}, -- falling
            dive1 =  {frames = {11}, speed = 1}, --
            dive2 =  {frames = {12}, speed = 1}, -- "fast" dive; used when landing will cause a big ground-slam
            conk =   {frames = {13}, speed = 1}, -- disoriented; used during big bounce
            squash = {frames = {14}, speed = 1}, -- 
            squash_big = {frames = {5, 14}, speed = 5}, -- used when landing at max fall-speed
            -- ^ a bit hacky; with landing_window == 8 and (anim) speed == 5, each pose is held for 4 (not 5) frames
        }
        this.directions = { UP = 1, RIGHT = 2, DOWN = 3, LEFT = 4 }
        this.orientation = this.directions.UP
        this.idle_poses = { "idle1", "idle2", "idle3", "idle4" }
        this.current_anim = this.idle_poses[1]
        this.anim_frame = 1
        this.anim_timer = 0
        this.is_squishy = not ((this.skin == 3) or (this.skin == 4))
        this.sprite_rotation = 0
        
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
        this.landing_window = 0
        this.inflate_timer = 0
        
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
                    
                    if (this.shockwave_hb and this.shockwave_hb.active and
                        this.shockwave_hb.x < o:right() and o:left() < this.shockwave_hb.x + this.shockwave_hb.w and
                        this.shockwave_hb.y < o:bottom() and o:top() < this.shockwave_hb.y + this.shockwave_hb.h) then
                        -- shockwave launches snowball
                        o.vy = this.shockwave_hb.shockwave_large and -2.75 or -2.0
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
        
        -- 
        this.init_dust_cloud = function(x, y, direction)
            table.insert(particles_fg, {
                x = x + (direction == -1 and 1 or 8),
                y = y,
                vx = 0.18 * direction,
                vy = -0.1 - love.math.random() * 0.2,
                timer = 1,
                duration = 12,  -- 4f, animated on 3s => 1-3-3-3
                flipX = direction,
                update = function(p)
                    p.x = p.x + p.vx
                    p.y = p.y + p.vy
                    p.timer = p.timer + 1
                    if p.timer >= p.duration then
                        return true
                    end
                end,
                draw = function(p)
                    local frame = math.floor(p.timer / p.duration * 4) + 1
                    if frame > 4 then frame = 4 end
                    local dx, dy = math.floor(p.x), math.floor(p.y)
                    sprites.draw(sprites["characters/roundelie_dust_cloud"][frame], dx, dy, 0, p.flipX, 1, 4, 0)
                end,
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
        
        -- tracks a specified # of ticks after roundelie lands (used for sprite anim logic)
        if this.landing_window > 0 then
            this.landing_window = this.landing_window - 1
        end
        
        -- anim timer for window to draw the "inflate" sprite
        -- TODO: messy?
        if this.inflate_timer > 0 then
            this.inflate_timer = this.inflate_timer - 1
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
                if this.shockwave_hb then this.shockwave_hb.active = false; this.shockwave_hb = nil end
            end
            return
        end
        
        --
        this.prev_facing = this.facing
        this.is_start_of_jump = false
        this.is_first_frame_jump = false
        
        local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
        local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
        -- hitstun (set by hitbox.lua)
        if this.hitstun > 0 then
            this.dash_time = 0
            this.hitstun = this.hitstun - 1
            this.vy = util.appr(this.vy, 3, 0.15)
            this.vx = util.appr(this.vx, 0, 0.143)
            
            if this.teleport_hb then this.teleport_hb.active = false; this.teleport_hb = nil end
            if this.shockwave_hb then this.shockwave_hb.active = false; this.shockwave_hb = nil end
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
                    -- shockwaves
                    -- TODO: still need sfx for the shockwave (probably don't want on-hit sfx)
                    -- TODO: probably should experiment with making the shockwave smaller, and also not extend as far into the air e.g. when you bounce near the edge of a platform
                    if this.prev_vy == 4.5 and this.dive_start == 0 then
                        this.shockwave_hb = hitbox.create(this.connectionID, (this.x - 25) + (-5 * this.conkdir), this.y + 4, 60, 4, 3, -2 * this.conkdir, -4, 2)
                        this.shockwave_hb.shockwave_large = true
                        this.conk = 10
                        this.was_big_conk = true
                        this.vy = -3.75
                        camera.shake(2, 2, 4)
                    else
                        this.shockwave_hb = hitbox.create(this.connectionID, (this.x - 15) + (-5 * this.conkdir), this.y + 4, 40, 4, 2, -2 * this.conkdir, -3, 2)
                        this.shockwave_hb.shockwave_small = true
                        this.conk = 9
                        this.vy = -2.0
                    end
                    --
                    for i = 5, this.shockwave_hb.w - 5, 10 do
                        game.init_smoke(this.shockwave_hb.x + i, this.shockwave_hb.y + 2)  --could be better
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
                    this.is_start_of_jump = true
                    this.inflate_timer = 10
                    
                    if (not this.was_on_ground) and this:is_solid(0, 1) then this.is_first_frame_jump = true; end
                    
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
                this.is_start_of_jump = true
                this.inflate_timer = 10
                this.bump_cooldown = 0  --TODO: different from main branch, update documentation and code neatness if you want to keep
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
        
        
        -- apply updates
        this:move(this.vx, this.vy)
        this:check_snowballs()
        
        
        -- check if roundelie has landed on a platform
        -- (has to happen after movement is calculated so that animations are accurate)
        local anim_on_ground = false
        if this.hitstun == 0 and this.vy >= 0 and this:is_solid(0, 1) then
            anim_on_ground = true
            if (not this.was_on_ground) then
                game.init_smoke(this.x, this.y + 4)
                
                if this.prev_vy >= 3 then
                    this.was_big_fall = true
                    this.landing_window = 8
                else
                    this.was_big_fall = false
                    this.landing_window = 4
                end
            end
        end
        
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
        
        -- update sprite pose orientation
        if this.current_anim == "roll" then
            this.orientation = this.anim_frame
        end
        
        if this.prev_facing ~= this.facing then
            -- TODO: messy
            if (anim_on_ground and math.abs(this.vx) >= 0.2 and this.current_anim ~= "squash" and v_input ~= 1) then
                this.init_dust_cloud(this.x, this.y + 1, -1 * this.facing)
            end
            
            if this.orientation == this.directions.RIGHT then
                this.orientation = this.directions.LEFT
            elseif this.orientation == this.directions.LEFT then
                this.orientation = this.directions.RIGHT
            end
        end
        
        -- select sprite pose
        local next_anim
        
        if this.hitstun > 0 and this.current_anim ~= "crouch" and this.current_anim ~= "squash" and this.current_anim ~= "squash_big" then
            -- animations are paused during hitstun
            next_anim = this.current_anim
        elseif not anim_on_ground then
            if this.conk > 0 and this.was_big_conk then
                -- during big bounce
                if this.is_start_of_jump or (this.current_anim == "jump1" and this.inflate_timer > 0) then
                    next_anim = "jump1"
                else
                    next_anim = "conk"
                end
            elseif this.down_attack and this.dribble_window == 0 then
                -- dive / down attack
                next_anim = (this.vy == 4.5) and "dive2" or "dive1"
            elseif this.is_start_of_jump then
                --
                if this.current_anim ~= "jump1" and this.is_first_frame_jump and math.abs(this.vx) >= 1.5 then
                    next_anim = "roll"
                else
                    next_anim = "jump1"
                end
            elseif this.current_anim == "jump1" and this.vy <= -0.7 then
                -- inflate (at the start of a jump/bump) -> jump (rising)
                next_anim = "jump1"
            elseif this.current_anim == "roll" and math.abs(this.vx) >= 1.0 then
                -- roll (midair)
                next_anim = "roll"
            else
                -- default midair pose (jump/fall)
                this.orientation = this.directions.UP
                next_anim = this.vy < 0.3 and "jump2" or "jump3"
            end
        --
        else
            --
            if this.current_anim == "crouch" and v_input ~= 1 then
                next_anim = "squash"
            elseif v_input == 1 then
                this.orientation = this.directions.UP
                if this.current_anim == "squash" or this.current_anim == "crouch" then
                    next_anim = "crouch"
                else
                    next_anim = "squash"
                end
            elseif this.landing_window > 0 and this.is_squishy and this.current_anim ~= "roll" then
                this.orientation = this.directions.UP
                next_anim = (this.was_big_fall or this.current_anim == "squash_big") and "squash_big" or "squash"
            elseif (this.current_anim == "roll" and (math.abs(this.vx) >= 1.0 or h_input == 1 or h_input == -1)) or (this.current_anim ~= "roll" and math.abs(this.vx) > 0.5) then
                next_anim = "roll"
            elseif v_input == -1 and this.orientation == this.directions.UP then
                next_anim = "up"
            else
                next_anim = this.idle_poses[this.orientation]
            end
        end
        
        if this.landing_window > 0 and anim_on_ground and (next_anim ~= "squash" and next_anim ~= "squash_big") then this.landing_window = 0; end
        
        -- update current animation
        if next_anim ~= this.current_anim then
            this.current_anim = next_anim
            
            if next_anim == "roll" then
                this.anim_frame = this.orientation
                -- speed up the animation immediately after changing direction to help the roll appear more natural
                this.anim_timer = (this.prev_facing ~= this.facing) and math.floor(this.animations[next_anim].speed / 2) or 0
            else
                this.anim_frame = 1
                this.anim_timer = 0
            end
        end
        
        if this.hitstun == 0 then this.anim_timer = this.anim_timer + 1 end  -- animations are paused during hitstun
        
        local anim = this.animations[this.current_anim]
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
            if this.shockwave_hb then this.shockwave_hb.active = false; this.shockwave_hb = nil end
            
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
        if (not hb.shockwave_large) then camera.shake(1.5, 1.5, 2) end
        
        if hb.shockwave_large then
            -- TODO: add on-hit vfx for both shockwaves
            --   I'm picturing something like, picking colors from the stage fg underneath the opponent (or roundelie?) and sending debris particles in the direction of the knockback?
            --   https://love2d.org/wiki/ImageData:getPixel
            
            --target.freeze = 2
        elseif hb.shockwave_small then
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
        local cx, cy = this.hurtbox.x + (this.hurtbox.w / 2), 4
        local rotation = (this.current_anim == "roll") and math.rad(this.facing * this.anim_frame * 90) or 0
        
        -- apply palette swaps
        if isBlinking then
            love.graphics.setShader(whiteShader)
            love.graphics.setColor(1, 1, 1)
        elseif this.dash_cooldown > 0 then
            love.graphics.setShader(paletteSwapShader)
            if this.skin == 3 then
                -- eyes swap from default (gold) -> "activated" (white)
                paletteSwapShader:send("color_find",    {203/255, 136/255,   4/255, 1.0})
                paletteSwapShader:send("color_replace", {255/255, 255/255, 255/255, 1.0})
            elseif this.skin == 4 then
                -- TODO: replace placeholder effect
                paletteSwapShader:send("color_find",    {171/255,  82/255,  54/255, 1.0})
                paletteSwapShader:send("color_replace", {255/255, 119/255, 168/255, 1.0})
            else
                local r, g, b = unpack(this.base_color)
                local tint = this.skin == 1 and 1.25 or 0.95
                r, g, b = r * tint, g * tint, b * tint
                -- ref: https://stackoverflow.com/questions/13328029/how-to-desaturate-a-color
                --      https://en.wikipedia.org/wiki/Grayscale#Luma_coding_in_video_systems
                local L = 0.299 * r + 0.587 * g + 0.114 * b  -- calculate luma using standard human-eye luminance weights (BT.601)
                local f = 0.20  -- => 20% desaturation
                paletteSwapShader:send("color_find", this.base_color)
                paletteSwapShader:send("color_replace", {(r + f * (L - r)), (g + f * (L - g)), (b + f * (L - b)), 1.0})
            end
            
        end
        
        if this.skin == 3 then
            -- roundelie's face and belly for the statue (gold) skin are drawn on top of a "base" sprite that does not flip
            local base_spr = sprites[ this.current_anim == "crouch" and "characters/roundelie_3_base_crouch" or "characters/roundelie_3_base_default" ]
            sprites.draw(base_spr, this.x + cx, this.y, 0, 1, 1, cx, 0)
        end
        
        -- TODO: messy
        if this.is_squishy and this.current_anim == "jump1" and this.inflate_timer > 0 and this.inflate_timer <= 8 then
            local spr = this.skin == 1 and "characters/roundelie_1_inflate" or "characters/roundelie_2_inflate"
            sprites.draw(sprites[spr], this.x + cx, this.y + cy, rotation, this.facing, 1, cx + 1, cy + 1)
        else
            sprites.draw(this.spr, this.x + cx, this.y + cy, rotation, this.facing, 1, cx, cy)
        end
        
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
