--!strict

-- Regression for rapid semi/burst release -> re-press edges. The pure firing
-- resolver owns trigger-latch semantics; the runtime must forward an accepted
-- release to that owner immediately rather than waiting for the next combat
-- evaluation tick.
local fs = require("@lune/fs")

local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local firingModes = fs.readFile("games/living-kingdoms/tests/WeaponFiringModes.test.luau")

local releaseBranch = assert(string.find(runtime, "if not playerState.isFiring then", 1, true))
local releaseReset = assert(
	string.find(runtime, "local releaseResolution = AutomaticFireResolver.resolve(", releaseBranch, true),
	"accepted trigger release must reset firing-mode state through AutomaticFireResolver"
)
local nilTarget = assert(
	string.find(runtime, "}, nil, playerState.weaponState, nowTimestamp)", releaseReset, true),
	"trigger release must use the resolver's nil-target reset path"
)
local stateCommit = assert(
	string.find(runtime, "playerState.weaponState = releaseResolution.weaponStateAfter", nilTarget, true),
	"trigger release must retain the resolver's reset weapon state"
)
local targetClear = assert(
	string.find(runtime, "discloseTarget(player, playerState, nil, nowTimestamp)", stateCommit, true),
	"trigger release must still clear disclosed targeting after resetting the latch"
)
assert(stateCommit < targetClear, "firing-mode latch must reset before release disclosure completes")

-- Keep this integration audit coupled to executable resolver coverage: the
-- dedicated fixture must still prove both semi-auto and burst re-arm through
-- exactly the nil-target release signal used above.
for _, token in
	{
		"local releasedSemi = resolver.resolve(operative(), nil, heldSemi.weaponStateAfter, 2.1)",
		'assert(semi.decision.shouldFire, "semi did not re-arm after release")',
		"local releasedBurst = resolver.resolve(operative(), nil, heldBurst.weaponStateAfter, 2.1)",
		'assert(burst.decision.shouldFire, "burst did not re-arm after release")',
	}
do
	assert(string.find(firingModes, token, 1, true), "firing-mode release regression coverage missing: " .. token)
end

print("CombatTriggerReleaseIntegration: runtime release edge is synchronized with semi/burst latch ownership")
