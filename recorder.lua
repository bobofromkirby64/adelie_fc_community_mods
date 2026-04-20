-- recorder.lua
recorder = {}

local buffer = {}
local buffer_index = 1
local max_frames = 8 * 30
local is_exporting = false

-- ffmpeg check
local function command_exists(cmd)
    local check_cmd = package.config:sub(1,1) == "\\" 
        and ("where " .. cmd .. " >nul 2>nul") 
        or ("export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin; command -v " .. cmd .. " >/dev/null 2>&1")
    return os.execute(check_cmd)
end

-- cleanup
love.filesystem.createDirectory("gifs")
for _, item in ipairs(love.filesystem.getDirectoryItems("gifs")) do
    if item:sub(1, 5) == "temp_" then
        local temp_dir = "gifs/" .. item
        for _, file in ipairs(love.filesystem.getDirectoryItems(temp_dir)) do
            love.filesystem.remove(temp_dir .. "/" .. file)
        end
        love.filesystem.remove(temp_dir)
    end
end

local thread_code = [[
    require("love.filesystem")
    require("love.image")
    require("os")

    local job_channel = love.thread.getChannel("gif_jobs")
    local status_channel = love.thread.getChannel("gif_status")

    while true do
        local data = job_channel:demand()
        if data == "quit" then break end

        local frames = data.frames
        local timestamp = data.timestamp
        local save_dir = love.filesystem.getSaveDirectory()

        local folder_name = "gifs/temp_" .. timestamp
        love.filesystem.createDirectory(folder_name)

        -- temp pngs
        for i, imgData in ipairs(frames) do
            local filename = folder_name .. "/frame_" .. string.format("%03d", i) .. ".png"
            imgData:encode("png", filename)
        end

        -- make gif
        local temp_path = save_dir .. "/" .. folder_name
        local final_gif = save_dir .. "/gifs/replay_" .. timestamp .. ".gif"
        local input_pattern = temp_path .. "/frame_%03d.png"
        local is_windows = package.config:sub(1,1) == "\\"
        local cmd_prefix = is_windows and "" or "export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin; "
        local ffmpeg_cmd = cmd_prefix .. 'ffmpeg -framerate 30 -reinit_filter 0 -i "' .. input_pattern .. '" ' ..
            '-filter_complex "[0:v]format=rgba,scale=480:270:flags=neighbor,split[s0][s1];' ..
            '[s0]palettegen=stats_mode=diff[pal];' ..
            '[s1][pal]paletteuse=dither=none" ' ..
            '-y "' .. final_gif .. '"'

        os.execute(ffmpeg_cmd)

        -- cleanup
        for i = 1, #frames do
            love.filesystem.remove(folder_name .. "/frame_" .. string.format("%03d", i) .. ".png")
        end
        love.filesystem.remove(folder_name)

        status_channel:push("done")
    end
]]

local export_thread = love.thread.newThread(thread_code)
export_thread:start()
local job_channel = love.thread.getChannel("gif_jobs")
local status_channel = love.thread.getChannel("gif_status")

local function canvas_img()
    local canvas = love.graphics.getCanvas()
    if canvas then
        love.graphics.setCanvas() 
        local img = canvas:newImageData()
        love.graphics.setCanvas(canvas) 
        return img
    end
end

-- dpi stuff makes imgs come at inconsistent resolutions
local function force_480x270(img)
    if not img then return nil end
    local src_w, src_h = img:getDimensions()
    local target_w, target_h = 480, 270
    if src_w == target_w and src_h == target_h then
        return img
    end
    local scaled_img = love.image.newImageData(target_w, target_h)
    scaled_img:mapPixel(function(x, y)
        return img:getPixel(
            math.min(math.floor(x * src_w / target_w), src_w - 1), 
            math.min(math.floor(y * src_h / target_h), src_h - 1)
        )
    end)
    return scaled_img
end

function recorder.clear()
    buffer = {}
    buffer_index = 1
end

function recorder.capture()
    local img

    if status_channel:pop() == "done" then
        is_exporting = false
    end

    if recorder.queue_screenshot then
        recorder.queue_screenshot = false
        if not img then img = canvas_img() end
        if img then
            love.filesystem.createDirectory("screenshots")
            local filename = "screenshots/screenshot_" .. os.time() .. ".png"
            force_480x270(img):encode("png", filename)
        end
    end

    if recorder.queue_capture then
        recorder.queue_capture = false
        if gameState == "GAME" then
            if not img then img = canvas_img() end
            if img then
                buffer[buffer_index] = img
                buffer_index = (buffer_index % max_frames) + 1
            end
        end
    end
end

function recorder.screenshot()
    recorder.queue_screenshot = true
end

function recorder.export()
    if not command_exists("ffmpeg") then
        return
    end

    if is_exporting or next(buffer) == nil then
        return
    end

    is_exporting = true
    
    local frames_to_export = {}
    local count = 1

    for i = 0, max_frames - 1 do
        local idx = ((buffer_index - 1 + i) % max_frames) + 1
        if buffer[idx] then
            frames_to_export[count] = buffer[idx]
            count = count + 1
        end
    end
    
    job_channel:push({
        timestamp = os.time(),
        frames = frames_to_export
    })
end

return recorder