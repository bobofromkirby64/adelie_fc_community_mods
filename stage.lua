-- stage.lua
require("objects/cloud")
cc_clouds = function(r, g, b)
    for i = 1, 32 do
        table.insert(particles_bg, {
            x = math.random() * 240,
            y = math.random() * 135,
            spd = (1 + math.random() * 4) * 0.5,
            w = 32 + math.random() * 32,
            c = {r, g, b},
            update = function(p)
                p.x = p.x + p.spd
                if p.x > 240 then
                    p.x = -p.w
                    p.y = math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                local h = math.max(1, math.floor(16 - p.w * 0.1875))
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), math.floor(p.w), h)
                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

cc2_clouds = function(flat, r, g, b)
    for i = 1, 32 do
        table.insert(flat and particles_fg or particles_bg, {
            x = math.random() * 240,
            y = flat and GAME_HEIGHT + 4 or math.random() * 135,
            spd = (1 + math.random() * 4) * 0.25,
            size = 16 + math.random() * 32,
            big = (i % 2 == 0),
            c = {r, g, b},
            flat = flat,
            update = function(p)
                p.x = p.x + p.spd
                if p.x > 260 then
                    p.x = -p.size
                    p.y = p.flat and GAME_HEIGHT + 4 or math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                love.graphics.arc("fill", math.floor(p.x), math.floor(p.y), p.size / 3, math.pi, math.pi * 2)

                if p.big then
                    love.graphics.arc("fill", math.floor(p.x) - p.size / 3, math.floor(p.y), p.size / 5, math.pi, math.pi * 2)
                    love.graphics.arc("fill", math.floor(p.x) + p.size / 3, math.floor(p.y), p.size / 6, math.pi, math.pi * 2)
                end

                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

cc_snowflakes = function()
    for i = 1, 47 do
        table.insert(particles_fg, {
            x = math.random() * 240,
            y = math.random() * 135,
            s = math.floor(math.random() * 1.25),
            spd = (0.25 + math.random() * 5) * 0.5,
            off = math.random(),
            c = math.random() < 0.5 and {194/255, 195/255, 199/255} or {255/255, 241/255, 232/255},
            update = function(p)
                p.x = p.x + p.spd
                p.y = p.y - math.sin(p.off * math.pi * 2)
                p.off = p.off + math.min(0.05, (p.spd * 2) / 32) * 0.5
                if p.x > 244 then
                    p.x = -4
                    p.y = math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.s + 1, p.s + 1)
                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end

cc2_snowflakes = function()
    for i = 1, 47 do
        table.insert(particles_fg, {
            x = math.random() * 240,
            y = math.random() * 135,
            s = math.floor(math.random() * 2),
            spd = (0.25 + math.random() * 5) * 0.5,
            off = math.random(),
            c = {255/255, 241/255, 232/255},
            update = function(p)
                p.x = p.x + p.spd
                p.y = p.y - math.sin(p.off * math.pi * 2)
                p.off = p.off + math.min(0.05, (p.spd * 2) / 32) * 0.5
                if p.x > 244 then
                    p.x = -4
                    p.y = math.random() * 135
                end
            end,
            draw = function(p)
                love.graphics.setColor(p.c)
                if p.s < 1 then
                    love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), 1, 1)
                else
                    love.graphics.rectangle("fill", math.floor(p.x) - 1, math.floor(p.y), 3, 1)
                    love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y) - 1, 1, 3)
                end
                love.graphics.setColor(1, 1, 1, 1)
            end
        })
    end
end
make_cog = function(x, y, flip_x)
    table.insert(particles_fg, {
        x = x - 2,
        y = y - 2,
        flip_x = flip_x,
        update = function(p) end,
        draw = function(p)
            local anim_offset = p.flip_x and 1 or 0
            local frame = (math.floor(frameCounter / 2) + anim_offset) % 4 + 1
            local sx = p.flip_x and -1 or 1
            local ox = p.flip_x and 16 or 0
            sprites.draw(sprites["stages/tinker_cog"][frame], p.x, p.y, 0, sx, 1, ox, 0)
        end
    })
end

make_flag = function(x, y, flip_x)
    local f = {
        x = x,
        y = y,
        flip_x = flip_x,
        secret = false,
        update = function(p) end,
        draw = function(p)
            local anim_offset = p.flip_x and 1 or 0
            local frame = (math.floor(frameCounter / 4) + anim_offset) % 3 + (p.secret and 4 or 1)
            local sx = p.flip_x and -1 or 1
            local ox = p.flip_x and 16 or 0
            sprites.draw(sprites["stages/summit_flag"][frame], p.x, p.y, 0, sx, 1, ox, 0)
        end
    }
    table.insert(particles_fg, f)
    return f
end

