--!strict

local fs = require("@lune/fs")

local attack = fs.readFile("games/living-kingdoms/src/client/Controllers/PrimaryAttackModeController.luau")
local presentation = fs.readFile("games/living-kingdoms/src/client/Controllers/MeleePresentationController.luau")
local server = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeCombatService.luau")

local function position(source: string, needle: string): number
	local found = string.find(source, needle, 1, true)
	assert(found ~= nil, "missing melee swing feedback source contract: " .. needle)
	return found :: number
end

local localClock = position(attack, "local nowClock = os.clock()")
local localCadence = position(attack, "nowClock - lastLocalSwingClock < MeleeCombatConfig.OpeningWeapon.CadenceSeconds")
local predictedSwing = position(attack, "MeleePresentationController.playLocalSwing()")
local remoteIntent = position(attack, "strikeIntent:FireServer")
assert(localClock < localCadence, "local prediction must read a monotonic client clock before its traffic guard")
assert(localCadence < predictedSwing, "local cadence guard must precede predicted swing presentation")
assert(predictedSwing < remoteIntent, "responsive swing presentation should begin before the network round trip")

assert(
	string.find(attack, "server-owned", 1, true) ~= nil,
	"client prediction must document that the server remains combat authority"
)
assert(
	string.find(server, "serverTimestamp - state.lastAcceptedSwingServerTimestamp < Weapon.CadenceSeconds", 1, true)
		~= nil,
	"server melee cadence must remain independently authoritative"
)

assert(
	string.find(presentation, "function Controller.playLocalSwing()", 1, true) ~= nil,
	"melee presentation must expose a presentation-only local swing entry point"
)
assert(
	string.find(presentation, "localSwingStartedAtClock = os.clock()", 1, true) ~= nil,
	"predicted swing must have a bounded local start time"
)
assert(
	string.find(presentation, "math.sin(math.clamp(progress, 0, 1) * math.pi)", 1, true) ~= nil,
	"swing arc must ease out and return instead of permanently offsetting the viewmodel"
)
assert(
	string.find(presentation, "local swing = localSwingAmount(os.clock())", 1, true) ~= nil,
	"render loop must consume the predicted swing phase"
)
assert(
	string.find(presentation, "SWING_DURATION_SECONDS", 1, true) ~= nil,
	"predicted swing duration must be bounded from configured melee cadence"
)
assert(string.find(presentation, "FireServer", 1, true) == nil, "presentation cannot own combat networking")
assert(string.find(presentation, "EnemyDirector", 1, true) == nil, "presentation cannot own target or damage authority")
assert(string.find(presentation, "commitHealthState", 1, true) == nil, "presentation cannot mutate enemy health")

print("MeleeSwingFeedbackSourceAudit: responsive predicted swing with independent server cadence passed")
