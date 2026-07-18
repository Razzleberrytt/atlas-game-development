--!strict

-- HROI-0104 source audit: combat-impact feedback consumes only replicated
-- server-confirmed hit/death facts, stays client-local, and preserves bounded
-- scheduler, connection, particle, distance, and enemy-count budgets.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "HROI-0104 combat impact source audit failed", 2)
	end
end

local function countOccurrences(source: string, token: string): number
	local count = 0
	local startIndex = 1
	while true do
		local found = string.find(source, token, startIndex, true)
		if found == nil then
			return count
		end
		count += 1
		startIndex = found + #token
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/CombatImpactPresentationConfig.luau"), {
	debugName = "CombatImpactPresentationConfig",
	injectGlobals = true,
})()

assert(config.Version == "HROI-0104-v1")
assert(table.isfrozen(config), "impact config must be immutable")
assert(config.MaximumTrackedEnemies == 24, "effect tracking must match the current validated global enemy ceiling")
assert(config.MaximumEffectDistanceStuds <= 200, "camera distance culling must stay bounded")
assert(config.HitParticleCount <= 12, "hit particles must remain a small burst")
assert(config.KillParticleCount <= 32, "kill particles must remain bounded")
assert(config.KillParticleCount > config.HitParticleCount, "kills require stronger feedback than ordinary hits")
assert(config.KillFlashSeconds > config.HitFlashSeconds, "kill confirmation must outlast hit confirmation")

local controllerPath = "games/living-kingdoms/src/client/Controllers/EnemyImpactPresentationController.luau"
local controller = fs.readFile(controllerPath)
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assert(controller:find("PresentationAttributeNames.HitSequence", 1, true) ~= nil)
assert(controller:find("PresentationAttributeNames.LifeStateId", 1, true) ~= nil)
assert(controller:find("PresentationLifeStateIds.Dead", 1, true) ~= nil)
assert(controller:find("hitSequence > record.lastHitSequence", 1, true) ~= nil)
assert(controller:find("isDead and not record.wasDead", 1, true) ~= nil)
assert(controller:find("Workspace:GetServerTimeNow()", 1, true) ~= nil)
assert(controller:find("ParticleEmitter", 1, true) ~= nil)
assert(controller:find(":Emit(CombatImpactPresentationConfig.HitParticleCount)", 1, true) ~= nil)
assert(controller:find(":Emit(CombatImpactPresentationConfig.KillParticleCount)", 1, true) ~= nil)
assert(controller:find("HighlightDepthMode.Occluded", 1, true) ~= nil)
assert(controller:find("MaximumEffectDistanceStuds", 1, true) ~= nil)
assert(controller:find("MaximumTrackedEnemies", 1, true) ~= nil)

assert(countOccurrences(controller, ":Connect(") == 3, "exactly two folder connections and one frame connection are allowed")
for _, prohibited in {
	"RemoteEvent",
	"RemoteFunction",
	"FireServer",
	"OnClientEvent",
	"task.delay",
	"task.spawn",
	"Debris",
	"while true",
	"TakeDamage",
	"applyAuthoritativeDamage",
	"commitHealthState",
	"SetNetworkOwner",
	"Humanoid:MoveTo",
} do
	assert(controller:find(prohibited, 1, true) == nil, "prohibited authority or scheduler token: " .. prohibited)
end

assert(bootstrap:find("require(script.Controllers.EnemyImpactPresentationController)", 1, true) ~= nil)
assert(bootstrap:find("EnemyImpactPresentationController.start()", 1, true) ~= nil)

print("EnemyImpactPresentationSourceAudit: confirmed facts, bounded effects, and client-only authority passed")
