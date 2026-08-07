--!strict

--[[
	VIS-0105 client-local static landmark accents. Existing server-authored models
	remain the complete world, collision, spawn, route, and mission truth. This
	controller only attaches bounded non-interactive geometry to eligible models.
]]

local Workspace = game:GetService("Workspace")

local Resolver = require(script.Parent.Parent.Presentation.LandmarkAccentPresentationResolver)
local Factory = require(script.Parent.Parent.Presentation.LandmarkAccentPresentationFactory)

local Controller = {}
local started = false
local descendantAddedConnection: RBXScriptConnection? = nil
local descendantRemovingConnection: RBXScriptConnection? = nil
local presentationsByLandmark: { [Model]: Model } = {}
local bindingInProgress: { [Model]: boolean } = {}

local REQUIRED_ANCHOR_NAMES = table.freeze({
	Roof = true,
	RadioMast = true,
	CheckpointCabin = true,
	RoadblockEmergencyLight = true,
	AbandonedTent1 = true,
	AbandonedTent2 = true,
	DeadFire = true,
	WashedOutWarning = true,
	FallenCreekTree = true,
	BrokenGuardRail = true,
	ReadableCliffEdge = true,
})

local function landmarkModelFor(instance: Instance): Model?
	local current: Instance? = instance
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("LandmarkId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function styleFor(model: Model): Resolver.StyleId?
	return Resolver.resolve(model.Name, model:GetAttribute("LandmarkId"), model:GetAttribute("Graybox"))
end

local function unbind(model: Model)
	bindingInProgress[model] = nil
	local presentation = presentationsByLandmark[model]
	presentationsByLandmark[model] = nil
	if presentation ~= nil and presentation.Parent ~= nil then
		presentation:Destroy()
	end
end

local function bind(model: Model)
	if not started or model.Parent == nil or bindingInProgress[model] then
		return
	end
	local styleId = styleFor(model)
	if styleId == nil then
		unbind(model)
		return
	end
	local existing = presentationsByLandmark[model]
	if existing ~= nil and existing.Parent == model then
		return
	end
	unbind(model)
	local stale = model:FindFirstChild(Factory.PresentationModelName)
	if stale ~= nil then
		stale:Destroy()
	end
	bindingInProgress[model] = true
	local presentation = Factory.create(model, styleId)
	bindingInProgress[model] = nil
	if presentation ~= nil then
		presentationsByLandmark[model] = presentation
	end
end

local function onDescendantAdded(descendant: Instance)
	local model = landmarkModelFor(descendant)
	if model ~= nil then
		bind(model)
	end
end

local function onDescendantRemoving(descendant: Instance)
	local model = landmarkModelFor(descendant)
	if model == nil then
		return
	end
	if descendant == model or REQUIRED_ANCHOR_NAMES[descendant.Name] == true then
		unbind(model)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		onDescendantAdded(descendant)
	end
	descendantAddedConnection = Workspace.DescendantAdded:Connect(onDescendantAdded)
	descendantRemovingConnection = Workspace.DescendantRemoving:Connect(onDescendantRemoving)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if descendantAddedConnection ~= nil then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end
	if descendantRemovingConnection ~= nil then
		descendantRemovingConnection:Disconnect()
		descendantRemovingConnection = nil
	end
	local landmarks = {}
	for model in presentationsByLandmark do
		table.insert(landmarks, model)
	end
	for _, model in landmarks do
		unbind(model)
	end
	table.clear(bindingInProgress)
end

return table.freeze(Controller)
