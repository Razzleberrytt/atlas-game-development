--!strict

--[[
	Studio-only LK-0207 integration harness. Two stationary labeled fixtures and
	per-player server-owned combat state exercise the existing pure P2 pipeline.
	This is not hostile discovery, enemy AI, production health, spawning, waves,
	or a production combat service. Outside Studio, start is a no-op.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local AutomaticFireResolver = require(script.Parent.AutomaticFireResolver)
local DamageResolver = require(script.Parent.DamageResolver)
local FirearmHitResolver = require(script.Parent.FirearmHitResolver)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local ReloadResolver = require(script.Parent.ReloadResolver)
local TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)

type CombatEntityId = CombatContracts.CombatEntityId
type FirearmTargetContext = CombatContracts.FirearmTargetContext
type OperativeReloadState = CombatContracts.OperativeReloadState
type TargetCandidate = CombatContracts.TargetCandidate
type TargetHealthState = CombatContracts.TargetHealthState
type WeaponReadinessState = CombatContracts.WeaponReadinessState

type HostileFixture = {
	entityId: CombatEntityId,
	model: Model,
	root: BasePart,
	healthLabel: TextLabel,
	healthState: TargetHealthState,
	isAlive: boolean,
	isTargetable: boolean,
	isVisible: boolean,
	hasLineOfSight: boolean,
	obstructionResultId: CombatContracts.ShotObstructionResultId,
}

type PlayerCombatState = {
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState,
	selectedTargetEntityId: CombatEntityId?,
	threateningHostileEntityId: CombatEntityId,
	lastRequestServerTimestamp: number,
	generation: number,
	processedShotIds: { [string]: boolean },
}

type AutomaticCombatDevelopmentHarness = {
	start: () -> (),
	stop: () -> (),
}

local FIXTURE_FOLDER_NAME = "LK0207CombatFixtures"
local INITIAL_FIXTURE_HEALTH = 1000
local SERVER_REQUEST_COOLDOWN_SECONDS = 0.25
local EVALUATION_INTERVAL_SECONDS = 0.05
local HOSTILE_DEFINITIONS = {
	{ entityId = "hostile.lk0207.alpha", name = "LK-0207 Hostile Alpha", position = Vector3.new(18, 3, 0) },
	{ entityId = "hostile.lk0207.bravo", name = "LK-0207 Hostile Bravo", position = Vector3.new(-18, 3, 0) },
}

local AutomaticCombatDevelopmentHarness: AutomaticCombatDevelopmentHarness = {} :: AutomaticCombatDevelopmentHarness
local started = false
local accumulatedSeconds = 0
local nextThreatIndex = 1
local reloadIntentConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local lifeStateConnection: { Disconnect: (self: any) -> () }? = nil
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local playerStates: { [Player]: PlayerCombatState } = {}
local hostileFixtures: { HostileFixture } = {}
local hostileByEntityId: { [CombatEntityId]: HostileFixture } = {}
local fixtureFolder: Folder? = nil

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local reloadIntentRemote = combatNetwork:WaitForChild("ReloadIntent") :: RemoteEvent
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function createWeaponState(): WeaponReadinessState
	local weaponId = FirearmConfig.BasicFirearm.WeaponId
	return {
		weaponId = weaponId,
		readinessStateId = CombatContracts.WeaponReadinessStateIds.Ready,
		ammunition = {
			weaponId = weaponId,
			loadedRounds = 0,
			reserveRounds = FirearmConfig.BasicFirearm.PrototypeInitialReserveRounds,
			magazineCapacity = FirearmConfig.BasicFirearm.MagazineCapacity,
		},
		cadence = {
			weaponId = weaponId,
			lastFireServerTimestamp = nil,
			nextAllowedFireServerTimestamp = 0,
		},
		reloadState = nil,
	}
end

local function createPlayerState(player: Player): PlayerCombatState
	local threateningHostile = hostileFixtures[nextThreatIndex]
	if threateningHostile == nil then
		threateningHostile = hostileFixtures[((nextThreatIndex - 1) % #hostileFixtures) + 1]
	end
	nextThreatIndex += 1
	local weaponId = FirearmConfig.BasicFirearm.WeaponId
	return {
		operativeState = {
			entityId = "operative.player:" .. tostring(player.UserId),
			combatStateId = CombatContracts.OperativeCombatStateIds.Ready,
			equippedWeaponId = weaponId,
		},
		weaponState = createWeaponState(),
		selectedTargetEntityId = nil,
		threateningHostileEntityId = threateningHostile.entityId,
		lastRequestServerTimestamp = -math.huge,
		generation = 1,
		processedShotIds = {},
	}
end

local function setFixtureHealthPresentation(fixture: HostileFixture)
	fixture.healthLabel.Text = string.format("%s\nHealth: %d", fixture.model.Name, fixture.healthState.currentHealth)
	fixture.root.Color = if fixture.isAlive then Color3.fromRGB(172, 52, 52) else Color3.fromRGB(74, 74, 74)
end

local function createHostileFixture(parent: Folder, definition): HostileFixture
	local model = Instance.new("Model")
	model.Name = definition.name
	model:SetAttribute("CombatEntityId", definition.entityId)

	local root = Instance.new("Part")
	root.Name = "StationaryFixture"
	root.Anchored = true
	root.CanCollide = true
	root.Size = Vector3.new(4, 6, 4)
	root.Position = definition.position
	root.Parent = model
	model.PrimaryPart = root

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FixtureLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 54)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "Health"
	label.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Parent = billboard

	model.Parent = parent
	local fixture: HostileFixture = {
		entityId = definition.entityId,
		model = model,
		root = root,
		healthLabel = label,
		healthState = {
			entityId = definition.entityId,
			currentHealth = INITIAL_FIXTURE_HEALTH,
			processedShotIds = {},
		},
		isAlive = true,
		isTargetable = true,
		isVisible = true,
		hasLineOfSight = true,
		obstructionResultId = CombatContracts.ShotObstructionResultIds.TargetHit,
	}
	setFixtureHealthPresentation(fixture)
	return fixture
end

local function createFixtures()
	local folder = Instance.new("Folder")
	folder.Name = FIXTURE_FOLDER_NAME
	folder.Parent = Workspace
	fixtureFolder = folder
	for _, definition in HOSTILE_DEFINITIONS do
		local fixture = createHostileFixture(folder, definition)
		table.insert(hostileFixtures, fixture)
		hostileByEntityId[fixture.entityId] = fixture
	end
end

local function getOperativePosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function createCandidates(playerState: PlayerCombatState, operativePosition: Vector3): { TargetCandidate }
	local candidates = {}
	for _, fixture in hostileFixtures do
		local distance = (fixture.root.Position - operativePosition).Magnitude
		table.insert(candidates, {
			entityId = fixture.entityId,
			entityKindId = CombatContracts.CombatEntityKindIds.Hostile,
			teamId = "team.lk0207.hostiles",
			relationshipId = CombatContracts.TeamRelationshipIds.Hostile,
			worldPosition = fixture.root.Position,
			distanceStuds = distance,
			isAlive = fixture.isAlive,
			isTargetable = fixture.isTargetable,
			isVisible = fixture.isVisible,
			hasLineOfSight = fixture.hasLineOfSight,
			isActivelyThreatening = fixture.entityId == playerState.threateningHostileEntityId,
			activelyThreateningOperativeEntityId = if fixture.entityId == playerState.threateningHostileEntityId
				then playerState.operativeState.entityId
				else nil,
		})
	end
	return candidates
end

local function discloseTarget(
	player: Player,
	playerState: PlayerCombatState,
	targetEntityId: CombatEntityId?,
	now: number
)
	if playerState.selectedTargetEntityId == targetEntityId then
		return
	end
	playerState.selectedTargetEntityId = targetEntityId
	if targetEntityId == nil then
		presentationRemote:FireClient(player, {
			kindId = CombatContracts.PresentationMessageKindIds.TargetCleared,
			operativeEntityId = playerState.operativeState.entityId,
			serverTimestamp = now,
		})
		return
	end
	local fixture = hostileByEntityId[targetEntityId]
	if fixture == nil or not fixture.isVisible then
		return
	end
	presentationRemote:FireClient(player, {
		kindId = CombatContracts.PresentationMessageKindIds.TargetSelected,
		operativeEntityId = playerState.operativeState.entityId,
		targetEntityId = targetEntityId,
		serverTimestamp = now,
	})
end

local function resolveAcceptedShot(
	player: Player,
	playerState: PlayerCombatState,
	operativePosition: Vector3,
	fireResult: CombatContracts.AuthoritativeFireResult,
	now: number
)
	local targetEntityId = fireResult.targetEntityId
	local shotId = fireResult.shotId
	if targetEntityId == nil or shotId == nil then
		return
	end
	local fixture = hostileByEntityId[targetEntityId]
	if fixture == nil then
		return
	end
	local targetContext: FirearmTargetContext = {
		entityId = fixture.entityId,
		worldPosition = fixture.root.Position,
		isAlive = fixture.isAlive,
		isTargetable = fixture.isTargetable,
		relationshipId = CombatContracts.TeamRelationshipIds.Hostile,
		isVisible = fixture.isVisible,
	}
	local hitResolution = FirearmHitResolver.resolve(fireResult, {
		operativeEntityId = playerState.operativeState.entityId,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		selectedTargetEntityId = targetEntityId,
		operativeWorldPosition = operativePosition,
		obstructionResultId = fixture.obstructionResultId,
	}, targetContext)
	local damageResolution = DamageResolver.resolve(hitResolution, fixture.healthState, now)
	fixture.healthState = damageResolution.targetHealthStateAfter
	if damageResolution.didApplyDamage then
		fixture.isAlive = fixture.healthState.currentHealth > 0
		setFixtureHealthPresentation(fixture)
	end
	presentationRemote:FireClient(player, {
		kindId = CombatContracts.PresentationMessageKindIds.ShotFired,
		shotId = shotId,
		operativeEntityId = playerState.operativeState.entityId,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		targetEntityId = targetEntityId,
		serverTimestamp = now,
	})
end

local function evaluatePlayer(player: Player, playerState: PlayerCombatState, now: number)
	if not OperativeLifeService.isCombatAllowed(player) then
		discloseTarget(player, playerState, nil, now)
		local restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)
		if restricted ~= nil then
			playerStates[player] = restricted
		end
		return
	end
	local operativePosition = getOperativePosition(player)
	if operativePosition == nil then
		discloseTarget(player, playerState, nil, now)
		return
	end
	local targetingState = {
		entityId = playerState.operativeState.entityId,
		worldPosition = operativePosition,
		combatStateId = playerState.operativeState.combatStateId,
		weaponReadiness = playerState.weaponState,
	}
	local selectedTarget =
		TargetCandidateSelector.select(targetingState, createCandidates(playerState, operativePosition))
	local targetEntityId = if selectedTarget == nil then nil else selectedTarget.targetEntityId
	discloseTarget(player, playerState, targetEntityId, now)
	local fireResolution = AutomaticFireResolver.resolve({
		entityId = playerState.operativeState.entityId,
		combatStateId = playerState.operativeState.combatStateId,
	}, selectedTarget, playerState.weaponState, now)
	playerState.weaponState = fireResolution.weaponStateAfter
	if fireResolution.decision.shouldFire then
		resolveAcceptedShot(player, playerState, operativePosition, fireResolution.fireResult, now)
	end
end

local function completeReload(player: Player, expectedCompletionTimestamp: number, expectedGeneration: number)
	local playerState = playerStates[player]
	if playerState == nil or playerState.generation ~= expectedGeneration then
		return
	end
	if not OperativeLifeService.isCombatAllowed(player) then
		local restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)
		if restricted ~= nil then
			playerStates[player] = restricted
		end
		return
	end
	local reloadState = playerState.weaponState.reloadState
	if reloadState == nil or reloadState.completionServerTimestamp ~= expectedCompletionTimestamp then
		return
	end
	local resolution =
		ReloadResolver.complete(playerState.operativeState, playerState.weaponState, Workspace:GetServerTimeNow())
	playerState.operativeState = resolution.operativeStateAfter
	playerState.weaponState = resolution.weaponStateAfter
	if resolution.didComplete then
		presentationRemote:FireClient(player, {
			kindId = CombatContracts.PresentationMessageKindIds.ReloadCompleted,
			weaponId = FirearmConfig.BasicFirearm.WeaponId,
		})
	elseif resolution.wasInterrupted then
		presentationRemote:FireClient(player, {
			kindId = CombatContracts.PresentationMessageKindIds.ReloadInterrupted,
			weaponId = FirearmConfig.BasicFirearm.WeaponId,
		})
	end
