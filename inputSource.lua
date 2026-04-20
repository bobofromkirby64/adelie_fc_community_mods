-- Input sources wrap different places we can recieve input from: local keyboard, remote player
-- All input sources are recorded for each frame, so we can rewind and replay inputs
-- Always query input from here for networked synced actions; use inputSource.getInputSource(<connectionId>)

require("controller")
local config = require("config")

local inputSources = {}

inputSource = {
    createInputSource = function(id)
        local i = {
            record = {}
        }

        function i:getKeyDown(key)
            local f = frameCounter
            while self.record[f] == nil do
                f = f-1
                if f==0 then return false end
            end
            return self.record[f][key]
        end

        function i:recordLocalInputForFrame(frameNum)
            local keys = {
                up    = input.checkDown("up"),
                down  = input.checkDown("down"),
                left  = input.checkDown("left"),
                right = input.checkDown("right"),
                b1    = input.checkDown("b1"),
                b2    = input.checkDown("b2")
            }
            self.record[frameNum] = keys
            return keys
        end

        function i:recordInputForFrame(frameNum, keys)
            if self.record[frameNum] ~= nil then return end
            self.record[frameNum] = keys
        end

        inputSources[id] = i
    end,
    getInputSource = function(id)
        return inputSources[id]
    end,
    resetInputSources = function()
        inputSources = {}
    end,
    getKeyDown = function(id, key)
        return inputSource.getInputSource(id):getKeyDown(key)
    end
}
