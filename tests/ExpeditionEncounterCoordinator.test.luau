--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "ExpeditionEncounterCoordinator fixture assertion failed", 2)
	end
end

local Coordinator = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionEncounterCoordinator.luau"),
	{ debugName = "ExpeditionEncounterCoordinator", injectGlobals = true }
)()

local snapshot = {
	RunId = "run-test-0001",
	PhaseId = "Approach",
	PhaseIndex = 2,
	PhaseStartedAtUnix = 100,
	OutcomeId = "InProgress",
}

local advanceCalls = 0
local runtime = {
	getSnapshot = function()
		return table.clone(snapshot)
	end,
	advancePhase = function(_self: unknown, expectedPhaseId: string, _nowUnix: number)
		assert(expectedPhaseId == snapshot.PhaseId, "coordinator advanced a stale phase")
		advanceCalls += 1
		if snapshot.PhaseId == "Approach" then
			snapshot.PhaseId = "Dungeon"
			snapshot.PhaseIndex = 3
		elseif snapshot.PhaseId == "Dungeon" then
			snapshot.PhaseId = "Elite"
			snapshot.PhaseIndex = 4
		elseif snapshot.PhaseId == "Elite" then
			snapshot.PhaseId = "Boss"
			snapshot.PhaseIndex = 5
		elseif snapshot.PhaseId == "Boss" then
			snapshot.PhaseId = "Rewards"
			snapshot.PhaseIndex = 6
		end
		return { Accepted = true, ReasonId = "PhaseAdvanced" }
	end,
}

local started = {}
local cancelled = {}
local function adapter(label: string)
	return {
		start = function(context: any)
			table.insert(started, { Label = label, Context = context })
			return true
		end,
		cancel = function(context: any, reasonId: string)
			table.insert(cancelled, { Context = context, ReasonId = reasonId })
		end,
	}
end

local plan = {
	Seed = 991,
	Nodes = {
		{ Index = 1, RoomId = "entry", RoleId = "Entry" },
		{ Index = 2, RoomId = "hall-a", RoleId = "Traversal" },
		{ Index = 3, RoomId = "arena-a", RoleId = "Combat" },
		{ Index = 4, RoomId = "elite-a", RoleId = "Elite" },
		{ Index = 5, RoomId = "boss-a", RoleId = "Boss" },
	},
}

local coordinator = Coordinator.new(runtime, plan, {
	Approach = adapter("Approach"),
	DungeonTraversal = adapter("Traversal"),
	DungeonCombat = adapter("Combat"),
	Elite = adapter("Elite"),
	Boss = adapter("Boss"),
})

local approachStart = coordinator:sync(101)
assert(approachStart.Accepted and started[1].Label == "Approach", "approach encounter did not start")
local approachContext = coordinator:getActiveContext()
assert(approachContext ~= nil, "active approach context missing")
assert(coordinator:sync(102).ReasonId == "EncounterAlreadyActive", "parallel encounter start was not rejected")
assert(coordinator:completeActive("wrong-token", 103).ReasonId == "StaleEncounterToken", "stale token was accepted")
assert(coordinator:completeActive(approachContext.Token, 104).Accepted, "approach completion failed")
assert(advanceCalls == 1 and snapshot.PhaseId == "Dungeon", "approach did not advance to dungeon")
assert(coordinator:completeActive(approachContext.Token, 105).ReasonId == "EncounterAlreadyCompleted", "duplicate completion was accepted")

assert(coordinator:sync(106).Accepted and started[2].Label == "Traversal", "first dungeon room did not start")
local traversal = coordinator:getActiveContext()
assert(traversal and traversal.RoomId == "hall-a", "wrong traversal room context")
assert(coordinator:completeActive(traversal.Token, 107).ReasonId == "DungeonRoomCompleted", "dungeon room completion failed")
assert(advanceCalls == 1, "individual dungeon room incorrectly advanced phase")

assert(coordinator:sync(108).Accepted and started[3].Label == "Combat", "combat room did not start")
local combat = coordinator:getActiveContext()
assert(combat and combat.RoomId == "arena-a", "wrong combat room context")
assert(coordinator:completeActive(combat.Token, 109).Accepted, "combat room completion failed")

local dungeonFinished = coordinator:sync(110)
assert(dungeonFinished.Accepted and snapshot.PhaseId == "Elite", "exhausted dungeon did not advance to elite")
assert(advanceCalls == 2, "dungeon phase advanced incorrect number of times")

assert(coordinator:sync(111).Accepted and started[4].Label == "Elite", "elite encounter did not start")
local elite = coordinator:getActiveContext()
assert(elite ~= nil and coordinator:completeActive(elite.Token, 112).Accepted, "elite completion failed")
assert(snapshot.PhaseId == "Boss", "elite did not advance to boss")

assert(coordinator:sync(113).Accepted and started[5].Label == "Boss", "boss encounter did not start")
local boss = coordinator:getActiveContext()
assert(boss ~= nil, "boss context missing")
coordinator:destroy()
assert(#cancelled == 1 and cancelled[1].ReasonId == "CoordinatorDestroyed", "active boss was not cancelled on destroy")
assert(coordinator:sync(114).ReasonId == "CoordinatorDestroyed", "destroyed coordinator accepted work")
assert(coordinator:completeActive(boss.Token, 115).ReasonId == "CoordinatorDestroyed", "destroyed coordinator accepted completion")

print("ExpeditionEncounterCoordinator fixture passed")
