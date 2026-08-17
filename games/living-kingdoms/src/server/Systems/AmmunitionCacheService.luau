--!strict

-- P6-0104 server-owned authored cache runtime. ProximityPrompt supplies only
-- the triggering Player; cache identity, position, grant, life eligibility,
-- distance, carry capacity, duplicate history, and ammunition mutation are
-- all derived and committed on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local NETWORK_WAIT_SECONDS = 20

local CachePresentationContracts = require(ReplicatedStorage.Shared.Combat.AmmunitionCachePresentationContracts)
local Contracts = require(ReplicatedStorage.Shared.Combat.AmmunitionScarcityContracts)
local CacheConfig = require(ReplicatedStorage.Shared.Config.AmmunitionCacheConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

local function resolveWeaponDefinition(weaponId: unknown)
	local getter = FirearmConfig.get
	if type(getter) == "function" then
		return getter(weaponId)
	end
	local basic = FirearmConfig.BasicFirearm
	return if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end
local AmmunitionSupplyResolver = require(script.Parent.Parent.Domain.AmmunitionSupplyResolver)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local SourceIds = Contracts.SupplySourceIds
local CACHE_FOLDER_NAME = "AmmunitionCaches"
local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)
assert(combatNetwork ~= nil, "CombatNetwork did not become available before the server bootstrap timeout")
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation", NETWORK_WAIT_SECONDS) :: any
assert(
	presentationRemote ~= nil,
	"combatNetwork.CombatPresentation did not become available before the server bootstrap timeout"
)

export type CollectionState = {
	processedCacheIds: { [string]: boolean },
	grantedRoundsByCacheId: { [string]: number },
}

local AmmunitionCacheService = {}
local started = false
local cacheFolder: Folder? = nil
local promptConnections: { RBXScriptConnection } = {}
local playerRemovingConnection: RBXScriptConnection? = nil
local processedByPlayer: { [Player]: { [string]: boolean } } = {}
local grantedRoundsByPlayer: { [Player]: { [string]: number } } = {}

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function operativePosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function processedSetFor(player: Player): { [string]: boolean }
	local existing = processedByPlayer[player]
	if existing ~= nil then
		return existing
	end
	local created = {}
	processedByPlayer[player] = created
	return created
end

local function grantedSetFor(player: Player): { [string]: number }
	local existing = grantedRoundsByPlayer[player]
	if existing ~= nil then
		return existing
	end
	local created = {}
	grantedRoundsByPlayer[player] = created
	return created
end

local function tryCollect(player: Player, definition)
	if not started or not OperativeLifeService.isCombatAllowed(player) then
		return
	end
	local processed = processedSetFor(player)
	if processed[definition.cacheId] then
		return
	end
	local position = operativePosition(player)
	local cachePosition = Vector3.new(definition.position.x, definition.position.y, definition.position.z)
	if
		position == nil
		or horizontalDistance(position, cachePosition) > CacheConfig.Interaction.MaximumDistanceStuds
	then
		return
	end
	local read = OperativeCombatRuntimeService.readReviveCombatState(player)
	if read == nil then
		return
	end
	local combatState = read.combatState
	local weaponState = combatState.weaponState
	local ammunition = weaponState.ammunition
	local result = AmmunitionSupplyResolver.collect({
		weaponId = ammunition.weaponId,
		loadedRounds = ammunition.loadedRounds,
		reserveRounds = ammunition.reserveRounds,
		magazineCapacity = ammunition.magazineCapacity,
		maximumReserveRounds = (resolveWeaponDefinition(ammunition.weaponId) or FirearmConfig.BasicFirearm).MaximumReserveRounds,
		processedSupplyIds = processed,
	}, {
		supplyId = definition.cacheId,
		sourceId = SourceIds.AuthoredCache,
		weaponId = ammunition.weaponId,
		availableRounds = (resolveWeaponDefinition(ammunition.weaponId) or FirearmConfig.BasicFirearm).AuthoredCacheRounds,
	})
	if not result.didCollect then
		return
	end
	local stateAfter = result.stateAfter
	combatState.weaponState.ammunition.reserveRounds = stateAfter.reserveRounds
	if
		not OperativeCombatRuntimeService.commitReviveCombatState(
			player,
			read.generation,
			combatState,
			result.grantedRounds
		)
	then
		return
	end
	processedByPlayer[player] = table.clone(stateAfter.processedSupplyIds)
	grantedSetFor(player)[definition.cacheId] = result.grantedRounds
	presentationRemote:FireClient(player, {
		kindId = CachePresentationContracts.MessageKindIds.Consumed,
		cacheId = definition.cacheId,
	})
end

function AmmunitionCacheService.readCollectionState(player: Player): CollectionState
	local processed = processedByPlayer[player] or {}
	local granted = grantedRoundsByPlayer[player] or {}
	return table.freeze({
		processedCacheIds = table.freeze(table.clone(processed)),
		grantedRoundsByCacheId = table.freeze(table.clone(granted)),
	})
end

local function createCache(definition, parent: Folder)
	local part = Instance.new("Part")
	part.Name = definition.cacheId
	part.Size = Vector3.new(3.6, 1.8, 2.6)
	part.Position = Vector3.new(definition.position.x, definition.position.y, definition.position.z)
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(76, 91, 67)
	part:SetAttribute("SupplyCacheId", definition.cacheId)
	part.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Collect"
	prompt.ObjectText = definition.displayName
	prompt.HoldDuration = CacheConfig.Interaction.HoldDurationSeconds
	prompt.MaxActivationDistance = CacheConfig.Interaction.MaximumDistanceStuds
	prompt.RequiresLineOfSight = true
	prompt.Parent = part
	table.insert(
		promptConnections,
		prompt.Triggered:Connect(function(player)
			tryCollect(player, definition)
		end)
	)
end

function AmmunitionCacheService.start()
	if started then
		return
	end
	started = true
	local existing = Workspace:FindFirstChild(CACHE_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = CACHE_FOLDER_NAME
	folder.Parent = Workspace
	cacheFolder = folder
	for _, definition in CacheConfig.Caches do
		createCache(definition, folder)
	end
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		processedByPlayer[player] = nil
		grantedRoundsByPlayer[player] = nil
	end)
end

function AmmunitionCacheService.stop()
	if not started then
		return
	end
	started = false
	for _, connection in promptConnections do
		connection:Disconnect()
	end
	table.clear(promptConnections)
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	table.clear(processedByPlayer)
	table.clear(grantedRoundsByPlayer)
	local folder = cacheFolder
	if folder ~= nil then
		folder:Destroy()
		cacheFolder = nil
	end
end

return AmmunitionCacheService
