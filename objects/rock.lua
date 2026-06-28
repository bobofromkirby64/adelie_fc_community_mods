-- objects/rock.lua

rock = {
    name = "rock",
    init = function(this)
        this.connectionID = "rock_" .. math.floor(this.x) .. "_" .. math.floor(this.y)
        
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

        this.semisolid = true
        this.w = 8

        this.body_hitbox_lock = 0

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

        this.on_release = function(this, thrown)
            if not thrown then this.stop = true end
            this.thrown_timer = 25
            this.draw_offset_y = 0
        end
    end,   

    update = function(this)
        local ground_hit = this:is_solid(0, 1)
        local on_ground = ground_hit ~= false
        local on_semisolid = ground_hit and (ground_hit.type == "semisolid" or ground_hit.semisolid)

        if not this.held then
            this.thrown_timer = math.max(0, this.thrown_timer - 1)
            if this.thrown_timer == 0 then this.throwerID = nil end

            this.vx = util.appr(this.vx, 0, 0.2 or 0.18)

            if on_ground and this.vy > 0 then this.vy = 0 end
            local maxfall = 4
            if not on_ground then this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167) end

            this:move(this.vx, this.vy)
        end

        local hb_w, hb_h = this.hurtbox.w + (this.hurtbox.w / 2), this.hurtbox.h + (this.hurtbox.h / 2)
        local targetX = this.x + this.vx
        local targetY = this.y + this.vy
        local cx = targetX + this.hurtbox.x
        local cy = targetY + this.hurtbox.y
        local hb_x = cx - (hb_w / 4)
        local hb_y = cy - (hb_h / 4)
        local kb_mod = this.vy > 0 and 2 or 1
        if (math.abs(this.vx) > 0.2 or math.abs(this.vy) > 0.2) and not this.held then
            if not this.held and this.body_hitbox_lock <= 0 then
                this.body_hb = hitbox.create(this.thrown_timer > 0 and this.throwerID or this.connectionID, hb_x, hb_y, hb_w, hb_h, 2, util.sign(this.vx)*3, math.abs(util.sign(this.vy) * (1.25 * kb_mod) - (0.5 * kb_mod)) * -1, 2)
            end
        end
        if this.body_hitbox_lock > 0 then this.body_hitbox_lock = this.body_hitbox_lock - 1 end
    end,

    set_up_riders = function(this, riders)
        for _, o in ipairs(objects) do
            if o ~= this and o:bottom() >= this.y - 4 and o:bottom() <= this.y and o:left() <= this:right() and o:right() >= this:left() and o.type.name ~= "cloud" then
                table.insert(riders, o)
                if o.semisolid then
                    for _, p in ipairs(objects) do
                        if p ~= o and p:bottom() >= o.y - 4 and p:bottom() <= o.y and p:left() <= o:right() and p:right() >= o:left() and p.type.name ~= "cloud" then
                            table.insert(riders, p)
                        end
                    end
                end
            end
        end
    end,

    draw = function(this)
        if this.destroyed then return end
        
        love.graphics.setColor(1, 1, 1, 1)
        sprites.draw(sprites["objects/rock"], math.floor(this.x), math.floor(this.y + this.draw_offset_y))

        love.graphics.setColor(1, 1, 1, 1)
    end
}