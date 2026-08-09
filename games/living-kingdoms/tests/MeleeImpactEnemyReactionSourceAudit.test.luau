--!strict

local fs = require("@lune/fs")

local melee = fs.readFile("games/living-kingdoms/src/client/Controllers/MeleePresentationController.luau")
local enemyImpact = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyImpactPresentationController.luau")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

assert(
	contains(melee, "MeleePresentationContracts.validateHitConfirmedMessage(message)"),
	"melee impact kick must be driven only by validated server-confirmed hit presentation"
)
assert(
	contains(melee, "localImpactConfirmedAtClock = nowClock"),
	"confirmed melee hits must arm the local impact response"
)
assert(contains(melee, "local function localImpactAmount"), "melee impact response must be bounded by a local decay")
assert(
	contains(melee, "local impact = localImpactAmount(nowClock)"),
	"first-person melee presentation must consume the confirmed impact response"
)
assert(
	contains(melee, "local impactScale = if localHitWasKill then 1.25 else 1"),
	"killing blows should receive stronger but still bounded impact punctuation"
)
assert(not contains(melee, "FireServer"), "melee impact presentation must not send combat intents")
assert(not contains(melee, "commitHealthState"), "melee impact presentation must not mutate health")
assert(not contains(melee, "EnemyDirector"), "melee impact presentation must not own enemy truth")

assert(
	contains(enemyImpact, "local function isEnemyModel"),
	"enemy impact tracking must use an archetype-agnostic predicate"
)
assert(
	contains(enemyImpact, 'model:GetAttribute("EnemyArchetypeId")'),
	"enemy impact tracking must rely on the existing server-replicated archetype identity"
)
assert(
	not contains(enemyImpact, "EnemyConfig.Walker.ArchetypeId"),
	"impact reactions must not be artificially limited to the Walker/Stalker archetype"
)
assert(
	contains(enemyImpact, "PresentationAttributeNames.HitSequence"),
	"enemy reactions must remain driven by server-confirmed hit sequence attributes"
)
assert(
	contains(enemyImpact, "PresentationAttributeNames.LifeStateId"),
	"kill punctuation must remain driven by replicated authoritative life state"
)
assert(
	contains(enemyImpact, "CombatImpactPresentationConfig.MaximumTrackedEnemyModels"),
	"broader enemy coverage must preserve the bounded tracking cap"
)
assert(not contains(enemyImpact, "FireServer"), "enemy reaction presentation must not send combat intents")
assert(not contains(enemyImpact, "TakeDamage"), "enemy reaction presentation must not mutate damage")
assert(not contains(enemyImpact, "commitHealthState"), "enemy reaction presentation must not mutate health state")

print(
	"MeleeImpactEnemyReactionSourceAudit: confirmed melee impact and archetype-wide enemy reactions remain presentation-only"
)
