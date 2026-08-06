--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RoomPlacementPlanner = require(ReplicatedStorage.Shared.Expeditions.RoomPlacementPlanner)
local ExpeditionEnvironmentBuilder = require(script.Parent.ExpeditionEnvironmentBuilder)

local ROOT_NAME = "ExpeditionRooms"
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

local function buildRoom(placement: any, seed: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = string.format("%02d_%s", placement.Index, placement.RoomId)
	model:SetAttribute("RoomIndex", placement.Index)
	model:SetAttribute("RoomId", placement.RoomId)
	model:SetAttribute("RoomRoleId", placement.RoleId)

	local center = placement.Center
	local size = placement.Size
	local floor = part("Floor", Vector3.new(size.x, 1, size.z), CFrame.new(center.x, 0, center.z), model)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(38, 43, 49)
	local west = part("WestWall", Vector3.new(1, size.y, size.z), CFrame.new(center.x - size.x / 2, center.y, center.z), model)
	local east = part("EastWall", Vector3.new(1, size.y, size.z), CFrame.new(center.x + size.x / 2, center.y, center.z), model)
	west.Material = Enum.Material.Rock
	east.Material = Enum.Material.Rock

	-- Broken ceiling ribs preserve the open graybox readability while adding a
	-- stronger silhouette and giving lights something to rake across.
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

	local entrance = part("EntranceConnector", Vector3.new(8, 8, 1), CFrame.new(placement.Entrance.x, placement.Entrance.y, placement.Entrance.z), model)
	entrance.CanCollide = false
	entrance.Transparency = 1
	local exit = part("ExitConnector", Vector3.new(8, 8, 1), CFrame.new(placement.Exit.x, placement.Exit.y, placement.Exit.z), model)
	exit.CanCollide = false
	exit.Transparency = 1

	ExpeditionEnvironmentBuilder.decorate(model, placement, seed)
	model.PrimaryPart = floor
	model.Parent = parent
end

function Service.place(roomPlan: any): any
	if activeRoot ~= nil then
		return table.freeze({ Accepted = false, ReasonId = "RoomsAlreadyPlaced", Layout = nil })
	end
	local ok, layoutOrError = pcall(RoomPlacementPlanner.plan, roomPlan)
	if not ok then
		return table.freeze({ Accepted = false, ReasonId = "InvalidRoomPlan", Layout = nil })
	end
	local layout = layoutOrError
	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root:SetAttribute("Seed", layout.Seed)
	root:SetAttribute("EnvironmentTheme", "RuinedSciFantasy")

	for _, placement in layout.Placements do
		buildRoom(placement, layout.Seed, root)
	end
	for index, connector in layout.Connectors do
		local center = connector.Center
		local bridge = part(
			string.format("Connector_%02d_%02d", connector.FromIndex, connector.ToIndex),
			Vector3.new(8, 1, connector.Length),
			CFrame.new(center.x, 0, center.z),
			root
		)
		bridge.Material = Enum.Material.CorrodedMetal
		bridge.Color = Color3.fromRGB(50, 55, 60)
		bridge:SetAttribute("ConnectorIndex", index)
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
