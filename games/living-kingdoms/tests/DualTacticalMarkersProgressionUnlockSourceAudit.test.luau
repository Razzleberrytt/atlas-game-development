--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local root = "games/living-kingdoms/"
local progressionPath = root .. "src/shared/Config/OperativeProgressionConfig.luau"
local pingConfigPath = root .. "src/shared/Config/SquadPingConfig.luau"
local pingServicePath = root .. "src/server/Systems/SquadPingService.luau"
local controllerPath = root .. "src/client/Controllers/SquadPingController.luau"

local progressionSource = fs.readFile(progressionPath)
local pingConfigSource = fs.readFile(pingConfigPath)
local pingServiceSource = fs.readFile(pingServicePath)
local controllerSource = fs.readFile(controllerPath)
local progression = luau.load(progressionSource, { debugName = "OperativeProgressionConfig", injectGlobals = true })()
local pingConfig = luau.load(pingConfigSource, { debugName = "SquadPingConfig", injectGlobals = true })()

assertThat(
	progression.UnlockIds.DualTacticalMarkers == "squad-dual-tactical-markers",
	"dual tactical markers need a stable durable unlock ID"
)
local authoredUnlock = nil
for _, unlock in progression.Unlocks do
	if unlock.Id == progression.UnlockIds.DualTacticalMarkers then
		authoredUnlock = unlock
		break
	end
end
assertThat(authoredUnlock ~= nil, "dual tactical markers must be authored in durable progression")
assertThat(authoredUnlock.RequiredRank == 2, "dual tactical markers must be a Delver / Rank 2 unlock")
assertThat(pingConfig.MaximumActivePerSender == 1, "baseline personal marker capacity must remain one")
assertThat(pingConfig.DualTacticalMaximumActivePerSender == 2, "Delver personal marker capacity must be exactly two")
assertThat(
	pingConfig.DualTacticalMaximumActivePerSender <= pingConfig.MaximumActivePerSquad,
	"personal capacity must remain bounded by the squad hard cap"
)

for _, required in
	{
		"local function maximumActiveFor(player: Player): number",
		"OperativeProgressionConfig.UnlockIds.DualTacticalMarkers",
		"SquadPingConfig.DualTacticalMaximumActivePerSender",
		"local maximumActive = maximumActiveFor(player)",
		"local replacing = if #owned >= maximumActive then owned[1] else nil",
		"SquadPingConfig.MaximumActivePerSquad",
	}
do
	assertThat(contains(pingServiceSource, required), `dual-marker server route is missing {required}`)
end

assertThat(
	contains(pingServiceSource, "OperativeProgressionService.hasOwnedUnlock("),
	"server must derive marker capacity from the durable progression owner"
)
assertThat(
	contains(pingServiceSource, "if unlockId == nil then"),
	"missing progression metadata must fail neutral to baseline capacity"
)
assertThat(
	not contains(controllerSource, "DualTacticalMarkers"),
	"client presentation must not author or decide dual-marker eligibility"
)
assertThat(
	contains(controllerSource, "categoryId = SquadPingContracts.CategoryIds.Location"),
	"dual-marker access must reuse the existing narrow Location intent"
)

print("Patch 0.4 dual tactical markers: durable Delver access routes through bounded server ping capacity")
