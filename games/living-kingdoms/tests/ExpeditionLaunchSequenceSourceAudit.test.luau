--!strict

--[[
	Launch-sequence safety.

	`launchInFlight` is a latch: it exists so two ready-state changes cannot start
	two expeditions. Every handled early return releases it, which is what made an
	*unhandled* path so damaging -- an error between the latch and the end would
	leave it set for the lifetime of the server, and a latched launchInFlight
	means this lobby can never launch again. A bricked server is a far worse
	outcome than a rejected launch.

	Ordering matters just as much. Mission and horde pressure were armed before
	the expedition started, so a rejected launch -- or a failed roster binding,
	which stops the expedition again -- left both running with no run to belong
	to, and neither owner exposes a way to put that back.
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

check(
	positionOf("launchInFlight = true") ~= nil,
	"the launch latch must exist; two ready changes must not launch twice"
)
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
check(
	positionOf("\tend)\n\n\tlaunchInFlight = false") ~= nil,
	"the latch release must sit after the wrapped sequence, unconditionally"
)

-- Pressure is armed only once the run is live and its roster is bound.

local launchCall = positionOf("ExpeditionLiveRuntimeService.startExpedition({")
local rosterBind = positionOf("ExpeditionRunRosterService.bind(")
local missionArm = positionOf("MissionDirectorService.armPressure()")
local hordeArm = positionOf("HordeExperienceService.armPressure()")
check(launchCall ~= nil and rosterBind ~= nil, "the lobby must still start the expedition and bind its roster")
check(missionArm ~= nil and hordeArm ~= nil, "the lobby must still arm pressure once a run is live")
check(
	(missionArm :: number) > (launchCall :: number) and (hordeArm :: number) > (launchCall :: number),
	"pressure must be armed after the launch, or a rejected launch leaves it running with no run"
)
check(
	(missionArm :: number) > (rosterBind :: number),
	"pressure must be armed after the roster binds, since a failed binding stops the expedition again"
)

--[[
	A rejected launch and a failed roster binding must each stop before arming
	rather than fall through, so both early returns are load-bearing.
]]
local rejectionGuard = positionOf("if launch.Accepted ~= true then")
local rosterGuard = positionOf("if roster == nil or roster.Accepted ~= true then")
check(rejectionGuard ~= nil and rosterGuard ~= nil, "a rejected launch and a failed roster binding must be detected")
check((rejectionGuard :: number) < (missionArm :: number), "the rejection guard must come before arming")
check((rosterGuard :: number) < (missionArm :: number), "the roster guard must come before arming")

--[[
	Only the lobby decides launchability. The client renders LaunchPending, which
	it needs in order to offer the button -- what it must never do is decide it.
]]
local clientController = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionLobbyController.luau")
check(
	string.find(clientController, "consumeLaunch", 1, true) == nil,
	"no client may consume a launch; the lobby is the only owner of that decision"
)

local consumeAt = positionOf("lobby:consumeLaunch()")
local decisionAt = positionOf("if snapshot == nil or not snapshot.LaunchPending then")
check(consumeAt ~= nil and decisionAt ~= nil, "the launch path must read the lobby decision before consuming it")
check(
	(decisionAt :: number) < (consumeAt :: number),
	"the lobby's launch decision must be read before it is consumed, not inferred afterwards"
)

print("ExpeditionLaunchSequenceSourceAudit: latch released on every path, pressure armed only once live")
