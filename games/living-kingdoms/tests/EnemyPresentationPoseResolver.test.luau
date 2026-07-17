--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver =
	luau.load(fs.readFile("games/living-kingdoms/src/client/Presentation/EnemyPresentationPoseResolver.luau"), {
		debugName = "EnemyPresentationPoseResolver",
		injectGlobals = true,
	})()

local function resolve(overrides)
	local input = {
		isDead = false,
		isStoodDown = false,
		isMoving = false,
		isPursuing = false,
		isWindingUp = false,
		windupSequence = 0,
		windupProgress = nil,
		attackSequence = 0,
		secondsSinceAttack = nil,
		secondsSinceHit = nil,
		strideIndex = 0,
	}
	for key, value in overrides do
		input[key] = value
	end
	return resolver.resolve(input)
end

assertThat(resolve({}).id == resolver.PoseIds.Idle, "stationary living Walker must use Idle")
assertThat(resolve({ isMoving = true, strideIndex = 0 }).id == resolver.PoseIds.RoamingA, "roaming even stride")
assertThat(resolve({ isMoving = true, strideIndex = 1 }).id == resolver.PoseIds.RoamingB, "roaming odd stride")
assertThat(
	resolve({ isMoving = true, isPursuing = true, strideIndex = 0 }).id == resolver.PoseIds.PursuingA,
	"pursuit even stride"
)
assertThat(resolve({ isPursuing = true }).id == resolver.PoseIds.ThreatReady, "stationary pursuit threat pose")
assertThat(
	resolve({ isWindingUp = true, windupSequence = 1, windupProgress = 0 }).id == resolver.PoseIds.WindupEarlyLeft,
	"odd windup starts on the left"
)
assertThat(
	resolve({ isWindingUp = true, windupSequence = 1, windupProgress = 0.55 }).id == resolver.PoseIds.WindupLateLeft,
	"windup late boundary must be inclusive"
)
assertThat(
	resolve({ isWindingUp = true, windupSequence = 2, windupProgress = 1 }).id == resolver.PoseIds.WindupLateRight,
	"even windup ends on the right"
)
assertThat(
	resolve({ isWindingUp = true, windupSequence = 1, windupProgress = 1.01, isPursuing = true }).id
		== resolver.PoseIds.ThreatReady,
	"malformed progress must not fabricate anticipation"
)
assertThat(
	resolve({ attackSequence = 1, secondsSinceAttack = 0 }).id == resolver.PoseIds.StrikeActiveLeft,
	"confirmed odd attack uses matching left strike"
)
assertThat(
	resolve({ attackSequence = 2, secondsSinceAttack = 0.16 }).id == resolver.PoseIds.StrikeActiveRight,
	"active strike includes exact boundary"
)
assertThat(
	resolve({ attackSequence = 2, secondsSinceAttack = 0.161 }).id == resolver.PoseIds.StrikeRecoveryRight,
	"recovery begins after active boundary"
)
assertThat(resolve({ isStoodDown = true }).id == resolver.PoseIds.StandDown, "stand-down pose")
assertThat(resolve({ secondsSinceHit = 0.28 }).id == resolver.PoseIds.HitReaction, "hit exact upper boundary")
assertThat(
	resolve({ isWindingUp = true, windupSequence = 1, windupProgress = 0.8, secondsSinceHit = 0.1 }).id
		== resolver.PoseIds.HitReaction,
	"committed hit overrides windup"
)
assertThat(
	resolve({ isStoodDown = true, isWindingUp = true, windupSequence = 1, windupProgress = 0.8 }).id
		== resolver.PoseIds.StandDown,
	"stand-down suppresses stale windup"
)
assertThat(
	resolve({ isDead = true, isStoodDown = true, isWindingUp = true, windupProgress = 0.8, secondsSinceHit = 0.1 }).id
		== resolver.PoseIds.Dead,
	"death has first precedence"
)

local poseMutationSucceeded = pcall(function()
	resolve({}).torsoPitchDegrees = 999
end)
assertThat(not poseMutationSucceeded, "resolved poses must be immutable")

print("EnemyPresentationPoseResolver: windup, strike, precedence, boundaries, and immutability passed")
