require("cpu/maddy_cpu")
require("cpu/stepstools_cpu")

-- cpu.lua

cpu = {
    getInputForFrame = function(charName)
        if charName == "maddy" or charName == "heavymaddy" or charName == "gemmy" then
            return maddy_cpu.getInputForFrame()
        elseif charName == "stepstools" then
            return stepstools_cpu.getInputForFrame()
        end
    end
}
