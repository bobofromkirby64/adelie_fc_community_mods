debugEnabled = false

local dtQueue = {}
local frameRate = 0

dbg = {
    update = function(dt)
        if love.keyboard.isScancodeDown("escape") and love.keyboard.isScancodeDown("lshift") then
            love.event.quit()
        elseif input.getKeyDown("d") then
            -- debugEnabled = not debugEnabled
        end

        table.insert(dtQueue, dt)
        if #dtQueue >= 50 then
            local sum = 0
            for _,i in ipairs(dtQueue) do
                sum = sum + i
            end
            local avgDt = sum/#dtQueue
            frameRate = 1/avgDt
            dtQueue = {}
        end
    end,
    draw = function()
        if debugEnabled then
            love.graphics.print("Frame Rate: " .. math.floor(frameRate), 5, 5)
            love.graphics.print("Memory Usage: " .. collectgarbage("count"), 5, 15)
            love.graphics.print("Current Frame: " .. frameCounter, 5, 40)
            love.graphics.print("Frontier Frame: " .. frontierFrame, 5, 55)
        end
    end
}