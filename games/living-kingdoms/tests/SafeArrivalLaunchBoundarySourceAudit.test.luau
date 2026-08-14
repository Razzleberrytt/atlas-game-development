--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "Safe-arrival launch boundary source audit failed", 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function occurrenceCount(source: string, token: string): number
	local count = 0
	local startIndex = 1
	while true do
		local found = string.find(source, token, startIndex, true)
		if found == nil then
			return count
		end
		count += 1
		startIndex = found + #token
	end
end

local missionService = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local hordeService = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local expeditionLobby = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

-- Both hostile-pressure owners expose exactly one arm switch and gate their
-- pressure-producing paths behind it, so a fresh server stays in safe arrival
-- until the player deliberately launches an expedition.
assert(occurrenceCount(missionService, "function Service.armPressure()") == 1, "mission director needs one arm switch")
assert(occurrenceCount(hordeService, "function Service.armPressure()") == 1, "horde experience needs one arm switch")
assert(
	contains(missionService, "if pressureArmed then\n\t\t\tarmInsertionCountdown(now())"),
	"PlayerAdded insertion arm must stay gated"
)
assert(
	contains(missionService, "if pressureArmed and #Players:GetPlayers() > 0 then"),
	"boot-time insertion arm must stay gated"
)

local evaluateStart = string.find(hordeService, "local function evaluate(serverTimestamp: number)", 1, true)
local pressureArmedGuard = string.find(hordeService, "if not pressureArmed then", 1, true)
assert(evaluateStart ~= nil and pressureArmedGuard ~= nil, "horde evaluate() must guard on pressureArmed")
assert((pressureArmedGuard :: number) > (evaluateStart :: number), "the guard must sit inside evaluate()")
assert(
	(pressureArmedGuard :: number) - (evaluateStart :: number) < 80,
	"the guard must be the first check in evaluate()"
)

-- init.server.luau still starts both owners unconditionally (unchanged
-- boot-order invariant other audits pin) but this file must never call
-- armPressure itself; only a deliberate launch may release pressure.
assert(contains(serverBootstrap, "MissionDirectorService.start()"), "bootstrap must still start the mission director")
assert(contains(serverBootstrap, "HordeExperienceService.start()"), "bootstrap must still start the horde runtime")
assert(not contains(serverBootstrap, "armPressure"), "server bootstrap must not itself arm hostile pressure")

-- The Forward Operations Hub's existing expedition lobby is the sole reused
-- deliberate-launch trigger; do not create another mission/lobby/enemy owner.
assert(
	contains(expeditionLobby, "require(Systems.MissionDirectorService)"),
	"lobby must reuse the existing mission director"
)
assert(
	contains(expeditionLobby, "require(Systems.HordeExperienceService)"),
	"lobby must reuse the existing horde runtime"
)
assert(
	occurrenceCount(expeditionLobby, "MissionDirectorService.armPressure()") == 1,
	"lobby launch must arm the mission director exactly once"
)
assert(
	occurrenceCount(expeditionLobby, "HordeExperienceService.armPressure()") == 1,
	"lobby launch must arm horde pressure exactly once"
)

local consumedLaunch = string.find(expeditionLobby, "local consumed = lobby:consumeLaunch()", 1, true)
local missionArm = string.find(expeditionLobby, "MissionDirectorService.armPressure()", 1, true)
local hordeArm = string.find(expeditionLobby, "HordeExperienceService.armPressure()", 1, true)
local startExpedition = string.find(expeditionLobby, "ExpeditionLiveRuntimeService.startExpedition(", 1, true)
assert(
	consumedLaunch ~= nil and missionArm ~= nil and hordeArm ~= nil and startExpedition ~= nil,
	"attemptLaunch must consume the lobby launch, start the expedition runtime, then arm both pressure owners"
)

--[[
	The guarantee here is the one stated above: only a deliberate launch may
	release pressure, never server boot. That is what the consumed-launch
	ordering protects and it is unchanged.

	The clause requiring arming *before* the runtime start has deliberately
	inverted. Arming first meant a rejected launch left both pressure owners
	running with no expedition to belong to, and neither exposes a disarm. Arming
	only once the run is live is strictly stronger, so the ordering now reflects
	that rather than the sequence it replaced.
]]
assert(
	(consumedLaunch :: number) < (missionArm :: number) and (missionArm :: number) < (hordeArm :: number),
	"pressure must only arm inside a server-validated consumed lobby launch"
)
assert(
	(startExpedition :: number) < (missionArm :: number),
	"pressure must arm only once the expedition runtime is live, so a rejected launch leaves nothing running"
)

print("SafeArrivalLaunchBoundarySourceAudit: mission/horde pressure gating and lobby launch wiring passed")
