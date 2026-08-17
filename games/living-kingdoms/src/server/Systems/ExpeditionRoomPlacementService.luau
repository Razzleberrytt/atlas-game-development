--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RoomPlacementPlanner = require(ReplicatedStorage.Shared.Expeditions.RoomPlacementPlanner)
local ExpeditionInstanceRegistry = require(ReplicatedStorage.Shared.Expeditions.ExpeditionInstanceRegistry)
local ExpeditionEnvironmentBuilder = require(script.Parent.ExpeditionEnvironmentBuilder)
local ModularDungeonRoomPresentation = require(script.Parent.ModularDungeonRoomPresentation)

local CONTAINER_NAME = "ExpeditionInstances"
local LEGACY_RUN_ID = "legacy:singleton"
local Service = {}

local registry = ExpeditionInstanceRegistry.new()
local rootsByRunId: { [string]: Folder } = {}
local layoutsByRunId: { [string]: any } = {}

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

local function container(): Folder
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = CONTAINER_NAME
	created:SetAttribute("AuthoritativeExpeditionContainer", true)
	created.Parent = Workspace
	return created
end

local function shiftPoint(pointValue: any, originX: number, originZ: number): any
	return table.freeze({
		x = pointValue.x + originX,
		y = pointValue.y,
		z = pointValue.z + originZ,
	})
end

local function shiftPlacement(placement: any, originX: number, originZ: number): any
	local shifted = table.clone(placement)
	shifted.Center = shiftPoint(placement.Center, originX, originZ)
	shifted.Entrance = shiftPoint(placement.Entrance, originX, originZ)
	shifted.Exit = shiftPoint(placement.Exit, originX, originZ)
	return table.freeze(shifted)
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

