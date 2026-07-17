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
assertThat(
	resolve({ isMoving = true, strideIndex = 0 }).id == resolver.PoseIds.RoamingA,
	"roaming even stride must use RoamingA"
)
assertThat(
	resolve({ isMoving = true, strideIndex = 1 }).id == resolver.PoseIds.RoamingB,
	"roaming odd stride must use RoamingB"
)
assertThat(
	resolve({ isMoving = true, isPursuing = true, strideIndex = 0 }).id == resolver.PoseIds.PursuingA,
	"pursuit even stride must use PursuingA"
)
assertThat(
	resolve({ isMoving = true, isPursuing = true, strideIndex = 1 }).id == resolver.PoseIds.PursuingB,
	"pursuit odd stride must use PursuingB"
)
assertThat(
	resolve({ isPursuing = true }).id == resolver.PoseIds.ThreatReady,
	"stationary pursuing Walker must use the non-strike threat pose"
)

assertThat(
	resolve({ attackSequence = 1, secondsSinceAttack = 0 }).id == resolver.PoseIds.StrikeActiveLeft,
	"odd confirmed attack sequence must begin with the left active strike"
)
assertThat(
	resolve({ attackSequence = 2, secondsSinceAttack = 0.16 }).id == resolver.PoseIds.StrikeActiveRight,
	"even confirmed attack sequence must include the exact active boundary on the right"
)
assertThat(
	resolve({ attackSequence = 1, secondsSinceAttack = 0.161 }).id == resolver.PoseIds.StrikeRecoveryLeft,
	"confirmed attack must enter recovery immediately after the active boundary"
)
assertThat(
	resolve({ attackSequence = 2, secondsSinceAttack = 0.52 }).id == resolver.PoseIds.StrikeRecoveryRight,
	"confirmed attack recovery must include its exact upper boundary"
)
assertThat(
	resolve({ isPursuing = true, attackSequence = 2, secondsSinceAttack = 0.521 }).id == resolver.PoseIds.ThreatReady,
	"expired committed attack must return to the authoritative threat state"
)
assertThat(
	resolve({ attackSequence = 1, secondsSinceAttack = -0.01 }).id == resolver.PoseIds.Idle,
	"future or malformed attack timestamps must not fabricate a strike"
)

assertThat(
	resolve({ isStoodDown = true }).id == resolver.PoseIds.StandDown,
	"authoritative stand-down must visibly stand the Walker down"
)
assertThat(
	resolve({ secondsSinceHit = 0.28 }).id == resolver.PoseIds.HitReaction,
	"hit reaction must include the exact upper boundary"
)
assertThat(
	resolve({ secondsSinceHit = 0.281 }).id == resolver.PoseIds.Idle,
	"hit reaction must end after the exact upper boundary"
)
assertThat(
	resolve({ attackSequence = 1, secondsSinceAttack = 0.1, secondsSinceHit = 0.1 }).id == resolver.PoseIds.HitReaction,
	"confirmed hit reaction must take precedence over confirmed strike presentation"
)
assertThat(
	resolve({ isStoodDown = true, attackSequence = 1, secondsSinceAttack = 0.1 }).id == resolver.PoseIds.StandDown,
	"terminal stand-down must suppress stale attack presentation"
)
assertThat(resolve({
	isDead = true,
	isStoodDown = true,
	isMoving = true,
	isPursuing = true,
	attackSequence = 1,
	secondsSinceAttack = 0.1,
	secondsSinceHit = 0.1,
}).id == resolver.PoseIds.Dead, "death must have stable first precedence over every transient pose")

local poseMutationSucceeded = pcall(function()
	resolve({}).torsoPitchDegrees = 999
end)
assertThat(not poseMutationSucceeded, "resolved poses must be immutable")

print(
	"EnemyPresentationPoseResolver: confirmed strike/recovery, precedence, boundaries, stride, and immutability passed"
)
