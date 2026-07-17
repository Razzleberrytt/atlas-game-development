--!strict

--[[
	P5-0104 production automatic-combat owner. It composes the existing P2
	targeting, cadence, reload, hit, and damage authority with the production
	enemy lifecycle. Clients may request reload only; target selection, firing,
	hit legality, damage, ammunition, and cadence remain server-owned.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local AutomaticFireResolver = require(script.Parent.AutomaticFireResolver)
local EnemyLifecycleService = require(script.Parent.EnemyLifecycleService)
local FirearmHitResolver = require(script.Parent.FirearmHitResolver)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local ReloadResolver = require(script.Parent.ReloadResolver)
local TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)

local Service = {}
local EVALUATION_INTERVAL_SECONDS = 0.05
local RELOAD_REQUEST_COOLDOWN_SECONDS = 0.25

local playerStates: { [Player]: any } = {}
local accumulatedSeconds = 0
local started = false
local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local reloadIntentConnection: RBXScriptConnection? = nil

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local reloadIntentRemote = combatNetwork:WaitForChild("ReloadIntent") :: RemoteEvent
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function createWeaponState()
	local config = FirearmConfig.BasicFirearm
	return {
		weaponId = config.WeaponId,
		readinessStateId = CombatContracts.WeaponReadinessStateIds.Ready,
		ammunition = {
			weaponId = config.WeaponId,
			loadedRounds = config.PrototypeInitialLoadedRounds,
			reserveRounds = config.PrototypeInitialReserveRounds,
			magazineCapacity = config.MagazineCapacity,
		},
		cadence = {
			weaponId = config.WeaponId,
			lastFireServerTimestamp = nil,
			nextAllowedFireServerTimestamp = 0,
		},
		reloadState = nil,
	}
end

local function createPlayerState(player: Player)
	return {
		operativeState = {
			entityId = "operative.player:" .. tostring(player.UserId),
			combatStateId = CombatContracts.OperativeCombatStateIds.Ready,
			equippedWeaponId = FirearmConfig.BasicFirearm.WeaponId,
		},
		weaponState = createWeaponState(),
		selectedTargetEntityId = nil,
		lastReloadRequestServerTimestamp = -math.huge,
		generation = 1,
	}
end

local function operativePosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

local function enemyModel(entityId: string): Model?
	local folder = Workspace:FindFirstChild(EnemyConfig.ModelFolderName)
	local model = if folder == nil then nil else folder:FindFirstChild(entityId)
	return if model ~= nil and model:IsA("Model") then model else nil
end

local function enemyPosition(entityId: string): Vector3?
	local model = enemyModel(entityId)
	local root = if model == nil then nil else model:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

local function hasLineOfSight(origin: Vector3, target: Vector3, targetModel: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions = {}
	local productionFolder = Workspace:FindFirstChild(EnemyConfig.ModelFolderName)
	if productionFolder ~= nil then
		table.insert(exclusions, productionFolder)
	end
	params.FilterDescendantsInstances = exclusions
	local result = Workspace:Raycast(origin + Vector3.new(0, 1.5, 0), target - origin, params)
	return result == nil or result.Instance:IsDescendantOf(targetModel) or (result.Position - target).Magnitude <= 4
end

local function createCandidates(operativeEntityId: string, origin: Vector3)
	local candidates = {}
	for _, snapshot in EnemyLifecycleService.readAll() do
		if snapshot.lifecycleStateId == "Active" then
			local model = enemyModel(snapshot.entityId)
			local position = enemyPosition(snapshot.entityId)
			if model ~= nil and position ~= nil then
				local distance = (position - origin).Magnitude
				local visible = distance <= FirearmConfig.BasicFirearm.RangeStuds
				local lineOfSight = visible and hasLineOfSight(origin, position, model)
				table.insert(candidates, {
					entityId = snapshot.entityId,
					entityKindId = CombatContracts.CombatEntityKindIds.Hostile,
					teamId = "team.living-kingdoms.hostiles",
					relationshipId = CombatContracts.TeamRelationshipIds.Hostile,
					worldPosition = position,
					distanceStuds = distance,
					isAlive = true,
					isTargetable = true,
					isVisible = visible,
					hasLineOfSight = lineOfSight,
					isActivelyThreatening = snapshot.selectedOperativeEntityId == operativeEntityId,
					activelyThreateningOperativeEntityId = if snapshot.selectedOperativeEntityId
							== operativeEntityId
						then operativeEntityId
						else nil,
				})
			end
		end
	end
	return candidates
end

local function discloseTarget(player: Player, state: any, targetEntityId: string?, serverTimestamp: number)
	if state.selectedTargetEntityId == targetEntityId then
		return
	end
	state.selectedTargetEntityId = targetEntityId
	presentationRemote:FireClient(
		player,
		if targetEntityId == nil
			then {
				kindId = CombatContracts.PresentationMessageKindIds.TargetCleared,
				operativeEntityId = state.operativeState.entityId,
				serverTimestamp = serverTimestamp,
			}
			else {
				kindId = CombatContracts.PresentationMessageKindIds.TargetSelected,
				operativeEntityId = state.operativeState.entityId,
				targetEntityId = targetEntityId,
				serverTimestamp = serverTimestamp,
			}
	)
end

local function resolveAcceptedShot(
	player: Player,
	state: any,
	origin: Vector3,
	fireResult: any,
	serverTimestamp: number
)
	local entityId = fireResult.targetEntityId
	local shotId = fireResult.shotId
	if entityId == nil or shotId == nil then
		return
	end
	local snapshot = EnemyLifecycleService.read(entityId)
	local model = enemyModel(entityId)
	local position = enemyPosition(entityId)
	if snapshot == nil or model == nil or position == nil or snapshot.lifecycleStateId ~= "Active" then
		return
	end
	local lineOfSight = hasLineOfSight(origin, position, model)
	local hit = FirearmHitResolver.resolve(fireResult, {
		operativeEntityId = state.operativeState.entityId,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		selectedTargetEntityId = entityId,
		operativeWorldPosition = origin,
		obstructionResultId = if lineOfSight
			then CombatContracts.ShotObstructionResultIds.TargetHit
			else CombatContracts.ShotObstructionResultIds.EnvironmentBlocked,
	}, {
		entityId = entityId,
		worldPosition = position,
		isAlive = true,
		isTargetable = true,
		relationshipId = CombatContracts.TeamRelationshipIds.Hostile,
		isVisible = (position - origin).Magnitude <= FirearmConfig.BasicFirearm.RangeStuds,
	})
	if hit.didHit == true and hit.hitEntityId == entityId then
		EnemyLifecycleService.applyAuthoritativeDamage(
			entityId,
			snapshot.revision,
			shotId,
			FirearmConfig.BasicFirearm.DamagePerHit,
			serverTimestamp
		)
	end
	presentationRemote:FireClient(player, {
		kindId = CombatContracts.PresentationMessageKindIds.ShotFired,
		shotId = shotId,
		operativeEntityId = state.operativeState.entityId,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		targetEntityId = entityId,
		serverTimestamp = serverTimestamp,
	})
end

local function evaluatePlayer(player: Player, state: any, serverTimestamp: number)
	if not OperativeLifeService.isCombatAllowed(player) then
		discloseTarget(player, state, nil, serverTimestamp)
		local restricted = OperativeLifeService.applyCombatRestrictions(player, state)
		if restricted ~= nil then
			playerStates[player] = restricted
		end
		return
	end
	local origin = operativePosition(player)
	if origin == nil then
		discloseTarget(player, state, nil, serverTimestamp)
		return
	end
	local selected = TargetCandidateSelector.select({
		entityId = state.operativeState.entityId,
		worldPosition = origin,
		combatStateId = state.operativeState.combatStateId,
		weaponReadiness = state.weaponState,
	}, createCandidates(state.operativeState.entityId, origin))
	local targetEntityId = if selected == nil then nil else selected.targetEntityId
	discloseTarget(player, state, targetEntityId, serverTimestamp)
	local resolution = AutomaticFireResolver.resolve(state.operativeState, selected, state.weaponState, serverTimestamp)
	state.weaponState = resolution.weaponStateAfter
	if resolution.decision.shouldFire then
		resolveAcceptedShot(player, state, origin, resolution.fireResult, serverTimestamp)
	end
end

local function completeReload(player: Player, expectedTimestamp: number, expectedGeneration: number)
	local state = playerStates[player]
	if state == nil or state.generation ~= expectedGeneration then
		return
	end
	local reloadState = state.weaponState.reloadState
	if reloadState == nil or reloadState.completionServerTimestamp ~= expectedTimestamp then
		return
	end
	local resolution = ReloadResolver.complete(state.operativeState, state.weaponState, Workspace:GetServerTimeNow())
	state.operativeState = resolution.operativeStateAfter
	state.weaponState = resolution.weaponStateAfter
	if resolution.didComplete then
		presentationRemote:FireClient(player, {
			kindId = CombatContracts.PresentationMessageKindIds.ReloadCompleted,
			weaponId = FirearmConfig.BasicFirearm.WeaponId,
		})
	end
end

local function onReloadIntent(player: Player, weaponId: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(weaponId) ~= "string" then
		return
	end
	local state = playerStates[player]
	if
		state == nil
		or not OperativeLifeService.isCombatAllowed(player)
		or weaponId ~= state.operativeState.equippedWeaponId
	then
		return
	end
	local serverTimestamp = Workspace:GetServerTimeNow()
	if serverTimestamp - state.lastReloadRequestServerTimestamp < RELOAD_REQUEST_COOLDOWN_SECONDS then
		return
	end
	state.lastReloadRequestServerTimestamp = serverTimestamp
	local resolution = ReloadResolver.begin(state.operativeState, state.weaponState, serverTimestamp)
	state.operativeState = resolution.operativeStateAfter
	state.weaponState = resolution.weaponStateAfter
	if not resolution.didBegin or resolution.weaponStateAfter.reloadState == nil then
		return
	end
	local completion = resolution.weaponStateAfter.reloadState.completionServerTimestamp
	local generation = state.generation
	presentationRemote:FireClient(player, {
		kindId = CombatContracts.PresentationMessageKindIds.ReloadStarted,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		completionServerTimestamp = completion,
	})
	task.delay(math.max(0, completion - serverTimestamp), function()
		completeReload(player, completion, generation)
	end)
end

function Service.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		playerStates[player] = createPlayerState(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		playerStates[player] = createPlayerState(player)
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)
	reloadIntentConnection = reloadIntentRemote.OnServerEvent:Connect(onReloadIntent)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaSeconds)
		accumulatedSeconds += deltaSeconds
		if accumulatedSeconds < EVALUATION_INTERVAL_SECONDS then
			return
		end
		accumulatedSeconds %= EVALUATION_INTERVAL_SECONDS
		local serverTimestamp = Workspace:GetServerTimeNow()
		for player, state in playerStates do
			evaluatePlayer(player, state, serverTimestamp)
		end
	end)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	for _, connection in
		{ heartbeatConnection, playerAddedConnection, playerRemovingConnection, reloadIntentConnection }
	do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	heartbeatConnection = nil
	playerAddedConnection = nil
	playerRemovingConnection = nil
	reloadIntentConnection = nil
	table.clear(playerStates)
	accumulatedSeconds = 0
end

return Service
