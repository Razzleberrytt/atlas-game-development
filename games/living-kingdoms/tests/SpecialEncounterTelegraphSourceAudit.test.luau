--!strict

-- P9-0105 source audit: the special-encounter telegraph controller is bounded and
-- purely cosmetic — one frame loop, one folder-add/remove pair, no per-enemy
-- attribute connections, no remotes, no health reads, no hit prediction — and it
-- is bootstrapped and disclosure-driven.
local fs = require("@lune/fs")

local function count(source: string, token: string): number
	local occurrences = 0
	local startIndex = 1
	while true do
		local found = string.find(source, token, startIndex, true)
		if found == nil then
			return occurrences
		end
		occurrences += 1
		startIndex = found + #token
	end
end

local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/SpecialEncounterTelegraphController.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/SpecialEncounterTelegraphConfig.luau")
local presentation = fs.readFile("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

local function present(source: string, token: string)
	assert(string.find(source, token, 1, true) ~= nil, "expected token missing: " .. token)
end

local function absent(source: string, token: string, message: string)
	assert(string.find(source, token, 1, true) == nil, message)
end

-- Bounded construction and disclosure-driven presentation.
present(controller, "MaximumActiveTelegraphs")
present(controller, "MaximumTrackedEnemyModels")
present(controller, "Workspace:GetServerTimeNow()")
present(controller, "discKindForArchetypeId")
present(controller, "record.kind.SequenceAttribute")
present(controller, "slot.radiusStuds * 2")
present(controller, "BLOOM_LINGER_SECONDS")
present(controller, "updateBossStatus")
assert(count(controller, "RenderStepped:Connect") == 1, "one frame loop must serve every telegraph and the boss status")
assert(count(controller, "ChildAdded:Connect") == 1)
assert(count(controller, "ChildRemoved:Connect") == 1)
absent(controller, "GetAttributeChangedSignal", "no per-enemy attribute connections")
present(controller, 'FindFirstChild("HumanoidRootPart")')

-- Cosmetic only: no authority, no prediction, no health.
for _, prohibited in
	{
		"RemoteEvent",
		"FireServer",
		"InvokeServer",
		"OnClientEvent",
		"OnServerEvent",
		"Raycast",
		"applyAuthoritativeDamage",
		"commitHealthState",
		"spawnEnemy",
		"spawnBoss",
		"task.delay",
		"task.spawn",
		"math.random",
	}
do
	absent(controller, prohibited, "telegraph presentation must stay cosmetic: " .. prohibited)
end
absent(controller, 'FindFirstChildOfClass("Humanoid")', "telegraph presentation cannot inspect Humanoid state")
absent(controller, ".Health", "telegraph presentation cannot inspect health")

-- The server discloses every attribute the controller reads.
for _, attributeName in
	{
		"EnemySpitterBloomChargeSequence",
		"EnemySpitterBloomCommitServerTimestamp",
		"EnemySpitterBloomCenterX",
		"EnemyBossSlamSequence",
		"EnemyBossSlamCommitServerTimestamp",
		"EnemyBossPhaseId",
		"EnemyBossIsVulnerable",
	}
do
	present(presentation, attributeName)
end

-- Config carries both disc kinds and the boss status, and is bootstrapped.
present(config, "SpitterBloom")
present(config, "ProgenitorSlam")
present(config, "BossStatus")
present(bootstrap, "SpecialEncounterTelegraphController")
present(bootstrap, "SpecialEncounterTelegraphController.start()")

print(
	"SpecialEncounterTelegraphSourceAudit: bounded loops, no authority/health, disclosure-driven, and bootstrap passed"
)
