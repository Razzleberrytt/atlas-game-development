--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "Screamer interrupt reward source audit failed", 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function occurrenceCount(source: string, token: string): number
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

local rewardConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/ScreamerInterruptRewardConfig.luau"), {
		debugName = "ScreamerInterruptRewardConfig",
		injectGlobals = true,
	})()
local punctuationConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/HordeDeathPunctuationConfig.luau"), {
		debugName = "HordeDeathPunctuationConfig",
		injectGlobals = true,
	})()
local service = fs.readFile("games/living-kingdoms/src/server/Systems/ScreamerInterruptRewardService.luau")
local progressionService = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local effectsController = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeEffectsController.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

assert(occurrenceCount(service, "RunService.Heartbeat:Connect") == 1, "reward observer needs one bounded scan")
assert(contains(service, "folder:GetChildren()"), "reward observer must inspect the bounded enemy folder")
assert(contains(service, "MaximumTrackedEnemyModels"), "reward observer requires a hard model ceiling")
assert(contains(service, "EnemyPresentationContracts.AttributeNames.LifeStateId"), "death must use server life truth")
assert(contains(service, "EnemyPresentationContracts.AttributeNames.HitSequence"), "reward requires a confirmed hit")
assert(contains(service, "HordeExperienceConfig.Roles.Screamer.Id"), "reward must require the Screamer role")
assert(contains(service, "SpecialKindIds.ScreamerReinforcement"), "reward must require reinforcement windup")
assert(contains(service, "SpecialStateIds.Interrupted"), "reward must require authoritative interruption")
assert(contains(service, "CombatEntityId"), "reward IDs require server-owned enemy identity")
assert(contains(service, "RunProgressionService.awardFieldIntel"), "bonus must use the idempotent progression owner")
assert(contains(progressionService, "processedFieldIntelRewardIds"), "progression owner must retain duplicate defense")
assert(contains(service, "initialScanComplete"), "startup corpses must not fabricate reward")
assert(contains(service, "table.clear(rewardedSequences)"), "reward history must clean up with the service")

for _, prohibited in
	{
		"RemoteEvent",
		"RemoteFunction",
		"OnServerEvent",
		"FireServer",
		"GetAttributeChangedSignal",
		"Humanoid.Health",
		"task.delay",
		"task.spawn",
		"task.defer",
	}
do
	assert(not contains(service, prohibited), "interrupt reward must remain server-only and bounded: " .. prohibited)
end

local progressionStart = string.find(serverBootstrap, "RunProgressionService.start()", 1, true)
local hordeStart = string.find(serverBootstrap, "HordeExperienceService.start()", 1, true)
local rewardStart = string.find(serverBootstrap, "ScreamerInterruptRewardService.start()", 1, true)
assert(
	progressionStart ~= nil and hordeStart ~= nil and rewardStart ~= nil,
	"bootstrap must start all reward prerequisites"
)
assert(
	(progressionStart :: number) < (hordeStart :: number) and (hordeStart :: number) < (rewardStart :: number),
	"interrupt reward must start after progression and horde attribute ownership"
)

local interruptedDefinition = punctuationConfig.get(punctuationConfig.KindIds.ScreamerInterrupted)
assert(interruptedDefinition ~= nil, "interrupted Screamer punctuation is missing")
assert(
	(interruptedDefinition.XpBonus or 0) == rewardConfig.BonusFieldXp,
	"presentation bonus copy must match the server reward"
)
assert(contains(effectsController, "definition.XpBonus or 0"), "death billboard must include the bonus copy")
assert(contains(effectsController, "xpAmount + bonusXp"), "death billboard must display the combined XP total")

print("ScreamerInterruptRewardSourceAudit: authority, idempotency, bounds, bootstrap, and presentation passed")
