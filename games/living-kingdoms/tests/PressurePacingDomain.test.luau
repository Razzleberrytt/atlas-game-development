--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0105 pressure pacing assertion failed", 2)
	end
end

local domain = luau.load(fs.readFile("games/living-kingdoms/src/server/Domain/PressurePacingDomain.luau"), {
	debugName = "PressurePacingDomain",
	injectGlobals = true,
})()

local function facts(overrides: { [string]: any }?): any
	local value = {
		missionResolved = false,
		requestedWaveIndex = 2,
		completedWaveCount = 1,
		activeEnemyCount = 2,
		maximumConcurrentEnemies = 6,
		serverTimestamp = 100,
		lastWaveReleasedServerTimestamp = 70,
		minimumSecondsBetweenWaves = 20,
		recoveryUntilServerTimestamp = nil,
	}
	for key, replacement in overrides or {} do
		value[key] = replacement
	end
	return value
end

local accepted = domain.evaluate(facts())
assert(accepted.shouldReleaseWave)
assert(accepted.reasonId == domain.DecisionReasonIds.Accepted)

local resolved = domain.evaluate(facts({ missionResolved = true }))
assert(not resolved.shouldReleaseWave)
assert(resolved.reasonId == domain.DecisionReasonIds.MissionResolved)

local duplicate = domain.evaluate(facts({ requestedWaveIndex = 1 }))
assert(not duplicate.shouldReleaseWave)
assert(duplicate.reasonId == domain.DecisionReasonIds.AlreadyReleased)

local budget = domain.evaluate(facts({ activeEnemyCount = 6 }))
assert(not budget.shouldReleaseWave)
assert(budget.reasonId == domain.DecisionReasonIds.ConcurrentBudgetReached)

local recovery = domain.evaluate(facts({ recoveryUntilServerTimestamp = 101 }))
assert(not recovery.shouldReleaseWave)
assert(recovery.reasonId == domain.DecisionReasonIds.RecoveryWindowActive)
local recoveryBoundary = domain.evaluate(facts({ recoveryUntilServerTimestamp = 100 }))
assert(recoveryBoundary.shouldReleaseWave, "recovery ends at the exact authored deadline")

local interval = domain.evaluate(facts({ serverTimestamp = 89 }))
assert(not interval.shouldReleaseWave)
assert(interval.reasonId == domain.DecisionReasonIds.MinimumIntervalActive)
local intervalBoundary = domain.evaluate(facts({ serverTimestamp = 90 }))
assert(intervalBoundary.shouldReleaseWave, "minimum interval opens at the exact deadline")

local precedence = domain.evaluate(facts({
	missionResolved = true,
	requestedWaveIndex = 1,
	activeEnemyCount = 6,
	recoveryUntilServerTimestamp = 999,
	serverTimestamp = 80,
}))
assert(precedence.reasonId == domain.DecisionReasonIds.MissionResolved, "resolution must fail first")

for _, invalid in {
	nil,
	{},
	facts({ requestedWaveIndex = 0 }),
	facts({ completedWaveCount = -1 }),
	facts({ activeEnemyCount = 1.5 }),
	facts({ maximumConcurrentEnemies = 0 }),
	facts({ serverTimestamp = -1 }),
	facts({ serverTimestamp = math.huge }),
	facts({ minimumSecondsBetweenWaves = -1 }),
	facts({ recoveryUntilServerTimestamp = math.huge }),
	facts({ lastWaveReleasedServerTimestamp = 0 / 0 }),
} do
	assert(not domain.validateFacts(invalid))
	local decision = domain.evaluate(invalid)
	assert(not decision.shouldReleaseWave)
	assert(decision.reasonId == domain.DecisionReasonIds.InvalidFacts)
end

assert(domain.validateFacts(facts()))
assert(table.isfrozen(domain))
assert(table.isfrozen(domain.DecisionReasonIds))

print("PressurePacingDomain fixture passed")
