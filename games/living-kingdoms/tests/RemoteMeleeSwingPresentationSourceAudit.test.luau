--!strict

local fs = require("@lune/fs")

local meleeContracts = fs.readFile("games/living-kingdoms/src/shared/Combat/MeleeContracts.luau")
local meleeService = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeCombatService.luau")
local intentService = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeIntentService.luau")
local presentationContracts = fs.readFile("games/living-kingdoms/src/shared/Combat/MeleePresentationContracts.luau")
local controller =
	fs.readFile("games/living-kingdoms/src/client/Controllers/RemoteMeleeSwingPresentationController.luau")
local mount = fs.readFile("games/living-kingdoms/src/client/remote-melee-swing.client.luau")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

assert(
	contains(meleeContracts, "swingAccepted: boolean"),
	"melee result must distinguish cadence-accepted swings from damage hits"
)
assert(
	contains(meleeService, "state.lastAcceptedSwingServerTimestamp = serverTimestamp"),
	"server swing cadence must remain the authoritative acceptance seam"
)
assert(
	contains(
		meleeService,
		"return rejected(selection.rejectionReasonId or Reasons.NoTarget, serverTimestamp, true, strikeId)"
	),
	"authoritative misses must still disclose that a cadence-valid swing occurred"
)
assert(
	contains(meleeService, "return rejected(Reasons.TargetOccluded, serverTimestamp, true, strikeId)"),
	"occluded cadence-valid swings must remain damage-rejected but presentation-eligible"
)
assert(contains(meleeService, "swingAccepted = true"), "successful damage results must also mark the swing accepted")

assert(
	contains(presentationContracts, 'SwingCommitted = "SwingCommitted"'),
	"remote swing presentation needs a stable server message kind"
)
assert(
	contains(presentationContracts, "function MeleePresentationContracts.validateSwingCommittedMessage"),
	"remote clients must validate server swing presentation"
)
assert(
	contains(intentService, "result.swingAccepted == true and result.strikeId ~= nil"),
	"server presentation broadcast must be gated by authoritative cadence acceptance"
)
assert(
	contains(intentService, "presentationRemote:FireAllClients"),
	"accepted swing occurrence must be available to co-op observers"
)
assert(
	contains(intentService, "attackerUserId = player.UserId"),
	"server must derive the remote attacker identity from the calling player"
)

assert(
	contains(controller, "MeleePresentationContracts.validateSwingCommittedMessage(message)"),
	"remote presentation must reject malformed swing messages"
)
assert(
	contains(controller, "player ~= Players.LocalPlayer"),
	"local predicted swing must not be double-animated by server broadcast"
)
assert(
	contains(controller, "player:GetAttribute(AttributeName) == ModeIds.Melee")
		and contains(controller, "player:GetAttribute(LIFE_STATE_ATTRIBUTE) == LifeStateIds.Alive"),
	"remote swing presentation must fail closed unless the observer sees an Alive melee operative"
)
assert(
	contains(controller, 'character:FindFirstChild("MeleeGrip", true)'),
	"remote animation must reuse the existing third-person hatchet grip"
)
assert(
	contains(controller, "grip.Transform = CFrame.Angles"),
	"remote swing should animate presentation through Motor6D.Transform"
)
assert(contains(controller, "grip.Transform = CFrame.identity"), "remote swing transform must return to neutral")
assert(not contains(controller, "FireServer"), "remote presentation cannot send combat intent")
assert(not contains(controller, "EnemyDirector"), "remote presentation cannot own targets or damage")
assert(not contains(controller, "commitHealthState"), "remote presentation cannot mutate health")
assert(contains(mount, "RemoteMeleeSwingPresentationController.start()"), "remote swing presentation must be mounted")

print("RemoteMeleeSwingPresentationSourceAudit: authoritative co-op swing readability remains presentation-only")