stage = {
    platforms = {},

    layouts = {
        function()
            stage.name = "lava field"

            stage.addPlatform(72, 100, 96, 28, "solid")
            stage.addPlatform(104, 60, 32, 4, "semisolid")
            stage.addPlatform(66, 75, 28, 4, "semisolid")
            stage.addPlatform(146, 75, 28, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/bf_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/bf_fg.png")

            stage.bgColor = nil
            stage.bgShader = lavaShader
        end,
        function()
            stage.name = "final iceberg"

            stage.addPlatform(72, 100, 96, 28, "solid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/fd_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/fd_fg.png")

            stage.bgColor = nil
            stage.bgShader = auroraShader
        end,
        function()
            stage.name = "temple of roundelie"

            stage.addPlatform(72, 96, 96, 14, "solid")
            stage.addPlatform(80, 110, 80, 18, "solid")
            stage.addPlatform(88, 66, 64, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/adetemple_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/adetemple_fg.png")

            stage.bgColor = nil
            stage.bgShader = sunsetShader
        end,
        -- tinker
        function()
            stage.name = "tinker tower"

            stage.addPlatform(72, 100, 96, 32, "solid")
            stage.addPlatform(72, 68, 24, 4, "semisolid")
            stage.addPlatform(144, 68, 24, 4, "semisolid")

            stage.addPlatform(56, 100, 16, 4, "semisolid")
            stage.addPlatform(168, 100, 16, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/tinker_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/tinker_fg.png")

            stage.bgColor = nil
            stage.bgShader = steampunkShader

            make_cog(125, 106)
            cc_snowflakes()
        end,
        -- summit from foreverred
        function()
            stage.name = "everred peak"

            stage.addPlatform(56, 127, 8, 24, "solid")
            stage.addPlatform(64, 119, 16, 32, "solid")

            stage.addPlatform(96, 111, 8, 40, "solid")
            stage.addPlatform(104, 87, 8, 64, "solid")
            stage.addPlatform(112, 79, 16, 72, "solid")
            stage.addPlatform(128, 95, 8, 56, "solid")
            stage.addPlatform(136, 119, 8, 32, "solid")

            stage.addPlatform(160, 119, 16, 32, "solid")
            stage.addPlatform(176, 127, 8, 24, "solid")

            stage.spawnDist = 48
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/summit_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/summit_fg.png")

            stage.bgColor = nil
            stage.bgShader = daytimeShader

            local enable_secret = false

            local date = os.date("*t")
            if (date.month == 11 and date.day == 20) or (date.month == 3 and date.day == 31) or love.math.random() < 0.01 then
                -- secret always enabled on nov. 20th and march 31st. otherwise 1% chance to happen
                enable_secret = true
            end

            make_flag(116, 71).secret = enable_secret
            cc_snowflakes()
        end,
        -- ancient trench from foreverred
        function()
            stage.name = "ancient trench"

            stage.addPlatform(104, 95, 32, 56, "solid")
            stage.addPlatform(72, 103, 32, 8, "solid")
            stage.addPlatform(136, 103, 32, 8, "solid")
            stage.addPlatform(88, 111, 16, 16, "solid")
            stage.addPlatform(136, 111, 16, 16, "solid")
            stage.addPlatform(80, 111, 8, 8, "solid")
            stage.addPlatform(152, 111, 8, 8, "solid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/trench_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/trench_fg.png")

            stage.bgColor = nil
            stage.bgShader = spaceShader
            -- TODO: this is also called in the stage select screen
            objectSystem.createObject(cloud, -60, 128, 1)
        end,
        -- the lonely island from amazon
        function()
            stage.name = "amazonia"

            stage.addPlatform(68, 87, 40, 24, "solid")
            stage.addPlatform(76, 111, 24, 8, "solid")
            stage.addPlatform(76, 63, 24, 4, "semisolid")
            stage.addPlatform(76, 39, 24, 4, "semisolid")

            stage.addPlatform(108, 87, 24, 4, "semisolid")

            stage.addPlatform(132, 87, 32, 24, "solid")
            stage.addPlatform(132, 111, 24, 16, "solid")
            stage.addPlatform(140, 127, 16, 24, "solid")
            stage.addPlatform(164, 103, 16, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/amazon_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/amazon_fg.png")

            stage.bgColor = nil
            stage.bgShader = amazonShader
        end,
        -- old site from solanum
        function()
            stage.name = "solanum mountain"

            stage.addPlatform(60, 119, 32, 32, "solid")
            stage.addPlatform(92, 111, 16, 40, "solid")
            stage.addPlatform(132, 111, 16, 40, "solid")
            stage.addPlatform(148, 119, 24, 32, "solid")

            stage.addPlatform(124, 111, 8, 4, "semisolid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/solanum_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/solanum_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        -- archaic meadow grotto from fingals
        function()
            stage.name = "archaic meadow grotto"

            stage.addPlatform(100, 63, 40, 24, "solid")

            stage.addPlatform(52, 87, 16, 32, "solid")
            stage.addPlatform(68, 87, 16, 64, "solid")
            stage.addPlatform(84, 111, 16, 40, "solid")
            stage.addPlatform(100, 119, 40, 32, "solid")
            stage.addPlatform(140, 111, 16, 40, "solid")
            stage.addPlatform(156, 87, 16, 64, "solid")
            stage.addPlatform(172, 87, 16, 32, "solid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/meadow_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/meadow_fg.png")

            stage.bgColor = {}
            stage.bgColor[1], stage.bgColor[2], stage.bgColor[3] = util.color(14)
            stage.bgShader = nil

            cc2_clouds(false, util.color(15))
            cc2_snowflakes()
        end,
        -- 600m from celeste
        function()
            stage.name = "600 m"

            stage.addPlatform(48, 103, 32, 48, "solid")
            stage.addPlatform(80, 111, 32, 40, "solid")

            stage.addPlatform(136, 119, 32, 32, "solid")
            stage.addPlatform(168, 111, 24, 40, "solid")

            stage.spawnDist = 52
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/600m_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/600m_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        -- chest level from celeste
        function()
            stage.name = "2200 m"

            stage.addPlatform(96, 95, 48, 16, "solid")
            stage.addPlatform(88, 103, 8, 8, "solid")
            stage.addPlatform(88, 111, 64, 8, "solid")
            stage.addPlatform(-16, 119, 256, 16, "solid")

            stage.spawnDist = 52
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/2200m_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/2200m_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            cc_clouds(util.color(1))
            cc_snowflakes()
        end,
        -- opening level from cc2
        function()
            stage.name = "trailhead"

            stage.addPlatform(-16, 95, 32, 16, "solid")
            stage.addPlatform(-16, 111, 24, 40, "solid")

            stage.addPlatform(44, 95, 8, 8, "solid")
            stage.addPlatform(64, 95, 24, 8, "solid")
            stage.addPlatform(104, 95, 32, 8, "solid")
            stage.addPlatform(152, 95, 24, 8, "solid")
            stage.addPlatform(188, 95, 8, 8, "solid")

            stage.addPlatform(224, 95, 32, 24, "solid")
            stage.addPlatform(232, 119, 24, 32, "solid")

            stage.spawnDist = nil
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/bridge_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/bridge_fg.png")

            stage.bgColor = nil
            stage.bgShader = nil

            cc2_clouds(false, 81 / 255, 72 / 255, 100 / 255)
            cc2_snowflakes()
        end,
        -- opening level from cc2
        function()
            stage.name = "golden valley"

            stage.addPlatform(72, 63, 24, 8, "solid")
            stage.addPlatform(96, 63, 8, 24, "solid")

            stage.addPlatform(96, 111, 48, 40, "solid")

            stage.addPlatform(136, 79, 32, 4, "semisolid")

            stage.spawnDist = 40
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/valley_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/valley_fg.png")

            stage.bgColor = {}
            stage.bgColor[1], stage.bgColor[2], stage.bgColor[3] = util.color(13)
            stage.bgShader = nil

            cc2_clouds(false, util.color(15))
            cc2_clouds(true, util.color(15))
            cc2_snowflakes()
        end,
        -- last level from cc2
        function()
            stage.name = "destination"

            stage.addPlatform(48, 87, 24, 32, "solid")
            stage.addPlatform(96, 103, 48, 48, "solid")
            stage.addPlatform(168, 87, 24, 32, "solid")

            stage.spawnDist = 52
            stage.blastZone = {l=0,r=240,t=-30,b=151}
            stage.bgImage = love.graphics.newImage("resources/graphics/stages/destination_bg.png")
            stage.fgImage = love.graphics.newImage("resources/graphics/stages/destination_fg.png")

            stage.bgColor = {}
            stage.bgColor[1], stage.bgColor[2], stage.bgColor[3] = util.color(15)
            stage.bgShader = nil

            cc2_clouds(false, util.color(7))
            cc2_clouds(true, util.color(7))
            cc2_snowflakes()
        end,
    },

    init = function(stageIdx)
        stage.platforms = {}
        stageIdx = stageIdx or 1
        if stage.layouts[stageIdx] then
            stage.layouts[stageIdx]()
        else
            stage.layouts[1]()
        end
    end,

    addPlatform = function(x, y, w, h, pType)
        table.insert(stage.platforms, {x = x, y = y, w = w, h = h, type = pType})
    end,

    draw_bg = function()
        love.graphics.setColor(1, 1, 1, 1)

        if stage.bgImage then
            if stage.bgShader then
                love.graphics.setShader(stage.bgShader)
                stage.bgShader:send("t", love.timer.getTime())
            end
            love.graphics.draw(stage.bgImage, 0, 0)
            if stage.bgShader then
                love.graphics.setShader()
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end,

    draw_fg = function()
        if stage.fgImage then
            love.graphics.draw(stage.fgImage, 0, 0)
        else
            for _, p in ipairs(stage.platforms) do
                if p.type == "solid" then
                    love.graphics.setColor(0.4, 0.4, 0.4)
                else
                    love.graphics.setColor(0.6, 0.6, 0.6)
                end
                love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end,
}
