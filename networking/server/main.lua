-- networking/server/main.lua
enet = require("enet")
require("util")

ADDRESS = "0.0.0.0"
PORT = 2378

REQUIRED_GAME_VERSION = 23

host = enet.host_create(ADDRESS..":"..PORT)

-- this sucks
clients = {} -- = {client1, client2}
rooms = {} -- { [roomID] = {client1, client2}}
clientToRoomID = {} -- { [clientID] = roomID }
roomState = {} -- { [roomID] = { [connID] = {char="maddy", ready=false} } }

-- matchmaking
matchmakingQueue = {}
function processQueue()
    while #matchmakingQueue >= 2 do
        local p1 = table.remove(matchmakingQueue, 1)
        local p2 = table.remove(matchmakingQueue, 1)
        local roomID = "MATCH_" .. tostring(os.time()) .. tostring(math.random(1000, 9999))
        addClientToRoom(p1.peer, roomID, p1.username, p1.char, p1.skin)
        addClientToRoom(p2.peer, roomID, p2.username, p2.char, p2.skin)
    end
end

function love.load()
    math.randomseed(os.time()) -- math.random not automatically seeded
    if love.filesystem.getInfo("stats.txt") == nil then
        love.filesystem.write("stats.txt", "matches=0")
    end
end

function love.update()
    local event = host:service()
    while event do
        if event.type == "connect" then
            if event.data == REQUIRED_GAME_VERSION then
                addClient(event.peer)
            else
                event.peer:send("ERROR|incompatible game version")
                event.peer:disconnect_later()
            end
        elseif event.type == "disconnect" then
            removeClient(event.peer)
            clientCleanupSweep()
        elseif event.type == "receive" then
            processMessage(event)
        end

        event = host:service()
    end
end

function love.draw()
    love.graphics.print("Connected clients:", 0, 0)
    for i,c in ipairs(clients) do
        local room = clientToRoomID[c:connect_id()] or ""
        love.graphics.print("Client "..c:connect_id()..
                            ": state - "..c:state()..
                            "| ping - "..c:round_trip_time()..
                            "| room - "..room
                            , 0, 15*i)
    end

    local i = 0
    for k,v in pairs(roomState) do
        love.graphics.print("Room "..k, 0, 65+15*i)
        for a,b in pairs(v) do
            love.graphics.print("Client "..a, 65, 65+15*i)
        end
        i = i+1
    end
end

function love.quit()
    for i,c in ipairs(clients) do
        c:disconnect_now()
    end
end

function addClient(client)
    table.insert(clients, client)
    client:send("CONNECT|"..client:connect_id())
end

function removeClient(client)
    removeClientFromRoom(client)

    if matchmakingQueue then
        for i, queuedPlayer in ipairs(matchmakingQueue) do
            if queuedPlayer.peer:connect_id() == client:connect_id() then
                table.remove(matchmakingQueue, i)
                break
            end
        end
    end

    for i,c in ipairs(clients) do
        if c:connect_id() == client:connect_id() then
            table.remove(clients, i)
            return
        end
    end
end

function addClientToRoom(client, roomID, username, char, skin)
    if rooms[roomID] == nil then
        rooms[roomID] = {}
        roomState[roomID] = {}
    end

    for _, c in ipairs(rooms[roomID]) do
        if c:connect_id() == client:connect_id() then
            return
        end
    end

    if #rooms[roomID] >= 2 then
        client:send("ERROR|room is full")
        return
    end

    table.insert(rooms[roomID], client)
    clientToRoomID[client:connect_id()] = roomID

    roomState[roomID][client:connect_id()] = {char = char or "maddy", ready = false, wins = 0, username = username or "player", skin = tonumber(skin) or 1}

    client:send("CONNECT|"..client:connect_id())
    client:send('JOINROOM|'..roomID)

    if #rooms[roomID] == 2 then
        for _, c in ipairs(rooms[roomID]) do
            c:send("ROOMREADY|")
        end
        broadcastCSSState(roomID)
    end
end

