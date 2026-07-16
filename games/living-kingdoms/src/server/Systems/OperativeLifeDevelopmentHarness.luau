--!strict

--[[
	Studio-only, server-command-bar transition controls for runtime life validation.
	Every committed snapshot is produced by an existing pure P3 resolver and is
	committed through OperativeLifeService's revision boundary. This module has
	no start loop, RemoteEvent, client surface, or production orchestration role.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local OperativeLifeConfig = require(ReplicatedStorage.Shared.Config.OperativeLifeConfig)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local OperativeLifeRuntimeService = require(script.Parent.OperativeLifeRuntimeService)
local SquadFailureService = require(script.Parent.SquadFailureService)

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

function Harness.read(player: Player)
	if not studioOnly() then
		return nil
	end
	return OperativeLifeService.read(player)
end

function Harness.readSquadFailure()
	if not studioOnly() then
		return nil
	end
	return {
		failure = SquadFailureService.read(),
		participation = SquadFailureService.readParticipationFacts(),
	}
end

function Harness.beginOperation()
	if not studioOnly() then
		return nil
	end
	return SquadFailureService.beginOperation()
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
	return OperativeLifeRuntimeService.applyAuthoritativeFinishingDamage(
		read.snapshot.operativeEntityId,
		read.revision,
		{
			damageEventId = eventId("studio.finish"),
			sourceEntityId = nil,
			targetEntityId = read.snapshot.operativeEntityId,
			damageAmount = 1,
			serverTimestamp = now,
		}
	)
end

function Harness.advanceToNextLifeDeadline(player: Player)
	if not studioOnly() then
		return nil
	end
	local read = OperativeLifeService.read(player)
	if read == nil or read.snapshot.lifeStateId ~= "Incapacitated" then
		return nil
	end
	local recoveryDeadline = read.snapshot.soloRecoveryState.recoveryCompletionServerTimestamp
	local incapacitation = read.snapshot.incapacitationState
	local deadline = if recoveryDeadline ~= nil
		then recoveryDeadline
		else if incapacitation == nil then nil else incapacitation.bleedOutDeadlineServerTimestamp
	if deadline == nil then
		return nil
	end
	return OperativeLifeRuntimeService.evaluateDeadlinesAt(deadline)
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
	createControl("ReadSquadFailure", Harness.readSquadFailure)
	createControl("BeginOperation", Harness.beginOperation)
	createControl("ApplyDamage", Harness.applyDamage)
	createControl("Incapacitate", Harness.incapacitate)
	createControl("AdvanceToNextLifeDeadline", Harness.advanceToNextLifeDeadline)
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
