-- sss.lua
require("controller")
local config = require("config")

sss = {
    players = {},
    mode = "ONLINE",
    thumbnails = {},
    p1_cursor = 1,
    p2_cursor = 1, 
    p1_ready = false,
    p2_ready = false,
    grid_w = 5,
    grid_h = 2,
    random_slot = 1,
    btn_pressed = {}, 

    init = function(players, mode)
        sss.players = players
        sss.mode = mode
        
        local num_stages = #stage.layouts + ((network.moddedConnection == true or sss.mode == "TRAINING") and #stage.modded_layouts or 0)
        sss.random_slot = 1
        sss.p1_cursor = 1
        sss.p2_cursor = 1 
        sss.p1_ready = false
        sss.p2_ready = false

        if sss.mode == "TRAINING" or sss.mode == "LOCAL" then
            sss.p2_ready = true 
        end

        overlay.setInputDisplay("O : vote | UDLR : move | X : back")

        -- stage caching
        sss.thumbnails = {}
        local _particles_bg, _particles_mg, _particles_fg = particles_bg, particles_mg, particles_fg
        particles_bg, particles_fg = {}, {}
        
        table.insert(sss.thumbnails, {
            bg = nil,
            fg = nil,
            name = "random",
            idx = 0
        })

        local cell_w, cell_h = 36, 20

        for i = 1, num_stages do
            particles_bg, particles_mg, particles_fg = {}, {}, {}
            stage.init(i)
            
            table.insert(sss.thumbnails, {
                bg = stage.bgImage,
                fg = stage.fgImage,
                name = string.lower(stage.name),
                shader = stage.shader,
                bgShader = stage.bgShader,
                fgShader = stage.fgShader,
                bgColor = stage.bgColor,
                idx = i,
                p_bg = particles_bg,
                p_mg = particles_mg,
                p_fg = particles_fg
            })
        end
        
        particles_bg, particles_mg, particles_fg = _particles_bg, _particles_mg, _particles_fg
    end,

    update = function()
        -- back
        if input.checkPressed("b2") or controllerInput("b") then
            if sss.mode == "ONLINE" and network and network.sendSSSCancel then
                network.sendSSSCancel()
            end
            gameController.enterCSS(sss.mode)
            love.audio.play("menu_back", "static")
            return
        end

        if not sss.p1_ready then
            local moved = false
            if input.checkPressed("right") then
                if sss.p1_cursor % sss.grid_w ~= 0 and sss.p1_cursor < #sss.thumbnails then sss.p1_cursor = sss.p1_cursor + 1; moved = true end
            elseif input.checkPressed("left") then
                if sss.p1_cursor % sss.grid_w ~= 1 then sss.p1_cursor = sss.p1_cursor - 1; moved = true end
            elseif input.checkPressed("down") then
                if sss.p1_cursor <= (#sss.thumbnails - sss.grid_w) then sss.p1_cursor = sss.p1_cursor + sss.grid_w; moved = true end
            elseif input.checkPressed("up") then
                if sss.p1_cursor > sss.grid_w then sss.p1_cursor = sss.p1_cursor - sss.grid_w; moved = true end
            end
            
            if moved then 
                love.audio.play("menu_text", "static", false, false) 
                if sss.mode == "ONLINE" then network.sendSSSCursor(sss.p1_cursor) end
            end
        end

        if input.checkPressed("b1") then
            sss.p1_ready = not sss.p1_ready
            love.audio.play("readyup", "static")
            if sss.mode == "ONLINE" then
                network.sendSSSReady(sss.p1_ready, sss.p1_cursor, sss.thumbnails[sss.p1_cursor].idx, #stage.layouts + (network.moddedConnection == true and #stage.modded_layouts or 0))
            end
        end

        -- training mode (cpu doesn't vote)
        if sss.mode == "TRAINING" and sss.p1_ready and sss.p2_ready then
            local picked = sss.p1_cursor
            if picked == sss.random_slot then 
                picked = love.math.random(1, #stage.layouts + #stage.modded_layouts) 
            else
                picked = sss.thumbnails[picked].idx
            end
            gameController.gameStart(picked, sss.players, sss.mode)
        end
    end,

    parseUpdate = function(dataStr)
        for _, pStr in ipairs(util.split(dataStr, "-")) do
            if pStr ~= "" then
                local parts = util.split(pStr, ",")
                local id = tonumber(parts[1])
                if id ~= connectionID then
                    sss.p2_cursor = tonumber(parts[2])
                    sss.p2_ready = parts[3] == "1"
                end
            end
        end
    end,

    draw = function()
        -- background
        if cssBGShader then
            love.graphics.setShader(cssBGShader)
            cssBGShader:send("t", love.timer.getTime())
            love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
            love.graphics.setShader()
        else
            love.graphics.setColor(29/255, 43/255, 83/255, 1)
            love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        end

        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

        -- Modded alteration: header moved after thumbnials so that it always renders over them

        local cell_w, cell_h = 36, 20
        local pad_x, pad_y = 6, 8
        local start_x = GAME_WIDTH/2 - ((sss.grid_w * cell_w + (sss.grid_w - 1) * pad_x) / 2)
        local start_y = 20

        for i, thumb in ipairs(sss.thumbnails) do
            -- Modded var, used to offset the thumbnails for when the cursor goes offscreen
            local cam_y = (cell_h + pad_y) * -(math.floor((sss.p1_cursor - 1) / sss.grid_w) < 2 and 0 or math.floor((sss.p1_cursor - 1) / sss.grid_w) - 2)

            local row = math.floor((i - 1) / sss.grid_w)
            local col = (i - 1) % sss.grid_w
            local cx = start_x + col * (cell_w + pad_x)
            local cy = start_y + row * (cell_h + pad_y) + cam_y

            -- thumbnail frame
            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", cx + 2, cy + 2, cell_w, cell_h)
            love.graphics.setColor(util.color(1))
            love.graphics.rectangle("fill", cx - 1, cy - 1, cell_w + 2, cell_h + 2)

            if i == sss.random_slot then
                love.graphics.setColor(util.color(1)) 
                love.graphics.rectangle("fill", cx, cy, cell_w, cell_h)
                love.graphics.setColor(util.color(0))
                love.graphics.print("?", cx + cell_w/2 - 2 + 1, cy + cell_h/2 - 3 + 1)
                love.graphics.setColor(util.color(6))
                love.graphics.print("?", cx + cell_w/2 - 2, cy + cell_h/2 - 3)
            else
                love.graphics.setColor(sss.thumbnails[i].bgColor or {0, 0, 0})
                love.graphics.rectangle("fill", cx, cy, cell_w, cell_h)
                
                local scale_x, scale_y = cell_w / 240, cell_h / 135

                love.graphics.stencil(function()
                    love.graphics.rectangle("fill", cx, cy, cell_w, cell_h)
                end, "replace", 1)
                love.graphics.setStencilTest("greater", 0)
                
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.scale(scale_x, scale_y)
                if thumb.p_bg then
                    for _, p in ipairs(thumb.p_bg) do p:draw() end
                end
                if thumb.bg then 
                    local shader = thumb.bgShader or thumb.shader
                    if shader then
                        love.graphics.setShader(shader)
                        if shader:hasUniform("t") then shader:send("t", 1.5) end
                    end
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(thumb.bg, 0, 0)
                    love.graphics.setShader()
                end
                if thumb.p_mg then
                    for _, p in ipairs(thumb.p_mg) do p:draw() end
                end
                if thumb.mg then 
                    local shader = thumb.mgShader or thumb.shader
                    if shader then
                        love.graphics.setShader(shader)
                        if shader:hasUniform("t") then shader:send("t", 1.5) end
                    end
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(thumb.mg, 0, 0)
                    love.graphics.setShader()
                end
                if thumb.fg then 
                    local shader = thumb.fgShader or thumb.shader
                    if shader then
                        love.graphics.setShader(shader)
                        if shader:hasUniform("t") then shader:send("t", 1.5) end
                    end
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(thumb.fg, 0, 0)
                    love.graphics.setShader()
                end
                if thumb.p_fg then
                    for _, p in ipairs(thumb.p_fg) do p:draw() end
                end
                
                love.graphics.pop()
                love.graphics.setStencilTest()
            end

            -- p1/p2 tag
            local function draw_tag(tx, ty, label, color_idx)
                local tw, th = 11, 9
                love.graphics.setColor(util.color(0))
                love.graphics.rectangle("fill", tx + 2, ty + 1, tw - 2, th)
                love.graphics.rectangle("fill", tx + 1, ty + 2, tw, th - 2)
                love.graphics.setColor(util.color(color_idx))
                love.graphics.rectangle("fill", tx + 1, ty, tw - 2, th)
                love.graphics.rectangle("fill", tx, ty + 1, tw, th - 2)
                love.graphics.setColor(util.color(7))
                love.graphics.print(label, tx + 2, ty + 2)
            end

            if i == sss.p1_cursor then
                love.graphics.setColor(util.color(8)) 
                love.graphics.setLineWidth(sss.p1_ready and 2 or 1)
                love.graphics.rectangle("line", cx - 2, cy - 2, cell_w + 4, cell_h + 4)
            end
            if sss.mode ~= "TRAINING" and i == sss.p2_cursor then
                love.graphics.setColor(util.color(12)) 
                love.graphics.setLineWidth(sss.p2_ready and 2 or 1)
                love.graphics.rectangle("line", cx - 3, cy - 3, cell_w + 6, cell_h + 6)
            end
            if i == sss.p1_cursor then
                draw_tag(cx - 5, cy - 11, "p1", 8)
            end
            if sss.mode ~= "TRAINING" and i == sss.p2_cursor then
                draw_tag(cx + cell_w - 6, cy - 11, "p2", 12)
            end
            love.graphics.setLineWidth(1)
        end

        -- header
        local title = "stage select"
        love.graphics.setColor(util.color(0))
        love.graphics.print(title, GAME_WIDTH/2 - (#title * 2) + 1, 8)
        love.graphics.setColor(util.color(7))
        love.graphics.print(title, GAME_WIDTH/2 - (#title * 2), 7)
        
        -- stage name
        local name = sss.thumbnails[sss.p1_cursor].name
        local box_w = math.max((#name * 4) + 16, 72)
        local box_h = 15
        local box_x, box_y = GAME_WIDTH/2 - box_w/2, GAME_HEIGHT - 31

        love.graphics.setColor(util.color(0))
        love.graphics.rectangle("fill", box_x + 2, box_y + 2, box_w, box_h)
        love.graphics.setColor(util.color(1))
        love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)
        love.graphics.setColor(util.color(5))
        love.graphics.rectangle("line", box_x + 1, box_y + 1, box_w - 2, box_h - 2)

        love.graphics.setColor(util.color(0))
        love.graphics.print(name, GAME_WIDTH/2 - (#name * 2) + 1, box_y + 5 + 1)
        love.graphics.setColor(util.color(7))
        love.graphics.print(name, GAME_WIDTH/2 - (#name * 2), box_y + 5)
    end
}
