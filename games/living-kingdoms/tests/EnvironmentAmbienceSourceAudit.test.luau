--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "environment ambience source audit failed", 2)
	end
end

local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/EnvironmentAmbienceController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

check(string.find(controller, "HROI-ENV-001", 1, true) ~= nil, "missing bounded environment mood identity")
check(string.find(controller, 'WaitForChild("HordeNetwork")', 1, true) ~= nil, "mood must use disclosed horde state")
check(
	string.find(controller, 'WaitForChild("State")', 1, true) ~= nil,
	"mood must subscribe to the canonical state remote"
)
check(string.find(controller, "stateRemote.OnClientEvent:Connect(onHordeState)", 1, true) ~= nil)
check(
	string.find(controller, "snapshot.revision <= lastThreatRevision", 1, true) ~= nil,
	"stale snapshots must be ignored"
)
check(
	string.find(controller, "math.clamp(snapshot.threat / 100, 0, 1)", 1, true) ~= nil,
	"threat response must be bounded"
)
check(
	string.find(controller, "THREAT_RESPONSE_RATE = 2.4", 1, true) ~= nil,
	"threat changes must smooth rather than snap"
)

check(string.find(controller, 'Instance.new("ColorCorrectionEffect")', 1, true) ~= nil, "missing local mood grade")
check(string.find(controller, 'Instance.new("BloomEffect")', 1, true) ~= nil, "missing local mood bloom")
check(string.find(controller, 'MOOD_GRADE_NAME = "LivingKingdomsThreatMoodGrade"', 1, true) ~= nil)
check(string.find(controller, 'MOOD_BLOOM_NAME = "LivingKingdomsThreatMoodBloom"', 1, true) ~= nil)
check(string.find(controller, "readStormPulse", 1, true) ~= nil, "missing bounded distant-storm pulse")
check(string.find(controller, "STORM_PULSE_DURATION_SECONDS = 0.48", 1, true) ~= nil, "storm flash must remain brief")
check(string.find(controller, "MINIMUM_STORM_INTERVAL_SECONDS = 9", 1, true) ~= nil, "storm cadence must have a floor")
check(
	string.find(controller, "MAXIMUM_STORM_INTERVAL_SECONDS = 24", 1, true) ~= nil,
	"storm cadence must remain bounded"
)
check(string.find(controller, "UPDATE_INTERVAL_SECONDS = 0.1", 1, true) ~= nil, "ambience must retain the 10 Hz budget")

local _, connectionCount = string.gsub(controller, ":Connect%(", "")
check(connectionCount == 2, "ambience must use exactly one heartbeat and one disclosed-state connection")
check(string.find(controller, "FireServer", 1, true) == nil, "environment presentation must not send client requests")
check(string.find(controller, "InvokeServer", 1, true) == nil, "environment presentation must not invoke server state")
check(string.find(controller, "RemoteFunction", 1, true) == nil, "environment presentation requires no new query route")
check(string.find(controller, 'Instance.new("Part")', 1, true) == nil, "mood pass must add no broad geometry")
check(string.find(controller, "ParticleEmitter", 1, true) == nil, "mood pass must add no unbudgeted particles")
check(string.find(controller, "Raycast", 1, true) == nil, "mood must not infer visibility or hidden entities")
check(string.find(controller, "Humanoid", 1, true) == nil, "mood must not mutate operative state")
check(string.find(controller, "SetAttribute", 1, true) == nil, "mood must not establish replicated truth")
check(string.find(controller, "CanCollide", 1, true) == nil, "mood must not change collision")
check(string.find(controller, "task.", 1, true) == nil, "storm pulse must not create task loops")
check(string.find(controller, "while true", 1, true) == nil, "ambience must remain bounded")

check(string.find(controller, "restoreTaggedLights()", 1, true) ~= nil, "stop must restore authored light brightness")
check(string.find(controller, "moodGrade:Destroy()", 1, true) ~= nil, "stop must remove the local grade")
check(string.find(controller, "moodBloom:Destroy()", 1, true) ~= nil, "stop must remove the local bloom")
check(
	string.find(bootstrap, "EnvironmentAmbienceController.start()", 1, true) ~= nil,
	"ambience must remain bootstrapped once"
)

print("environment ambience source audit passed")