function removeClientFromRoom(client)
    local connID = client:connect_id()
    local roomID = clientToRoomID[connID]
    if not roomID then return end

    for i,c in ipairs(rooms[roomID]) do
        if c:connect_id() == connID then
            table.remove(rooms[roomID], i)
            roomState[roomID][connID] = nil

            if #rooms[roomID] == 0 then
                rooms[roomID] = nil
                roomState[roomID] = nil
            else
                rooms[roomID].inGame = false
                local remainingClient = rooms[roomID][1]
                local remainingID = rooms[roomID][1]:connect_id()
                if string.sub(roomID, 1, 6) == "MATCH_" then
                    remainingClient:send("EXITROOM|")
                    remainingClient:send("CSSCANCEL|")
                    clientToRoomID[remainingID] = nil
                    rooms[roomID] = nil
                    roomState[roomID] = nil
                else
                    -- Un-ready the remaining player and update their CSS
                    roomState[roomID][remainingID].ready = false
                    remainingClient:send("CSSCANCEL|")
                end
            end

            clientToRoomID[connID] = nil
            client:send("EXITROOM|")
            return
        end
    end
end

-- if we have forced disconnects, it can leave orphan clients/rooms with no connID
function clientCleanupSweep()
    for i = #clients, 1, -1 do
        if clients[i]:connect_id() == 0 then
            table.remove(clients, i)
        end
    end

    for k,v in pairs(clientToRoomID) do
        if not cidExists(k) then
            if rooms[v] then
                for i = #rooms[v], 1, -1 do
                    local c = rooms[v][i]
                    if c:connect_id() == 0 or c:connect_id() == k then
                        table.remove(rooms[v], i)
                    end
                end

                roomState[v][k] = nil

                if #rooms[v] == 0 then
                    rooms[v] = nil
                    roomState[v] = nil
                else
                    rooms[v].inGame = false

                    local remainingClient = rooms[v][1]
                    local remainingID = remainingClient:connect_id()
                    if string.sub(v, 1, 6) == "MATCH_" then
                        remainingClient:send("EXITROOM|")
                        remainingClient:send("CSSCANCEL|")
                        clientToRoomID[remainingID] = nil
                        rooms[v] = nil
                        roomState[v] = nil
                    else
                        -- Un-ready the remaining player and update their CSS
                        roomState[v][remainingID].ready = false
                        remainingClient:send("CSSCANCEL|")
                    end
                end
            end
            clientToRoomID[k] = nil
        end
    end
end

function cidExists(cid)
    for _,c in ipairs(clients) do
        if c:connect_id() == cid then
            return true
        end
    end
    return false
end

