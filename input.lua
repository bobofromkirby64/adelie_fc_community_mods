-- input.lua
local config = require("config")

local textListener = function() end
local keysPressed = {}
local gamepadPressed = {}
local defaults = {
    up    = { kb = "up",    pad = "dpup" },
    down  = { kb = "down",  pad = "dpdown" },
    left  = { kb = "left",  pad = "dpleft" },
    right = { kb = "right", pad = "dpright" },
    b1    = { kb = "z",     pad = "a" },
    b2    = { kb = "x",     pad = "b" }
}

input = {
    setTextListener = function(listener)
        textListener = listener
    end,
    getKeyDown = function(key)
        return love.keyboard.isDown(love.keyboard.getKeyFromScancode(key))
    end,
    getKeyPressed = function(key)
        return keysPressed[key] == true
    end,
    getGamepadPressed = function(btn)
        return gamepadPressed[btn] == true
    end,
    checkDown = function(inp)
        local def = defaults[inp]
        if not def then return false end
        return input.getKeyDown(config["kb_" .. inp] or def.kb) or controllerInput(config["pad_" .. inp] or def.pad)
    end,
    checkPressed = function(inp)
        local def = defaults[inp]
        if not def then return false end
        return input.getKeyPressed(config["kb_" .. inp] or def.kb) or input.getGamepadPressed(config["pad_" .. inp] or def.pad)
    end,
    flush = function()
        keysPressed = {}
        gamepadPressed = {}
    end
}

function love.keypressed(k, scancode, isrepeat)
    textListener(k, "keyboard")
    if not isrepeat then
        keysPressed[k] = true
        if scancode then
            keysPressed[scancode] = true
        end

        local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
        if ctrl and k == "6" then -- ctrl + 6 screenshot
            recorder.screenshot()
        elseif ctrl and k == "9" then -- ctrl + 9 gif
            recorder.export()
        end
    end
end

function love.gamepadpressed(joystick, button)
    textListener(button, "gamepad")
    gamepadPressed[button] = true
end