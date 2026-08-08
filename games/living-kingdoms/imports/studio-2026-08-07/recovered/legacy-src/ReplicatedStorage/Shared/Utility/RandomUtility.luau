-- RandomUtility: Advanced random number generation utilities
local RandomUtility = {}

-- Generate a random seed
function RandomUtility.generateSeed()
	return math.random(1, 2^31 - 1)
end

-- Create a Random object from a seed
function RandomUtility.fromSeed(seed)
	return Random.new(seed)
end

-- Random integer in range [min, max]
function RandomUtility.int(min, max, rng)
	rng = rng or Random.new()
	return rng:NextInteger(min, max)
end

-- Random float in range [min, max]
function RandomUtility.float(min, max, rng)
	rng = rng or Random.new()
	return min + rng:NextNumber() * (max - min)
end

-- Random number in [0, 1)
function RandomUtility.next(rng)
	rng = rng or Random.new()
	return rng:NextNumber()
end

-- Chance roll (probability 0-1)
function RandomUtility.chance(probability, rng)
	rng = rng or Random.new()
	return rng:NextNumber() < probability
end

-- Pick a random element from a table
function RandomUtility.choice(table, rng)
	rng = rng or Random.new()
	if #table == 0 then return nil end
	return table[rng:NextInteger(1, #table)]
end

-- Weighted random selection
-- entries: array of {item = value, weight = number}
function RandomUtility.weighted(entries, rng)
	rng = rng or Random.new()
	local totalWeight = 0
	for _, entry in ipairs(entries) do
		totalWeight += entry.weight
	end
	if totalWeight <= 0 then return entries[1] and entries[1].item or nil end
	
	local roll = rng:NextNumber() * totalWeight
	local cumulative = 0
	for _, entry in ipairs(entries) do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry.item
		end
	end
	return entries[#entries].item
end

-- Gaussian distribution (Box-Muller transform)
function RandomUtility.gaussian(mean, stddev, rng)
	rng = rng or Random.new()
	local u1 = rng:NextNumber()
	local u2 = rng:NextNumber()
	if u1 < 0.0001 then u1 = 0.0001 end
	local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	return mean + z * stddev
end

-- Shuffle a table in place
function RandomUtility.shuffle(tbl, rng)
	rng = rng or Random.new()
	for i = #tbl, 2, -1 do
		local j = rng:NextInteger(1, i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

-- Roll a dice with multiple chances (returns index of the successful roll, or nil)
function RandomUtility.multiRoll(chances, rng)
	rng = rng or Random.new()
	for i, chance in ipairs(chances) do
		if rng:NextNumber() < chance then
			return i
		end
	end
	return nil
end

-- Random sign (-1 or 1)
function RandomUtility.sign(rng)
	rng = rng or Random.new()
	return rng:NextNumber() < 0.5 and -1 or 1
end

-- Random rotation in radians
function RandomUtility.rotation(rng)
	rng = rng or Random.new()
	return rng:NextNumber() * math.pi * 2
end

return RandomUtility