function processMessage(event)
    if string.len(event.data) > 1024 then -- massive packet!
        event.peer:reset()
        return
    end
    local parts = util.split(event.data, "|")
    local head = parts[1]
    local body = parts[2] or ""
    local bodyParts = util.split(body, ",")
    local connID = event.peer:connect_id()
    local roomID = clientToRoomID[connID]
    local room = rooms[roomID]
    local inMatch = room and room.inGame

    if head == "JOINROOM" then
        removeClientFromRoom(event.peer) -- prevent multi-room stuff
        local raw_room = tostring(bodyParts[1] or ""):gsub("[|,%-:]", "")
        local raw_user = tostring(bodyParts[2] or "player"):gsub("[|,%-:]", "")
        local raw_char = tostring(bodyParts[3] or "maddy"):gsub("[|,%-:]", "")
        local safe_room = string.sub(raw_room, 1, 32)
        local safe_user = string.sub(raw_user, 1, 16)
        local safe_char = string.sub(raw_char, 1, 16)

        if safe_room and safe_room ~= "" then
            addClientToRoom(event.peer, safe_room, safe_user, safe_char, bodyParts[4]) 
        end
    end

    if head == "EXITROOM" then
        removeClientFromRoom(event.peer)
    end

    if head == "FRAME" then
        if string.len(event.data) < 256 then
            broadcastMessageToRoom(event, "unreliable")
        else
            event.peer:reset()
        end
    end

    if roomID and roomState[roomID] and roomState[roomID][connID] then
        
        if not inMatch then
            if head == "CSS_READY" then
                roomState[roomID][connID].ready = (body == "1")
                broadcastCSSState(roomID)
                checkRoomStart(roomID)
            end

            if head == "CSS_CHAR" then
                local safe_char = string.sub(tostring(body or ""):gsub("[|,%-:]", ""), 1, 16)
                roomState[roomID][connID].char = safe_char
                broadcastCSSState(roomID)
            end

            if head == "CSS_SKIN" then
                roomState[roomID][connID].skin = tonumber(body) or 1
                broadcastCSSState(roomID)
            end

            if head == "SSS_CURSOR" then
                roomState[roomID][connID].sss_cursor = tonumber(body) or 1
                broadcastSSSUpdate(roomID)
            end
                    
            if head == "SSS_READY" then
                local bParts = util.split(body, ",") 
                roomState[roomID][connID].sss_ready = (bParts[1] == "1")
                roomState[roomID][connID].sss_cursor = tonumber(bParts[2]) or 1
                roomState[roomID][connID].sss_vote = math.max(0, tonumber(bParts[3]) or 0)
                roomState[roomID][connID].num_stages = math.max(1, math.min(100, tonumber(bParts[4]) or 9))
                
                broadcastSSSUpdate(roomID)
                checkSSSStart(roomID)
            end

            if head == "SSS_CANCEL" then
                if roomID and rooms[roomID] then
                    for _, c in ipairs(rooms[roomID]) do
                        if roomState[roomID][c:connect_id()] then
                            roomState[roomID][c:connect_id()].sss_ready = false
                            roomState[roomID][c:connect_id()].sss_cursor = 1
                        end
                        c:send("SSSCANCEL|")
                    end
                end
            end
        end

        if head == "MATCHEND" then
            local room = rooms[roomID]
            if room then
                if room.inGame then
                    if body == "FORFEIT" then
                        room.inGame = false
                        room.matchResults = nil
                        for _, c in ipairs(room) do
                            roomState[roomID][c:connect_id()].ready = false
                            roomState[roomID][c:connect_id()].sss_ready = false
                            roomState[roomID][c:connect_id()].sss_cursor = 1
                            c:send("ROOMREADY|")
                        end
                        broadcastCSSState(roomID)
                    else
                        room.matchResults = room.matchResults or {}
                        room.matchResults[connID] = body
                        local claimCount = 0
                        for k, v in pairs(room.matchResults) do
                            claimCount = claimCount + 1
                        end
                        if claimCount == 2 then
                            room.inGame = false

                            local claim1 = room.matchResults[room[1]:connect_id()]
                            local claim2 = room.matchResults[room[2]:connect_id()]

                            if claim1 == claim2 then
                                local winnerID = tonumber(claim1) -- draw gets filtered out here
                                if winnerID and roomState[roomID][winnerID] then
                                    roomState[roomID][winnerID].wins = roomState[roomID][winnerID].wins + 1
                                end
                                incrementMatchesPlayed() 
                            else
                                -- they disagree, don't count it
                            end

                            for _, c in ipairs(room) do
                                roomState[roomID][c:connect_id()].ready = false
                                roomState[roomID][c:connect_id()].sss_ready = false
                                roomState[roomID][c:connect_id()].sss_cursor = 1
                                c:send("ROOMREADY|")
                            end
                            room.matchResults = nil
                            broadcastCSSState(roomID)
                        end
                    end
                else
                    -- severe desync or someone's sending out of game MATCHENDs
                end
            end
        end
    end

    if head == "JOINQUEUE" then 
        removeClientFromRoom(event.peer)

        local alreadyInQueue = false
        for _, queuedPlayer in ipairs(matchmakingQueue) do
            if queuedPlayer.peer:connect_id() == event.peer:connect_id() then
                alreadyInQueue = true
                break
            end
        end
        
        if not alreadyInQueue then
            local raw_user = tostring(bodyParts[1] or "player"):gsub("[|,%-:]", "")
            local raw_char = tostring(bodyParts[2] or "maddy"):gsub("[|,%-:]", "")
            local safe_username = string.sub(raw_user, 1, 16)
            local safe_char = string.sub(raw_char, 1, 16)
            table.insert(matchmakingQueue, {
                peer = event.peer, 
                username = safe_username, 
                char = safe_char,
                skin = tonumber(bodyParts[3]) or 1
            })
            processQueue()
        end
    end
    
    if head == "LEAVEQUEUE" then
        for i, queuedPlayer in ipairs(matchmakingQueue) do
            if queuedPlayer.peer:connect_id() == event.peer:connect_id() then
                table.remove(matchmakingQueue, i)
                break
            end
        end
    end