local function buildRoom(placement: any, seed: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = string.format("%02d_%s", placement.Index, placement.RoomId)
	model:SetAttribute("RoomIndex", placement.Index)
	model:SetAttribute("RoomId", placement.RoomId)
	model:SetAttribute("RoomRoleId", placement.RoleId)
	model:SetAttribute("RevealState", "Hidden")

	local center = placement.Center
	local size = placement.Size
	local floor = part("Floor", Vector3.new(size.x, 1, size.z), CFrame.new(center.x, 0, center.z), model)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(38, 43, 49)
	local west =
		part("WestWall", Vector3.new(1, size.y, size.z), CFrame.new(center.x - size.x / 2, center.y, center.z), model)
	local east =
		part("EastWall", Vector3.new(1, size.y, size.z), CFrame.new(center.x + size.x / 2, center.y, center.z), model)
	west.Material = Enum.Material.Rock
	east.Material = Enum.Material.Rock

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

	local entranceCFrame = CFrame.new(placement.Entrance.x, placement.Entrance.y, placement.Entrance.z)
	local exitCFrame = CFrame.new(placement.Exit.x, placement.Exit.y, placement.Exit.z)
	local entrance = part("EntranceConnector", Vector3.new(8, 8, 1), entranceCFrame, model)
	entrance.CanCollide = false
	entrance.Transparency = 1
	local exit = part("ExitConnector", Vector3.new(8, 8, 1), exitCFrame, model)
	exit.CanCollide = false
	exit.Transparency = 1

	doorwayFixture("EntranceReveal", entranceCFrame, placement.RoleId, model)
	doorwayFixture("ExitReveal", exitCFrame, placement.RoleId, model)
	ExpeditionEnvironmentBuilder.decorate(model, placement, seed)
	ModularDungeonRoomPresentation.apply(model, placement)
	model.PrimaryPart = floor
	model.Parent = parent
end

local function normalizePlanIdentity(roomPlan: any): string
	if type(roomPlan.PlanIdentity) == "string" and #roomPlan.PlanIdentity > 0 then
		return roomPlan.PlanIdentity
	end
	return `seed={roomPlan.Seed}|rooms={#roomPlan.Nodes}`
end

local function removeEmptyContainer()
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing ~= nil and existing:IsA("Folder") and #existing:GetChildren() == 0 then
		existing:Destroy()
	end
end

function Service.placeForRun(runId: string, roomPlan: any): any
	local ok, layoutOrError = pcall(RoomPlacementPlanner.plan, roomPlan)
	if not ok then
		return table.freeze({ Accepted = false, ReasonId = "InvalidRoomPlan", Layout = nil, RunId = runId })
	end
	local layout = layoutOrError
	local planIdentity = normalizePlanIdentity(roomPlan)
	local reproductionKey = `run={runId}|seed={layout.Seed}|plan={planIdentity}`
	local registration = registry:create(runId, layout.Seed, planIdentity, reproductionKey)
	if registration.Accepted ~= true then
		return table.freeze({
			Accepted = false,
			ReasonId = registration.ReasonId,
			Layout = layoutsByRunId[runId],
			RunId = runId,
			Instance = registration.Record,
		})
	end
	local instance = registration.Record
	local root = Instance.new("Folder")
	root.Name = string.format("Run_%02d", instance.SlotIndex)
	root:SetAttribute("RunId", runId)
	root:SetAttribute("InstanceSlot", instance.SlotIndex)
	root:SetAttribute("Seed", layout.Seed)
	root:SetAttribute("PlanIdentity", planIdentity)
	root:SetAttribute("ReproductionKey", reproductionKey)
	root:SetAttribute("OriginX", instance.OriginX)
	root:SetAttribute("OriginZ", instance.OriginZ)
	root:SetAttribute("EnvironmentTheme", "RuinedSciFantasy")

	local buildOk, buildError = pcall(function()
		for _, placement in layout.Placements do
			buildRoom(shiftPlacement(placement, instance.OriginX, instance.OriginZ), layout.Seed, root)
		end
		for index, connector in layout.Connectors do
			local center = connector.Center
			local bridge = part(
				string.format("Connector_%02d_%02d", connector.FromIndex, connector.ToIndex),
				Vector3.new(8, 1, connector.Length),
				CFrame.new(center.x + instance.OriginX, 0, center.z + instance.OriginZ),
				root
			)
			bridge.Material = Enum.Material.CorrodedMetal
			bridge.Color = Color3.fromRGB(50, 55, 60)
			bridge:SetAttribute("ConnectorIndex", index)
		end
	end)
	if not buildOk then
		root:Destroy()
		registry:remove(runId)
		warn("[ExpeditionRoomPlacement] failed to build run instance:", runId, buildError)
		return table.freeze({ Accepted = false, ReasonId = "InstanceBuildFailed", Layout = nil, RunId = runId })
	end

	root.Parent = container()
	rootsByRunId[runId] = root
	layoutsByRunId[runId] = layout
	return table.freeze({
		Accepted = true,
		ReasonId = "RoomsPlaced",
		Layout = layout,
		RunId = runId,
		Instance = instance,
	})
end

function Service.destroyRun(runId: string): any
	local root = rootsByRunId[runId]
	if root ~= nil then
		root:Destroy()
	end
	rootsByRunId[runId] = nil
	layoutsByRunId[runId] = nil
	local removed = registry:remove(runId)
	removeEmptyContainer()
	return removed
end

function Service.getRootForRun(runId: string): Folder?
	return rootsByRunId[runId]
end

function Service.getLayoutForRun(runId: string): any
	return layoutsByRunId[runId]
end

function Service.getInstanceForRun(runId: string): any
	return registry:get(runId)
end

function Service.getActiveInstances(): { any }
	return registry:list()
end

function Service.destroyAll()
	for _, root in rootsByRunId do
		root:Destroy()
	end
	table.clear(rootsByRunId)
	table.clear(layoutsByRunId)
	registry:reset()
	removeEmptyContainer()
end

-- Compatibility surface for the current singleton ExpeditionLiveRuntimeService.
function Service.place(roomPlan: any): any
	return Service.placeForRun(LEGACY_RUN_ID, roomPlan)
end

function Service.destroy()
	Service.destroyRun(LEGACY_RUN_ID)
end

function Service.getRoot(): Folder?
	return Service.getRootForRun(LEGACY_RUN_ID)
end

return table.freeze(Service)
