--!strict

--[[
	Studio-only, server-command-bar transition controls for runtime life validation.
	Every committed snapshot is produced by an existing pure P3 resolver and is
	committed through OperativeLifeService's revision boundary. This module has
	no start loop, RemoteEvent, client surface, or production orchestration role.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local OperativeLifeConfig = require(ReplicatedStorage.Shared.Config.OperativeLifeConfig)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local OperativeIncapacitationResolver = require(script.Parent.OperativeIncapacitationResolver)
local OperativeReviveResolver = require(script.Parent.OperativeReviveResolver)

local Harness = {}
local nextEventId = 0
local controlFolder: Folder? = nil

local CONTROL_FOLDER_NAME = "LK0305OperativeLifeDevelopment"

local function studioOnly(): boolean
	return RunService:IsStudio()
end

local function eventId(prefix: string): string
	nextEventId += 1
	return string.format("%s:%d", prefix, nextEventId)
end

local function commit(player: Player, read, resolverResult)
	return OperativeLifeService.commitAcceptedTransition(player, read.revision, resolverResult)
end

function Harness.read(player: Player)
	if not studioOnly() then
		return nil
	end
	return OperativeLifeService.read(player)
end

function Harness.incapacitate(player: Player)
	if not studioOnly() then
		return nil
	end
	local read = OperativeLifeService.read(player)
	if read == nil then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	return OperativeLifeService.applyAuthoritativeDamage(read.snapshot.operativeEntityId, read.revision, {
		damageEventId = eventId("studio.incapacitate"),
		sourceEntityId = nil,
		targetEntityId = read.snapshot.operativeEntityId,
		damageAmount = OperativeLifeConfig.MaximumHealth,
		serverTimestamp = now,
	})
end

function Harness.applyDamage(player: Player, damageAmount: number, damageEventId: string?)
	if not studioOnly() then
		return nil
	end
	local read = OperativeLifeService.read(player)
	if read == nil then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	return OperativeLifeService.applyAuthoritativeDamage(read.snapshot.operativeEntityId, read.revision, {
		damageEventId = damageEventId or eventId("studio.damage"),
		sourceEntityId = "studio.server",
		targetEntityId = read.snapshot.operativeEntityId,
		damageAmount = damageAmount,
		serverTimestamp = now,
	})
end

function Harness.kill(player: Player)
	if not studioOnly() then
		return nil
	end
	local read = OperativeLifeService.read(player)
	if read == nil then
		return nil
	end
	if read.snapshot.lifeStateId == "Alive" then
		local incapacitated = Harness.incapacitate(player)
		if incapacitated == nil or not incapacitated.didCommit then
			return incapacitated
		end
		read = OperativeLifeService.read(player)
		if read == nil then
			return nil
		end
	end
	local now = Workspace:GetServerTimeNow()
	local resolverResult = OperativeIncapacitationResolver.resolveFinishingDamage(read.snapshot, {
		damageEventId = eventId("studio.finish"),
		sourceEntityId = nil,
		targetEntityId = read.snapshot.operativeEntityId,
		damageAmount = 1,
		serverTimestamp = now,
	}, now)
	return commit(player, read, resolverResult)
end

local function reviveCombatState(operativeEntityId: string)
	local weaponId = FirearmConfig.BasicFirearm.WeaponId
	return {
		weaponState = {
			weaponId = weaponId,
			readinessStateId = CombatContracts.WeaponReadinessStateIds.Ready,
			ammunition = {
				weaponId = weaponId,
				loadedRounds = 0,
				reserveRounds = 0,
				magazineCapacity = FirearmConfig.BasicFirearm.MagazineCapacity,
			},
			cadence = {
				weaponId = weaponId,
				lastFireServerTimestamp = nil,
				nextAllowedFireServerTimestamp = 0,
			},
			reloadState = nil,
		},
		selectedTargetState = nil,
		processedShotIds = {},
		operativeEntityId = operativeEntityId,
	}
end

function Harness.revive(player: Player)
	if not studioOnly() then
		return nil
	end
	local targetRead = OperativeLifeService.read(player)
	if targetRead == nil or targetRead.snapshot.lifeStateId ~= "Incapacitated" then
		return nil
	end
	local reviverRead = nil
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player then
			local candidateRead = OperativeLifeService.read(candidate)
			if candidateRead ~= nil and candidateRead.snapshot.lifeStateId == "Alive" then
				reviverRead = candidateRead
				break
			end
		end
	end
	if reviverRead == nil then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	local sessionId = eventId("studio.revive")
	local beginFacts = {
		sessionId = sessionId,
		reviverOperativeEntityId = reviverRead.snapshot.operativeEntityId,
		targetOperativeEntityId = targetRead.snapshot.operativeEntityId,
		distanceStuds = 0,
		hasLineOfSight = true,
		serverTimestamp = now,
		activeSessionIdForTarget = nil,
		hasConflictingActiveSession = false,
	}
	local began = OperativeReviveResolver.beginRevive(reviverRead.snapshot, targetRead.snapshot, beginFacts)
	if not began.didTransition or began.sessionStateAfter == nil then
		return began
	end
	local completionTimestamp = now + OperativeLifeConfig.ReviveDurationSeconds
	local completed =
		OperativeReviveResolver.continueRevive(reviverRead.snapshot, targetRead.snapshot, began.sessionStateAfter, {
			sessionId = sessionId,
			reviverOperativeEntityId = reviverRead.snapshot.operativeEntityId,
			targetOperativeEntityId = targetRead.snapshot.operativeEntityId,
			distanceStuds = 0,
			hasLineOfSight = true,
			serverTimestamp = completionTimestamp,
			activeSessionIdForTarget = sessionId,
			hasConflictingActiveSession = false,
			reviverRemainsConnectedAndParticipating = true,
			reviverMovementRemainedValid = true,
			reviverReceivedNoInterruptingDamage = true,
			holdRemainsActive = true,
		}, reviveCombatState(targetRead.snapshot.operativeEntityId))
	return commit(player, targetRead, completed)
end

local function createControl(name: string, callback: (Player) -> any)
	local control = Instance.new("BindableFunction")
	control.Name = name
	control.OnInvoke = callback
	control.Parent = controlFolder
end

function Harness.start()
	if not studioOnly() or controlFolder ~= nil then
		return
	end
	local existing = ServerStorage:FindFirstChild(CONTROL_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTROL_FOLDER_NAME
	folder.Parent = ServerStorage
	controlFolder = folder
	createControl("Read", Harness.read)
	createControl("ApplyDamage", Harness.applyDamage)
	createControl("Incapacitate", Harness.incapacitate)
	createControl("Revive", Harness.revive)
	createControl("Kill", Harness.kill)
end

function Harness.stop()
	local folder = controlFolder
	if folder == nil then
		return
	end
	controlFolder = nil
	folder:Destroy()
end

return table.freeze(Harness)
