-- networking/client/network.lua
local enet = require ("enet")
local config = require("config")

-- address override!
--ADDRESS = config["server_ip"]
--ADDRESS = "3.129.71.135"
--ADDRESS = "localhost"
PORT = 2378

PACKET_FRAMES = 20

connectionID = -1
connectionIDs = {}
currentRoom = ""

local host = nil
local server = nil
local socket = nil

network = {
    connected = false,
    moddedConnection = false,
    init = function()
        if network.connected then return end
        network.moddedConnection = false
        connectionID = -1
        connectionIDs = {}
        network.version_mismatch = false
        network.connectServer()
    end,
    update = function()
        if not host then return end
        local event = host:service()
        while event do
            if event.type == "connect" then
                network.connected = true
                socket = event.peer
            elseif event.type == "disconnect" then
                network.connected = false
                socket = nil

                -- Force a fresh handshake next time we enter CSS
                if css then css.lobby_active = false end 
                
                if not network.version_mismatch then
                    overlay.add_msg("server disconnected")
                end
                -- ...

                if not network.version_mismatch then
                    overlay.add_msg("server disconnected")
                end
                if gameState ~= "TITLE" then
                    gameController.enterTitle()
                elseif title.getState() ~= "init" and title.getState() ~= "mode" then
                    title.changeState("init")
                end
            elseif event.type == "receive" then
                network.processMessage(event.data)
            end
            event = host:service()
        end
    end,

    connectServer = function(test_ip)
        local target_ip = test_ip or ADDRESS or config["server_ip"] or "3.129.71.135"

        if host then
            if server then
                server:disconnect()
                host:flush()
            end
        end
        host = enet.host_create()
        socket = nil
        connectionID = -1
        server = host:connect(target_ip..":"..PORT, 1, GAME_VERSION)
    end,

    disconnectServer = function()
        server:disconnect(connectionID)
        host:flush()
    end,

    joinQueue = function(username)
        if not network.connected then return end
        css:modded_skin_routine()
        local char = css.player_char or "maddy"
        local skin = css.player_skin or 1
        network.sendMessage("JOINQUEUE|"..username..","..char..","..tostring(skin), "reliable")
    end,

    leaveQueue = function()
        if not network.connected then return end
        network.sendMessage("LEAVEQUEUE|", "reliable")
    end,

    joinRoom = function(roomID, username)
        if not network.connected then return end
        if roomID=="" then return end
        local char = css.player_char or "maddy"
        local skin = css.player_skin or 1
        network.sendMessage("JOINROOM|"..roomID..","..username..","..char..","..tostring(skin), "reliable")
    end,

    exitRoom = function()
        network.sendMessage("EXITROOM|", "reliable")
        currentRoom = ""
    end,

    sendCSSReady = function(isReady)
        local val = isReady and "1" or "0"
        network.sendMessage("CSS_READY|" .. val, "reliable")
    end,

    sendCSSChar = function(char)
        network.sendMessage("CSS_CHAR|" .. char, "reliable")
    end,

    sendCSSSkin = function(skin)
        network.sendMessage("CSS_SKIN|" .. skin, "reliable")
    end,

    sendSSSReady = function(isReady, cursor, idx, numStages)
        local val = isReady and "1" or "0"
        network.sendMessage("SSS_READY|" .. val .. "," .. tostring(cursor) .. "," .. tostring(idx) .. "," .. tostring(numStages), "reliable")
    end,

    sendSSSCursor = function(cursor)
        network.sendMessage("SSS_CURSOR|" .. tostring(cursor), "reliable")
    end,

    sendSSSCancel = function()
        network.sendMessage("SSS_CANCEL|", "reliable")
    end,

    sendInput = function(i, frame)
        if not network.connected or not socket then return end

        local source = inputSource.getInputSource(tonumber(connectionID))
        local history_str = ""

        for offset = 0, PACKET_FRAMES do
            local past_frame = frame - offset
            local mask = 0
            
            -- i is current frame, use history for past frames
            local keys = (offset == 0) and i or source.record[past_frame]

            if keys then
                if keys.up then mask = mask + 1 end
                if keys.down then mask = mask + 2 end
                if keys.left then mask = mask + 4 end
                if keys.right then mask = mask + 8 end
                if keys.b1 then mask = mask + 16 end
                if keys.b2 then mask = mask + 32 end
            end

            history_str = history_str .. tostring(mask) .. (offset < PACKET_FRAMES and "," or "")
        end

        local msg = "FRAME|"..connectionID.."/"..frame.."/"..history_str
        network.sendMessage(msg, "unreliable")
    end,

    sendMessage = function(data, flag)
        if not network.connected or not socket then return end

        socket:send(data, 0, flag or "unreliable")
    end,

    processMessage = function(data)
        local parts = util.split(data, "|")
        local head = parts[1]
        local bodyParts = parts[2] and util.split(parts[2], ",") or {}

        --CONNECT|connectionID
        if head == "CONNECT" then connectionID = tonumber(parts[2]) end
        --JOINROOM|roomID
        if head == "JOINROOM" then currentRoom = parts[2] end
        --EXITROOM|
        if head == "EXITROOM" then currentRoom = "" end

        --ROOMREADY|
        if head == "ROOMREADY" then
            if gameState == "TITLE" then
                -- only play audio cue from room code or quickplay
                love.audio.play("readyup", "static")
                love.window.requestAttention(true)
            end
            gameController.enterCSS()
        end

        --CSSUPDATE|connID,charactername,readystate,numwins-...
        if head == "CSSUPDATE" then
            css.parseUpdate(parts[2])
        end

        --CSSCANCEL|
        if head == "CSSCANCEL" then
            gameController.enterTitle()
        end

        --SSS_START|connID:char1,username1,skin1,...
        if head == "SSS_START" then
            local playerData = {}
            connectionIDs = {}

            local playerString = parts[3] and parts[3] or parts[2]

            for _, pStr in ipairs(util.split(playerString, ",")) do
                local pParts = util.split(pStr, ":")
                local id = tonumber(pParts[1])
                table.insert(connectionIDs, id)
                table.insert(playerData, {id = id, char = pParts[2], username = pParts[3], skin = pParts[4]})
            end

            gameController.enterSSS(playerData, "ONLINE")
        end

        --SSSUPDATE|connID,cursor,readystate-...
        if head == "SSSUPDATE" then
            sss.parseUpdate(parts[2])
        end

        --SSSCANCEL|
        if head == "SSSCANCEL" then
            if gameState == "SSS" then
                gameController.enterCSS(currentRoom ~= "" and "ONLINE" or "LOCAL")
            end
        end

        --START|stageID|waitFrames
        if head == "START" then
            local stageIdx = tonumber(parts[2])
            local wait_frames = tonumber(parts[3]) or 0
            gameController.gameStart(stageIdx, sss.players, "ONLINE")
            game.startupDelay = wait_frames
        end

        --FRAME|connID/frameNum/inputmask...
        if head == "FRAME" then
            if gameState ~= "GAME" then return end

            local id, frameStr, maskStr = unpack(util.split(parts[2], "/"))
            id = tonumber(id)
            local base_frame = tonumber(frameStr)
            local masks = util.split(maskStr, ",")

            if id ~= connectionID then
                if game.remoteFrame then
                    game.remoteFrame = math.max(game.remoteFrame, base_frame)
                end
            end

            local rollback_target_frame = math.huge
            local requires_rollback = false

            -- read masks backwards
            for offset = 0, #masks - 1 do
                local current_f = base_frame - offset
                if current_f > 0 then
                    local mask = tonumber(masks[offset + 1]) or 0
                    local keys = {
                        up    = math.floor(mask / 1) % 2 == 1,
                        down  = math.floor(mask / 2) % 2 == 1,
                        left  = math.floor(mask / 4) % 2 == 1,
                        right = math.floor(mask / 8) % 2 == 1,
                        b1    = math.floor(mask / 16) % 2 == 1,
                        b2    = math.floor(mask / 32) % 2 == 1
                    }
                    
                    local source = inputSource.getInputSource(id)
                    
                    -- flag missing frame for rollback
                    if source.record[current_f] == nil then
                        source:recordInputForFrame(current_f, keys)
                        requires_rollback = true
                        -- rollback target to oldest recovered frame
                        if current_f < rollback_target_frame then
                            rollback_target_frame = current_f
                        end
                    end
                end
            end

            if requires_rollback then
                local target = math.max(1, rollback_target_frame - 1)
                if not game.pendingRollback or target < game.pendingRollback then
                    game.pendingRollback = target
                end
            end
        end

        --ERROR|message
        if head == "ERROR" then
            overlay.add_msg(parts[2])
            if parts[2] and parts[2]:match("incompatible game version") then
                network.version_mismatch = true
            end
        end
    end
}