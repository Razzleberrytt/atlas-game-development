from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected one match in {path}, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


controller_source = '''--!strict

--[[
	VIS-0105 client-local supply-cache presentation. The server-owned BasePart and
	ProximityPrompt remain the only gameplay root and interaction path. This
	controller attaches a bounded procedural shell and remembers only the local
	operative's server-disclosed consumed messages.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
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
		if consumed then SupplyCachePresentationConfig.StateIds.Consumed else SupplyCachePresentationConfig.StateIds.Available
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
'''
Path("games/living-kingdoms/src/client/Controllers/AmmunitionCachePresentationController.luau").write_text(
    controller_source,
    encoding="utf-8",
)

factory = "games/living-kingdoms/src/client/Presentation/SupplyCachePresentationFactory.luau"
replace_once(factory, "\tmotor.Parent = root", "\tmotor.Parent = lid")
replace_once(factory, "\tlocal signalBand = nil", "\tlocal signalBand: BasePart? = nil")
replace_once(factory, "\tlocal emptyTray = nil", "\tlocal emptyTray: BasePart? = nil")
replace_once(factory, "\tlocal latches = {}", "\tlocal latches: { BasePart } = {}")
replace_once(factory, "\tlocal frontPanel = nil", "\tlocal frontPanel: BasePart? = nil")
replace_once(factory, "\t\t\tpart.Color = availableColor", "\t\t\tpart.Color = availableColor or PALETTE.Body")

registry = "games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau"
replace_once(
    registry,
    '''\trecord(
\t\tKeys.SupplyAmmunitionCacheModel,
\t\tFamilyIds.Supply,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/AmmunitionCacheService.luau",
\t\t"Each authored cache is generated as one green metal Part with a ProximityPrompt.",
\t\t"AmmunitionCache",
\t\t{ "PromptAttachment" },
\t\t"supply.authored-cache",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.SupplyAmmunitionCacheModel,
\t\tFamilyIds.Supply,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/AmmunitionCachePresentationController.luau",
\t\t"The server-owned collidable cache root and prompt remain unchanged while a 13-part client-local procedural supply case provides available and per-operative consumed readability.",
\t\t"SupplyCachePresentation",
\t\t{},
\t\t"supply.authored-cache",
\t\tfalse
\t),''',
)

roadmap = "docs/roadmap/VISUAL-PRODUCTION-TRACK.md"
replace_once(
    roadmap,
    '''- [ ] **VIS-0105 — Replace world, supply, and objective placeholders.**
  - Produce authored landmarks, environmental dressing, caches, depletion state, objective equipment, extraction presentation, route cues, temporary defensive positions, lighting, fog, and ambience.
  - Objective art follows the P8 authored chain and may not disclose hidden or inactive truth.''',
    '''- [~] **VIS-0105 — Replace world, supply, and objective placeholders.**
  - The authored rifle-ammunition cache now receives a 13-part client-local procedural supply case with rails, latches, handle, signal band, surface label, empty tray, and one motorized lid around the unchanged server-owned `3.6 x 1.8 x 2.6` collidable root.
  - Existing per-operative consumed disclosure opens and darkens only that player's case, exposes the empty tray, changes the label from `RIFLE AMMO` to `EMPTY`, and disables only the local prompt; consumed messages are remembered before cache lookup for streaming safety.
  - The cache layer uses three global connections, zero per-cache connections, zero frame loops, zero timers, zero new remotes, and no server runtime change. Cleanup restores local root visibility and prompt state.
  - Still required: Studio gameplay-camera and interaction review, final cache materials/effects/audio, world dressing, landmarks, objective equipment, extraction presentation, route cues, lighting, fog, ambience, and representative performance evidence.
  - Objective art follows the P8 authored chain and may not disclose hidden or inactive truth.''',
)

inventory = "docs/specifications/visual-placeholder-inventory.md"
replace_once(
    inventory,
    "| Supply | Ammunition cache | Primitive placeholder | `AmmunitionCacheService`; one green metal Part and ProximityPrompt | VIS-0105 |",
    "| Supply | Ammunition cache | Primitive placeholder | `AmmunitionCacheService` retains the authoritative root/prompt; `SupplyCachePresentationFactory` and `AmmunitionCachePresentationController` add a 13-part available/locally-consumed procedural case | VIS-0105 |",
)
replace_once(
    inventory,
    "Continue VIS-0104 with canonical rig and authored animation planning while keeping class-action cues, gameplay-camera and animation-interaction approval, avatar-scale coverage, and representative squad performance evidence pending.",
    "Continue VIS-0105 with objective, extraction, and major-world readability while keeping Studio cache review, final cache materials/effects/audio, canonical operative art, class-action cues, avatar-scale coverage, and representative performance evidence pending.",
)

test = "games/living-kingdoms/tests/VisualAssetContractsConfig.test.luau"
replace_once(
    test,
    '''assertThat(
\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
\t"standard hostile must remain honestly marked as primitive geometry"
)''',
    '''local supplyCache = config.ByKey[contracts.AssetKeys.SupplyAmmunitionCacheModel]
assertThat(supplyCache.statusId == contracts.StatusIds.PrimitivePlaceholder, "supply cache must remain primitive")
assertThat(
\tsupplyCache.runtimeOwnerPath == "src/client/Controllers/AmmunitionCachePresentationController.luau",
\t"supply cache registry must name the presentation owner"
)
assertThat(supplyCache.expectedRootName == "SupplyCachePresentation", "supply cache root contract drifted")
assertThat(#supplyCache.requiredAttachmentNames == 0, "procedural supply cache must not claim authored attachments")
assertThat(
\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
\t"standard hostile must remain honestly marked as primitive geometry"
)''',
)

print("supply cache visual integration staged")
