-- gameController.lua
require ("title")
require ("css")
require ("sss")
require ("game")
require("replay")

gameState = "TITLE" -- TITLE, CSS, SSS, GAME
currentMode = "ONLINE"

gameController = {
    update = function()
        if gameState=="TITLE" then title.update()
        elseif gameState=="CSS" then css.update()
        elseif gameState=="SSS" then sss.update()
        elseif gameState=="GAME" then game.update()
        end
    end,

    draw = function()
        if gameState=="GAME" then game.draw() end
    end,

    drawUI = function()
        if gameState=="TITLE" then title.draw()
        elseif gameState=="CSS" then css.draw()
        elseif gameState=="SSS" then sss.draw()
        elseif gameState=="GAME" then game.drawUI()
        end
    end,

    enterTitle = function(targetState)
        gameState = "TITLE"
        title.changeState(targetState or "mode")
        playBGM("music/menu_theme.ogg")
    end,

    enterCSS = function(mode)
        gameState = "CSS"
        currentMode = mode or "ONLINE"
        input.setTextListener(function() end)
        css.init(currentMode)
        playBGM("music/menu_theme.ogg")
    end,

    enterSSS = function(players, mode)
        gameState = "SSS"
        currentMode = mode or "ONLINE"
        input.setTextListener(function() end)
        sss.init(players, currentMode)
    end,

    gameStart = function(stageIdx, playerData, mode, replayData)
        gameState = "GAME"
        input.setTextListener(function() end)
        game.init(stageIdx, playerData, mode, replayData)
        fadeOutBGM()
        recorder.clear()
    end,

    playReplay = function(filename)
        local replayData = replay.load(filename)
        if replayData then
            gameController.gameStart(replayData.stageIdx, replayData.playerData, "REPLAY", replayData)
        end
    end
}