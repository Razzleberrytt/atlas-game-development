--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeCombatService.luau")

local function position(needle: string): number
	local found = string.find(source, needle, 1, true)
	assert(found ~= nil, "missing melee cadence source contract: " .. needle)
	return found :: number
end

assert(
	string.find(source, "lastCommittedStrikeServerTimestamp", 1, true) == nil,
	"melee cadence cannot remain tied only to successful damage commits"
)

local cadenceCheck = position("serverTimestamp - state.lastAcceptedSwingServerTimestamp < Weapon.CadenceSeconds")
local positionCheck = position("local origin, character = operativePosition(player)")
local consumeCadence = position("state.lastAcceptedSwingServerTimestamp = serverTimestamp")
local consumeRequest = position("recordRequest(state, requestIdString)")
local readEnemyFacts = position("local facts = EnemyDirectorService.readEnemyCombatFacts()")
local resolveTarget = position("MeleeStrikeResolver.selectTarget")
local commitHealth = position("EnemyDirectorService.commitHealthState")

assert(cadenceCheck < positionCheck, "cadence must reject rapid repeat swings before target work")
assert(positionCheck < consumeCadence, "missing-character requests must not consume a swing")
assert(consumeCadence < readEnemyFacts, "a valid swing must consume cadence before target selection")
assert(consumeRequest < readEnemyFacts, "a valid swing request ID must be consumed even when no target is found")
assert(
	readEnemyFacts < resolveTarget and resolveTarget < commitHealth,
	"target/damage authority order must remain intact"
)

assert(
	string.find(source, "return rejected(selection.rejectionReasonId or Reasons.NoTarget", 1, true) ~= nil,
	"empty swings may remain no-target results while still consuming their authoritative cadence"
)
assert(
	string.find(source, "return rejected(Reasons.TargetOccluded", 1, true) ~= nil,
	"occluded swings must remain damage-rejected after cadence is consumed"
)

print("MeleeSwingCadenceSourceAudit: misses and occluded swings consume authoritative cadence")