end

function broadcastCSSState(roomID)
    local msg = "CSSUPDATE|"
    for _, c in ipairs(rooms[roomID]) do
        local st = roomState[roomID][c:connect_id()]
        local readyStr = st.ready and "1" or "0"
        msg = msg .. c:connect_id() .. "," .. st.char .. "," .. readyStr .. "," .. st.wins .. "," .. st.skin .. "," .. st.username .. "-"
    end
    msg = msg:sub(1, -2)

    for _, c in ipairs(rooms[roomID]) do
        c:send(msg)
    end
end

function checkRoomStart(roomID)
    if #rooms[roomID] == 2 then
        local allReady = true
        for _, c in ipairs(rooms[roomID]) do
            if not roomState[roomID][c:connect_id()].ready then allReady = false end
        end

        if allReady then
            local msg = "SSS_START|"
            for _,c in ipairs(rooms[roomID]) do
                roomState[roomID][c:connect_id()].sss_ready = false
                roomState[roomID][c:connect_id()].sss_cursor = 1
                msg = msg .. c:connect_id() .. ":" .. roomState[roomID][c:connect_id()].char .. ":"
                                            .. roomState[roomID][c:connect_id()].username .. ":"
                                            .. tostring(roomState[roomID][c:connect_id()].skin) .. ","
            end
            msg = msg:sub(1, -2)

            for _,c in ipairs(rooms[roomID]) do c:send(msg) end
        end
    end
end

function broadcastSSSUpdate(roomID)
    local msg = "SSSUPDATE|"
    for _, c in ipairs(rooms[roomID]) do
        local state = roomState[roomID][c:connect_id()]
        local readyStr = state.sss_ready and "1" or "0"
        local cursor = state.sss_cursor or 1
        msg = msg .. c:connect_id() .. "," .. cursor .. "," .. readyStr .. "-"
    end
    msg = msg:sub(1, -2)
    
    for _, c in ipairs(rooms[roomID]) do
        c:send(msg)
    end
end

function checkSSSStart(roomID)
    if #rooms[roomID] == 2 then
        local allReady = true
        for _, c in ipairs(rooms[roomID]) do
            if not roomState[roomID][c:connect_id()].sss_ready then allReady = false end
        end

        if allReady then
            rooms[roomID].inGame = true

            local choices = {}
            local max_stages = 1
            
            for _, c in ipairs(rooms[roomID]) do
                local state = roomState[roomID][c:connect_id()]
                local vote = state.sss_vote or 0 
                if state.num_stages then max_stages = state.num_stages end

                if vote == 0 then
                    table.insert(choices, math.random(1, max_stages))
                else
                    table.insert(choices, vote)
                end
            end
            
            local winning_stage = choices[math.random(1, #choices)]

            local p1_ping = rooms[roomID][1]:round_trip_time()
            local p2_ping = rooms[roomID][2]:round_trip_time()
            local worst_ping = math.max(p1_ping, p2_ping)

            for i, c in ipairs(rooms[roomID]) do
                local my_ping = (i == 1) and p1_ping or p2_ping
                local wait_time_ms = (worst_ping - my_ping) / 2
                local wait_frames = math.floor(wait_time_ms / 33.3)
                wait_frames = math.max(0, math.min(15, wait_frames))
                local msg = "START|" .. winning_stage .. "|" .. wait_frames
                c:send(msg)
            end
        end
    end
end

function broadcastMessageToRoom(event, flag)
    local room = rooms[clientToRoomID[event.peer:connect_id()]]
    if not room then return end
    for _,c in ipairs(room) do
        if c:connect_id() ~= event.peer:connect_id() then
            c:send(event.data, 0, flag or "reliable")
        end
    end
end

function incrementMatchesPlayed()
    local stats = love.filesystem.read("stats.txt")
    if stats then
        local parts = util.split(stats, "=")
        if parts and #parts >= 2 then
            local val = tonumber(parts[2]) or 0
            love.filesystem.write("stats.txt", parts[1] .. "=" .. tostring(val + 1))
            return
        end
    end
    love.filesystem.write("stats.txt", "matches=1")
end
