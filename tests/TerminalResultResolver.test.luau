--!strict

-- P10-0102 pure terminal-result resolver: fact/timestamp validation, the fixed
-- wipe > abandonment > extraction precedence, first-commit-wins idempotence, the
-- not-terminal case, and determinism.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P10-0102 terminal resolver fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local missionContracts =
	loadSimple("games/living-kingdoms/src/shared/Mission/MissionContracts.luau", "MissionContracts")
local lifeContracts =
	loadSimple("games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau", "OperativeLifeContracts")

local MISSION_TOKEN = {}
local LIFE_TOKEN = {}
local matchResultContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Mission/MatchResultContracts.luau"), {
		debugName = "MatchResultContracts",
		environment = {
			script = {
				Parent = {
					MissionContracts = MISSION_TOKEN,
					Parent = { Health = { OperativeLifeContracts = LIFE_TOKEN } },
				},
			},
			require = function(token: unknown)
				if token == MISSION_TOKEN then
					return missionContracts
				end
				if token == LIFE_TOKEN then
					return lifeContracts
				end
				error("unexpected MatchResultContracts dependency")
			end,
		},
		injectGlobals = true,
	})()

local CONTRACTS_TOKEN = {}
local replicatedStorage = { Shared = { Mission = { MatchResultContracts = CONTRACTS_TOKEN } } }
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/TerminalResultResolver.luau"), {
	debugName = "TerminalResultResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			assert(token == CONTRACTS_TOKEN, "unexpected resolver dependency")
			return matchResultContracts
		end,
	},
	injectGlobals = true,
})()

local function facts(overrides: { [string]: any }?)
	local base = {
		resolvedCauseId = nil,
		squadWiped = false,
		isAbandoned = false,
		extractionArrived = false,
		serverTimestamp = 500,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

-- Fact and timestamp validation.
assert(resolver.resolve(nil :: any).rejectionReasonId == "InvalidFacts")
assert(resolver.resolve(facts({ squadWiped = "yes" })).rejectionReasonId == "InvalidFacts")
assert(resolver.resolve(facts({ resolvedCauseId = "Vanished" })).rejectionReasonId == "InvalidFacts")
assert(resolver.resolve(facts({ serverTimestamp = 0 / 0 })).rejectionReasonId == "InvalidTimestamp")
assert(resolver.resolve(facts({ serverTimestamp = -1 })).rejectionReasonId == "InvalidTimestamp")

-- Not terminal: no condition satisfied.
local notTerminal = resolver.resolve(facts())
assert(not notTerminal.shouldCommit and notTerminal.rejectionReasonId == "NotTerminal")
assert(notTerminal.causeId == nil and notTerminal.outcomeId == nil)

-- Each single cause commits with its paired outcome.
local extracted = resolver.resolve(facts({ extractionArrived = true }))
assert(extracted.shouldCommit and extracted.causeId == "Extracted" and extracted.outcomeId == "Success")
local wiped = resolver.resolve(facts({ squadWiped = true }))
assert(wiped.shouldCommit and wiped.causeId == "SquadWipe" and wiped.outcomeId == "Failure")
local abandoned = resolver.resolve(facts({ isAbandoned = true }))
assert(abandoned.shouldCommit and abandoned.causeId == "Abandoned" and abandoned.outcomeId == "Failure")

-- Fixed precedence: a dead squad cannot extract, and wipe outranks abandonment.
assert(resolver.resolve(facts({ squadWiped = true, extractionArrived = true })).causeId == "SquadWipe")
assert(resolver.resolve(facts({ squadWiped = true, isAbandoned = true })).causeId == "SquadWipe")
assert(resolver.resolve(facts({ isAbandoned = true, extractionArrived = true })).causeId == "Abandoned")
assert(
	resolver.resolve(facts({ squadWiped = true, isAbandoned = true, extractionArrived = true })).causeId == "SquadWipe",
	"wipe wins even when every condition is satisfied at once"
)

-- First-commit-wins: a resolved operation never resolves again, whatever fires.
for _, resolved in { "Extracted", "SquadWipe", "Abandoned" } do
	local decision = resolver.resolve(facts({
		resolvedCauseId = resolved,
		squadWiped = true,
		isAbandoned = true,
		extractionArrived = true,
	}))
	assert(
		not decision.shouldCommit and decision.rejectionReasonId == "AlreadyResolved",
		"already resolved: " .. resolved
	)
	assert(decision.causeId == nil and decision.outcomeId == nil)
end

-- Determinism and immutability: identical frozen facts give identical decisions.
local frozenFacts = table.freeze(facts({ extractionArrived = true }))
local first = resolver.resolve(frozenFacts)
local second = resolver.resolve(frozenFacts)
assert(first.causeId == second.causeId and first.shouldCommit == second.shouldCommit and first.causeId == "Extracted")

print("TerminalResultResolver: P10-0102 validation, precedence, first-commit-wins, and determinism passed")
