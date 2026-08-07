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
	Campground = "Campground",
	CreekCrossing = "CreekCrossing",
	RockyOverlook = "RockyOverlook",
})

export type StyleId = "RangerStation" | "MilitaryRoadblock" | "Campground" | "CreekCrossing" | "RockyOverlook"

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
	if modelName == "Campground" and landmarkId == "Campground" then
		return Resolver.StyleIds.Campground
	end
	if modelName == "CreekCrossing" and landmarkId == "CreekCrossing" then
		return Resolver.StyleIds.CreekCrossing
	end
	if modelName == "RockyOverlook" and landmarkId == "RockyOverlook" then
		return Resolver.StyleIds.RockyOverlook
	end
	return nil
end

return table.freeze(Resolver)
