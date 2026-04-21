-- css.lua
require("controller")
local config = require("config")

NUM_PLAYER_SKINS = {
    maddy = 4,
    lani = 4,
    gemmy = 4,
    stepstools = 4
}
AVAILABLE_CHARS = {"maddy", "gemmy", "lani", "stepstools"}
VANILLA_CHARS = {"maddy", "lani"}

css = {
    players = {},
    localReady = false,
    mode = "ONLINE",

    init = function(mode)
        css.mode = mode or "ONLINE"

        --css.players = {}
        css.localReady = false
        css.btnPressed = {}

        css.player_char = css.player_char or "maddy"
        css.char_idx = css.char_idx or 1
        css.player_skin = css.player_skin or 1

        if css.mode == "ONLINE" and network and network.sendCSSReady then
            network.sendCSSReady(false)
        end

        overlay.setInputDisplay("O : ready | LR : character | UD : skin | X : leave")

        if css.mode == "TRAINING" then
            css.players = {
                {
                    id = connectionID,
                    char = css.player_char,
                    ready = "0",
                    wins = -1,
                    skin = css.player_skin,
                    username = config["username"] or "p1"
                },
                {
                    id = 2,
                    char = "gemmy",
                    ready = "1",
                    wins = -1,
                    skin = 2,
                    username = "cpu"
                }
            }
        end
    end,

    update = function()
        -- confirm
        if input.checkPressed("b1") then
            css.localReady = not css.localReady

            if css.mode == "ONLINE" then
                network.sendCSSReady(css.localReady)
            else
                css.players[1].ready = css.localReady and "1" or "0"
                if css.localReady then
                    gameController.enterSSS(css.players, css.mode)
                end
            end

            love.audio.play("readyup", "static", false, false)
        end

        -- back
        if input.checkPressed("b2") then
            if css.mode == "ONLINE" then network.exitRoom() end
            css.players = {}
            gameController.enterTitle()
            love.audio.play("menu_back", "static")
        end

        if not css.localReady then
            local n_skins = NUM_PLAYER_SKINS[css.player_char]
            local updated = false

            if input.checkPressed("up") then
                css.player_skin = css.player_skin % n_skins + 1
                updated = true
            end
            if input.checkPressed("down") then
                css.player_skin = (css.player_skin - 2) % n_skins + 1
                updated = true
            end
            if input.checkPressed("right") then
                css.char_idx = css.char_idx % #AVAILABLE_CHARS + 1
                css.player_char = AVAILABLE_CHARS[css.char_idx]
                css.player_skin = 1
                updated = true
            end
            if input.checkPressed("left") then
                css.char_idx = (css.char_idx - 2) % #AVAILABLE_CHARS + 1
                css.player_char = AVAILABLE_CHARS[css.char_idx]
                css.player_skin = 1
                updated = true
            end
            if updated then
                if css.mode == "ONLINE" then
                    network.sendCSSChar(css.player_char)
                    network.sendCSSSkin(css.player_skin)
                else
                    css.players[1].char = css.player_char
                    css.players[1].skin = css.player_skin
                end
            end
        end
    end,

    draw = function()
        -- bg shader
        love.graphics.setShader(cssBGShader)
        cssBGShader:send("t", love.timer.getTime())
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
        love.graphics.setShader()

        -- darken
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

        -- header
        local title = "character select"
        love.graphics.setColor(util.color(0)) -- shadow
        love.graphics.print(title, GAME_WIDTH/2 - (#title * 2) + 1, 8 + 1)
        love.graphics.setColor(util.color(7)) -- white
        love.graphics.print(title, GAME_WIDTH/2 - (#title * 2), 8)

        -- vs
        local vs = "vs"
        love.graphics.setColor(util.color(0))
        love.graphics.print(vs, GAME_WIDTH/2 - (#vs * 2) + 1, 56 + 1)
        love.graphics.setColor(util.color(8)) -- Red
        love.graphics.print(vs, GAME_WIDTH/2 - (#vs * 2), 56)

        -- player panels
        for i, p in ipairs(css.players) do
            local isMe = (tonumber(p.id) == tonumber(connectionID))

            local panelWidth = 68
            local panelHeight = 90
            local panelX = GAME_WIDTH/2 + (isMe and -82 or 14)
            local panelCenter = panelX + (panelWidth / 2)
            local portraitX = GAME_WIDTH/2 + (isMe and -80 or 80)

            -- name tabs
            local playerText = p.username
            local tabW = (#playerText * 4) + 6
            local tabH = 10
            local tabX = isMe and (panelX + 4) or (panelX + panelWidth - tabW - 4)
            local tabY = 14

            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", tabX + 2, tabY + 2, tabW, tabH)
            love.graphics.setColor(util.color(1))
            love.graphics.rectangle("fill", tabX, tabY, tabW, tabH)

            love.graphics.setColor(util.color(6))
            love.graphics.print(playerText, tabX + 3, tabY + 2)

            -- drop shadow + border
            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", panelX + 2, 22 + 2, panelWidth, panelHeight)
            love.graphics.setColor(util.color(1))
            love.graphics.rectangle("fill", panelX, 22, panelWidth, panelHeight)

            -- portrait box
            love.graphics.setColor(util.color(5))
            love.graphics.rectangle("fill", panelX + 2, 24, 64, 64)

            -- portrait sprite
            love.graphics.setColor(1, 1, 1, 1)
            local portrait_name_skin = "ui/portrait_" .. p.char .. "_" .. p.skin

            -- fall back if skin doesn't exist (can have race condition)
            local portrait_spr = sprites[portrait_name_skin] or sprites["ui/portrait_" .. p.char .. "_1"]
            sprites.draw(portrait_spr, portraitX, 24, 0, isMe and 2 or -2, 2)

            -- name frame
            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", panelX + 6, 86, panelWidth - 8, 13)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", panelX + 4, 84, panelWidth - 8, 13)
            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", panelX + 5, 85, panelWidth - 10, 11)

            -- char name
            love.graphics.setColor(util.color(7))
            local charName = string.lower(p.char)
            love.graphics.print(charName, panelCenter - (#charName * 2), 88)

            -- ready status
            local t = love.timer.getTime()
            if p.ready == "1" then
                love.graphics.setColor(util.color(0))
                love.graphics.print("ready!", panelX + 5 + 1, 100 + 1)
                love.graphics.setColor(util.color(11))
                love.graphics.print("ready!", panelX + 5, 100)
            else
                if math.floor(t * 2) % 2 == 0 then
                    love.graphics.setColor(util.color(0))
                    love.graphics.print("selecting", panelX + 5 + 1, 100 + 1)
                    love.graphics.setColor(util.color(5))
                    love.graphics.print("selecting", panelX + 5, 100)
                end
            end

            -- win counter
            if css.mode ~= "TRAINING" then
                love.graphics.setColor(util.color(10))
                local winsText = tostring(p.wins)
                local textX = panelX + panelWidth - 5 - (#winsText * 4)
                local textY = 100
                love.graphics.print(winsText, textX, textY)
                local starX = textX - 9
                local starY = textY
                love.graphics.rectangle("fill", starX + 3, starY + 0, 1, 1) -- p8 star
                love.graphics.rectangle("fill", starX + 2, starY + 1, 3, 1)
                love.graphics.rectangle("fill", starX + 0, starY + 2, 7, 1)
                love.graphics.rectangle("fill", starX + 1, starY + 3, 5, 1)
                love.graphics.rectangle("fill", starX + 1, starY + 4, 1, 1)
                love.graphics.rectangle("fill", starX + 5, starY + 4, 1, 1)
            end
        end
    end,

    parseUpdate = function(dataStr)
        css.players = {}
        for _, pStr in ipairs(util.split(dataStr, "-")) do
            local parts = util.split(pStr, ",")
            table.insert(css.players, {
                id = parts[1],
                char = parts[2],
                ready = parts[3],
                wins = parts[4],
                skin = parts[5],
                username = parts[6] or "opp"
            })
        end
    end
}