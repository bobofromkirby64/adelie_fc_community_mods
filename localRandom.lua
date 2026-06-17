MODULUS = 2^31
MULTIPLIER = 1664525
INCREMENT = 1013904223

localRandom = {
    player_seed = 0,
    opponent_seed = 0,
    combo_seed = math.random(),

    init = function()
        localRandom.player_seed = 0
        localRandom.opponent_seed = 0
        localRandom.combo_seed = math.random()
    end,

    setSeed = function(newSeed)
        localRandom.combo_seed = newSeed
    end,

    next = function()
        localRandom.combo_seed = (MULTIPLIER * localRandom.combo_seed + INCREMENT) % MODULUS
        return localRandom.combo_seed
    end,

    float = function()
        return localRandom.next() / MODULUS
    end

}