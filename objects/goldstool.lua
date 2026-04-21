goldstool = {
    name = "goldstool",
    init = function(this, skin, owner)
        this.connectionID = "goldstool_" .. math.floor(this.x) .. "_" .. math.floor(this.y)

        local player_skins = {
                sprites["objects/goldstool_1"], -- gold
                sprites["objects/goldstool_2"], -- lapis
                sprites["objects/goldstool_3"], -- emerald
                sprites["objects/goldstool_4"], -- amethyst
            }

        this.spritesheet = player_skins[skin]
        this.skin = skin
        this.spr = this.spritesheet[4]

        this.owner = owner

        this.hurtbox = {x = 1, y = 0, w = 6, h = 8}
        this.wings_were_active = false
        this.body_was_active = false
        this.w = 6
        this.semisolid = true
        this.collides = true
        this.flying = false
        this.was_flying = false
        this.flystarttimer = 0
        this.flylock = 0
        this.step = 0
        this.held = false

        this.wings_timer = 0
        this.body_timer = 0

        this.animations = {
            idle = {frames = {1}, speed = 1},
            flying = {frames = {2}, speed = 1},
            flystart = {frames = {4, 3}, speed = 4}
        }
        this.current_anim = "idle"
        this.anim_frame = 1
        this.anim_timer = 0
        this.layer = -1

        this.was_on_ground = false
        this.was_colliding = false
    end,

    update = function(this)  
        local ground_hit = this:is_solid(0, 1)
        local on_ground = ground_hit ~= false
        local on_semisolid = ground_hit and (ground_hit.type == "semisolid" or ground_hit.semisolid)

        -- check for oob
        if this:oob() then
            this.flying = true
            this.was_flying = true
            this.flystarttimer = 0
            this.collides = false
            this.x = this.owner.x
            this.y = stage.blastZone.b
            this.was_colliding = false
        end

        -- check for flystarttimer
        if this.flying then
            if this.was_flying == false then
                this.flystarttimer = 6
                this.was_flying = true
            end
        else
            this.was_flying = false
        end

        -- check for finish flying
        if this.flying then
            if this.flystarttimer <= 0 then
                if ground_hit and this.was_colliding == false then
                    this.was_colliding = true
                elseif ground_hit == false and this.was_colliding == true then
                    if this.flylock <= 0 then
                        this.flying = false
                        this.collides = true
                    end
                    this.was_colliding = false
                end
            else
                this.flystarttimer = this.flystarttimer - 1
            end
        end

        -- Decrement flylock
        if this.flylock > 0 then
            this.flylock = this.flylock - 1
        end

        -- friction
        this.vx = util.appr(this.vx, 0, 0.2 or 0.18)

        if this.flying and this.flystarttimer <= 0 then
            this.vy = util.appr(this.vy, -3.5, 0.25)
        else
            if on_ground and not this.was_on_ground then
            game.init_smoke(this.x, this.y + 4)
            end

            if on_ground and this.vy > 0 then
                this.vy = 0
            end

            local maxfall = 2.6
            if not on_ground then
                this.vy = util.appr(this.vy, maxfall, math.abs(this.vy) > 0.124 and 0.334 or 0.167)
            end
        end

        this.was_on_ground = on_ground

        -- Set Up Riders
        local px = this.x
        local py = this.y
        local riders = {}
        for _, o in ipairs(objects) do
            if o ~= this and o:bottom() >= this.y - 4 and o:bottom() <= this.y and o:left() <= this:right() and o:right() >= this:left() then
                table.insert(riders, o)
            end
        end

        -- damage stuff
        -- Movement damage
        if (math.abs(this.vx) > 0.2 or math.abs(this.vy) > 0.2) and not this.held and this.owner then
            if this.body_was_active then
                this.body_timer = 0
                this.body_was_active = false
            end
            if this.body_timer % 3 == 0 then
                hitbox.create(this.owner.connectionID, this.x + this.hurtbox.x,  this.y + this.hurtbox.y, this.hurtbox.w, this.hurtbox.h, 2, util.sign(this.vx) * 3 + 1, util.sign(this.vy) * 2 - 1, 4)
            end
            this.body_timer = this.body_timer + 1
        end
        -- Wing Damage
        if(this.flying and this.flystarttimer <= 0) then
            if not this.wings_were_active then
                hitbox.create(this.owner.connectionID, this.x + this.hurtbox.x - 6,  this.y + this.hurtbox.y, this.hurtbox.w, this.hurtbox.h, 2, 3, 2, 4)
                hitbox.create(this.owner.connectionID, this.x + this.hurtbox.x + 6,  this.y + this.hurtbox.y, this.hurtbox.w, this.hurtbox.h, 2, 3, 2, 4)
                this.wings_timer = 0
                this.wings_were_active = true
            elseif this.wings_timer % 3 == 0 then
                hitbox.create(this.owner.connectionID, this.x + this.hurtbox.x - 6,  this.y + this.hurtbox.y, this.hurtbox.w, this.hurtbox.h, 2, 3, 2, 4)
                hitbox.create(this.owner.connectionID, this.x + this.hurtbox.x + 6,  this.y + this.hurtbox.y, this.hurtbox.w, this.hurtbox.h, 2, 3, 2, 4)
            end
            this.wings_timer = this.wings_timer + 1
        else
            this.wings_were_active = false
        end

        -- Move stool
        if this.flying and this.flystarttimer <= 0 then
            this:moveWithoutCollide(this.vx, this.vy)
        elseif not this.held then
            this:move(this.vx, this.vy)
        end

        -- Move riders
        local dx = this.x - px
        local dy = this.y - py
        for _, r in ipairs(riders) do
            r:move(dx, dy)
        end

        

        -- sprite stuff

        local next_anim = "idle"
        if this.flystarttimer > 0 then
            next_anim = "flystart"
        elseif this.flying then
            next_anim = "flying"
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
    end,

    draw = function(this)
        local anim = this.animations[this.current_anim]
        local frame_idx = anim.frames[this.anim_frame]
        this.spr = this.spritesheet[frame_idx]
        local cx = this.hurtbox.x + (this.hurtbox.w)

        sprites.draw(this.spr, this.x + 1, this.y - 1, 0, 1, 1, cx, 0)
    end
}