--!strict

--[[
	Minimal server-owned continuous-hold revive session orchestration. The only
	client input is a strict target/phase intent. Identity, timing, session IDs,
	distance, line of sight, movement and damage continuity, completion, health,
	and the target combat companion are all derived and committed on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local ClassService = require(script.Parent.ClassService)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)
local MatchResultService = require(script.Parent.MatchResultService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local RelicModifierService = require(script.Parent.RelicModifierService)
local OperativeReviveResolver = require(script.Parent.OperativeReviveResolver)
local SquadFailureService = require(script.Parent.SquadFailureService)

type Session = {
	sessionState: OperativeLifeContracts.ReviveSessionState,
	reviverPlayer: Player,
	targetPlayer: Player,
	reviverCharacter: Model,
	targetCharacter: Model,
	reviverStartPosition: Vector3,
	reviverProcessedDamageEventIds: { [string]: boolean },
	reviveDurationSeconds: number,
	restoredHealth: number,
	isMedicAssisted: boolean,
}

type IntentResult = { accepted: boolean, rejectionReason: string? }

type Service = {
	start: () -> (),
	stop: () -> (),
	handleReviveIntent: (player: Player, payload: unknown, ...unknown) -> IntentResult,
	readActiveSessionForTarget: (targetOperativeEntityId: string) -> any?,
}

local Service: Service = {} :: Service
local REQUEST_COOLDOWN_SECONDS = 0.05
local MOVEMENT_INTERRUPTION_STUDS = 0.25
local EVALUATION_INTERVAL_SECONDS = 0.05
local ATTRIBUTE_NAMES = {
	"LK_P3_ReviveStatus",
	"LK_P3_ReviveProgress",
	"LK_P3_ReviveTarget",
	"LK_P3_ReviveReviver",
	"LK_P7_MedicReviveAssisted",
}

local sessionsByTarget: { [string]: Session } = {}
local sessionsByReviver: { [Player]: Session } = {}
local lastRequestAt: { [Player]: number } = {}
local nextSessionId = 0
local accumulatedSeconds = 0
local started = false
local remoteConnection: RBXScriptConnection? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local lifeConnection: { Disconnect: (self: any) -> () }? = nil

local function getOrCreateReviveIntentRemote(): RemoteEvent
	local lifeNetwork = ReplicatedStorage:FindFirstChild("OperativeLifeNetwork")
	if lifeNetwork == nil then
		lifeNetwork = Instance.new("Folder")
		lifeNetwork.Name = "OperativeLifeNetwork"
		lifeNetwork.Parent = ReplicatedStorage
	end
	local existing = lifeNetwork:FindFirstChild("ReviveIntent")
	if existing ~= nil and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ReviveIntent"
	remote.Parent = lifeNetwork
	return remote
end

local reviveIntentRemote = getOrCreateReviveIntentRemote()

local function result(accepted: boolean, rejectionReason: string?): IntentResult
	return { accepted = accepted, rejectionReason = rejectionReason }
end

local function rootPosition(player: Player): (BasePart?, Vector3?)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return root, root.Position
end

local function distanceAndLineOfSight(reviver: Player, target: Player): (number, boolean)
	local reviverRoot, reviverPosition = rootPosition(reviver)
	local targetRoot, targetPosition = rootPosition(target)
	if reviverRoot == nil or reviverPosition == nil or targetRoot == nil or targetPosition == nil then
		return math.huge, false
	end
	local displacement = targetPosition - reviverPosition
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { reviver.Character :: Model, target.Character :: Model }
	local hit = Workspace:Raycast(reviverPosition, displacement, parameters)
	return displacement.Magnitude, hit == nil
end

local function isStrictIntent(payload: unknown): boolean
	if type(payload) ~= "table" then
		return false
	end
	local count = 0
	for key in payload :: any do
		if key ~= "targetOperativeEntityId" and key ~= "phase" then
			return false
		end
		count += 1
	end
	local value = payload :: any
	return count == 2
		and type(value.targetOperativeEntityId) == "string"
		and value.targetOperativeEntityId ~= ""
		and (value.phase == "Begin" or value.phase == "End")
end

local function hasDamageChanged(session: Session, snapshot: OperativeLifeContracts.OperativeLifeStateSnapshot): boolean
	for damageEventId in snapshot.processedDamageEventIds do
		if session.reviverProcessedDamageEventIds[damageEventId] ~= true then
			return true
		end
	end
	return false
end

local function clearDisclosure(session: Session)
	for _, player in { session.reviverPlayer, session.targetPlayer } do
		for _, attributeName in ATTRIBUTE_NAMES do
			player:SetAttribute(attributeName, nil)
		end
	end
end

local function disclose(session: Session, progress: number)
	local reviverId = session.sessionState.reviverOperativeEntityId
	local targetId = session.sessionState.targetOperativeEntityId
	for _, player in { session.reviverPlayer, session.targetPlayer } do
		player:SetAttribute("LK_P3_ReviveStatus", "Active")
		player:SetAttribute("LK_P3_ReviveProgress", math.clamp(progress, 0, 1))
		player:SetAttribute("LK_P3_ReviveTarget", targetId)
		player:SetAttribute("LK_P3_ReviveReviver", reviverId)
		player:SetAttribute("LK_P7_MedicReviveAssisted", session.isMedicAssisted)
	end
end

local function removeSession(session: Session)
	if sessionsByTarget[session.sessionState.targetOperativeEntityId] == session then
		sessionsByTarget[session.sessionState.targetOperativeEntityId] = nil
	end
	if sessionsByReviver[session.reviverPlayer] == session then
		sessionsByReviver[session.reviverPlayer] = nil
	end
	clearDisclosure(session)
end

local function cancelSession(session: Session)
	ClassService.recordMedicReviveEnded(session.reviverPlayer, Workspace:GetServerTimeNow(), false)
	removeSession(session)
end

--[[
	Guardian Signal (RPG-0109) is a cooperative relic: when its owner completes a
	revive, both the reviver and the operative they brought back receive a bounded,
	expiring pool of temporary armor. The armor amount derives from each operative's
	own authoritative maximum health, and the life owner holds the pool.
]]
local function grantGuardianSignalArmor(session: Session, serverTimestamp: number)
	local modifiers = RelicModifierService.read(session.reviverPlayer)
	local fraction = modifiers.temporaryArmorFractionOfMaximumHealth
	local durationSeconds = modifiers.temporaryArmorDurationSeconds
	if fraction <= 0 or durationSeconds <= 0 then
		return
	end
	local expiresAt = serverTimestamp + durationSeconds
	for _, operativeEntityId in
		{ session.sessionState.reviverOperativeEntityId, session.sessionState.targetOperativeEntityId }
	do
		local read = OperativeLifeService.readByOperativeEntityId(operativeEntityId)
		if read == nil then
			continue
		end
		local armorAmount = math.floor(read.snapshot.healthState.maximumHealth * fraction)
		if armorAmount >= 1 then
			OperativeLifeService.grantTemporaryArmor(operativeEntityId, armorAmount, expiresAt)
		end
	end
end

local function evaluateSession(session: Session, serverTimestamp: number)
	if sessionsByTarget[session.sessionState.targetOperativeEntityId] ~= session then
		return
	end
	local reviverRead = OperativeLifeService.read(session.reviverPlayer)
	local targetRead = OperativeLifeService.read(session.targetPlayer)
	local _, reviverPosition = rootPosition(session.reviverPlayer)
	local connected = reviverRead ~= nil
		and targetRead ~= nil
		and session.reviverPlayer.Parent == Players
		and session.targetPlayer.Parent == Players
		and session.reviverPlayer.Character == session.reviverCharacter
		and session.targetPlayer.Character == session.targetCharacter
		and SquadFailureService.isOperativeAdmitted(session.sessionState.reviverOperativeEntityId)
		and SquadFailureService.isOperativeAdmitted(session.sessionState.targetOperativeEntityId)
	if reviverRead == nil or targetRead == nil or reviverPosition == nil then
		cancelSession(session)
		return
	end
	local distanceStuds, hasLineOfSight = distanceAndLineOfSight(session.reviverPlayer, session.targetPlayer)
	local movementRemainedValid = (reviverPosition - session.reviverStartPosition).Magnitude
		<= MOVEMENT_INTERRUPTION_STUDS
	local combatRead = OperativeCombatRuntimeService.readReviveCombatState(session.targetPlayer)
	if combatRead == nil then
		cancelSession(session)
		return
	end
	local continued =
		OperativeReviveResolver.continueRevive(reviverRead.snapshot, targetRead.snapshot, session.sessionState, {
			sessionId = session.sessionState.sessionId,
			reviverOperativeEntityId = session.sessionState.reviverOperativeEntityId,
			targetOperativeEntityId = session.sessionState.targetOperativeEntityId,
			distanceStuds = distanceStuds,
			hasLineOfSight = hasLineOfSight,
			serverTimestamp = serverTimestamp,
			reviveDurationSeconds = session.reviveDurationSeconds,
			restoredHealth = session.restoredHealth,
			activeSessionIdForTarget = session.sessionState.sessionId,
			hasConflictingActiveSession = false,
			reviverRemainsConnectedAndParticipating = connected,
			reviverMovementRemainedValid = movementRemainedValid,
			reviverReceivedNoInterruptingDamage = not hasDamageChanged(session, reviverRead.snapshot),
			holdRemainsActive = true,
		}, combatRead.combatState)
	if continued.didTransition and continued.sessionStateAfter ~= nil then
		if continued.sessionStateAfter.statusId == OperativeLifeContracts.ReviveSessionStatusIds.Cancelled then
			cancelSession(session)
			return
		end
		if continued.sessionStateAfter.statusId == OperativeLifeContracts.ReviveSessionStatusIds.Completed then
			local oldCombatState = combatRead.combatState
			if
				continued.combatStateAfter == nil
				or not OperativeCombatRuntimeService.commitReviveCombatState(
					session.targetPlayer,
					combatRead.generation,
					continued.combatStateAfter
				)
			then
				cancelSession(session)
				return
			end
			local committed =
				OperativeLifeService.commitAcceptedTransition(session.targetPlayer, targetRead.revision, continued)
			if committed.didCommit then
				-- P10-0104 contribution: only a committed revive counts, and only
				-- for the operative who performed it.
				MatchResultService.recordRevivePerformed(session.sessionState.reviverOperativeEntityId)
				grantGuardianSignalArmor(session, serverTimestamp)
				ClassService.recordMedicReviveEnded(session.reviverPlayer, serverTimestamp, true)
			end
			if not committed.didCommit then
				OperativeCombatRuntimeService.commitReviveCombatState(
					session.targetPlayer,
					combatRead.generation,
					oldCombatState
				)
				ClassService.recordMedicReviveEnded(session.reviverPlayer, serverTimestamp, false)
			end
			removeSession(session)
			return
		end
	end
	disclose(session, continued.normalizedProgress)
end

local function begin(player: Player, targetOperativeEntityId: string): IntentResult
	local reviverRead = OperativeLifeService.read(player)
	local targetRead = OperativeLifeService.readByOperativeEntityId(targetOperativeEntityId)
	local targetPlayer = OperativeLifeService.playerForOperativeEntityId(targetOperativeEntityId)
	if reviverRead == nil or targetRead == nil or targetPlayer == nil then
		return result(false, "HiddenOrUnregisteredTarget")
	end
	if reviverRead.snapshot.operativeEntityId == targetOperativeEntityId then
		return result(false, "SelfTarget")
	end
	if
		not SquadFailureService.isOperativeAdmitted(reviverRead.snapshot.operativeEntityId)
		or not SquadFailureService.isOperativeAdmitted(targetOperativeEntityId)
	then
		return result(false, "CrossOperationTarget")
	end
	if sessionsByReviver[player] ~= nil then
		return result(false, "StalePhase")
	end
	local existing = sessionsByTarget[targetOperativeEntityId]
	if existing ~= nil then
		return result(false, "TargetBusy")
	end
	local reviverRoot, reviverPosition = rootPosition(player)
	local reviverCharacter = player.Character
	local targetCharacter = targetPlayer.Character
	if reviverRoot == nil or reviverPosition == nil or reviverCharacter == nil or targetCharacter == nil then
		return result(false, "MissingCharacter")
	end
	local distanceStuds, hasLineOfSight = distanceAndLineOfSight(player, targetPlayer)
	local reviveDurationSeconds, restoredHealth, isMedicAssisted = ClassService.readMedicReviveBenefits(player)
	local serverTimestamp = Workspace:GetServerTimeNow()
	nextSessionId += 1
	local sessionId = string.format("revive.server:%d", nextSessionId)
	local resolved = OperativeReviveResolver.beginRevive(reviverRead.snapshot, targetRead.snapshot, {
		sessionId = sessionId,
		reviverOperativeEntityId = reviverRead.snapshot.operativeEntityId,
		targetOperativeEntityId = targetOperativeEntityId,
		distanceStuds = distanceStuds,
		hasLineOfSight = hasLineOfSight,
		serverTimestamp = serverTimestamp,
		reviveDurationSeconds = reviveDurationSeconds,
		restoredHealth = restoredHealth,
		activeSessionIdForTarget = nil,
		hasConflictingActiveSession = false,
	})
	if not resolved.didTransition or resolved.sessionStateAfter == nil then
		return result(false, resolved.rejectionReasonId or "ResolverRejected")
	end
	local session: Session = {
		sessionState = resolved.sessionStateAfter,
		reviverPlayer = player,
		targetPlayer = targetPlayer,
		reviverCharacter = reviverCharacter,
		targetCharacter = targetCharacter,
		reviverStartPosition = reviverPosition,
		reviverProcessedDamageEventIds = table.clone(reviverRead.snapshot.processedDamageEventIds),
		reviveDurationSeconds = reviveDurationSeconds,
		restoredHealth = restoredHealth,
		isMedicAssisted = isMedicAssisted,
	}
	sessionsByTarget[targetOperativeEntityId] = session
	sessionsByReviver[player] = session
	ClassService.recordMedicReviveStarted(player, serverTimestamp)
	disclose(session, 0)
	return result(true, nil)
end

function Service.handleReviveIntent(player: Player, payload: unknown, ...: unknown): IntentResult
	if select("#", ...) ~= 0 or not isStrictIntent(payload) then
		return result(false, "MalformedPayload")
	end
	local value = payload :: any
	if value.phase == "End" then
		local session = sessionsByReviver[player]
		if session == nil or session.sessionState.targetOperativeEntityId ~= value.targetOperativeEntityId then
			return result(false, "StalePhase")
		end
		-- A valid release only removes authority; it must never be delayed by the
		-- anti-spam gate applied to attempts that create a session.
		cancelSession(session)
		return result(true, nil)
	end
	local now = Workspace:GetServerTimeNow()
	local last = lastRequestAt[player]
	if last ~= nil and now - last < REQUEST_COOLDOWN_SECONDS then
		return result(false, "RateLimited")
	end
	lastRequestAt[player] = now
	return begin(player, value.targetOperativeEntityId)
end

function Service.readActiveSessionForTarget(targetOperativeEntityId: string): any?
	local session = sessionsByTarget[targetOperativeEntityId]
	if session == nil then
		return nil
	end
	return table.clone(session.sessionState)
end

function Service.start()
	if started then
		return
	end
	started = true
	remoteConnection = reviveIntentRemote.OnServerEvent:Connect(function(player, payload, ...)
		local intentResult = Service.handleReviveIntent(player, payload, ...)
		if RunService:IsStudio() then
			player:SetAttribute("LK_P3_LastReviveIntentAccepted", intentResult.accepted)
			player:SetAttribute("LK_P3_LastReviveIntentRejection", intentResult.rejectionReason)
		end
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		local own = sessionsByReviver[player]
		if own ~= nil then
			cancelSession(own)
		end
		for _, session in sessionsByTarget do
			if session.targetPlayer == player then
				cancelSession(session)
			end
		end
		lastRequestAt[player] = nil
	end)
	lifeConnection = OperativeLifeService.subscribe(function()
		for _, session in sessionsByTarget do
			evaluateSession(session, Workspace:GetServerTimeNow())
		end
	end)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < EVALUATION_INTERVAL_SECONDS then
			return
		end
		accumulatedSeconds = 0
		local now = Workspace:GetServerTimeNow()
		for _, session in sessionsByTarget do
			evaluateSession(session, now)
		end
	end)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	for _, connection in { remoteConnection, heartbeatConnection, playerRemovingConnection } do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	remoteConnection = nil
	heartbeatConnection = nil
	playerRemovingConnection = nil
	if lifeConnection ~= nil then
		lifeConnection:Disconnect()
		lifeConnection = nil
	end
	for _, session in sessionsByTarget do
		clearDisclosure(session)
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute("LK_P3_LastReviveIntentAccepted", nil)
		player:SetAttribute("LK_P3_LastReviveIntentRejection", nil)
	end
	table.clear(sessionsByTarget)
	table.clear(sessionsByReviver)
	table.clear(lastRequestAt)
	accumulatedSeconds = 0
end

return Service
