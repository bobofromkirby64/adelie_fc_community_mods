local config = require("config")
require("dbg")
require("input")
require("gameController")
require("overlay")
require("util")
require("sprites")
require("shaders")
require("audio")
require("networking/client/network")
require("recorder")
require("replay")

local push = require("libraries/push")

GAME_WIDTH, GAME_HEIGHT = 240, 135 --fixed game resolution
WINDOW_SCALE = math.max(2, config["window_scale"] or 4)
WINDOW_WIDTH, WINDOW_HEIGHT = GAME_WIDTH * WINDOW_SCALE, GAME_HEIGHT * WINDOW_SCALE
IS_FULLSCREEN = (config["fullscreen"] ~= nil and config["fullscreen"] == 1) or false

VOL_SFX, VOL_MUSIC = config["vol_sfx"] or 8, config["vol_music"] or 8

UPDATE_RATE = 30

GAME_VERSION = 23

local accum = 0

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest", 1)
    
    push:setupScreen(GAME_WIDTH, GAME_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = IS_FULLSCREEN,
        resizable = true,
        pixelperfect = true,
        highdpi = true,
        canvas = true,
        stretched = false
    })
    love.keyboard.setKeyRepeat(true)

    local rasterizer = love.font.newRasterizer("resources/fonts/PICO-8.ttf", 5, "none", 1)
    local font = love.graphics.newFont(rasterizer)
    font:setFilter("nearest", "nearest")
    love.graphics.setFont(font)

    sprites.init()
    network.init()

    --bgMusic = love.audio.play("music/main_theme.ogg", "stream", true)
    --bgMusic:setVolume(0.2)
    playBGM("music/menu_theme.ogg")
end

-- this probably shouldn't be in main but push is a local reference
function refresh_window()
    WINDOW_WIDTH = GAME_WIDTH * WINDOW_SCALE
    WINDOW_HEIGHT = GAME_HEIGHT * WINDOW_SCALE
    push:setupScreen(GAME_WIDTH, GAME_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = IS_FULLSCREEN,
        resizable = true,
        pixelperfect = true, 
        highdpi = true,
        canvas = true,
        stretched = false 
    })
end

function love.resize(w, h)
    return push:resize(w, h)
end

function love.update(dt)
    network.update()
    love.audio.update(dt)

    accum = accum + dt
    while accum >= 1/UPDATE_RATE do
        accum = accum - 1/UPDATE_RATE

        gameController.update()
        overlay.update()
        camera.update()

        input.flush()
        
        recorder.queue_capture = true
    end

    dbg.update(dt)
end

function love.draw()
    push:start()
    camera.start()
    gameController.draw()
    camera.finish()
    gameController.drawUI()
    overlay.draw()
    recorder.capture()
    push:finish()

    dbg.draw()
end

function love.quit()
    network.disconnectServer()
end

function love.filedropped(file)
    if gameState == "TITLE" and title.getState() == "replay_wait" then
        file:open("r")
        local content = file:read()
        file:close()

        local replayData = replay.loadFromString(content)
        if replayData then
            gameController.gameStart(replayData.stageIdx, replayData.playerData, "REPLAY", replayData)
        else
            love.audio.play("menu_back", "static") -- feedback
        end
    end
end
