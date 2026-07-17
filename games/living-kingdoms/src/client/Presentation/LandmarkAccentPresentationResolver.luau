--!strict

--[[
	VIS-0105 safe static-landmark selection. Only landmarks that exist from world
	construction and disclose no mission phase are eligible. Unknown, mismatched,
	or non-graybox models resolve to no client presentation.
]]

local Resolver = {}

Resolver.StyleIds = table.freeze({
	RangerStation = "RangerStation",
	MilitaryRoadblock = "MilitaryRoadblock",
})

export type StyleId = "RangerStation" | "MilitaryRoadblock"

function Resolver.resolve(modelName: unknown, landmarkId: unknown, isGraybox: unknown): StyleId?
	if isGraybox ~= true or type(modelName) ~= "string" or type(landmarkId) ~= "string" then
		return nil
	end
	if modelName == "RangerStation" and landmarkId == "RangerStation" then
		return Resolver.StyleIds.RangerStation
	end
	if modelName == "MilitaryRoadblock" and landmarkId == "MilitaryRoadblock" then
		return Resolver.StyleIds.MilitaryRoadblock
	end
	return nil
end

return table.freeze(Resolver)
