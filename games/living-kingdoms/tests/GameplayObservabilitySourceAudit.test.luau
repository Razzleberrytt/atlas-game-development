--!strict

local fs = require("@lune/fs")

local service = fs.readFile("games/living-kingdoms/src/server/Systems/GameplayObservabilityService.luau")
local bridge = fs.readFile("games/living-kingdoms/src/server/gameplay-observability.server.luau")

for _, required in
	{
		"AmmunitionScarcityTelemetryService.read()",
		"ClassService.readRoster()",
		"ClassService.readValidationTelemetry()",
		"EnemyDirectorService.readPressureState()",
		"EnemyDirectorService.readEnemyCombatFacts()",
		"ExpeditionRunStateService.readActiveRunIds()",
		"ExpeditionRunStateService.read(runId)",
		"ExpeditionRunStateService.readLastResult()",
	}
do
	assert(string.find(service, required, 1, true) ~= nil, "canonical gameplay snapshot must reuse " .. required)
end

for _, forbidden in
	{
		"AmmunitionScarcityTelemetryService.sample(",
		"resetSampling(",
		"resetValidationTelemetry(",
		"recordAction",
		"recordReward",
		"RemoteEvent",
		"RemoteFunction",
		"Heartbeat",
		"task.spawn",
		"task.delay",
	}
do
	assert(
		string.find(service, forbidden, 1, true) == nil,
		"gameplay observability service must remain read-only: " .. forbidden
	)
end

assert(
	string.find(bridge, "RunService:IsStudio()", 1, true) ~= nil,
	"gameplay observability bridge must be Studio-only"
)
assert(string.find(bridge, 'game:GetService("ServerStorage")', 1, true) ~= nil, "bridge must remain server-only")
assert(
	string.find(bridge, 'folder.Name = "LivingKingdomsGameplayObservability"', 1, true) ~= nil,
	"canonical Studio folder name"
)
assert(
	string.find(bridge, 'Instance.new("BindableFunction")', 1, true) ~= nil,
	"bridge must use a server-only bindable"
)
assert(string.find(bridge, 'readSnapshot.Name = "ReadSnapshot"', 1, true) ~= nil, "bridge must expose ReadSnapshot")
assert(
	string.find(bridge, "GameplayObservabilityService.readSnapshot", 1, true) ~= nil,
	"bridge must delegate to canonical gameplay snapshot"
)

for _, forbidden in { "RemoteEvent", "RemoteFunction", "Heartbeat", "task.spawn", "task.delay" } do
	assert(
		string.find(bridge, forbidden, 1, true) == nil,
		"Studio observability bridge must remain inert: " .. forbidden
	)
end

print("GameplayObservabilitySourceAudit: canonical gameplay metrics remain read-only and Studio-gated")
