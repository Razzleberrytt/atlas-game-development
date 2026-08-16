--!strict

-- A trigger release is state synchronization, not an aimed attack. A transient
-- missing CurrentCamera must never prevent the client from clearing the
-- authoritative semi/burst latch that AutomaticFireResolver owns server-side.
local fs = require("@lune/fs")

local client = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")

local fallback = assert(
	string.find(client, "local RELEASE_DIRECTION_FALLBACK = Vector3.new(0, 0, -1)", 1, true),
	"trigger release needs a deterministic valid transport direction when the camera is unavailable"
)
local sender = assert(string.find(client, "local function sendFireIntent(isFiring: boolean)", fallback, true))
local missingDirection = assert(string.find(client, "if direction == nil then", sender, true))
local pressFailsClosed = assert(
	string.find(client, "if isFiring then\n\t\t\treturn\n\t\tend", missingDirection, true),
	"an aimed fire press must still fail closed without a valid camera direction"
)
local releaseFallback = assert(
	string.find(client, "direction = RELEASE_DIRECTION_FALLBACK", pressFailsClosed, true),
	"release must survive a transient missing camera"
)
local send = assert(
	string.find(client, "fireIntentRemote:FireServer(isFiring, direction)", releaseFallback, true),
	"release fallback must reach the existing FireIntent transport"
)
assert(releaseFallback < send, "release fallback must be selected before FireIntent is sent")

-- Couple this transport guarantee to the server-side latch reset installed by
-- the preceding checkpoint. If that owner moves, this fixture should force the
-- integration to be reconsidered rather than silently preserving dead client logic.
local releaseBranch = assert(string.find(runtime, "if not playerState.isFiring then", 1, true))
local resolverReset = assert(
	string.find(runtime, "local releaseResolution = AutomaticFireResolver.resolve(", releaseBranch, true),
	"server trigger release must still reset firing-mode state through AutomaticFireResolver"
)
assert(
	string.find(runtime, "playerState.weaponState = releaseResolution.weaponStateAfter", resolverReset, true),
	"server trigger release must retain the resolver reset state"
)

print("CombatTriggerReleaseTransport: releases remain deliverable without camera aim while presses fail closed")
