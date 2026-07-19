--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local selector = fs.readFile("games/living-kingdoms/src/server/Systems/WeaponTargetSelector.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau")
local enemyConfig = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau")

for _, token in
	{
		"TargetCandidateSelector",
		"TargetCandidateValidator",
		"WeaponPatternConfig",
		"WeaponPatternResolver",
		"hasThreateningPrimary",
		"WeaponPatternResolver.resolve",
		"best.utilityCount <= 0",
		"TargetCandidateSelector.select(operative, candidates)",
		"ThreateningPatternUtility",
		"ValidPatternUtility",
		"EQUIVALENT_PATTERN_UTILITY_DISTANCE_ALLOWANCE_STUDS = 6",
		"current.utilityCount ~= best.utilityCount",
		"maximumRetainedDistance",
		"currentTargetEntityId",
		"retainedOrBest(best, current)",
	}
do
	assertThat(contains(selector, token), "weapon-aware selector missing " .. token)
end

assertThat(
	contains(runtime, "WeaponTargetSelector.select(targetingState, candidates, playerState.selectedTargetEntityId)"),
	"production automatic combat must pass the current authoritative target into weapon-aware selection"
)
assertThat(
	not contains(runtime, "TargetCandidateSelector.select(targetingState, candidates)"),
	"runtime must not bypass weapon-aware targeting"
)
assertThat(contains(contracts, '"ThreateningPatternUtility"'), "contracts missing threatening pattern reason")
assertThat(contains(contracts, '"ValidPatternUtility"'), "contracts missing valid pattern reason")
assertThat(
	contains(enemyConfig, "MaximumLineOfSightRaycastsPerEvaluation = 8"),
	"valid primary evaluation must remain bounded by the existing LOS budget"
)

for _, forbidden in
	{
		"Workspace:Raycast",
		"FireServer",
		"FireClient",
		"FireAllClients",
		"RemoteEvent",
		"RemoteFunction",
		"DamageResolver",
		"commitHealthState",
		"loadedRounds -=",
		"TakeDamage",
		"task.delay",
		"task.spawn",
		"selectedAtServerTimestamp = os.clock",
	}
do
	assertThat(not contains(selector, forbidden), "selector cannot own side effects or timers: " .. forbidden)
end

assertThat(
	contains(selector, "candidate.relationshipId == CombatContracts.TeamRelationshipIds.Hostile"),
	"secondary utility must exclude non-hostile lookalikes"
)
assertThat(
	contains(selector, "candidate.entityKindId == CombatContracts.CombatEntityKindIds.Hostile"),
	"secondary utility must require hostile entity kind"
)
assertThat(
	contains(selector, "hasThreateningPrimary and not isThreatening(operative, candidate)"),
	"equivalent-utility retention must never cross the active-threat cohort boundary"
)

print(
	"WeaponTargetSelectorSourceAudit: threat priority, fallback parity, bounded retention, authority, and LOS bounds passed"
)
