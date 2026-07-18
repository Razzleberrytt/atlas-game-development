--!strict

local fs = require("@lune/fs")

local function count(source: string, token: string): number
	local _, occurrences = string.gsub(source, token, "")
	return occurrences
end

local server = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeSpecialTelegraphController.luau")
local audio = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyAudioController.luau")
local audioConfig = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyAudioConfig.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/HordeSpecialTelegraphConfig.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assert(string.find(server, "HordeSpecialTelegraphConfig", 1, true) ~= nil)
assert(string.find(server, "beginSpecialTelegraph", 1, true) ~= nil)
assert(string.find(server, "commitPendingSpecial", 1, true) ~= nil)
assert(string.find(server, "pendingSpecialCommitServerTimestamp", 1, true) ~= nil)
assert(string.find(server, "KindIds.ScreamerReinforcement", 1, true) ~= nil)
assert(string.find(server, "KindIds.BloaterDeathBurst", 1, true) ~= nil)
assert(string.find(server, "KindIds.BruteSecondPhase", 1, true) ~= nil)
assert(string.find(server, "spawnReinforcements(record.root.Position", 1, true) ~= nil)
assert(string.find(server, "damagePlayersInBurst(record, role, serverTimestamp)", 1, true) ~= nil)
assert(string.find(server, "spawnRoleAt(HordeConfig.Roles.Brute.Id", 1, true) ~= nil)
assert(string.find(server, "task.delay", 1, true) == nil, "special consequences must ride the bounded evaluation pass")
assert(string.find(server, "OnServerEvent", 1, true) == nil, "horde specials cannot add client requests")

assert(string.find(controller, "MaximumActiveTelegraphs", 1, true) ~= nil)
assert(string.find(controller, "MaximumTrackedEnemyModels", 1, true) ~= nil)
assert(string.find(controller, "Workspace:GetServerTimeNow()", 1, true) ~= nil)
assert(string.find(controller, "StateIds.Windup", 1, true) ~= nil)
assert(string.find(controller, "definition.RadiusStuds * 2", 1, true) ~= nil)
assert(count(controller, "RenderStepped:Connect") == 1, "one frame loop must serve all telegraphs")
assert(count(controller, "ChildAdded:Connect") == 1)
assert(count(controller, "ChildRemoved:Connect") == 1)
assert(string.find(controller, "GetAttributeChangedSignal", 1, true) == nil, "no per-enemy attribute connections")
for _, prohibited in {
	"RemoteEvent",
	"FireServer",
	"InvokeServer",
	"OnClientEvent",
	"Raycast",
	"Humanoid",
	"applyAuthoritativeDamage",
	"spawnEnemy",
	"task.delay",
	"task.spawn",
} do
	assert(string.find(controller, prohibited, 1, true) == nil, "telegraph presentation must stay cosmetic: " .. prohibited)
end

assert(string.find(audio, "HordeSpecialTelegraphConfig", 1, true) ~= nil)
assert(string.find(audio, "lastSpecialSequence", 1, true) ~= nil)
assert(string.find(audio, "ScreamerWarning", 1, true) ~= nil)
assert(string.find(audio, "BloaterWarning", 1, true) ~= nil)
assert(string.find(audio, "BruteWarning", 1, true) ~= nil)
assert(count(audio, "RenderStepped:Connect") == 1, "special audio must reuse the existing hostile frame loop")
assert(count(audio, "Instance.new(\"Sound\")") == 1, "special audio must reuse the existing fixed sound pool")
for _, cueName in { "ScreamerWarning", "BloaterWarning", "BruteWarning" } do
	assert(string.find(audioConfig, cueName .. " = table.freeze", 1, true) ~= nil, "missing bounded warning cue: " .. cueName)
end

assert(string.find(bootstrap, "HordeSpecialTelegraphController", 1, true) ~= nil)
assert(string.find(bootstrap, "HordeSpecialTelegraphController.start()", 1, true) ~= nil)
assert(string.find(config, "the Bloater warning must disclose the exact authoritative damage radius", 1, true) ~= nil)
assert(string.find(config, "corpse specials must commit before authoritative cleanup", 1, true) ~= nil)

print("HordeSpecialTelegraphSourceAudit: authority, exact radius, fixed pools, shared loops, and bootstrap passed")
