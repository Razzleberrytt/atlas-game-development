--!strict

--[[
	VIS-0105 client-local supply-cache presentation. The server-owned BasePart and
	ProximityPrompt remain the only gameplay root and interaction path. This
	controller attaches a bounded procedural shell and remembers only the local
	operative's server-disclosed consumed messages.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local Workspace = game:GetService("Workspace")

local Contracts = require(ReplicatedStorage.Shared.Combat.AmmunitionCachePresentationContracts)
local SupplyCachePresentationConfig = require(script.Parent.Parent.Presentation.SupplyCachePresentationConfig)
local SupplyCachePresentationFactory = require(script.Parent.Parent.Presentation.SupplyCachePresentationFactory)

type SupplyCachePresentationRig = SupplyCachePresentationFactory.SupplyCachePresentationRig

type CacheBinding = {
	cacheId: string,
	root: BasePart,
	rig: SupplyCachePresentationRig,
	originalLocalTransparencyModifier: number,
	prompt: ProximityPrompt?,
	promptWasEnabled: boolean?,
}

local SUPPLY_CACHE_ID_ATTRIBUTE = "SupplyCacheId"
local COLLECT_PROMPT_NAME = "CollectPrompt"

local Controller = {}
local started = false
local presentationConnection: RBXScriptConnection? = nil
local descendantAddedConnection: RBXScriptConnection? = nil
local descendantRemovingConnection: RBXScriptConnection? = nil
local consumedCacheIds: { [string]: boolean } = {}
local bindingsByCacheId: { [string]: CacheBinding } = {}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function cacheIdFor(root: BasePart): string?
	local cacheId = root:GetAttribute(SUPPLY_CACHE_ID_ATTRIBUTE)
	return if isNonEmptyString(cacheId) then cacheId :: string else nil
end

local function promptFor(root: BasePart): ProximityPrompt?
	local prompt = root:FindFirstChild(COLLECT_PROMPT_NAME)
	return if prompt ~= nil and prompt:IsA("ProximityPrompt") then prompt else nil
end

local function applyBinding(binding: CacheBinding)
	local consumed = consumedCacheIds[binding.cacheId] == true
	SupplyCachePresentationFactory.applyState(
		binding.rig,
		if consumed
			then SupplyCachePresentationConfig.StateIds.Consumed
			else SupplyCachePresentationConfig.StateIds.Available
	)
	local prompt = binding.prompt
	if prompt ~= nil and prompt.Parent ~= nil then
		prompt.Enabled = if consumed then false else binding.promptWasEnabled == true
	end
end

local function unbindCache(cacheId: string)
	local binding = bindingsByCacheId[cacheId]
	if binding == nil then
		return
	end
	bindingsByCacheId[cacheId] = nil
	local root = binding.root
	if root.Parent ~= nil then
		root.LocalTransparencyModifier = binding.originalLocalTransparencyModifier
	end
	local prompt = binding.prompt
	if prompt ~= nil and prompt.Parent ~= nil and binding.promptWasEnabled ~= nil then
		prompt.Enabled = binding.promptWasEnabled
	end
	if binding.rig.model.Parent ~= nil then
		binding.rig.model:Destroy()
	end
end

local function bindCache(root: BasePart)
	if not started or root.Parent == nil then
		return
	end
	local cacheId = cacheIdFor(root)
	if cacheId == nil then
		return
	end
	local existing = bindingsByCacheId[cacheId]
	if existing ~= nil then
		if existing.root == root then
			applyBinding(existing)
			return
		end
		unbindCache(cacheId)
	end
	local stalePresentation = root:FindFirstChild(SupplyCachePresentationConfig.PresentationModelName)
	if stalePresentation ~= nil then
		stalePresentation:Destroy()
	end
	local prompt = promptFor(root)
	local binding: CacheBinding = {
		cacheId = cacheId,
		root = root,
		rig = SupplyCachePresentationFactory.create(root),
		originalLocalTransparencyModifier = root.LocalTransparencyModifier,
		prompt = prompt,
		promptWasEnabled = if prompt == nil then nil else prompt.Enabled,
	}
	bindingsByCacheId[cacheId] = binding
	root.LocalTransparencyModifier = 1
	applyBinding(binding)
end

local function onDescendantAdded(descendant: Instance)
	if descendant:IsA("BasePart") and cacheIdFor(descendant) ~= nil then
		bindCache(descendant)
	end
end

local function onDescendantRemoving(descendant: Instance)
	if not descendant:IsA("BasePart") then
		return
	end
	local cacheId = cacheIdFor(descendant)
	if cacheId == nil then
		return
	end
	local binding = bindingsByCacheId[cacheId]
	if binding ~= nil and binding.root == descendant then
		unbindCache(cacheId)
	end
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	if payload.kindId ~= Contracts.MessageKindIds.Consumed or not isNonEmptyString(payload.cacheId) then
		return
	end
	local cacheId = payload.cacheId :: string
	consumedCacheIds[cacheId] = true
	local binding = bindingsByCacheId[cacheId]
	if binding ~= nil then
		applyBinding(binding)
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
	presentationConnection = presentationRemote.OnClientEvent:Connect(onPresentationMessage)
	descendantAddedConnection = Workspace.DescendantAdded:Connect(onDescendantAdded)
	descendantRemovingConnection = Workspace.DescendantRemoving:Connect(onDescendantRemoving)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if presentationConnection ~= nil then
		presentationConnection:Disconnect()
		presentationConnection = nil
	end
	if descendantAddedConnection ~= nil then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end
	if descendantRemovingConnection ~= nil then
		descendantRemovingConnection:Disconnect()
		descendantRemovingConnection = nil
	end
	local boundCacheIds = {}
	for cacheId in bindingsByCacheId do
		table.insert(boundCacheIds, cacheId)
	end
	for _, cacheId in boundCacheIds do
		unbindCache(cacheId)
	end
	table.clear(consumedCacheIds)
end

return table.freeze(Controller)
