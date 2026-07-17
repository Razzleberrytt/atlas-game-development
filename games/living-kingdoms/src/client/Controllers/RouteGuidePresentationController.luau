--!strict

--[[
	VIS-0105 client-local route guide presentation. It attaches two bounded guide
	posts to each existing authored logging-road or switchback-trail segment. It
	never changes route transforms, size, collision, movement, mission state,
	objective state, extraction state, or server ownership.
]]

local Workspace = game:GetService("Workspace")

local RouteEdgePresentationResolver = require(script.Parent.Parent.Presentation.RouteEdgePresentationResolver)
local RouteGuidePresentationFactory = require(script.Parent.Parent.Presentation.RouteGuidePresentationFactory)

type RouteGuideRig = RouteGuidePresentationFactory.RouteGuideRig

local Controller = {}
local PRESENTATION_MODEL_NAME = "RouteGuidePresentation"

local started = false
local descendantAddedConnection: RBXScriptConnection? = nil
local descendantRemovingConnection: RBXScriptConnection? = nil
local rigsBySegment: { [BasePart]: RouteGuideRig } = {}

local function removeSegment(segment: BasePart)
	local rig = rigsBySegment[segment]
	if rig == nil then
		return
	end
	rigsBySegment[segment] = nil
	if rig.model.Parent ~= nil then
		rig.model:Destroy()
	end
end

local function inspect(instance: Instance)
	if not started or not instance:IsA("BasePart") or rigsBySegment[instance] ~= nil then
		return
	end
	local definition = RouteEdgePresentationResolver.resolve({
		segmentName = instance.Name,
		widthStuds = instance.Size.X,
		heightStuds = instance.Size.Y,
	})
	if definition.styleId == "Hidden" then
		return
	end
	local stale = instance:FindFirstChild(PRESENTATION_MODEL_NAME)
	if stale ~= nil then
		stale:Destroy()
	end
	local rig = RouteGuidePresentationFactory.create(instance, definition)
	rig.model.Parent = instance
	rigsBySegment[instance] = rig
end

local function onRemoving(instance: Instance)
	if instance:IsA("BasePart") then
		removeSegment(instance)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		inspect(descendant)
	end
	descendantAddedConnection = Workspace.DescendantAdded:Connect(inspect)
	descendantRemovingConnection = Workspace.DescendantRemoving:Connect(onRemoving)
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
	local segments = {}
	for segment in rigsBySegment do
		table.insert(segments, segment)
	end
	for _, segment in segments do
		removeSegment(segment)
	end
end

return table.freeze(Controller)
