--!strict

--[[
	Central runtime owner for the two deadline-driven P3 transitions and the
	server-only finishing-damage route. It schedules only the earliest stored
	operative deadline and revalidates identity, revision, and deadline before
	calling the existing pure resolver and OperativeLifeService commit boundary.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local OperativeIncapacitationResolver = require(script.Parent.OperativeIncapacitationResolver)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local SquadFailureService = require(script.Parent.SquadFailureService)

type AuthoritativeOperativeDamage = OperativeLifeContracts.AuthoritativeOperativeDamage
type CommitResult = OperativeLifeService.CommitResult

type Service = {
	start: () -> (),
	stop: () -> (),
	applyAuthoritativeFinishingDamage: (
		operativeEntityId: string,
		expectedRevision: number,
		authoritativeDamage: AuthoritativeOperativeDamage
	) -> CommitResult,
	evaluateDeadlinesAt: (serverTimestamp: number) -> { CommitResult },
}

local Runtime: Service = {} :: Service
local lifeConnection: { Disconnect: (self: any) -> () }? = nil
local rosterConnection: { Disconnect: (self: any) -> () }? = nil
local failureConnection: { Disconnect: (self: any) -> () }? = nil
local timerGeneration = 0
local started = false

local DISCLOSED_ATTRIBUTES = {
	"LK_P3_OperativeEntityId",
	"LK_P3_LifeState",
	"LK_P3_CurrentHealth",
	"LK_P3_MaximumHealth",
	"LK_P3_BleedOutDeadline",
	"LK_P3_SoloRecoveryPending",
	"LK_P3_SoloRecoveryDeadline",
	"LK_P3_SquadFailureStatus",
}

local function rejected(reason: string): CommitResult
	return { didCommit = false, rejectionReason = reason, revision = nil, snapshot = nil }
end

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function discloseLife(player: Player)
	local read = OperativeLifeService.read(player)
	if read == nil then
		return
	end
	local snapshot = read.snapshot
	local incapacitation = snapshot.incapacitationState
	local solo = snapshot.soloRecoveryState
	player:SetAttribute("LK_P3_OperativeEntityId", snapshot.operativeEntityId)
	player:SetAttribute("LK_P3_LifeState", snapshot.lifeStateId)
	player:SetAttribute("LK_P3_CurrentHealth", snapshot.healthState.currentHealth)
	player:SetAttribute("LK_P3_MaximumHealth", snapshot.healthState.maximumHealth)
	player:SetAttribute(
		"LK_P3_BleedOutDeadline",
		if incapacitation == nil then nil else incapacitation.bleedOutDeadlineServerTimestamp
	)
	player:SetAttribute("LK_P3_SoloRecoveryPending", solo.recoveryCompletionServerTimestamp ~= nil)
	player:SetAttribute("LK_P3_SoloRecoveryDeadline", solo.recoveryCompletionServerTimestamp)
end

local function discloseFailure(statusId: string)
	for _, read in OperativeLifeService.readAll() do
		local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
		if player ~= nil then
			player:SetAttribute("LK_P3_SquadFailureStatus", statusId)
		end
	end
end

local function nextDeadline(): number?
	local earliest = nil
	local participation = SquadFailureService.readParticipationFacts()
	for _, read in OperativeLifeService.readAll() do
		local snapshot = read.snapshot
		if snapshot.lifeStateId == OperativeLifeContracts.OperativeLifeStateIds.Incapacitated then
			local soloDeadline = snapshot.soloRecoveryState.recoveryCompletionServerTimestamp
			local incapacitation = snapshot.incapacitationState
			local hasCanonicalSoloPath = soloDeadline ~= nil
				and participation.operationStartedSolo
				and not participation.hasEverHadMultipleParticipants
				and snapshot.soloRecoveryState.isEligible
			local deadline = if hasCanonicalSoloPath
				then soloDeadline
				else if incapacitation == nil then nil else incapacitation.bleedOutDeadlineServerTimestamp
			if deadline ~= nil and (earliest == nil or deadline < earliest) then
				earliest = deadline
			end
		end
	end
	return earliest
end

local scheduleNext: () -> ()

function Runtime.evaluateDeadlinesAt(serverTimestamp: number): { CommitResult }
	local results = {}
	if not isFiniteNonnegative(serverTimestamp) then
		table.insert(results, rejected("InvalidServerTimestamp"))
		return results
	end
	local participation = SquadFailureService.readParticipationFacts()
	for _, rosterRead in OperativeLifeService.readAll() do
		local read = OperativeLifeService.readByOperativeEntityId(rosterRead.operativeEntityId)
		if read == nil or read.snapshot.lifeStateId ~= OperativeLifeContracts.OperativeLifeStateIds.Incapacitated then
			continue
		end
		local player = OperativeLifeService.playerForOperativeEntityId(rosterRead.operativeEntityId)
		if player == nil then
			continue
		end
		local soloDeadline = read.snapshot.soloRecoveryState.recoveryCompletionServerTimestamp
		local hasCanonicalSoloPath = soloDeadline ~= nil
			and participation.operationStartedSolo
			and not participation.hasEverHadMultipleParticipants
			and read.snapshot.soloRecoveryState.isEligible
		if hasCanonicalSoloPath and serverTimestamp >= (soloDeadline :: number) then
			local resolved = OperativeIncapacitationResolver.evaluateSoloRecovery(read.snapshot, {
				operationStartedSolo = participation.operationStartedSolo,
				hasEverHadMultipleParticipants = participation.hasEverHadMultipleParticipants,
			}, serverTimestamp)
			table.insert(results, OperativeLifeService.commitAcceptedTransition(player, read.revision, resolved))
			continue
		end
		local incapacitation = read.snapshot.incapacitationState
		if incapacitation ~= nil and serverTimestamp >= incapacitation.bleedOutDeadlineServerTimestamp then
			local resolved = OperativeIncapacitationResolver.evaluateBleedOut(read.snapshot, serverTimestamp)
			table.insert(results, OperativeLifeService.commitAcceptedTransition(player, read.revision, resolved))
		end
	end
	if started then
		scheduleNext()
	end
	return results
end

scheduleNext = function()
	timerGeneration += 1
	local generation = timerGeneration
	local deadline = nextDeadline()
	if not started or deadline == nil then
		return
	end
	task.delay(math.max(0, deadline - Workspace:GetServerTimeNow()), function()
		if not started or generation ~= timerGeneration then
			return
		end
		Runtime.evaluateDeadlinesAt(Workspace:GetServerTimeNow())
	end)
end

function Runtime.applyAuthoritativeFinishingDamage(
	operativeEntityId: string,
	expectedRevision: number,
	authoritativeDamage: AuthoritativeOperativeDamage
): CommitResult
	local read = OperativeLifeService.readByOperativeEntityId(operativeEntityId)
	local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
	if read == nil or player == nil then
		return rejected("OperativeNotRegistered")
	end
	if expectedRevision ~= read.revision then
		return rejected("StaleRevision")
	end
	if read.snapshot.lifeStateId ~= OperativeLifeContracts.OperativeLifeStateIds.Incapacitated then
		return rejected("IllegalTransition")
	end
	local damage = authoritativeDamage :: any
	local serverTimestamp = if type(damage) == "table" then damage.serverTimestamp else nil
	local resolved = OperativeIncapacitationResolver.resolveFinishingDamage(
		read.snapshot,
		authoritativeDamage,
		serverTimestamp :: any
	)
	if type(resolved) ~= "table" or resolved.didTransition ~= true then
		return rejected(
			if type(resolved) == "table" then resolved.rejectionReasonId or "ResolverRejected" else "ResolverRejected"
		)
	end
	return OperativeLifeService.commitAcceptedTransition(player, read.revision, resolved)
end

function Runtime.start()
	if started then
		return
	end
	started = true
	lifeConnection = OperativeLifeService.subscribe(function()
		for _, read in OperativeLifeService.readAll() do
			local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
			if player ~= nil then
				discloseLife(player)
			end
		end
		scheduleNext()
	end)
	rosterConnection = OperativeLifeService.subscribeRoster(function(eventName, operativeEntityId)
		if eventName == "Registered" then
			local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
			if player ~= nil then
				discloseLife(player)
			end
		end
		scheduleNext()
	end)
	failureConnection = SquadFailureService.subscribe(function(state)
		discloseFailure(state.statusId)
	end)
	for _, read in OperativeLifeService.readAll() do
		local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
		if player ~= nil then
			discloseLife(player)
		end
	end
	discloseFailure(SquadFailureService.read().state.statusId)
	scheduleNext()
end

function Runtime.stop()
	if not started then
		return
	end
	started = false
	timerGeneration += 1
	if lifeConnection ~= nil then
		lifeConnection:Disconnect()
		lifeConnection = nil
	end
	if rosterConnection ~= nil then
		rosterConnection:Disconnect()
		rosterConnection = nil
	end
	if failureConnection ~= nil then
		failureConnection:Disconnect()
		failureConnection = nil
	end
	for _, read in OperativeLifeService.readAll() do
		local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
		if player ~= nil then
			for _, attributeName in DISCLOSED_ATTRIBUTES do
				player:SetAttribute(attributeName, nil)
			end
		end
	end
end

return Runtime
