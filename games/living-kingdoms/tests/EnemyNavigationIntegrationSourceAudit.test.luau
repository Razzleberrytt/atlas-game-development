--!strict

local fs = require("@lune/fs")

local director = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

for _, token in {
	"EnemyNavigationScheduler",
	"pathComputationGrants",
	"navigationFairnessCursorEntityId",
	"buildEvaluationBudget",
	"resolveRoundRobin",
	"resolveProgress",
	"navigationProgressAnchor",
	"navigationProgressAnchorServerTimestamp",
	"nextStuckRecoveryServerTimestamp",
	"entry.pursuitFlankSign *= -1",
	"entry.humanoid:MoveTo(destination)",
} do
	assert(contains(director, token), "enemy navigation Wave 2 integration missing " .. token)
end

for _, token in {
	'MVP-0.1-v8-fair-stuck-recovery',
	"StuckMinimumProgressStuds = 1.5",
	"StuckProgressWindowSeconds = 1.25",
	"StuckRecoveryCooldownSeconds = 1.5",
	"MaximumPathComputationsPerEvaluation = 4",
} do
	assert(contains(config, token), "enemy navigation Wave 2 tuning missing " .. token)
end

assert(not contains(director, "remainingPathComputations"), "path budget must not depend on enemy table iteration order")

print("EnemyNavigationIntegrationSourceAudit: fair path grants + stuck recovery remain wired into the server director")
