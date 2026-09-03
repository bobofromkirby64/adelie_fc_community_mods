-- https://www.love2d.org/wiki/General_math
-- TODO: probably should throw these into util?
local function clamp(low, n, high) return math.min(math.max(low, n), high) end
local function lerp(a, b, t) return (1 - t) * a + t * b end

--[[
TODO: ((?) => "maybe", (*) => "high priority")
    - * modify all characters to improve interactions with moving platforms
        - stepstools will need to be updated later, after slimeguy pushes his changes
    - * add option for curved path (=> cubic bezier func)
        - blocking for cc_hillzone
        - might need alternate ease in/out calc for this?
    - cleaner init
    - (?) support for arbitrary # of waypoints
    - ...
--]]

moving_platform = {
    name = "moving_platform",
    
    init = function(this, w)
        this.is_solid = function() return false end
        this.hurtbox = {x=0, y=0, w=w, h=0}
        this.w = w
        this.semisolid = true
        --
        this.sprite = nil
        
        -- platform moves from a -> b -> a ... on repeat
        this.ax, this.ay = this.x, this.y
        this.bx, this.by = this.x, this.y
        
        this.movement_duration = 60     -- time (in ticks) for platform to move between pts
        this.movement_timer = 0         -- tracks # ticks for duration
        this.movement_delay = 30        -- time (in ticks) for platform to pause at destination before resuming movement
        this.movement_delay_timer = 0   -- tracks # ticks for delay
        this.movement_smoothing = false -- if true, apply smoothstep calc to ease in and out of movement
        
    end,
    update = function(this)
        
        local px, py = this.x, this.y
        local riders = {}
        for _, o in ipairs(objects) do
            if o ~= this and o:bottom() == this.y - 1 and o:left() <= this:right() and o:right() >= this:left() then
                table.insert(riders, o)
                
                if o.set_up_riders then  -- support for goldstool
                    o.set_up_riders(o, riders)
                end
            end
        end
        
        local target_x, target_y
        
        if this.movement_timer < this.movement_duration then
            local t = clamp(0.0, this.movement_timer / this.movement_duration, 1.0)
            if this.movement_smoothing then
                t = t * t * (3 - 2 * t)
            end
            target_x = lerp(this.ax, this.bx, t)
            target_y = lerp(this.ay, this.by, t)
            
            this.movement_timer = this.movement_timer + 1
            
        elseif this.movement_delay_timer < this.movement_delay then
            this.movement_delay_timer = this.movement_delay_timer + 1
            target_x, target_y = this.bx, this.by
        else
            this.movement_timer = 1
            this.movement_delay_timer = 0
            
            this.rem.x, this.rem.y = 0, 0
            this.x, this.y = this.bx, this.by
            target_x, target_y = this.x, this.y
            
            -- swap directions
            local temp_x, temp_y = this.ax, this.ay
            this.ax, this.ay = this.bx, this.by
            this.bx, this.by = temp_x, temp_y
        end
        
        -- rounding is needed to avoid more jittery movement at pt B compared to at pt A
        local dx = math.floor(target_x + 0.5) - px
        local dy = math.floor(target_y + 0.5) - py
        
        -- need to update rem here to avoid loss of precision
        this.rem.x = target_x - px - dx
        this.rem.y = target_y - py - dy
        
        -- update the platform
        this:move(dx, dy)
        
        -- update riders
        dx = this.x - px
        dy = this.y - py
        for _, r in ipairs(riders) do
            r:move(dx, dy)
        end
    end,
    draw = function(this)
        
        if this.sprite then
            sprites.draw(this.sprite, math.floor(this.x), math.floor(this.y))
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.rectangle("fill", math.floor(this.x), math.floor(this.y), this.w, 3)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
}
