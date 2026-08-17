--!strict

local Planner = require("../src/shared/Expeditions/RoomPlacementPlanner")
local Validator = require("../src/shared/Expeditions/InstanceLayoutValidator")

local function planFor(seed: number, roomCount: number): any
	local nodes = {}
	for index = 1, roomCount do
		table.insert(nodes, {
			Index = index,
			RoomId = `room-{index}`,
			Role = if index == 1 then "Entry" elseif index == roomCount then "Boss" else "Traversal",
		})
	end
	return { Seed = seed, Nodes = nodes }
end

local function copyPoint(value: any): any
	return { x = value.x, y = value.y, z = value.z }
end

local function mutableLayout(layout: any): any
	local placements = {}
	for index, placement in layout.Placements do
		placements[index] = {
			Index = placement.Index,
			RoomId = placement.RoomId,
			RoleId = placement.RoleId,
			GridCell = { x = placement.GridCell.x, z = placement.GridCell.z },
			TurnId = placement.TurnId,
			EntranceSide = placement.EntranceSide,
			ExitSide = placement.ExitSide,
			Center = copyPoint(placement.Center),
			Size = copyPoint(placement.Size),
			Entrance = copyPoint(placement.Entrance),
			Exit = copyPoint(placement.Exit),
		}
	end
	local connectors = {}
	for index, connector in layout.Connectors do
		connectors[index] = {
			FromIndex = connector.FromIndex,
			ToIndex = connector.ToIndex,
			FromRoomId = connector.FromRoomId,
			ToRoomId = connector.ToRoomId,
			Axis = connector.Axis,
			Center = copyPoint(connector.Center),
			Size = copyPoint(connector.Size),
			Length = connector.Length,
		}
	end
	return {
		Seed = layout.Seed,
		LayoutVersion = layout.LayoutVersion,
		GenerationAttempt = layout.GenerationAttempt,
		MaximumGenerationAttempts = layout.MaximumGenerationAttempts,
		UsedFallback = layout.UsedFallback,
		GridStep = layout.GridStep,
		RoomLength = layout.RoomLength,
		RoomWidth = layout.RoomWidth,
		RoomHeight = layout.RoomHeight,
		DoorwayWidth = layout.DoorwayWidth,
		Placements = placements,
		Connectors = connectors,
	}
end

local plan = planFor(778, 8)
local layout = Planner.plan(plan)
local accepted = Validator.validate(plan, layout)
assert(accepted.Accepted and accepted.ReasonId == "LayoutValid")
assert(accepted.ValidatedRoomCount == 8 and accepted.ValidatedConnectorCount == 7)

local malformed = Validator.validate(plan, { Placements = {}, Connectors = {} })
assert(not malformed.Accepted, "malformed layout must fail closed")

local seedMismatch = mutableLayout(layout)
seedMismatch.Seed = 779
assert(Validator.validate(plan, seedMismatch).ReasonId == "SeedMismatch")

local versionMismatch = mutableLayout(layout)
versionMismatch.LayoutVersion = 999
assert(Validator.validate(plan, versionMismatch).ReasonId == "LayoutVersionMismatch")

local invalidAttempt = mutableLayout(layout)
invalidAttempt.GenerationAttempt = invalidAttempt.MaximumGenerationAttempts + 1
invalidAttempt.UsedFallback = false
assert(Validator.validate(plan, invalidAttempt).ReasonId == "InvalidGenerationAttempt")

local identityDrift = mutableLayout(layout)
identityDrift.Placements[2].RoomId = "invented-room"
assert(Validator.validate(plan, identityDrift).ReasonId == "RoomPlacementMismatch")

local duplicateCell = mutableLayout(layout)
local first = duplicateCell.Placements[1]
local second = duplicateCell.Placements[2]
second.GridCell = { x = first.GridCell.x, z = first.GridCell.z }
second.Center = copyPoint(first.Center)
second.EntranceSide = first.EntranceSide
second.ExitSide = first.ExitSide
second.Entrance = copyPoint(first.Entrance)
second.Exit = copyPoint(first.Exit)
assert(Validator.validate(plan, duplicateCell).ReasonId == "DuplicateGridCell")

local centerDrift = mutableLayout(layout)
centerDrift.Placements[2].Center.x += 1
assert(Validator.validate(plan, centerDrift).ReasonId == "RoomCenterMismatch")

local turnDrift = mutableLayout(layout)
turnDrift.Placements[2].TurnId = if turnDrift.Placements[2].TurnId == "Straight" then "Left" else "Straight"
assert(Validator.validate(plan, turnDrift).ReasonId == "TurnMetadataMismatch")

local socketDrift = mutableLayout(layout)
local originalExit = socketDrift.Placements[1].ExitSide
local replacementSide = if originalExit == "North" then "East" else "North"
socketDrift.Placements[1].ExitSide = replacementSide
local center = socketDrift.Placements[1].Center
if replacementSide == "North" then
	socketDrift.Placements[1].Exit = { x = center.x, y = 4, z = center.z - 32 }
else
	socketDrift.Placements[1].Exit = { x = center.x + 24, y = 4, z = center.z }
end
assert(Validator.validate(plan, socketDrift).ReasonId == "SocketDirectionMismatch")

local connectorDrift = mutableLayout(layout)
connectorDrift.Connectors[1].Size.x += 1
assert(Validator.validate(plan, connectorDrift).ReasonId == "ConnectorGeometryMismatch")

local badPoint = mutableLayout(layout)
badPoint.Placements[2].Center = { x = 0 / 0, y = 10, z = 0 }
assert(Validator.validate(plan, badPoint).ReasonId == "InvalidRoomGeometry")

local ok, result = pcall(function()
	return Validator.validate({ Seed = 1, Nodes = { false, false } }, { Placements = { false }, Connectors = {} })
end)
assert(ok and result.Accepted == false, "malformed external structures must reject rather than throw")

print("InstanceLayoutValidator: fail-closed spatial invariants and corruption rejection passed")
