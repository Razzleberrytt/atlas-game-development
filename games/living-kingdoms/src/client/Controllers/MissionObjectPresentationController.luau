--!strict

--[[
	VIS-0105 client-local mission-object presentation. It consumes only validated,
	monotonic safe mission snapshots and server-created mission objects. It never
	sends a remote or changes prompts, collision, objective state, extraction
	state, timers, outcomes, or any server-owned root transform.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MissionContracts = require(ReplicatedStorage.Shared.Mission.MissionContracts)
local MissionObjectPresentationFactory = require(script.Parent.Parent.Presentation.MissionObjectPresentationFactory)
local MissionObjectPresentationResolver = require(script.Parent.Parent.Presentation.MissionObjectPresentationResolver)

type SafeMissionSnapshot = MissionContracts.SafeMissionSnapshot
type RelayRig = MissionObjectPresentationFactory.RelayRig
type ExtractionRig = MissionObjectPresentationFactory.ExtractionRig

type RelayBinding = {
	serverModel: Model,
	body: BasePart,
	lamp: BasePart,
	rig: RelayRig,
	bodyLocalTransparencyModifier: number,
	lampLocalTransparencyModifier: number,
	serverLight: PointLight?,
	serverLightWasEnabled: boolean?,
}

type ExtractionBinding = {
	serverModel: Model,
	pillar: BasePart,
	rig: ExtractionRig,
	pillarLocalTransparencyModifier: number,
	serverLight: PointLight?,
	serverLightWasEnabled: boolean?,
	serverMarker: BillboardGui?,
	serverMarkerWasEnabled: boolean?,
}

local Controller = {}

local NETWORK_WAIT_SECONDS = 20
local RELAY_MODEL_NAME = "RelayConsole"
local RELAY_BODY_NAME = "ConsoleBody"
local RELAY_LAMP_NAME = "StatusLamp"
local EXTRACTION_MODEL_NAME = "ExtractionBeacon"
local EXTRACTION_PILLAR_NAME = "SignalPillar"
local EXTRACTION_MARKER_NAME = "ExtractionMarker"

local started = false
local latestSnapshot: SafeMissionSnapshot? = nil
local stateConnection: RBXScriptConnection? = nil
local descendantAddedConnection: RBXScriptConnection? = nil
local descendantRemovingConnection: RBXScriptConnection? = nil
local relayBinding: RelayBinding? = nil
local extractionBinding: ExtractionBinding? = nil

local missionNetwork = ReplicatedStorage:WaitForChild("MissionNetwork", NETWORK_WAIT_SECONDS)
assert(missionNetwork ~= nil, "MissionNetwork did not become available before the client bootstrap timeout")
local stateRemote = missionNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(stateRemote ~= nil, "MissionNetwork.State did not become available before the client bootstrap timeout")

local function findBasePart(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function restoreRelay(binding: RelayBinding)
	if binding.body.Parent ~= nil then
		binding.body.LocalTransparencyModifier = binding.bodyLocalTransparencyModifier
	end
	if binding.lamp.Parent ~= nil then
		binding.lamp.LocalTransparencyModifier = binding.lampLocalTransparencyModifier
	end
	local serverLight = binding.serverLight
	if serverLight ~= nil and serverLight.Parent ~= nil and binding.serverLightWasEnabled ~= nil then
		serverLight.Enabled = binding.serverLightWasEnabled
	end
end

local function restoreExtraction(binding: ExtractionBinding)
	if binding.pillar.Parent ~= nil then
		binding.pillar.LocalTransparencyModifier = binding.pillarLocalTransparencyModifier
	end
	local serverLight = binding.serverLight
	if serverLight ~= nil and serverLight.Parent ~= nil and binding.serverLightWasEnabled ~= nil then
		serverLight.Enabled = binding.serverLightWasEnabled
	end
	local serverMarker = binding.serverMarker
	if serverMarker ~= nil and serverMarker.Parent ~= nil and binding.serverMarkerWasEnabled ~= nil then
		serverMarker.Enabled = binding.serverMarkerWasEnabled
	end
end

local function unbindRelay()
	local binding = relayBinding
	if binding == nil then
		return
	end
	relayBinding = nil
	restoreRelay(binding)
	if binding.rig.model.Parent ~= nil then
		binding.rig.model:Destroy()
	end
end

local function unbindExtraction()
	local binding = extractionBinding
	if binding == nil then
		return
	end
	extractionBinding = nil
	restoreExtraction(binding)
	if binding.rig.model.Parent ~= nil then
		binding.rig.model:Destroy()
	end
end

local function resolvePresentation()
	local snapshot = latestSnapshot
	if snapshot == nil then
		return MissionObjectPresentationResolver.resolve({
			phaseId = nil,
			objectiveStateId = nil,
			extractionUnlocked = nil,
			outcomeId = nil,
		})
	end
	return MissionObjectPresentationResolver.resolve({
		phaseId = snapshot.phaseId,
		objectiveStateId = snapshot.objectiveStateId,
		extractionUnlocked = snapshot.extractionUnlocked,
		outcomeId = snapshot.outcomeId,
	})
end

local function applyRelay()
	local binding = relayBinding
	if binding == nil then
		return
	end
	local presentation = resolvePresentation().relay
	MissionObjectPresentationFactory.applyRelayState(binding.rig, presentation.stateId, presentation.labelText)
	if presentation.stateId == "Hidden" then
		restoreRelay(binding)
		return
	end
	binding.body.LocalTransparencyModifier = 1
	binding.lamp.LocalTransparencyModifier = 1
	local serverLight = binding.serverLight
	if serverLight ~= nil and serverLight.Parent ~= nil then
		serverLight.Enabled = false
	end
end

local function applyExtraction()
	local binding = extractionBinding
	if binding == nil then
		return
	end
	local presentation = resolvePresentation().extraction
	MissionObjectPresentationFactory.applyExtractionState(binding.rig, presentation.stateId, presentation.labelText)
	if presentation.stateId == "Hidden" then
		restoreExtraction(binding)
		return
	end
	binding.pillar.LocalTransparencyModifier = 1
	local serverLight = binding.serverLight
	if serverLight ~= nil and serverLight.Parent ~= nil then
		serverLight.Enabled = false
	end
	local serverMarker = binding.serverMarker
	if serverMarker ~= nil and serverMarker.Parent ~= nil then
		serverMarker.Enabled = false
	end
end

local function applyAll()
	applyRelay()
	applyExtraction()
end

local function bindRelay(serverModel: Model)
	if not started or serverModel.Parent == nil then
		return
	end
	local existing = relayBinding
	if existing ~= nil and existing.serverModel == serverModel then
		applyRelay()
		return
	end
	unbindRelay()
	local body = findBasePart(serverModel, RELAY_BODY_NAME)
	local lamp = findBasePart(serverModel, RELAY_LAMP_NAME)
	if body == nil or lamp == nil then
		return
	end
	local serverLight = lamp:FindFirstChildOfClass("PointLight")
	local rig = MissionObjectPresentationFactory.createRelay(body)
	rig.model.Parent = serverModel
	relayBinding = {
		serverModel = serverModel,
		body = body,
		lamp = lamp,
		rig = rig,
		bodyLocalTransparencyModifier = body.LocalTransparencyModifier,
		lampLocalTransparencyModifier = lamp.LocalTransparencyModifier,
		serverLight = serverLight,
		serverLightWasEnabled = if serverLight == nil then nil else serverLight.Enabled,
	}
	applyRelay()
end

local function bindExtraction(serverModel: Model)
	if not started or serverModel.Parent == nil then
		return
	end
	local existing = extractionBinding
	if existing ~= nil and existing.serverModel == serverModel then
		applyExtraction()
		return
	end
	unbindExtraction()
	local pillar = findBasePart(serverModel, EXTRACTION_PILLAR_NAME)
	if pillar == nil then
		return
	end
	local serverLight = pillar:FindFirstChildOfClass("PointLight")
	local marker = pillar:FindFirstChild(EXTRACTION_MARKER_NAME)
	local serverMarker = if marker ~= nil and marker:IsA("BillboardGui") then marker else nil
	local rig = MissionObjectPresentationFactory.createExtraction(pillar)
	rig.model.Parent = serverModel
	extractionBinding = {
		serverModel = serverModel,
		pillar = pillar,
		rig = rig,
		pillarLocalTransparencyModifier = pillar.LocalTransparencyModifier,
		serverLight = serverLight,
		serverLightWasEnabled = if serverLight == nil then nil else serverLight.Enabled,
		serverMarker = serverMarker,
		serverMarkerWasEnabled = if serverMarker == nil then nil else serverMarker.Enabled,
	}
	applyExtraction()
end

local function inspectInstance(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance.Name == RELAY_MODEL_NAME then
		bindRelay(instance)
	elseif instance.Name == EXTRACTION_MODEL_NAME then
		bindExtraction(instance)
	end
end

local function onDescendantRemoving(instance: Instance)
	local currentRelay = relayBinding
	if currentRelay ~= nil and currentRelay.serverModel == instance then
		unbindRelay()
	end
	local currentExtraction = extractionBinding
	if currentExtraction ~= nil and currentExtraction.serverModel == instance then
		unbindExtraction()
	end
end

local function onSnapshot(payload: unknown)
	if not MissionContracts.validateSafeMissionSnapshot(payload) then
		return
	end
	local snapshot = payload :: SafeMissionSnapshot
	local previous = latestSnapshot
	if previous ~= nil and snapshot.operationId == previous.operationId and snapshot.revision <= previous.revision then
		return
	end
	latestSnapshot = snapshot
	applyAll()
end

function Controller.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		inspectInstance(descendant)
	end
	stateConnection = stateRemote.OnClientEvent:Connect(onSnapshot)
	descendantAddedConnection = Workspace.DescendantAdded:Connect(inspectInstance)
	descendantRemovingConnection = Workspace.DescendantRemoving:Connect(onDescendantRemoving)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if stateConnection ~= nil then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	if descendantAddedConnection ~= nil then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end
	if descendantRemovingConnection ~= nil then
		descendantRemovingConnection:Disconnect()
		descendantRemovingConnection = nil
	end
	unbindRelay()
	unbindExtraction()
	latestSnapshot = nil
end

return table.freeze(Controller)
