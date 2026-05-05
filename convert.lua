local gfx = "08080011110001111110111711711111991111111111117777110677776000666600"

local palette = {
    {0,0,0}, {29,43,83}, {126,37,83}, {0,135,81},
    {171,82,54}, {95,87,79}, {194,195,199}, {255,241,232},
    {255,0,77}, {255,163,0}, {255,236,39}, {0,228,54},
    {41,173,255}, {131,118,156}, {255,119,168}, {255,204,170}
}

function love.load()
    local totalHex = #gfx
    local totalPixels = totalHex / 2  -- each pixel = 2 hex digits

    -- PICO-8 clipboard exports rows of 8, 16, 24, or 32 pixels
    local possibleWidths = {8, 16, 24, 32}
    local width = nil

    for _, w in ipairs(possibleWidths) do
        if totalPixels % w == 0 then
            width = w
            break
        end
    end

    if not width then
        error("Could not determine width from pixel count " .. totalPixels)
    end

    local height = totalPixels / width
    print("Detected sprite size:", width .. "x" .. height)

    local img = love.image.newImageData(width, height)

    for i = 0, totalPixels - 1 do
        local hex = gfx:sub(i*2+1, i*2+2)
        local c = tonumber(hex, 16)
        local r, g, b = unpack(palette[c+1])
        local x = i % width
        local y = math.floor(i / width)

        if c == 0 then
            img:setPixel(x, y, 0, 0, 0, 0)
        else
            img:setPixel(x, y, r/255, g/255, b/255, 1)
        end
    end

    local path = love.filesystem.getSourceBaseDirectory() .. "/sprite.png"
    img:encode("png", path)
    print("Sprite written to:", path)

    love.event.quit()
end