end

local function onReloadIntent(player: Player, weaponId: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(weaponId) ~= "string" then
		return
	end
	local playerState = playerStates[player]
	if
		playerState == nil
		or not OperativeLifeService.isCombatAllowed(player)
		or weaponId ~= playerState.operativeState.equippedWeaponId
	then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now - playerState.lastRequestServerTimestamp < SERVER_REQUEST_COOLDOWN_SECONDS then
		return
	end
	playerState.lastRequestServerTimestamp = now
	local resolution = ReloadResolver.begin(playerState.operativeState, playerState.weaponState, now)
	playerState.operativeState = resolution.operativeStateAfter
	playerState.weaponState = resolution.weaponStateAfter
	if not resolution.didBegin then
		return
	end
	local reloadState = resolution.weaponStateAfter.reloadState
	assert(reloadState ~= nil, "accepted reload must include authoritative timing")
	presentationRemote:FireClient(player, {
		kindId = CombatContracts.PresentationMessageKindIds.ReloadStarted,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		completionServerTimestamp = reloadState.completionServerTimestamp,
	})
	local generation = playerState.generation
	task.delay(FirearmConfig.BasicFirearm.ReloadDurationSeconds, function()
		completeReload(player, reloadState.completionServerTimestamp, generation)
	end)
end

local function resetPlayer(player: Player)
	local previousState = playerStates[player]
	if previousState == nil then
		playerStates[player] = createPlayerState(player)
		return
	end
	previousState.generation += 1
	local restricted = OperativeLifeService.applyCombatRestrictions(player, previousState)
	if restricted ~= nil then
		playerStates[player] = restricted
	end
end

local function applyLifeStateRestriction(player: Player)
	local playerState = playerStates[player]
	if playerState == nil then
		return
	end
	local wasReloading = playerState.weaponState.reloadState ~= nil
	discloseTarget(player, playerState, nil, Workspace:GetServerTimeNow())
	local restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)
	if restricted == nil then
		return
	end
	playerStates[player] = restricted
	if wasReloading and restricted.weaponState.reloadState == nil then
		presentationRemote:FireClient(player, {
			kindId = CombatContracts.PresentationMessageKindIds.ReloadInterrupted,
			weaponId = FirearmConfig.BasicFirearm.WeaponId,
		})
	end
