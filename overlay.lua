local msgQueue = {}
local menuInputDisplay = ""
overlay = {
    add_msg = function(text)
        table.insert(msgQueue, {msg=text, life=120})
    end,
    update = function()
        if #msgQueue > 0 then
            msgQueue[1].life = msgQueue[1].life - 1
            if msgQueue[1].life <= 0 then
                table.remove(msgQueue, 1)
            end
        end
    end,
    setInputDisplay = function(text)
        menuInputDisplay = text
    end,
    draw = function()
        -- offline
        if not network.connected then
            love.graphics.setColor(util.color(8))
            love.graphics.print("offline", 1, 1)
        end

        -- error messages
        if #msgQueue > 0 and love.timer.getTime()%1 < 0.5 then
            love.graphics.setColor(util.color(8))
            local m = msgQueue[1].msg
            love.graphics.print(m, GAME_WIDTH/2 - #m*2, 1)
        end

        --menu inputs
        if #menuInputDisplay > 0 then
            love.graphics.setColor(util.color(5))
            love.graphics.rectangle("fill", 0, GAME_HEIGHT-9, GAME_WIDTH, 8)
            love.graphics.setColor(util.color(1))
            love.graphics.rectangle("fill", 0, GAME_HEIGHT-8, GAME_WIDTH, 8)
            love.graphics.setColor(util.color(7))
            love.graphics.print(menuInputDisplay, 2, GAME_HEIGHT-7)
        end
    end
}