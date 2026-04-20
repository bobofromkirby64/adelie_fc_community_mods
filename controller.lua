-- controller.lua
local config = require("config")

function controllerInput(inp)
    local joysticks = love.joystick.getJoysticks()
    local joystick = joysticks[1]

    if not joystick then
        return false
    end

    local success, is_down = pcall(function() return joystick:isGamepadDown(inp) end)
    local btn_down = success and is_down

    -- analog handling
    if inp == (config["pad_up"] or "dpup") then
        return btn_down or joystick:getGamepadAxis("lefty") < -0.2
    elseif inp == (config["pad_down"] or "dpdown") then
        return btn_down or joystick:getGamepadAxis("lefty") > 0.2
    elseif inp == (config["pad_right"] or "dpright") then
        return btn_down or joystick:getGamepadAxis("leftx") > 0.2
    elseif inp == (config["pad_left"] or "dpleft") then
        return btn_down or joystick:getGamepadAxis("leftx") < -0.2
    end

    return btn_down
end
