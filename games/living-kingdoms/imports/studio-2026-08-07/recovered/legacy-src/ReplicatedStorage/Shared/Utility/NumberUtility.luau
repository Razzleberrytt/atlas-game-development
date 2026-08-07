-- NumberUtility: Math helper functions for rounding, clamping, and interpolation
local NumberUtility = {}

function NumberUtility.round(value, decimalPlaces)
	decimalPlaces = decimalPlaces or 0
	local multiplier = 10 ^ decimalPlaces
	return math.floor(value * multiplier + 0.5) / multiplier
end

function NumberUtility.clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

function NumberUtility.lerp(a, b, t)
	return a + (b - a) * t
end

function NumberUtility.map(value, inMin, inMax, outMin, outMax)
	return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
end

function NumberUtility.approach(current, target, delta)
	if current < target then
		return math.min(current + delta, target)
	elseif current > target then
		return math.max(current - delta, target)
	end
	return current
end

return NumberUtility