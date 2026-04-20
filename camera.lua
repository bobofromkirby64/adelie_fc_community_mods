local cx,cy = 0,0
local activeShake = nil

camera = {
    shake = function(x,y,t)
        activeShake = {x=x, y=y, t=t}
    end,
    update = function()
        if activeShake ~= nil then
            cx = (math.random()*2 - 1) * activeShake.x
            cy = (math.random()*2 - 1) * activeShake.y
            activeShake.t = activeShake.t - 1
            if activeShake.t <= 0 then
                activeShake = nil
                cx,cy = 0,0
            end
        end
    end,
    start = function()
        love.graphics.push()
        love.graphics.translate(cx, cy)
    end,
    finish = function()
        love.graphics.pop()
    end
}