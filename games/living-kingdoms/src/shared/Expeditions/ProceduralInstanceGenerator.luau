--!strict

-- Thin pure orchestration seam for canonical room content -> spatial resolution ->
-- fail-closed validation. It deliberately does not own room selection, encounters,
-- rewards, Roblox instance placement, or run lifecycle.

local RoomSequenceAssembler = require(script.Parent.RoomSequenceAssembler)
local RoomPlacementPlanner = require(script.Parent.RoomPlacementPlanner)
local InstanceLayoutValidator = require(script.Parent.InstanceLayoutValidator)

local Generator = {}

local function rejected(reasonId: string, roomPlan: any?, layout: any?, validation: any?, detail: string?): any
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		RoomPlan = roomPlan,
		Layout = layout,
		Validation = validation,
		Detail = detail,
	})
end

local function accepted(roomPlan: any, layout: any, validation: any): any
	return table.freeze({
		Accepted = true,
		ReasonId = "ProceduralInstanceGenerated",
		RoomPlan = roomPlan,
		Layout = layout,
		Validation = validation,
		Detail = nil,
	})
end

function Generator.generateFromRoomPlan(roomPlan: any): any
	local planned, layoutOrError = pcall(RoomPlacementPlanner.plan, roomPlan)
	if not planned then
		return rejected("InvalidRoomPlan", roomPlan, nil, nil, tostring(layoutOrError))
	end
	local layout = layoutOrError
	local validated, validationOrError = pcall(InstanceLayoutValidator.validate, roomPlan, layout)
	if not validated then
		return rejected("LayoutValidationFailedClosed", roomPlan, layout, nil, tostring(validationOrError))
	end
	local validation = validationOrError
	if type(validation) ~= "table" or validation.Accepted ~= true then
		local reasonId = if type(validation) == "table" and type(validation.ReasonId) == "string"
			then validation.ReasonId
			else "InvalidLayout"
		return rejected(reasonId, roomPlan, layout, validation, nil)
	end
	return accepted(roomPlan, layout, validation)
end

function Generator.generate(seed: number): any
	local assembled, roomPlanOrError = pcall(RoomSequenceAssembler.assemble, seed)
	if not assembled then
		return rejected("RoomAssemblyRejected", nil, nil, nil, tostring(roomPlanOrError))
	end
	return Generator.generateFromRoomPlan(roomPlanOrError)
end

return table.freeze(Generator)
