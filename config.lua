DEFAULT_CONFIG =[[
server_ip=3.129.71.135
input_delay=2
sync_tolerance=6
window_scale=4
fullscreen=0
kb_up=up
kb_down=down
kb_left=left
kb_right=right
kb_b1=z
kb_b2=x
pad_up=dpup
pad_down=dpdown
pad_left=dpleft
pad_right=dpright
pad_b1=a
pad_b2=b
]]

local function writeConfig(config_data)
    love.filesystem.write("config.txt", config_data)
end

local function readConfig()
    local contents, size = love.filesystem.read("config.txt")
    if contents ~= nil then
        return contents
    end

    writeConfig(DEFAULT_CONFIG)

    return DEFAULT_CONFIG
end

local function parseConfig(config)
    local parsed_config = {}
    for line in string.gmatch(config, "[^\n]+") do
        local k,v = line:match("^(.+)=(.+)")
        if k~=nil then
            parsed_config[k] = v
        end
    end
    return parsed_config
end

-- update config if anything is missing
local config = parseConfig(readConfig())
local default_config = parseConfig(DEFAULT_CONFIG)
local config_changed = false
for k, v in pairs(default_config) do
    if config[k] == nil then
        config[k] = v
        config_changed = true
    end
end

function saveConfig()
    local keys = {}
    for k in pairs(config) do
        table.insert(keys, k)
    end
    table.sort(keys)
    local config_str=""
    for _, k in ipairs(keys) do
        config_str = config_str .. k .. "=" .. config[k] .. "\n"
    end
    writeConfig(config_str)
end

if config_changed then
    saveConfig()
end

return config