end

local function addPlayer(player: Player)
	resetPlayer(player)
	characterAddedConnections[player] = player.CharacterAdded:Connect(function()
		resetPlayer(player)
	end)
end

local function removePlayer(player: Player)
	local connection = characterAddedConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		characterAddedConnections[player] = nil
	end
	playerStates[player] = nil
end

function AutomaticCombatDevelopmentHarness.start()
	if started or not RunService:IsStudio() then
		return
	end
	started = true
	createFixtures()
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
	lifeStateConnection = OperativeLifeService.subscribe(function(player)
		applyLifeStateRestriction(player)
	end)
	reloadIntentConnection = reloadIntentRemote.OnServerEvent:Connect(onReloadIntent)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < EVALUATION_INTERVAL_SECONDS then
			return
		end
		accumulatedSeconds = 0
		local now = Workspace:GetServerTimeNow()
		for player, playerState in playerStates do
			evaluatePlayer(player, playerState, now)
		end
	end)
end

function AutomaticCombatDevelopmentHarness.stop()
	if not started then
		return
	end
	started = false
	local playersToRemove = {}
	for player, playerState in playerStates do
		discloseTarget(player, playerState, nil, Workspace:GetServerTimeNow())
		table.insert(playersToRemove, player)
	end
	for _, player in playersToRemove do
		removePlayer(player)
	end
	for _, connection in
		{ reloadIntentConnection, playerAddedConnection, playerRemovingConnection, heartbeatConnection }
	do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	reloadIntentConnection = nil
	playerAddedConnection = nil
	playerRemovingConnection = nil
	heartbeatConnection = nil
	if lifeStateConnection ~= nil then
		lifeStateConnection:Disconnect()
		lifeStateConnection = nil
	end
	table.clear(characterAddedConnections)
	table.clear(playerStates)
	table.clear(hostileFixtures)
	table.clear(hostileByEntityId)
	local folder = fixtureFolder
	if folder ~= nil then
		folder:Destroy()
		fixtureFolder = nil
	end
	accumulatedSeconds = 0
	nextThreatIndex = 1
end

return AutomaticCombatDevelopmentHarness
