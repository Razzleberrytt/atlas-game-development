--!strict

--[[
	Patch 0.8 launch-sequence safety.

	`launchInFlight` is a latch: it exists so two ready-state changes cannot
	start two expeditions. Every handled early return releases it, which is what
	makes an *unhandled* path so damaging -- an error between the latch and the
	end would leave it set for the lifetime of the server, and a latched
	launchInFlight means this lobby can never launch again. A bricked server is a
	far worse outcome than a rejected launch.

	Ordering matters just as much. Mission and horde pressure were armed before
	the expedition started, so a rejected launch left both running with no run to
	belong to -- and neither owner exposes a way to put that back.
]]

local fs = require("@lune/fs")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local source = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")

local function positionOf(needle: string): number?
	return string.find(source, needle, 1, true)
end

-- The latch must be released on every path, including an unhandled error.

local latchSet = positionOf("launchInFlight = true")
check(latchSet ~= nil, "the launch latch must still exist; two ready changes must not start two expeditions")
check(positionOf("pcall(function()") ~= nil, "the launch sequence must be wrapped so the latch cannot survive an error")

local releaseCount = 0
for _ in string.gmatch(source, "launchInFlight = false") do
	releaseCount += 1
end
check(releaseCount >= 3, "every launch exit must release the latch, found " .. tostring(releaseCount))

--[[
	The unconditional release has to sit after the wrapped sequence, not inside
	it, or an error would skip the very release the wrapper exists to guarantee.
]]
local wrapperEnd = positionOf("\tend)\n\n\tlaunchInFlight = false")
check(wrapperEnd ~= nil, "the latch release must sit after the wrapped sequence, unconditionally")

-- Pressure is armed only once the run is live.

local launchCall = positionOf("ExpeditionLiveRuntimeService.startExpedition({")
local missionArm = positionOf("MissionDirectorService.armPressure()")
local hordeArm = positionOf("HordeExperienceService.armPressure()")
check(launchCall ~= nil, "the lobby must still start the expedition")
check(missionArm ~= nil and hordeArm ~= nil, "the lobby must still arm pressure once a run is live")
check(
	(missionArm :: number) > (launchCall :: number),
	"mission pressure must be armed after the launch, or a rejected launch leaves it running with no run"
)
check(
	(hordeArm :: number) > (launchCall :: number),
	"horde pressure must be armed after the launch, or a rejected launch leaves it running with no run"
)

--[[
	A rejected launch must stop before arming rather than fall through, so the
	early return between the launch check and the arming is load-bearing.
]]
local rejectionGuard = positionOf("if launch.Accepted ~= true then")
check(rejectionGuard ~= nil, "a rejected launch must be detected")
check((rejectionGuard :: number) < (missionArm :: number), "the rejection guard must come before arming, not after it")

--[[
	#10: only the lobby decides launchability.

	The client renders LaunchPending, which is right -- it needs to know whether
	to offer the button. What it must never do is decide it: a client that could
	consume a launch would start runs the party never agreed to.
]]
local clientController = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionLobbyController.luau")
check(
	string.find(clientController, "consumeLaunch", 1, true) == nil,
	"no client may consume a launch; the lobby is the only owner of that decision"
)
check(
	string.find(clientController, "LaunchPending", 1, true) ~= nil,
	"the client may still read launch state to render it"
)

--[[
	The server script may consume, but only after reading the lobby's own
	decision -- never by deciding for itself that a party is ready.
]]
local consumeAt = positionOf("lobby:consumeLaunch()")
local decisionAt = positionOf("if snapshot == nil or not snapshot.LaunchPending then")
check(consumeAt ~= nil and decisionAt ~= nil, "the launch path must read the lobby decision before consuming it")
check(
	(decisionAt :: number) < (consumeAt :: number),
	"the lobby's launch decision must be read before it is consumed, not inferred afterwards"
)
--[[
	The server script may forward the lobby's readiness verdict into the
	sanitized snapshot it broadcasts. What it must not do is derive one: every
	AllReady it mentions has to come straight off the lobby snapshot.
]]
local forwardedReadiness = 0
for _ in string.gmatch(source, "AllReady = snapshot%.AllReady") do
	forwardedReadiness += 1
end
local mentionedReadiness = 0
for _ in string.gmatch(source, "AllReady") do
	mentionedReadiness += 1
end
check(
	mentionedReadiness == forwardedReadiness * 2,
	"the server script may only forward the lobby's readiness verdict, never derive one"
)

print("ExpeditionLaunchSequenceSourceAudit: latch, arming order, and single launch authority")
