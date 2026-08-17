--!strict

local fs = require("@lune/fs")

local config = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau")
local director = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

assert(
	contains(config, "MaximumPathComputationsPerEvaluation = 4"),
	"enemy navigation must publish an explicit small path-computation budget"
)
assert(
	contains(config, "EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation % 1 == 0"),
	"path-computation budget must be validated as an integer"
)
assert(
	contains(config, "the path-computation budget must be a positive bounded integer"),
	"invalid path-computation budgets must fail fast at authored-config load"
)

assert(
	contains(director, "require(script.Parent.Parent.Domain.EnemyNavigationScheduler)"),
	"EnemyDirectorService must use the pure navigation scheduler"
)
assert(
	contains(director, "EnemyNavigationScheduler.resolveRoundRobinGrants("),
	"each evaluation must resolve a deterministic fair grant set"
)
assert(
	contains(director, "EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation"),
	"the evaluation grant count must come from authored config"
)
assert(
	contains(director, "pathGrantByEntityId[entityId] == true"),
	"each enemy behavior evaluation must receive only its scoped grant"
)
assert(
	contains(director, "pathComputationGranted: boolean"),
	"walker pursuit must make the expensive path permission explicit"
)

local grantGate = assert(string.find(director, "if pathComputationGranted then", 1, true))
local createPath = assert(string.find(director, "pathService:CreatePath({", 1, true))
local directFallback = assert(string.find(director, "entry.humanoid:MoveTo(targetPosition)", createPath, true))
assert(grantGate < createPath, "CreatePath must remain behind the evaluation grant gate")
assert(createPath < directFallback, "ungranted/failed pathfinding must retain direct pursuit fallback")

local _, createPathCount = string.gsub(director, "pathService:CreatePath%(%{", "")
assert(createPathCount == 1, "all enemy path computation must stay behind the single budgeted owner")
assert(
	contains(director, "navigationPathBudgetCursorEntityId = nil"),
	"navigation fairness cursor must reset with the director lifecycle"
)
assert(
	not contains(director, "remainingPathComputations"),
	"director must not regress to first-N-wins mutable path budgeting"
)
assert(
	not contains(director, "EnemyNavigationProgress"),
	"LKB-0321 must not absorb stale #570 stuck-recovery state"
)

print("EnemyNavigationBudgetSourceAudit: fair bounded pathfinding budget and direct fallback passed")
