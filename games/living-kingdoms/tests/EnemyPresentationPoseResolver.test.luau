--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/client/Presentation/EnemyPresentationPoseResolver.luau"),
	{
		debugName = "EnemyPresentationPoseResolver",
		injectGlobals = true,
	}
)()

local function resolve(overrides)
	local input = {
		isDead = false,
		isStoodDown = false,
		isMoving = false,
		isPursuing = false,
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
	"stationary pursuit-speed Walker must use the non-strike threat pose"
)
assertThat(
	resolve({ isStoodDown = true }).id == resolver.PoseIds.StandDown,
	"zero-speed living Walker must visibly stand down"
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
	resolve({ secondsSinceHit = -0.01 }).id == resolver.PoseIds.Idle,
	"future or malformed hit timestamps must not fabricate a reaction"
)
assertThat(
	resolve({ isStoodDown = true, secondsSinceHit = 0.1 }).id == resolver.PoseIds.HitReaction,
	"a committed hit must remain readable over stand-down posture"
)
assertThat(
	resolve({ isDead = true, isStoodDown = true, isMoving = true, isPursuing = true, secondsSinceHit = 0.1 }).id
		== resolver.PoseIds.Dead,
	"death must have stable first precedence over every transient pose"
)

local poseMutationSucceeded = pcall(function()
	resolve({}).torsoPitchDegrees = 999
end)
assertThat(not poseMutationSucceeded, "resolved poses must be immutable")

print("EnemyPresentationPoseResolver: precedence, boundaries, stride states, and immutability passed")
