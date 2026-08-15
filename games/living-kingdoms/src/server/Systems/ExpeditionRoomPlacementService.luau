--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RoomPlacementPlanner = require(ReplicatedStorage.Shared.Expeditions.RoomPlacementPlanner)
local ExpeditionEnvironmentBuilder = require(script.Parent.ExpeditionEnvironmentBuilder)

local ROOT_NAME = "ExpeditionRooms"
local WALL_THICKNESS = 1
local Service = {}

local activeRoot: Folder? = nil

local function part(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = cframe
	value.Anchored = true
	value.CanCollide = true
	value.Material = Enum.Material.Slate
	value.Color = Color3.fromRGB(47, 53, 60)
	value.Parent = parent
	return value
end

local function rockWall(name: string, size: Vector3, cframe: CFrame, parent: Instance)
	local wall = part(name, size, cframe, parent)
	wall.Material = Enum.Material.Rock
	return wall
end

local function doorwayCFrame(point: any, sideId: string): CFrame
	local yaw = if sideId == "East" or sideId == "West" then math.rad(90) else 0
	return CFrame.new(point.x, point.y, point.z) * CFrame.Angles(0, yaw, 0)
end

local function buildWallSide(
	sideId: string,
	center: any,
	size: any,
	doorwayWidth: number,
	isOpen: boolean,
	parent: Instance
)
	if sideId == "North" or sideId == "South" then
		local z = center.z + (if sideId == "North" then -size.z / 2 else size.z / 2)
		if not isOpen then
			rockWall(sideId .. "Wall", Vector3.new(size.x, size.y, WALL_THICKNESS), CFrame.new(center.x, center.y, z), parent)
			return
		end

		local segmentLength = (size.x - doorwayWidth) / 2
		local offset = doorwayWidth / 2 + segmentLength / 2
		rockWall(
			sideId .. "Wall_A",
			Vector3.new(segmentLength, size.y, WALL_THICKNESS),
			CFrame.new(center.x - offset, center.y, z),
			parent
		)
		rockWall(
			sideId .. "Wall_B",
			Vector3.new(segmentLength, size.y, WALL_THICKNESS),
			CFrame.new(center.x + offset, center.y, z),
			parent
		)
		return
	end

	local x = center.x + (if sideId == "West" then -size.x / 2 else size.x / 2)
	if not isOpen then
		rockWall(sideId .. "Wall", Vector3.new(WALL_THICKNESS, size.y, size.z), CFrame.new(x, center.y, center.z), parent)
		return
	end

	local segmentLength = (size.z - doorwayWidth) / 2
	local offset = doorwayWidth / 2 + segmentLength / 2
	rockWall(
		sideId .. "Wall_A",
		Vector3.new(WALL_THICKNESS, size.y, segmentLength),
		CFrame.new(x, center.y, center.z - offset),
		parent
	)
	rockWall(
		sideId .. "Wall_B",
		Vector3.new(WALL_THICKNESS, size.y, segmentLength),
		CFrame.new(x, center.y, center.z + offset),
		parent
	)
end

local function doorwayFixture(name: string, cframe: CFrame, roleId: string, parent: Instance)
	local fixture = Instance.new("Model")
	fixture.Name = name
	fixture:SetAttribute("ExpeditionDoorwayFixture", true)
	fixture:SetAttribute("RoomRoleId", roleId)

	local frameColor = if roleId == "Boss"
		then Color3.fromRGB(68, 108, 150)
		elseif roleId == "Elite" then Color3.fromRGB(103, 70, 130)
		else Color3.fromRGB(73, 82, 89)
	local energyColor = if roleId == "Boss"
		then Color3.fromRGB(75, 180, 255)
		elseif roleId == "Elite" then Color3.fromRGB(181, 93, 255)
		else Color3.fromRGB(255, 176, 82)

	for _, offset in { -4.5, 4.5 } do
		local post = part("DoorPost", Vector3.new(1, 10, 1.5), cframe * CFrame.new(offset, 4.5, 0), fixture)
		post.Material = Enum.Material.CorrodedMetal
		post.Color = frameColor
	end
	local header = part("DoorHeader", Vector3.new(10, 1, 1.5), cframe * CFrame.new(0, 9, 0), fixture)
	header.Material = Enum.Material.CorrodedMetal
	header.Color = frameColor

	local barrier = part("EnergyBarrier", Vector3.new(8, 8, 0.35), cframe * CFrame.new(0, 4, 0), fixture)
	barrier.Material = Enum.Material.ForceField
	barrier.Color = energyColor
	barrier.Transparency = 1
	barrier.CanCollide = false
	barrier.CastShadow = false
	barrier:SetAttribute("ExpeditionRevealBarrier", true)
	barrier:SetAttribute("BaseTransparency", 0.38)

	local light = Instance.new("PointLight")
	light.Name = "BarrierGlow"
	light.Color = energyColor
	light.Brightness = 0
	light.Range = 13
	light.Shadows = false
	light.Parent = barrier

	fixture.PrimaryPart = barrier
	fixture.Parent = parent
end

local function buildRoom(placement: any, seed: number, doorwayWidth: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = string.format("%02d_%s", placement.Index, placement.RoomId)
	model:SetAttribute("RoomIndex", placement.Index)
	model:SetAttribute("RoomId", placement.RoomId)
	model:SetAttribute("RoomRoleId", placement.RoleId)
	model:SetAttribute("LayoutTurnId", placement.TurnId)
	model:SetAttribute("EntranceSide", placement.EntranceSide)
	model:SetAttribute("ExitSide", placement.ExitSide)
	model:SetAttribute("GridX", placement.Grid.x)
	model:SetAttribute("GridZ", placement.Grid.z)
	model:SetAttribute("RevealState", "Hidden")

	local center = placement.Center
	local size = placement.Size
	local floor = part("Floor", Vector3.new(size.x, 1, size.z), CFrame.new(center.x, 0, center.z), model)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(38, 43, 49)

	local openSides = {
		[placement.EntranceSide] = true,
		[placement.ExitSide] = true,
	}
	for _, sideId in { "North", "East", "South", "West" } do
		buildWallSide(sideId, center, size, doorwayWidth, openSides[sideId] == true, model)
	end

	for offset = -1, 1 do
		local rib = part(
			"CeilingRib",
			Vector3.new(size.x - 5, 1.2, 1.2),
			CFrame.new(center.x, size.y - 1.5, center.z + offset * size.z * 0.28),
			model
		)
		rib.Material = Enum.Material.CorrodedMetal
		rib.Color = Color3.fromRGB(61, 65, 69)
	end

	local entranceCFrame = doorwayCFrame(placement.Entrance, placement.EntranceSide)
	local exitCFrame = doorwayCFrame(placement.Exit, placement.ExitSide)
	local entrance = part("EntranceConnector", Vector3.new(8, 8, 1), entranceCFrame, model)
	entrance.CanCollide = false
	entrance.Transparency = 1
	local exit = part("ExitConnector", Vector3.new(8, 8, 1), exitCFrame, model)
	exit.CanCollide = false
	exit.Transparency = 1

	doorwayFixture("EntranceReveal", entranceCFrame, placement.RoleId, model)
	doorwayFixture("ExitReveal", exitCFrame, placement.RoleId, model)
	ExpeditionEnvironmentBuilder.decorate(model, placement, seed)
	model.PrimaryPart = floor
	model.Parent = parent
end

function Service.place(roomPlan: any, runId: string?): any
	if activeRoot ~= nil then
		return table.freeze({ Accepted = false, ReasonId = "RoomsAlreadyPlaced", Layout = nil })
	end
	if runId ~= nil and type(runId) ~= "string" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidRunId", Layout = nil })
	end

	local ok, layoutOrError = pcall(RoomPlacementPlanner.plan, roomPlan)
	if not ok then
		return table.freeze({ Accepted = false, ReasonId = "InvalidRoomPlan", Layout = nil })
	end
	local layout = layoutOrError
	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root:SetAttribute("Seed", layout.Seed)
	root:SetAttribute("LayoutVersion", layout.LayoutVersion)
	root:SetAttribute("GenerationAttempt", layout.GenerationAttempt)
	root:SetAttribute("UsedLayoutFallback", layout.UsedFallback)
	root:SetAttribute("EnvironmentTheme", "RuinedSciFantasy")
	if runId ~= nil then
		root:SetAttribute("RunId", runId)
	end

	for _, placement in layout.Placements do
		buildRoom(placement, layout.Seed, layout.DoorwayWidth, root)
	end
	for index, connector in layout.Connectors do
		local center = connector.Center
		local connectorSize = connector.Size
		local bridge = part(
			string.format("Connector_%02d_%02d", connector.FromIndex, connector.ToIndex),
			Vector3.new(connectorSize.x, connectorSize.y, connectorSize.z),
			CFrame.new(center.x, center.y, center.z),
			root
		)
		bridge.Material = Enum.Material.CorrodedMetal
		bridge.Color = Color3.fromRGB(50, 55, 60)
		bridge:SetAttribute("ConnectorIndex", index)
		bridge:SetAttribute("ConnectorAxis", connector.Axis)
	end

	root.Parent = Workspace
	activeRoot = root
	return table.freeze({ Accepted = true, ReasonId = "RoomsPlaced", Layout = layout })
end

function Service.destroy()
	if activeRoot ~= nil then
		activeRoot:Destroy()
		activeRoot = nil
	end
end

function Service.getRoot(): Folder?
	return activeRoot
end

return table.freeze(Service)
