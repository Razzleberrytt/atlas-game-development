--!strict

local fs = require("@lune/fs")

local mount = fs.readFile("games/living-kingdoms/src/server/melee-input.server.luau")
local intent = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeIntentService.luau")
local presentation = fs.readFile("games/living-kingdoms/src/client/Controllers/MeleePresentationController.luau")
local contract = fs.readFile("games/living-kingdoms/src/shared/Combat/MeleePresentationContracts.luau")

local function position(source: string, needle: string): number
	local found = string.find(source, needle, 1, true)
	assert(found ~= nil, "missing melee hit-confirmation source contract: " .. needle)
	return found :: number
end

assert(
	string.find(mount, 'for _, remoteName in { "StrikeIntent", "Presentation" }', 1, true) ~= nil,
	"melee runtime must create one separate server-to-client presentation transport"
)
assert(
	string.find(contract, 'HitConfirmed = "HitConfirmed"', 1, true) ~= nil,
	"confirmed melee hit presentation needs a stable message kind"
)
assert(
	string.find(contract, "function MeleePresentationContracts.validateHitConfirmedMessage", 1, true) ~= nil,
	"client must validate the safe presentation payload"
)

local authoritativeStrike = position(intent, "local result = MeleeCombatService.tryStrike(player, requestId, aimDirection)")
local acceptedGate = position(intent, "result.accepted ~= true")
local positiveDamageGate = position(intent, "result.damageAmount <= 0")
local firePresentation = position(intent, "presentationRemote:FireClient(player")
assert(authoritativeStrike < acceptedGate, "presentation can only inspect the authoritative strike result")
assert(acceptedGate < firePresentation, "rejected/missed swings cannot produce a hit confirmation")
assert(positiveDamageGate < firePresentation, "zero-damage results cannot produce a hit confirmation")
assert(
	string.find(intent, "targetEntityId = result.targetEntityId", 1, true) ~= nil,
	"presentation target must come from the server-committed strike result"
)
assert(
	string.find(intent, "damageAmount = result.damageAmount", 1, true) ~= nil,
	"presentation damage must come from the server-committed strike result"
)
assert(
	string.find(intent, "becameDead = result.becameDead", 1, true) ~= nil,
	"presentation kill state must come from the server-committed strike result"
)

assert(
	string.find(presentation, "MeleePresentationContracts.validateHitConfirmedMessage(message)", 1, true) ~= nil,
	"client must reject malformed hit presentation"
)
assert(
	string.find(presentation, "presentationRemote.OnClientEvent:Connect(onPresentation)", 1, true) ~= nil,
	"melee presentation must subscribe to the server-only result channel"
)
assert(
	string.find(presentation, "localHitConfirmedAtClock = os.clock()", 1, true) ~= nil,
	"confirmed hit feedback must be bounded locally"
)
assert(
	string.find(presentation, "blade.Material = Enum.Material.Neon", 1, true) ~= nil,
	"confirmed hit must have a visible blade pulse"
)
assert(
	string.find(presentation, "BLADE_KILL_COLOR", 1, true) ~= nil,
	"confirmed killing blows may be visually distinguished without changing gameplay"
)
assert(string.find(presentation, "FireServer", 1, true) == nil, "presentation cannot send combat authority back to server")
assert(string.find(presentation, "commitHealthState", 1, true) == nil, "presentation cannot mutate enemy health")
assert(string.find(presentation, "EnemyDirector", 1, true) == nil, "presentation cannot select or inspect authoritative targets")

print("MeleeHitConfirmationSourceAudit: server-committed hit feedback remains presentation-only")
