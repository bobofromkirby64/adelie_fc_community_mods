-- title.lua
require("input")
require("overlay")
require("controller")
require("replay")
local config = require("config")

local roomCode = ""
local username = config["username"] or ""
local titleState = "init" -- init, code, username, mode, options, searching, waiting, controls, replay_wait

local selected_mode = 1
local selected_option = 1
local options_scroll = 1
local max_visible_options = 5
local changing_option = false

local selected_control = 1
local changing_control = false
local just_remapped = false
local current_val = 0

local replay_files = {}
local replay_selected = 1
local replay_scroll = 1
local max_visible_replays = 4
local replay_acting = false
local replay_action_selected = 1
local replay_actions = {" play ", "delete", "cancel"}
local replay_das_timer = 0
local replay_das_dir = 0

local server_ip_input = config["server_ip"] or "3.129.71.135"

local anim_offset_y = 0

title = {}

-- useful stuff

local function formatVersion(v)
    if v < 10 then return "0.0." .. v end
    local patch = v % 10
    local minor = math.floor(v / 10) % 10
    local major = math.floor(v / 100)
    return string.format("%d.%d.%d", major, minor, patch)
end

local function boxedText(boxX, boxY, boxWidth, boxHeight, boxFill, boxOutline, textColor, text, isSelected)
    local pop = isSelected and -2 or 0
    local shadow_offset = isSelected and 3 or 3
    
    love.graphics.setColor(util.color(0))
    love.graphics.rectangle("fill", (boxX - 1) + shadow_offset, (boxY - 1) + shadow_offset, boxWidth + 2, boxHeight + 2)
    love.graphics.setColor(util.color(boxFill))
    love.graphics.rectangle("fill", boxX, boxY + pop, boxWidth, boxHeight)
    love.graphics.setColor(util.color(boxOutline))
    love.graphics.rectangle("line", boxX-1, boxY-1 + pop, boxWidth+2, boxHeight+2)

    local textX = boxX + math.floor(boxWidth/2) - (#text*4)/2
    local textY = boxY + math.floor(boxHeight/2) - 2
    love.graphics.setColor(util.color(textColor))
    love.graphics.print(text, textX, textY + pop)
end

local function drawInputScreen(promptText, inputText, t)
    local promptY = 66
    
    love.graphics.setColor(util.color(0))
    love.graphics.print(promptText, GAME_WIDTH/2 - (#promptText * 2) + 1, promptY + 1)
    love.graphics.setColor(util.color(7))
    love.graphics.print(promptText, GAME_WIDTH/2 - (#promptText * 2), promptY)

    local boxWidth = 80
    local boxX = GAME_WIDTH/2 - boxWidth/2
    local boxY = 76

    love.graphics.setColor(util.color(0))
    love.graphics.rectangle("fill", (boxX - 1) + 3, (boxY - 1) + 3, boxWidth + 2, 16)
    love.graphics.setColor(util.color(1))
    love.graphics.rectangle("fill", boxX, boxY, boxWidth, 14)
    love.graphics.setColor(util.color(9))
    love.graphics.rectangle("line", boxX - 1, boxY - 1, boxWidth + 2, 16)

    local font = love.graphics.getFont()
    local textWidth = font:getWidth(inputText)

    local codeX = math.floor(GAME_WIDTH/2 - textWidth/2)
    love.graphics.setColor(util.color(7))
    love.graphics.print(inputText, codeX, boxY + 4)

    if math.floor(t * 3) % 2 == 0 then
        love.graphics.print("_", codeX + textWidth, boxY + 4)
    end
end

local function mappingListener(config_key)
    local function isKeyAlreadyMapped(k, device)
        if device == "gamepad" then
            local current_pads = {
                up = config["pad_up"] or "dpup",
                down = config["pad_down"] or "dpdown",
                left = config["pad_left"] or "dpleft",
                right = config["pad_right"] or "dpright",
                b1 = config["pad_b1"] or "a",
                b2 = config["pad_b2"] or "b"
            }
            current_pads[config_key] = nil 
            for _, mapped_key in pairs(current_pads) do
                if mapped_key == k then return true end
            end
        else
            if k == "escape" or k == "return" then return true end
            local current_kbs = {
                up = config["kb_up"] or "up",
                down = config["kb_down"] or "down",
                left = config["kb_left"] or "left",
                right = config["kb_right"] or "right",
                b1 = config["kb_b1"] or "z",
                b2 = config["kb_b2"] or "x"
            }
            current_kbs[config_key] = nil 
            for _, mapped_key in pairs(current_kbs) do
                if mapped_key == k then return true end
            end
        end
        return false
    end

    changing_control = true
    input.setTextListener(function(t, device)
        if isKeyAlreadyMapped(t, device) then
            love.audio.play("menu_back", "static")
            input.setTextListener(function() end)
            just_remapped = true
            return
        end
        local prefix = (device == "gamepad") and "pad_" or "kb_"
        config[prefix .. config_key] = t
        saveConfig()
        love.audio.play("menu_select", "static")
        input.setTextListener(function() end)
        just_remapped = true
    end)
end

local function boxedDualBind(boxX, boxY, boxWidth, boxHeight, boxOutline, inpColor, textColor, inp, kb_bind, pad_bind, isSelected, isActive)
    local pop = isSelected and -2 or 0
    local shadow_offset = isSelected and 3 or 3

    love.graphics.setColor(util.color(0))
    love.graphics.rectangle("fill", (boxX - 1) + shadow_offset, (boxY - 1) + shadow_offset, boxWidth + 2, boxHeight + 2)
    love.graphics.setColor(util.color(1))
    love.graphics.rectangle("fill", boxX, boxY + pop, boxWidth, boxHeight)
    love.graphics.setColor(util.color(boxOutline))
    love.graphics.rectangle("line", boxX-1, boxY-1 + pop, boxWidth+2, boxHeight+2)

    if isActive then
        love.graphics.setColor(util.color(10))
        -- wait for input
        local prompt = "waiting..."
        local textX = boxX + math.floor(boxWidth/2) - (#prompt*4)/2
        local textY = boxY + math.floor(boxHeight/2) - 2
        love.graphics.print(prompt, textX, textY + pop)
    else
        love.graphics.setColor(util.color(inpColor))
        local inpX = boxX + math.floor(boxWidth/2) - (#inp*4)/2
        love.graphics.print(inp, inpX, boxY + 2 + pop)

        local padding = 4
        local icon_w = 8
        local space = 2

        -- left align kb input
        love.graphics.setColor(1, 1, 1, 1)
        sprites.draw(sprites["ui/icon_kb"], boxX + padding - 1, boxY + 10 + pop)
        
        love.graphics.setColor(util.color(textColor))
        love.graphics.print(kb_bind, boxX + padding + icon_w + space, boxY + 12 + pop)
        
        -- right align pad input
        local pad_text_w = #pad_bind * 4
        local right_start_x = boxX + boxWidth - padding - icon_w - space - pad_text_w
        
        love.graphics.print(pad_bind, right_start_x, boxY + 12 + pop)
        
        love.graphics.setColor(1, 1, 1, 1)
        sprites.draw(sprites["ui/icon_pad"], right_start_x + pad_text_w + space + 1, boxY + 10 + pop)
    end
end

local function refreshReplayList()
    replay_files = {}
    if love.filesystem.getInfo("replays") then
        local items = love.filesystem.getDirectoryItems("replays")
        for _, item in ipairs(items) do
            if item:sub(-4) == ".txt" then
                local content = love.filesystem.read("replays/" .. item)
                local replayData = replay.loadFromString(content)
                if replayData then
                    local p1_name = replayData.playerData[1].username or "p1"
                    local p2_name = replayData.playerData[2].username or "p2"
                    local base_name = item:sub(1, -5)
                    local time_match = base_name:match("^replay_(%d+)$")
                    local display_name = ""
                    if time_match and tonumber(time_match) > 1000000000 then
                        display_name = os.date("%Y-%m-%d %H:%M", tonumber(time_match))
                    else
                        display_name = string.sub(base_name, 1, 16)
                    end
                    table.insert(replay_files, {
                        filename = item,
                        p1 = p1_name,
                        p2 = p2_name,
                        display_name = display_name
                    })
                else
                    -- invalid replay file
                end
            end
        end
    end
    
    -- sort by filename (newest on top if not renamed)
    table.sort(replay_files, function(a, b) return a.filename > b.filename end)
    
    if replay_selected > #replay_files and #replay_files > 0 then
        replay_selected = #replay_files
    end

    local max_scroll = math.max(1, #replay_files - max_visible_replays + 1)
    if replay_scroll > max_scroll then
        replay_scroll = max_scroll
    end
end

local function deleteOldReplays()
    local time_limit
    if REPLAY_DELETION == 0 then return
    elseif REPLAY_DELETION == 6 then time_limit = 1 * 24 * 3600
    elseif REPLAY_DELETION == 5 then time_limit = 3 * 24 * 3600
    elseif REPLAY_DELETION == 4 then time_limit = 5 * 24 * 3600
    elseif REPLAY_DELETION == 3 then time_limit = 7 * 24 * 3600
    elseif REPLAY_DELETION == 2 then time_limit = 2 * 7 * 24 * 3600
    elseif REPLAY_DELETION == 1 then time_limit = 4 * 7 * 24 * 3600
    else return end

    replay_files = {}
    if love.filesystem.getInfo("replays") then
        local items = love.filesystem.getDirectoryItems("replays")
        for _, item in ipairs(items) do
            if item:sub(-4) == ".txt" then
                local content = love.filesystem.read("replays/" .. item)
                local replayData = replay.loadFromString(content)
                if replayData then
                    local base_name = item:sub(1, -5)
                    local time_match = base_name:match("^replay_(%d+)$")
                    if time_match then
                        if math.abs(tonumber(time_match) - tonumber(os.time())) > time_limit then love.filesystem.remove("replays/" .. item) end
                    end
                end
            end
        end
    end
end

local function isValidIP(ip)
    if ip == "0.0.0.0" then return false end
    local o1, o2, o3, o4 = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if o1 and o2 and o3 and o4 then
        if tonumber(o1) <= 255 and tonumber(o2) <= 255 and 
           tonumber(o3) <= 255 and tonumber(o4) <= 255 then
            return true
        end
    end
    return false
end

local server_list = {}

local function getServerListIndex(ip)
    for i, srv in ipairs(server_list) do
        if srv.ip == ip then return i end
    end
    return #server_list + 1
end

local function loadServerList()
    if love.filesystem.getInfo("server_list.txt") then
        local contents = love.filesystem.read("server_list.txt")
        for line in string.gmatch(contents, "[^\r\n]+") do
            if not line:match("^%s*#") and line:match("%S") then
                local name, ip = string.match(line, "^(.-)=(.+)$")
                if name and ip then
                    name = name:match("^%s*(.-)%s*$")
                    ip = ip:match("^%s*(.-)%s*$")
                    table.insert(server_list, { name = name, ip = ip })
                end
            end
        end
    else
        local default_content = "# Adelie Fight Club - Server List\n" ..
                                "# Format: Server Name = IP Address\n\n" ..
                                "us-east=3.129.71.135\n"
        love.filesystem.write("server_list.txt", default_content)
        server_list = {
            { name = "us-east", ip = "3.129.71.135" },
        }
    end
end
loadServerList()

-- menu defs

local mode_menu = {
    {
        label = "quickplay",
        onEnter = function() title.changeState("searching"); cpuID = -1 end
    },
    {
        label = "room",
        onEnter = function() title.changeState("code"); cpuID = -1 end
    },
    {
        label = "practice",
        onEnter = function() connectionID = 1; cpuID = 2; gameController.enterCSS("TRAINING") end
    },
    {
        label = "replays",
        onEnter = function() replay_selected = 1; replay_scroll = 1; title.changeState("replay_browser") end
    },
    {
        label = "config",
        onEnter = function() title.changeState("options"); changing_option = false; selected_option = 1; options_scroll = 1 end
    },
    {
        label = "controls",
        onEnter = function() title.changeState("controls"); changing_control = false end
    }
}

local options_menu = {
    {
        type = "button",
        getText = function(active, val) return "username : " .. username end,
        onEnter = function() title.changeState("username") end
    },
    {
        type = "slider",
        min = 1, max = #server_list + 1,
        getValue = function() return getServerListIndex(config["server_ip"] or "3.129.71.135") end,
        getText = function(active, val) 
            local current_ip = config["server_ip"] or "3.129.71.135"
            local check_val = active and val or getServerListIndex(current_ip)
            local display_text = check_val <= #server_list and (server_list[check_val].name) or (active and "manual ip" or current_ip)
            return active and "< server : " .. display_text .. " >" or "server : " .. display_text
        end,
        onSave = function(val)
            if val <= #server_list then title.autoTestIP = server_list[val].ip title.changeState("auto_connect", true) else title.changeState("server_ip") end
        end
    },
    {
        type = "slider",
        min = 1, max = 32,
        getValue = function() return WINDOW_SCALE end,
        getText = function(active, val) return active and ("< window scale : " .. val .. "x >") or ("window scale : " .. WINDOW_SCALE .. "x") end,
        onSave = function(val) WINDOW_SCALE = val; config["window_scale"] = val; saveConfig(); refresh_window() end
    },
    {
        type = "slider",
        min = 0, max = 1,
        getValue = function() return config["fullscreen"] or 0 end,
        getText = function(active, val) return active and ("< fullscreen : " .. (val == 1 and "on" or "off") .. " >") or ("fullscreen : " .. (IS_FULLSCREEN and "on" or "off")) end,
        onSave = function(val) IS_FULLSCREEN = (val == 1); config["fullscreen"] = val; saveConfig(); refresh_window() end
    },
    {
        type = "slider",
        min = 0, max = 10,
        getValue = function() return config["vol_music"] or 8 end,
        getText = function(active, val) return active and ("< music volume : " .. val .. " >") or ("music volume : " .. VOL_MUSIC) end,
        onChange = function(val) VOL_MUSIC = val; bgMusic:setVolume(val * 0.05) end,
        onCancel = function() VOL_MUSIC = config["vol_music"] or 8; bgMusic:setVolume(VOL_MUSIC * 0.05) end,
        onSave = function(val) VOL_MUSIC = val; config["vol_music"] = val; bgMusic:setVolume(val * 0.05); saveConfig() end
    },
    {
        type = "slider",
        min = 0, max = 10,
        getValue = function() return config["vol_sfx"] or 8 end,
        getText = function(active, val) return active and ("< sfx volume : " .. val .. " >") or ("sfx volume : " .. VOL_SFX) end,
        onChange = function(val) VOL_SFX = val end,
        onCancel = function() VOL_SFX = config["vol_sfx"] or 8 end,
        onSave = function(val) VOL_SFX = val; config["vol_sfx"] = val; saveConfig() end
    },
    {
        type = "slider",
        min = 0, max = 1,
        getValue = function() return config["debug"] or 0 end,
        getText = function(active, val) return active and ("< debug mode in solo : " .. (val == 1 and "on" or "off") .. " >") or ("debug mode in solo : " .. (DEBUG_SOLO and "on" or "off")) end,
        onCancel = function() DEBUG_SOLO = config["debug"] or 0 end,
        onSave = function(val) DEBUG_SOLO = (val == 1); config["debug"] = val; saveConfig(); end
    },
    {
        type = "slider",
        min = 0, max = 6,
        getValue = function() return config["replay_deletion"] or 0 end,
        getText = function(active, val)
            local display_val = active and val or (config["replay_deletion"] or 0)

            local labels = {
                [0] = "never",
                [1] = "1 month",
                [2] = "2 weeks",
                [3] = "1 week",
                [4] = "5 days",
                [5] = "3 days",
                [6] = "1 day"
            }
            local label = labels[display_val] or "never"

            if active then return "< delete replays older than : " .. label .. " >" else return "delete replays older than : " .. label end
        end,
        onSave = function(val) REPLAY_DELETION = (val); config["replay_deletion"] = val; saveConfig(); end
    }
}

local controls_menu = {
    { inp = "U", id = "up",    def_kb = "up",    def_pad = "dpup",    onEnter = function() mappingListener("up") end },
    { inp = "D", id = "down",  def_kb = "down",  def_pad = "dpdown",  onEnter = function() mappingListener("down") end },
    { inp = "L", id = "left",  def_kb = "left",  def_pad = "dpleft",  onEnter = function() mappingListener("left") end },
    { inp = "R", id = "right", def_kb = "right", def_pad = "dpright", onEnter = function() mappingListener("right") end },
    { inp = "O", id = "b1",    def_kb = "z",     def_pad = "a",       onEnter = function() mappingListener("b1") end },
    { inp = "X", id = "b2",    def_kb = "x",     def_pad = "b",       onEnter = function() mappingListener("b2") end },
    { 
        is_button = true, 
        label = "restore defaults", 
        onEnter = function()
            config["kb_up"] = "up"; config["pad_up"] = "dpup"
            config["kb_down"] = "down"; config["pad_down"] = "dpdown"
            config["kb_left"] = "left"; config["pad_left"] = "dpleft"
            config["kb_right"] = "right"; config["pad_right"] = "dpright"
            config["kb_b1"] = "z"; config["pad_b1"] = "a"
            config["kb_b2"] = "x"; config["pad_b2"] = "b"
            saveConfig()
            love.audio.play("menu_select", "static")
        end
    }
}

-- state machine

local state_handlers
state_handlers = {
    init = {
        overlay = "O : start | esc : quit",
        update = function()
            if input.getKeyPressed("escape") then
                love.event.quit()
            elseif input.checkPressed("b1") or input.getKeyPressed("return") then
                if username == "" then
                    title.changeState("username")
                else
                    title.changeState("mode")
                end
                love.audio.play("menu_select", "static")
            end
        end,
        draw = function(t)
            local prompt = "press start"
            if math.floor(t * 2) % 2 == 0 then
                love.graphics.setColor(util.color(0))
                love.graphics.print(prompt, GAME_WIDTH/2 - (#prompt * 2) + 1, 90 + 1)
                love.graphics.setColor(util.color(7))
                love.graphics.print(prompt, GAME_WIDTH/2 - (#prompt * 2), 90)
            end

            local credits = "ruby | meep | petra | gonen | cominixo"
            love.graphics.setColor(util.color(0)) 
            love.graphics.print(credits, GAME_WIDTH/2 - (#credits * 2) + 1, 110 + 1)
            love.graphics.setColor(util.color(5)) 
            love.graphics.print(credits, GAME_WIDTH/2 - (#credits * 2), 110)
        end
    },
    
    searching = {
        overlay = "X : cancel matchmaking",
        onEnter = function() network.joinQueue(username) end,
        update = function()
            if input.checkPressed("b2") then
                network.leaveQueue()
                title.changeState("mode")
                love.audio.play("menu_back", "static")
            end
        end,
        draw = function(t)
            local searchPrompt = "searching for opponent..."
            local cancelPrompt = "press cancel to go back"
            
            love.graphics.setColor(util.color(0))
            love.graphics.print(searchPrompt, GAME_WIDTH/2 - (#searchPrompt * 2) + 1, 105)
            if math.floor(t * 4) % 2 == 0 then
                love.graphics.setColor(util.color(10))
            else
                love.graphics.setColor(util.color(9))
            end
            love.graphics.print(searchPrompt, GAME_WIDTH/2 - (#searchPrompt * 2), 104)

            love.graphics.setColor(util.color(5))
            love.graphics.print(cancelPrompt, GAME_WIDTH/2 - (#cancelPrompt * 2), 114)
        end
    },
    
    waiting = {
        overlay = "X : cancel",
        update = function()
            if input.checkPressed("b2") then
                network.exitRoom() 
                love.audio.play("menu_back", "static")
            end
        end,
        draw = function(t)
            local waitPrompt = "waiting for player 2..."
            local cancelPrompt = "press cancel to go back"

            love.graphics.setColor(util.color(0))
            love.graphics.print(waitPrompt, GAME_WIDTH/2 - (#waitPrompt * 2) + 1, 105)
            if math.floor(t * 4) % 2 == 0 then
                love.graphics.setColor(util.color(10))
            else
                love.graphics.setColor(util.color(9))
            end
            love.graphics.print(waitPrompt, GAME_WIDTH/2 - (#waitPrompt * 2), 104)

            love.graphics.setColor(util.color(5))
            love.graphics.print(cancelPrompt, GAME_WIDTH/2 - (#cancelPrompt * 2), 114)
        end
    },
    
    code = {
        overlay = "enter : join room | esc : back",
        onEnter = function()
            input.setTextListener(function(t)
                if t=="backspace" then
                    roomCode = string.sub(roomCode, 1, -2)
                    love.audio.play("menu_text", "static", false, false)
                elseif #roomCode < 16 and t:match("^[%w]$") then
                    love.audio.play("menu_text", "static", false, false)
                    roomCode = roomCode .. string.lower(t)
                end
            end)
        end,
        update = function()
            if input.getKeyPressed("escape") then
                title.changeState("mode")
                love.audio.play("menu_back", "static")
            elseif input.getKeyPressed("return") then
                network.joinRoom(roomCode, username)
                love.audio.play("menu_select", "static")
            end
        end,
        draw = function(t)
            drawInputScreen("room code:", roomCode, t)
        end
    },
    
    username = {
        overlay = "enter : confirm | esc : back",
        onEnter = function()
            input.setTextListener(function(t)
                if t=="backspace" then
                    username = string.sub(username, 1, -2)
                elseif #username < 8 and t:match("^[%w]$") then
                    love.audio.play("menu_text", "static", false, false)
                    username = username .. string.lower(t)
                end
            end)
        end,
        update = function()
            if input.getKeyPressed("escape") then
                username = config["username"] or ""
                if changing_option then
                    title.changeState("options")
                    changing_option = false
                else
                    title.changeState("init")
                end
                love.audio.play("menu_back", "static")
            elseif input.getKeyPressed("return") and username ~= "" then
                if changing_option then
                    title.changeState("options")
                    changing_option = false
                else
                    title.changeState("mode")
                end
                love.audio.play("menu_select", "static")
                config["username"] = username
                saveConfig()
            end
        end,
        draw = function(t)
            drawInputScreen("username:", username, t)
        end
    },
    
    mode = {
        overlay = "UDLR : navigate | O : choose mode | X : back",
        update = function()
            if input.checkPressed("b2") then
                title.changeState("init")
                love.audio.play("menu_back", "static")
            elseif input.checkPressed("b1") then
                mode_menu[selected_mode].onEnter()
                love.audio.play("menu_select", "static")
            elseif input.checkPressed("left") then
                local col = (selected_mode - 1) % 3
                local row_start = selected_mode - col
                selected_mode = row_start + (col + 2) % 3
                love.audio.play("menu_text", "static", false, false)
            elseif input.checkPressed("right") then
                local col = (selected_mode - 1) % 3
                local row_start = selected_mode - col
                selected_mode = row_start + (col + 1) % 3
                love.audio.play("menu_text", "static", false, false)
            elseif input.checkPressed("up") or input.checkPressed("down") then
                if selected_mode <= 3 then
                    selected_mode = selected_mode + 3
                else
                    selected_mode = selected_mode - 3
                end
                love.audio.play("menu_text", "static", false, false)
            end
        end,
        draw = function(t)
            local boxY = 76
            local row_height = 13
            local row_spacing = 8
            local spacing = 8

            for row = 1, 2 do
                local total_width = 0
                local item_widths = {}
                -- total row width
                for col = 1, 3 do
                    local i = (row - 1) * 3 + col
                    local item = mode_menu[i]
                    if item then
                        local w = (#item.label * 4) + 8 
                        item_widths[col] = w
                        total_width = total_width + w
                    end
                end
                -- starting x to enter row
                local currentX = math.floor(GAME_WIDTH / 2 - (total_width + spacing * 2) / 2)
                local currentY = boxY + (row - 1) * (row_height + row_spacing)
                -- draw buttons
                for col = 1, 3 do
                    local i = (row - 1) * 3 + col
                    local item = mode_menu[i]
                    if item then
                        local is_selected = (selected_mode == i)
                        boxedText(currentX, currentY, item_widths[col], row_height, 1, is_selected and 9 or 5, 7, item.label, is_selected)
                        currentX = currentX + item_widths[col] + spacing
                    end
                end
            end
        end
    },
    
    options = {
        hideLogo = true,
        overlay = "UD : navigate | O : choose option | X : back",
        update = function()
            local active_opt = options_menu[selected_option]
            local default_overlay = "UD : navigate | O : choose option | X : back"
            
            if changing_option then
                if input.checkPressed("b2") then
                    changing_option = false
                    overlay.setInputDisplay(default_overlay)
                    if active_opt.onCancel then active_opt.onCancel() end
                    love.audio.play("menu_back", "static")
                elseif input.checkPressed("b1") then
                    changing_option = false
                    overlay.setInputDisplay(default_overlay)
                    if active_opt.onSave then active_opt.onSave(current_val) end
                    love.audio.play("menu_select", "static")
                elseif input.checkPressed("right") then
                    local next_val = math.min(active_opt.max, current_val + 1)
                    if next_val ~= current_val then
                        current_val = next_val
                        if active_opt.onChange then active_opt.onChange(current_val) end
                        love.audio.play("menu_text", "static", false, false)
                    end
                elseif input.checkPressed("left") then
                    local next_val = math.max(active_opt.min, current_val - 1)
                    if next_val ~= current_val then
                        current_val = next_val
                        if active_opt.onChange then active_opt.onChange(current_val) end
                        love.audio.play("menu_text", "static", false, false)
                    end
                end
            else
                if input.checkPressed("b2") then
                    title.changeState("mode")
                    love.audio.play("menu_back", "static")
                elseif input.checkPressed("b1") then
                    if active_opt.type == "button" then
                        active_opt.onEnter()
                    elseif active_opt.type == "slider" then
                        overlay.setInputDisplay("LR : change value | O : confirm | X : cancel")
                        changing_option = true
                        current_val = active_opt.getValue()
                    end
                    love.audio.play("menu_select", "static", false, false)
                elseif input.checkPressed("up") then
                    selected_option = (selected_option - 2) % #options_menu + 1
                    if selected_option == #options_menu then
                        options_scroll = math.max(1, #options_menu - max_visible_options + 1)
                    elseif selected_option < options_scroll then
                        options_scroll = selected_option
                    end
                    love.audio.play("menu_text", "static", false, false)
                    
                elseif input.checkPressed("down") then
                    selected_option = selected_option % #options_menu + 1
                    if selected_option == 1 then
                        options_scroll = 1
                    elseif selected_option >= options_scroll + max_visible_options then
                        options_scroll = selected_option - max_visible_options + 1
                    end
                    love.audio.play("menu_text", "static", false, false)
                end
            end
        end,
        draw = function(t)
            local padding = 8
            local startY = 16
            local boxWidth = GAME_WIDTH - padding * 2
            local boxHeight = 13

            for i = 0, max_visible_options - 1 do
                local idx = options_scroll + i
                if idx <= #options_menu then
                    local opt = options_menu[idx]
                    local is_selected = (selected_option == idx)
                    local is_active = (is_selected and changing_option)
                    local text = opt.getText(is_active, current_val)
                    
                    local boxY = startY + (i * (boxHeight + padding))
                    local outlineColor = is_selected and 9 or 5
                    local textColor = is_active and 10 or 7
                    
                    boxedText(padding, boxY, boxWidth, boxHeight, 1, outlineColor, textColor, text, is_selected)
                end
            end
            love.graphics.setColor(util.color(6))
            if options_scroll > 1 then
                love.graphics.print("U", GAME_WIDTH/2 - 2, startY - 10)
            end
            if options_scroll + max_visible_options <= #options_menu then
                love.graphics.print("D", GAME_WIDTH/2 - 2, startY + (max_visible_options * (boxHeight + padding)) - padding + 4)
            end
        end
    },

    controls = {
        hideLogo = true,
        overlay = "UDLR : navigate | O : choose input | X : back",
        update = function()
            if just_remapped then
                just_remapped = false
                changing_control = false
                return 
            end

            local active_opt = controls_menu[selected_control]

            if not changing_control then
                if input.checkPressed("b2") then
                    title.changeState("mode")
                    love.audio.play("menu_back", "static")
                elseif input.checkPressed("b1") then
                    active_opt.onEnter()
                elseif input.checkPressed("up") then
                    if selected_control == 7 then selected_control = 5
                    elseif selected_control > 2 then selected_control = selected_control - 2
                    else selected_control = selected_control + 4 end 
                    love.audio.play("menu_text", "static", false, false)
                elseif input.checkPressed("down") then
                    if selected_control == 7 then selected_control = 1 
                    elseif selected_control == 5 or selected_control == 6 then selected_control = 7
                    else selected_control = selected_control + 2 end
                    love.audio.play("menu_text", "static", false, false)
                elseif input.checkPressed("right") then
                    if selected_control ~= 7 then
                        selected_control = (selected_control % 2 ~= 0) and (selected_control + 1) or (selected_control - 1)
                        love.audio.play("menu_text", "static", false, false)
                    end
                elseif input.checkPressed("left") then
                    if selected_control ~= 7 then
                        selected_control = (selected_control % 2 == 0) and (selected_control - 1) or (selected_control + 1)
                        love.audio.play("menu_text", "static", false, false)
                    end
                end
            end
        end,
        draw = function(t)
            local padding = 10
            local boxHeight = 19 
            local startY = 20 
            local rowSpacing = 8 

            for i, opt in ipairs(controls_menu) do
                local is_selected = (selected_control == i)
                local is_active = (is_selected and changing_control)
                
                local outlineColor = is_selected and 9 or 5
                local defaultsColor = 7
                local textColor = 13
                local inpColor = 7

                local boxX, boxY, boxWidth
                
                if opt.is_button then
                    boxX = padding
                    boxY = startY + 3 * (boxHeight + rowSpacing)
                    boxWidth = GAME_WIDTH - padding * 2

                    boxedText(boxX, boxY, boxWidth, boxHeight, 1, outlineColor, defaultsColor, opt.label, is_selected)
                else
                    boxWidth = GAME_WIDTH/2 - padding * 2
                    local row = math.ceil(i / 2)
                    local col = (i - 1) % 2 + 1
                    boxX = (col == 1) and padding or (GAME_WIDTH - padding - boxWidth)
                    boxY = startY + (row - 1) * (boxHeight + rowSpacing)

                    local kb_bind = config["kb_" .. opt.id] or opt.def_kb
                    local pad_bind = config["pad_" .. opt.id] or opt.def_pad

                    boxedDualBind(boxX, boxY, boxWidth, boxHeight, outlineColor, inpColor, textColor, opt.inp, kb_bind, pad_bind, is_selected, is_active)
                end
            end
        end
    },

    replay_browser = {
        hideLogo = true,
        overlay = "UD : navigate | O : select | X : back",
        onEnter = function()
            deleteOldReplays()
            refreshReplayList()
            replay_acting = false
        end,
        update = function()
            local default_overlay = "UD : navigate | O : select | X : back"
            local acting_overlay = "LR : choose action | O : confirm | X : cancel"

            if replay_acting then
                if input.checkPressed("b2") then
                    replay_acting = false
                    overlay.setInputDisplay(default_overlay)
                    love.audio.play("menu_back", "static")
                elseif input.checkPressed("b1") then
                    love.audio.play("menu_select", "static")
                    -- play
                    if replay_action_selected == 1 then
                        local filename = "replays/" .. replay_files[replay_selected].filename
                        local content = love.filesystem.read(filename)
                        local replayData = replay.loadFromString(content)
                        if replayData then
                            gameController.gameStart(replayData.stageIdx, replayData.playerData, "REPLAY", replayData)
                        end
                    -- delete
                    elseif replay_action_selected == 2 then
                        love.filesystem.remove("replays/" .. replay_files[replay_selected].filename)
                        refreshReplayList()
                        replay_acting = false
                        overlay.setInputDisplay(default_overlay)
                    -- cancel
                    else
                        replay_acting = false
                        overlay.setInputDisplay(default_overlay)
                    end
                elseif input.checkPressed("left") or input.checkPressed("up") then
                    replay_action_selected = (replay_action_selected - 2) % 3 + 1
                    love.audio.play("menu_text", "static", false, false)
                    
                elseif input.checkPressed("right") or input.checkPressed("down") then
                    replay_action_selected = replay_action_selected % 3 + 1
                    love.audio.play("menu_text", "static", false, false)
                end
            else
                if input.checkPressed("b2") or input.getKeyPressed("escape") then
                    title.changeState("mode")
                    love.audio.play("menu_back", "static")
                elseif input.checkPressed("b1") then
                    if #replay_files > 0 then
                        replay_acting = true
                        replay_action_selected = 1
                        overlay.setInputDisplay(acting_overlay)
                        love.audio.play("menu_select", "static")
                    else
                        love.audio.play("menu_back", "static")
                    end
                else
                    local move_dir = 0
                    if input.checkPressed("up") then
                        move_dir = -1
                        replay_das_dir = -1
                        replay_das_timer = 15
                    elseif input.checkPressed("down") then
                        move_dir = 1
                        replay_das_dir = 1
                        replay_das_timer = 15
                    elseif input.checkDown("up") and replay_das_dir == -1 then
                        replay_das_timer = replay_das_timer - 1
                        if replay_das_timer <= 0 then
                            move_dir = -1
                            replay_das_timer = 2
                        end
                    elseif input.checkDown("down") and replay_das_dir == 1 then
                        replay_das_timer = replay_das_timer - 1
                        if replay_das_timer <= 0 then
                            move_dir = 1
                            replay_das_timer = 2
                        end
                    else
                        replay_das_dir = 0
                    end
                    if move_dir == -1 then
                        if replay_selected > 1 then
                            replay_selected = replay_selected - 1
                            if replay_selected < replay_scroll then replay_scroll = replay_selected end
                            love.audio.play("menu_text", "static", false, false)
                        end
                    elseif move_dir == 1 then
                        if replay_selected < #replay_files then
                            replay_selected = replay_selected + 1
                            if replay_selected >= replay_scroll + max_visible_replays then
                                replay_scroll = replay_selected - max_visible_replays + 1
                            end
                            love.audio.play("menu_text", "static", false, false)
                        end
                    end
                end
            end
        end,
        draw = function(t)
            local padding = 15
            local boxWidth = GAME_WIDTH - padding * 2
            local boxHeight = 13
            local startY = 41
            
            love.graphics.setColor(util.color(7))
            love.graphics.print("saved replays", GAME_WIDTH/2 - (#"saved replays"*2), 22)
            
            if #replay_files == 0 then
                love.graphics.setColor(util.color(5))
                love.graphics.print("no replays found.", GAME_WIDTH/2 - (#"no replays found."*2), startY + 15)
                return
            end
            
            for i = 0, max_visible_replays - 1 do
                local idx = replay_scroll + i
                if idx <= #replay_files then
                    local data = replay_files[idx]
                    
                    local is_selected = (idx == replay_selected)
                    local boxY = startY + (i * (boxHeight + 5))
                    local outlineColor = is_selected and 9 or 5
                    local textColor = (is_selected and replay_acting) and 10 or 7

                    local text = string.sub(data.p1, 1, 8) .. " | " .. string.sub(data.p2, 1, 8) .. " : " .. string.sub(data.display_name, 1, 16)
                    
                    if is_selected and replay_acting then
                        text = text .. "  < " .. replay_actions[replay_action_selected] .. " >"
                    end

                    boxedText(padding, boxY, boxWidth, boxHeight, 1, outlineColor, textColor, text, is_selected)
                end
            end
            love.graphics.setColor(util.color(6))
            if replay_scroll > 1 then
                love.graphics.print("U", GAME_WIDTH/2 - 2, startY - 9)
            end
            if replay_scroll + max_visible_replays <= #replay_files then
                love.graphics.print("D", GAME_WIDTH/2 - 2, startY + (max_visible_replays * (boxHeight + 5)))
            end
        end
    },
    auto_connect = {
        hideLogo = true,
        overlay = "testing connection...",
        onEnter = function()
            title.connectTimer = 3.0
            network.connected = false
            network.connectServer(title.autoTestIP)
        end,
        update = function()
            title.connectTimer = title.connectTimer - (1 / UPDATE_RATE)
            if network.connected then
                config["server_ip"] = title.autoTestIP
                saveConfig()
                title.autoTestIP = nil
                title.changeState("options", true)
                love.audio.play("menu_select", "static")
            elseif title.connectTimer <= 0 then
                network.connectServer(config["server_ip"]) 
                title.autoTestIP = nil
                title.changeState("options", true)
                love.audio.play("menu_back", "static")
                overlay.add_msg("connection failed!")
            end
        end,
        draw = function(t)
            state_handlers["options"].draw(t)

            local boxWidth = 90
            local boxHeight = 19
            local boxX = GAME_WIDTH/2 - boxWidth/2
            local boxY = GAME_HEIGHT/2 - boxHeight/2
            
            love.graphics.setColor(util.color(0))
            love.graphics.rectangle("fill", boxX + 2, boxY + 2, boxWidth, boxHeight)
            love.graphics.setColor(util.color(1))
            love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight)
            love.graphics.setColor(util.color(5))
            love.graphics.rectangle("line", boxX-1, boxY-1, boxWidth+2, boxHeight+2)

            love.graphics.setColor(util.color(10))
            love.graphics.printf("connecting...", 0, boxY + 6, GAME_WIDTH, "center")
        end
    },
    server_ip = {
        overlay = "enter : connect | esc : cancel",
        onEnter = function()
            local current_ip = config["server_ip"]
            server_ip_input = getServerListIndex(current_ip) <= #server_list and "" or current_ip
            title.ipNote = ""
            title.isConnecting = false 
            title.connectTimer = 0
            input.setTextListener(function(t)
                if title.isConnecting then return end 
                if t == "backspace" then
                    server_ip_input = string.sub(server_ip_input, 1, -2)
                elseif #server_ip_input < 15 and t:match("^[0-9%.]$") then
                    love.audio.play("menu_text", "static", false, false)
                    server_ip_input = server_ip_input .. t
                end
            end)
        end,
        update = function()
            if title.isConnecting then
                title.connectTimer = title.connectTimer - (1 / UPDATE_RATE)
                if network.connected then
                    config["server_ip"] = server_ip_input
                    saveConfig()
                    title.isConnecting = false
                    title.changeState("options")
                    love.audio.play("menu_select", "static")
                elseif title.connectTimer <= 0 then
                    network.connectServer(config["server_ip"]) 
                    title.isConnecting = false
                    title.ipNote = "connection failed!"
                    love.audio.play("menu_back", "static")
                end
                return 
            end
            if input.getKeyPressed("escape") then
                server_ip_input = config["server_ip"] or "3.129.71.135"
                title.changeState("options")
                love.audio.play("menu_back", "static")
            elseif input.getKeyPressed("return") and isValidIP(server_ip_input) then
                title.ipNote = "connecting..."
                title.isConnecting = true
                title.connectTimer = 3.0 
                network.connected = false
                network.connectServer(server_ip_input)
            end
        end,
        draw = function(t)
            drawInputScreen("server ip:", server_ip_input, t)
            if title.isConnecting then
                love.graphics.setColor(util.color(10)) 
            else
                love.graphics.setColor(util.color(5))
            end
            love.graphics.printf(title.ipNote, 0, 100, GAME_WIDTH, "center")
        end
    },
}

-- menu logic

title.getState = function()
    return titleState
end

title.changeState = function(newState, skipAnim)
    titleState = newState
    local state = state_handlers[newState]
    
    if not skipAnim then
        anim_offset_y = 15
    end

    if input.setTextListener then input.setTextListener(function() end) end 
    
    if state then
        if state.overlay then overlay.setInputDisplay(state.overlay) end
        if state.onEnter then state.onEnter() end
    end
end

title.update = function()
    if (currentRoom ~= nil and currentRoom ~= "") and titleState ~= "waiting" then
        title.changeState("waiting")
    elseif (currentRoom == nil or currentRoom == "") and titleState == "waiting" then
        title.changeState("mode")
    end

    local currentState = state_handlers[titleState]
    if currentState and currentState.update then
        currentState.update()
    end
end

-- menu renderer

title.draw = function()
    local t = love.timer.getTime()
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(menuBGShader)
    if menuBGShader:hasUniform("time") then
        menuBGShader:send("time", t)
    end
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)
    love.graphics.setShader()

    local currentState = state_handlers[titleState]
    
    anim_offset_y = anim_offset_y * 0.7
    if math.abs(anim_offset_y) < 0.5 then anim_offset_y = 0 end

    -- logo banner
    if not (currentState and currentState.hideLogo) then
        local bob = math.floor(math.sin(t * 2.5) * 2)
        
        local logoSpr = sprites["ui/logo"]
        local logoW = logoSpr:getPixelWidth()
        local bannerW = logoW + 36 
        local bannerX = GAME_WIDTH/2 - bannerW/2
        local bannerY = 13 + bob
        local bannerH = 45

        love.graphics.setColor(util.color(0))
        love.graphics.rectangle("fill", bannerX + 3, bannerY + 3, bannerW, bannerH)

        love.graphics.setColor(util.color(1))
        love.graphics.rectangle("fill", bannerX, bannerY, bannerW, bannerH)

        love.graphics.setColor(util.color(0))
        love.graphics.rectangle("fill", bannerX + 1, bannerY + 1, bannerW - 2, bannerH - 2)
        love.graphics.setColor(1,1,1)

        local logoX = GAME_WIDTH/2 - logoW/2
        sprites.draw(logoSpr, logoX, 20 + bob)
    end

    love.graphics.push()
    love.graphics.translate(0, math.floor(anim_offset_y))

    if currentState and currentState.draw then
        currentState.draw(t)
    end
    
    love.graphics.pop()

    -- version
    love.graphics.setColor(util.color(1))
    love.graphics.print("v" .. formatVersion(GAME_VERSION), 1, 1)
end

title.changeState("init")