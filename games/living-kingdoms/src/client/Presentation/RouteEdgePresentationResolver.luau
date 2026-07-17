--!strict

--[[
	Pure VIS-0105 route-edge resolver. It derives presentation geometry only from
	the existing authored route segment name and size. It owns no world position,
	collision, movement, mission state, objective state, or extraction state.
]]

export type RouteStyleId = "Hidden" | "Road" | "Trail"

export type RouteEdgeFacts = {
	segmentName: unknown,
	widthStuds: unknown,
	heightStuds: unknown,
}

export type RouteEdgePresentation = {
	styleId: RouteStyleId,
	leftOffsetX: number,
	rightOffsetX: number,
	markerWidth: number,
	markerHeight: number,
	markerDepth: number,
	markerCenterY: number,
}

local Resolver = {}

local HIDDEN: RouteEdgePresentation = table.freeze({
	styleId = "Hidden",
	leftOffsetX = 0,
	rightOffsetX = 0,
	markerWidth = 0,
	markerHeight = 0,
	markerDepth = 0,
	markerCenterY = 0,
})

local function isPositiveFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end

local function startsWith(value: string, prefix: string): boolean
	return string.sub(value, 1, #prefix) == prefix
end

function Resolver.resolve(facts: RouteEdgeFacts): RouteEdgePresentation
	if
		type(facts.segmentName) ~= "string"
		or facts.segmentName == ""
		or not isPositiveFiniteNumber(facts.widthStuds)
		or not isPositiveFiniteNumber(facts.heightStuds)
	then
		return HIDDEN
	end
	local widthStuds = facts.widthStuds :: number
	local heightStuds = facts.heightStuds :: number
	if startsWith(facts.segmentName, "LoggingRoad") then
		local offset = widthStuds / 2 + 1.1
		return table.freeze({
			styleId = "Road",
			leftOffsetX = -offset,
			rightOffsetX = offset,
			markerWidth = 0.5,
			markerHeight = 1.9,
			markerDepth = 0.5,
			markerCenterY = heightStuds / 2 + 1,
		})
	end
	if startsWith(facts.segmentName, "SwitchbackTrail") then
		local offset = widthStuds / 2 + 0.8
		return table.freeze({
			styleId = "Trail",
			leftOffsetX = -offset,
			rightOffsetX = offset,
			markerWidth = 0.9,
			markerHeight = 1.15,
			markerDepth = 0.9,
			markerCenterY = heightStuds / 2 + 0.62,
		})
	end
	return HIDDEN
end

return table.freeze(Resolver)
