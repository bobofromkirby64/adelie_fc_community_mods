-- hitbox.lua
hitbox = {
    create = function(ownerID, x, y, w, h, damage, kx, ky, duration)
        local hb = {
            ownerID = ownerID,
            x = x,
            y = y,
            w = w,
            h = h,
            damage = damage,
            kx = kx,
            ky = ky,
            duration = duration,
            active = true
        }
        table.insert(hitboxes, hb)
        return hb
    end,

    updateAll = function()
        for i = #hitboxes, 1, -1 do
            local hb = hitboxes[i]
            hb.duration = hb.duration - 1
            
            if hb.duration <= 0 then
                hb.active = false
            else
                for _, obj in ipairs(objects) do
                    if obj.connectionID ~= nil and obj.connectionID ~= hb.ownerID and obj.invincible_timer == 0 and obj.respawn_timer == 0 and not obj.held then
                        local px = obj.x + obj.hurtbox.x
                        local py = obj.y + obj.hurtbox.y
                        local pw = obj.hurtbox.w
                        local ph = obj.hurtbox.h
                        if hb.x < px + pw and px < hb.x + hb.w and hb.y < py + ph and py < hb.y + hb.h then
                            obj.damage = obj.damage + hb.damage

                            local kx, ky = hb.kx, hb.ky
                            local k_mag = math.sqrt(kx * kx + ky * ky)

                            if k_mag > 0.01 then
                                local id = obj.connectionID
                                local h_input = (inputSource.getKeyDown(id, "right") and 1 or 0) - (inputSource.getKeyDown(id, "left") and 1 or 0)
                                local v_input = (inputSource.getKeyDown(id, "down") and 1 or 0) - (inputSource.getKeyDown(id, "up") and 1 or 0)
                                if h_input ~= 0 or v_input ~= 0 then
                                    -- input unit vec
                                    local i_mag = math.sqrt(h_input * h_input + v_input * v_input)
                                    local ix = h_input / i_mag
                                    local iy = v_input / i_mag
                                    -- tan(17.5)
                                    local di_scale = 0.31529879 * k_mag
                                    local di_kx = kx + ix * di_scale
                                    local di_ky = ky + iy * di_scale
                                    -- rescale
                                    local di_mag = 1e-6 + math.sqrt(di_kx * di_kx + di_ky * di_ky)
                                    kx = di_kx / di_mag * k_mag
                                    ky = di_ky / di_mag * k_mag
                                end
                            end

                            local scaling = 1 + (obj.damage / 125)
                            obj.vx = kx * scaling
                            obj.vy = ky * scaling
                            obj.hitstun = 15 + math.floor(math.min(50, obj.damage) / 10)
                            hb.active = false 
                            
                            love.audio.play(hb.hit_sfx or "hit", "static")

                            -- hit confirm
                            for _, attacker in ipairs(objects) do
                                if attacker.connectionID == hb.ownerID then
                                    if attacker.type.on_hit_confirm then
                                        attacker.type.on_hit_confirm(attacker, obj, hb)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if not hb.active then
                table.remove(hitboxes, i)
            end
        end
    end,

    drawAll = function()
        if debugEnabled then
            love.graphics.setColor(1, 0, 0, 0.5)
            for _, hb in ipairs(hitboxes) do
                love.graphics.rectangle("fill", hb.x, hb.y, hb.w, hb.h)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
}