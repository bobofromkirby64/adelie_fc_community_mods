-- objects/snowball.lua

snowball = {
    name = "snowball",
    init = function(this)
        this.connectionID = "snowball_" .. math.floor(this.x) .. "_" .. math.floor(this.y)
        
        this.hurtbox = {x = 0, y = 0, w = 8, h = 8}
        this.thrown_timer = 0
        this.held = false
        this.stop = false
        this.a = 0
        this.destroyed = false
        
        this.layer = -1
        this.freeze = 0
        
        this.draw_offset_y = 0 
        
        this.damage = 0
        this.hitstun = 0
        this.active = true
        
        this.hb = nil
        this.throwerID = nil 

        this.corner_correct = function(this_obj, dir_x, dir_y, side_dist, only_sign)
            only_sign = only_sign or 0
            if dir_x ~= 0 then
                for i = 1, side_dist do
                    for _, s in ipairs({1, -1}) do
                        if s ~= -only_sign then
                            if not this_obj:is_solid(dir_x, i * s) then
                                this_obj.x = this_obj.x + dir_x
                                this_obj.y = this_obj.y + i * s
                                return true
                            end
                        end
                    end
                end
            elseif dir_y ~= 0 then
                for i = 1, side_dist do
                    for _, s in ipairs({1, -1}) do
                        if s ~= -only_sign then
                            if not this_obj:is_solid(i * s, dir_y) then
                                this_obj.x = this_obj.x + i * s
                                this_obj.y = this_obj.y + dir_y
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end

        this.on_collide_x = function(this, stepX)
            if this.corner_correct(this, stepX, 0, 2, 1) then return true end

            if math.abs(this.vx) > 2 then
                this.vx = -this.vx * 0.5
            else
                this.vx = -this.vx
            end
            this.rem.x = 0
            this.freeze = 1
            return true
        end

        this.on_collide_y = function(this, stepY)
            if stepY > 0 then
                if this.vy >= 3.9 then
                    this.vy = -2
                elseif this.vy > 1.1 then
                    this.vy = -1
                else
                    this.vy = 0
                end
            else
                this.vy = 0
            end
            this.rem.y = 0
            if math.abs(this.vy) > 0 then
                love.audio.play("snowball_bounce", "static")
            end
            return true
        end

        this.on_release = function(this, thrown)
            if not thrown then this.stop = true end
            this.thrown_timer = 10
            this.draw_offset_y = 0
        end
    end,

    update = function(this)
        if this.freeze and this.freeze > 0 then
            this.freeze = this.freeze - 1
            return
        end

        if this:right() < stage.blastZone.l or this:left() > stage.blastZone.r or this:top() > stage.blastZone.b or this.x < -500 or this.y < -500 then
            this.destroyed = true
            if this.hb then
                this.hb.active = false
                this.hb = nil
            end
            for i, o in ipairs(objects) do
                if o == this then
                    table.remove(objects, i)
                    break
                end
            end
            return
        end
        
        if this.held then
            local is_actually_held = false
            for _, obj in ipairs(objects) do
                if obj.holding == this or obj.grapple_hit == this then
                    this.throwerID = obj.connectionID
                    is_actually_held = true
                    break
                end
            end
            if not is_actually_held then
                this.held = false
            end
            if this.hb then
                this.hb.active = false
                this.hb = nil
            end
        else
            this.thrown_timer = math.max(0, this.thrown_timer - 1)
            if this.thrown_timer == 0 then this.throwerID = nil end
             
            if this.stop then
                this.vx = util.appr(this.vx, 0, 0.125)
                if this.vx == 0 then this.stop = false end
            else
                if this.vx ~= 0 then
                    this.vx = util.appr(this.vx, util.sign(this.vx) * 2, 0.1)
                end
            end
            
            this.vy = util.appr(this.vy, 4, 0.4)
            
            this:move(this.vx, this.vy, this.on_collide_x, this.on_collide_y)
            
            this.a = this.a - 0.05 * util.sign(this.vx)

            if not this.destroyed then
                if this.hb and not this.hb.active then
                    if this.hb.duration > 0 then
                        this.stop = true
                        this.vx = this.vx * 0.25 
                        this.vy = -1.5 
                    end
                    this.hb = nil
                end
                local is_fast = math.abs(this.vx) >= 2 or math.abs(this.vy) >= 2

                if is_fast then
                    local dir = math.abs(this.vx) > 0.1 and util.sign(this.vx) or 1
                    local hx, hy, hw, hh = this.x, this.y, 8, 8
                    if this.vy >= 2 then
                        hy = this.y + 4
                        hh = 4
                    elseif math.abs(this.vx) >= 2 then
                        --hw = 4
                        hx = (this.vx > 0) and (this.x + 4) or (this.x - 4)
                        hy = this.y + 2
                        hh = 6
                    end
                    this.hb = hitbox.create(this.thrown_timer > 0 and this.throwerID or this.connectionID, hx, hy, hw, hh, 4, dir * 3.5, -1 + this.vy, 2)
                else
                    if this.hb then
                        this.hb.active = false
                        this.hb = nil
                    end
                end
            end
        end
    end,

    draw = function(this)
        if this.destroyed then return end
        
        love.graphics.setColor(1, 1, 1, 1)
        sprites.draw(sprites["objects/snowball"], math.floor(this.x), math.floor(this.y + this.draw_offset_y))
        
        for i = 1, 4 do
            local r_vals = {1.5, 2, 1.5, 2.75}
            local th_vals = {0.0, 0.2, 0.6, 0.8}
            local r = r_vals[i]
            local theta = this.a + th_vals[i]
            
            local angle = theta * math.pi * 2
            
            love.graphics.setColor(194/255, 195/255, 199/255, 1)
            love.graphics.rectangle("fill", 
                math.floor(this.x + 4 + r * math.cos(angle)), 
                math.floor(this.y + 4 + this.draw_offset_y - r * math.sin(angle)), 
                1, 1)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end
}