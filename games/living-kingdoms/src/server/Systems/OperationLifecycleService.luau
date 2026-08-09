--!strict

--[[
	P10-0105 deterministic match cleanup and deliberate replay preparation.

	This is the one owner of the terminal stop/start sequence. It holds no gameplay
	state of its own: it executes `MatchResultConfig.CleanupStopOrder` and
	`ReplayStartOrder` against each system's existing lifecycle, so cleanup order
	lives in shared configuration rather than in a hand-written sequence here. Both
	orders are asserted to cover every declared cleanup owner exactly once, so no
	owner can be skipped or torn down twice.

	A resolved operation now stays resolved until the server-owned expedition lobby
	consumes a fresh deliberate launch. That launch calls `prepareForLaunch()` to
	run the existing clean stop/start sequence immediately before pressure is armed
	and a new expedition is created. The mission director still mints a fresh
	per-run `operationId`, so a repeated operation is never a resume.

	This owner has one terminal subscription and no timer or client request surface.
	It prepares fresh operation state; it never decides that a new expedition
	should launch.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchResultConfig = require(ReplicatedStorage.Shared.Config.MatchResultConfig)
local MatchResultContracts = require(ReplicatedStorage.Shared.Mission.MatchResultContracts)
local AmmunitionCacheService = require(script.Parent.AmmunitionCacheService)
local ClassService = require(script.Parent.ClassService)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local MatchResultService = require(script.Parent.MatchResultService)
local MissionDirectorService = require(script.Parent.MissionDirectorService)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local OperativeReviveSessionService = require(script.Parent.OperativeReviveSessionService)
local PrimaryCombatModeService = require(script.Parent.PrimaryCombatModeService)
local RunBuildService = require(script.Parent.RunBuildService)
local RunProgressionService = require(script.Parent.RunProgressionService)
local SquadFailureService = require(script.Parent.SquadFailureService)
local SurvivalLootService = require(script.Parent.SurvivalLootService)

type OperationReplayStateId = MatchResultContracts.OperationReplayStateId
type ListenerConnection = { Disconnect: (self: ListenerConnection) -> () }

local CleanupOwnerIds = MatchResultContracts.CleanupOwnerIds
local ReplayStateIds = MatchResultContracts.OperationReplayStateIds

local OperationLifecycleService = {}

-- Each declared cleanup owner maps to the lifecycle it already exposes. The
-- objective runtime is owned by the mission director, so it releases its own
-- state at its documented place and the director tears the rest down last.
local stopByOwnerId: { [string]: () -> () } = {
	[CleanupOwnerIds.EnemyDirector] = function()
		EnemyDirectorService.stop()
	end,
	[CleanupOwnerIds.Objectives] = function()
		MissionDirectorService.resetObjectiveRuntime()
	end,
	[CleanupOwnerIds.AmmunitionCaches] = function()
		AmmunitionCacheService.stop()
	end,
	[CleanupOwnerIds.Classes] = function()
		ClassService.stop()
	end,
	[CleanupOwnerIds.ReviveSessions] = function()
		OperativeReviveSessionService.stop()
	end,
	-- OperativeLifeService owns application-scoped player and subscriber
	-- bindings. A fresh run resets operation state instead of stopping it and
	-- orphaning long-lived consumers.
	[CleanupOwnerIds.OperativeLife] = function() end,
	[CleanupOwnerIds.SquadFailure] = function()
		SquadFailureService.stop()
	end,
	[CleanupOwnerIds.ContributionRecord] = function()
		MatchResultService.stop()
	end,
	[CleanupOwnerIds.MissionDirector] = function()
		MissionDirectorService.stop()
	end,
}

local startByOwnerId: { [string]: () -> () } = {
	[CleanupOwnerIds.EnemyDirector] = function()
		EnemyDirectorService.start()
	end,
	-- The objective runtime comes back with the mission director that owns it.
	[CleanupOwnerIds.Objectives] = function() end,
	[CleanupOwnerIds.AmmunitionCaches] = function()
		AmmunitionCacheService.start()
	end,
	[CleanupOwnerIds.Classes] = function()
		ClassService.start()
	end,
	[CleanupOwnerIds.ReviveSessions] = function()
		OperativeReviveSessionService.start()
	end,
	[CleanupOwnerIds.OperativeLife] = function()
		OperativeLifeService.resetForReplay()
	end,
	[CleanupOwnerIds.SquadFailure] = function()
		SquadFailureService.start()
	end,
	[CleanupOwnerIds.ContributionRecord] = function()
		MatchResultService.start()
	end,
	[CleanupOwnerIds.MissionDirector] = function()
		MissionDirectorService.start()
	end,
}

local started = false
local replayStateId: OperationReplayStateId = ReplayStateIds.InProgress
local terminalConnection: ListenerConnection? = nil
local completedReplayCount = 0

-- Runs the documented stop order, then the documented start order. Every step is
-- isolated so one owner error cannot prevent the rest of the cleanup sequence.
local function prepareFreshRun()
	for _, ownerId in MatchResultConfig.CleanupStopOrder do
		local stopOwner = stopByOwnerId[ownerId]
		if stopOwner ~= nil then
			pcall(stopOwner)
		end
	end
	-- These application-scoped owners carry run-sensitive state but predate the
	-- cleanup-owner vocabulary. Reset them explicitly at the replay seam. Run
	-- build resets first because progression derives its replicated combat
	-- modifiers from the build's temporary upgrade stacks.
	PrimaryCombatModeService.resetAllToMelee()
	OperativeCombatRuntimeService.resetForReplay()
	SurvivalLootService.resetForReplay()
	RunBuildService.resetOperation()
	RunProgressionService.resetOperation()
	for _, ownerId in MatchResultConfig.ReplayStartOrder do
		local startOwner = startByOwnerId[ownerId]
		if startOwner ~= nil then
			pcall(startOwner)
		end
	end
	completedReplayCount += 1
	replayStateId = ReplayStateIds.InProgress
end

local function onResolved()
	if not started or replayStateId ~= ReplayStateIds.InProgress then
		return
	end
	replayStateId = ReplayStateIds.Resolved
end

-- Called only by the server-owned deliberate launch path. The first launch is
-- already fresh and is a no-op here. After a terminal result, the next launch
-- prepares all operation-scoped owners before the lobby arms pressure.
function OperationLifecycleService.prepareForLaunch(): boolean
	if not started then
		return false
	end
	if replayStateId == ReplayStateIds.InProgress then
		return true
	end
	if replayStateId ~= ReplayStateIds.Resolved then
		return false
	end
	replayStateId = ReplayStateIds.Replayable
	prepareFreshRun()
	return true
end

function OperationLifecycleService.readReplayStateId(): OperationReplayStateId
	return replayStateId
end

function OperationLifecycleService.readCompletedReplayCount(): number
	return completedReplayCount
end

function OperationLifecycleService.start()
	if started then
		return
	end
	started = true
	replayStateId = ReplayStateIds.InProgress
	completedReplayCount = 0
	terminalConnection = MissionDirectorService.subscribeResolved(onResolved)
end

function OperationLifecycleService.stop()
	if not started then
		return
	end
	started = false
	if terminalConnection ~= nil then
		terminalConnection:Disconnect()
		terminalConnection = nil
	end
	replayStateId = ReplayStateIds.InProgress
	completedReplayCount = 0
end

return table.freeze(OperationLifecycleService)
