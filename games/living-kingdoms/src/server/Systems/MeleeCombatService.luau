--!strict

--[[
	MVP 0.1 server-only melee owner.

	Trusted callers provide only the player, a bounded request ID, and an aim
	direction. This service derives the operative position, living enemy facts,
	cadence, range/cone selection, occlusion, authoritative enemy revision, damage,
	death, and result contribution on the server. It deliberately owns no firearm
	ammunition/readiness/reload state and creates no client remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MeleeContracts = require(ReplicatedStorage.Shared.Combat.MeleeContracts)
local MeleeCombatConfig = require(ReplicatedStorage.Shared.Config.MeleeCombatConfig)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local MatchResultService = require(script.Parent.MatchResultService)
local MeleeStrikeResolver = require(script.Parent.MeleeStrikeResolver)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local Service = {}
local Reasons = MeleeContracts.RejectionReasonIds
local Weapon = MeleeCombatConfig.OpeningWeapon

type PlayerState = {
	lastCommittedStrikeServerTimestamp: number,
	processedRequestIds: { [string]: boolean },
	processedRequestOrder: { string },
}

local started = false
local states: { [Player]: PlayerState } = {}
local playerRemovingConnection: RBXScriptConnection? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function stateFor(player: Player): PlayerState
	local existing = states[player]
	if existing ~= nil then
		return existing
	end
	local created = {
		lastCommittedStrikeServerTimestamp = -math.huge,
		processedRequestIds = {},
		processedRequestOrder = {},
	}
	states[player] = created
	return created
end

local function rejected(reasonId: string, serverTimestamp: number): MeleeContracts.MeleeStrikeResult
	return table.freeze({
		accepted = false,
		strikeId = nil,
		weaponId = Weapon.WeaponId,
		targetEntityId = nil,
		damageAmount = 0,
		becameDead = false,
		serverTimestamp = serverTimestamp,
		rejectionReasonId = reasonId,
	})
end

local function validRequestId(requestId: unknown): boolean
	return type(requestId) == "string"
		and requestId ~= ""
		and #requestId <= MeleeCombatConfig.MaximumRequestIdLength
end

local function validAimDirection(aimDirection: unknown): boolean
	if typeof(aimDirection) ~= "Vector3" then
		return false
	end
	local direction = aimDirection :: Vector3
	return direction.X == direction.X
		and direction.Y == direction.Y
		and direction.Z == direction.Z
		and direction.Magnitude > 0.001
end

local function operativePosition(player: Player): (Vector3?, Model?)
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil, character
	end
	return root.Position, character
end

local function recordRequest(state: PlayerState, requestId: string)
	state.processedRequestIds[requestId] = true
	table.insert(state.processedRequestOrder, requestId)
	while #state.processedRequestOrder > MeleeCombatConfig.MaximumProcessedRequestIdsPerOperative do
		local expired = table.remove(state.processedRequestOrder, 1)
		if expired ~= nil then
			state.processedRequestIds[expired] = nil
		end
	end
end

local function selectedFact(entityId: string, facts: { EnemyDirectorService.EnemyCombatFact })
	for _, fact in facts do
		if fact.entityId == entityId and fact.isAlive then
			return fact
		end
	end
	return nil
end

local function targetOccluded(character: Model?, origin: Vector3, fact: EnemyDirectorService.EnemyCombatFact): boolean
	local offset = fact.worldPosition - origin
	if offset.Magnitude <= 0.001 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if character == nil then {} else { character }
	local hit = Workspace:Raycast(origin, offset, params)
	return hit ~= nil and not hit.Instance:IsDescendantOf(fact.model)
end

function Service.tryStrike(player: Player, requestId: unknown, aimDirection: unknown): MeleeContracts.MeleeStrikeResult
	local serverTimestamp = now()
	if not started then
		return rejected(Reasons.ServiceStopped, serverTimestamp)
	end
	if not validRequestId(requestId) or not validAimDirection(aimDirection) then
		return rejected(Reasons.InvalidIntent, serverTimestamp)
	end
	if not OperativeLifeService.isCombatAllowed(player) then
		return rejected(Reasons.CombatNotAllowed, serverTimestamp)
	end

	local state = stateFor(player)
	local requestIdString = requestId :: string
	if state.processedRequestIds[requestIdString] then
		return rejected(Reasons.DuplicateRequest, serverTimestamp)
	end
	if serverTimestamp - state.lastCommittedStrikeServerTimestamp < Weapon.CadenceSeconds then
		return rejected(Reasons.CadenceBlocked, serverTimestamp)
	end

	local origin, character = operativePosition(player)
	if origin == nil then
		return rejected(Reasons.CombatNotAllowed, serverTimestamp)
	end
	local facts = EnemyDirectorService.readEnemyCombatFacts()
	local candidates = {}
	for _, fact in facts do
		table.insert(candidates, {
			entityId = fact.entityId,
			worldPosition = fact.worldPosition,
			isAlive = fact.isAlive,
		})
	end
	local selection = MeleeStrikeResolver.selectTarget(origin, aimDirection :: Vector3, candidates)
	if selection.targetEntityId == nil then
		return rejected(selection.rejectionReasonId or Reasons.NoTarget, serverTimestamp)
	end
	local fact = selectedFact(selection.targetEntityId, facts)
	if fact == nil then
		return rejected(Reasons.TargetStale, serverTimestamp)
	end
	if targetOccluded(character, origin, fact) then
		return rejected(Reasons.TargetOccluded, serverTimestamp)
	end

	local healthRead = EnemyDirectorService.readHealthState(fact.entityId)
	if healthRead == nil or healthRead.isAlive ~= true then
		return rejected(Reasons.TargetStale, serverTimestamp)
	end
	local previousHealth = healthRead.healthState.currentHealth
	local healthStateAfter = {
		entityId = fact.entityId,
		currentHealth = math.max(0, previousHealth - Weapon.DamagePerHit),
		processedShotIds = table.clone(healthRead.healthState.processedShotIds),
	}
	local committed, committedDamage = EnemyDirectorService.commitHealthState(
		fact.entityId,
		healthRead.revision,
		healthStateAfter,
		serverTimestamp
	)
	if not committed or type(committedDamage) ~= "number" or committedDamage <= 0 then
		return rejected(Reasons.CommitRejected, serverTimestamp)
	end

	state.lastCommittedStrikeServerTimestamp = serverTimestamp
	recordRequest(state, requestIdString)
	local operativeEntityId = "operative.player:" .. tostring(player.UserId)
	MatchResultService.recordDamageDealt(operativeEntityId, committedDamage)
	if EnemyDirectorService.isBossEntity(fact.entityId) then
		MatchResultService.recordBossExposureHit(operativeEntityId)
	end
	local becameDead = committedDamage >= previousHealth
	if becameDead then
		MatchResultService.recordKills(operativeEntityId, 1)
	end
	return table.freeze({
		accepted = true,
		strikeId = "melee:" .. tostring(player.UserId) .. ":" .. requestIdString,
		weaponId = Weapon.WeaponId,
		targetEntityId = fact.entityId,
		damageAmount = committedDamage,
		becameDead = becameDead,
		serverTimestamp = serverTimestamp,
		rejectionReasonId = nil,
	})
end

function Service.start()
	if started then
		return
	end
	started = true
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	table.clear(states)
end

return table.freeze(Service)
