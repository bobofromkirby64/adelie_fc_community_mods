do
    -- will hold the currently playing sources
    local sources = {}

    bgMusic = nil
    local isMuted = false
    local bgmFade = false
    local currentBGMName = ""
    local fadeVol = 1.0

    -- check for sources that finished playing and remove them
    -- add to love.update
    function love.audio.update(dt)
        local remove = {}
        for _,s in pairs(sources) do
            if not s.s:isPlaying() then
                remove[#remove + 1] = s.s
            end
        end

        for i,s in ipairs(remove) do
            sources[s] = nil
        end

        if bgMusic and not bgmFade and bgMusic:isPlaying() then
            isMuted = (bgMusic:getVolume() == 0)
        end

        if bgmFade and bgMusic then
            local step = dt and (dt * 1.0) or 0.016 -- 1s fade out
            fadeVol = math.max(0, fadeVol - step)
            bgMusic:setVolume(isMuted and 0 or ((VOL_MUSIC * 0.05) * fadeVol))
            if fadeVol == 0 then
                bgMusic:stop()
                bgmFade = false
            end
        end
    end

    -- overwrite love.audio.play to create and register source if needed
    local play = love.audio.play
    function love.audio.play(what, how, loop, debounce)
        debounce = debounce==nil and true or debounce
        if debounce and alreadyPlaying(what) then return nil end
        local src = what
        if type(what) ~= "userdata" or not what:typeOf("Source") then
            local ext = string.find(what, ".", 1, true)
            src = love.audio.newSource("resources/audio/"..what..(ext==nil and ".wav" or ""), how)
            src:setLooping(loop or false)
        end

        src:setVolume(VOL_SFX * 0.1)

        if not loop then
            src:setPitch(1 + love.math.random()/5 - 0.1)
        end

        play(src)
        sources[src] = {s=src,n=what}
        return src
    end

    -- stops a source
    local stop = love.audio.stop
    function love.audio.stop(src)
        if not src then return end
        stop(src.s)
        sources[src] = nil
    end

    function alreadyPlaying(name)
        for _,s in pairs(sources) do
            if s.n == name then return true end
        end
        return false
    end

    function playBGM(name)
        if currentBGMName == name and bgMusic and bgMusic:isPlaying() then
            bgmFade = false
            fadeVol = 1.0
            bgMusic:setVolume(isMuted and 0 or (VOL_MUSIC * 0.05))
            return
        end

        if bgMusic then
            bgMusic:stop()
        end
        
        bgmFade = false
        fadeVol = 1.0
        currentBGMName = name

        local success, src = pcall(love.audio.newSource, "resources/audio/" .. name, "stream")
        if success and src then
            src:setLooping(true)
            src:setVolume(isMuted and 0 or (VOL_MUSIC * 0.05))
            play(src)
            bgMusic = src
        else
            bgMusic = nil
        end
    end
    
    function fadeOutBGM()
        bgmFade = true
    end

    function stopBGM()
        bgmFade = false
        currentBGMName = ""
        if bgMusic then
            bgMusic:stop()
        end
    end
end