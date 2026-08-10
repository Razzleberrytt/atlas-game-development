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
local progressionConfigPath = root .. "src/shared/Config/OperativeProgressionConfig.luau"
local progressionServicePath = root .. "src/server/Systems/OperativeProgressionService.luau"
local contractsPath = root .. "src/shared/Navigation/SquadPingContracts.luau"
local pingServicePath = root .. "src/server/Systems/SquadPingService.luau"
local controllerPath = root .. "src/client/Controllers/SquadPingController.luau"

local progressionConfigSource = fs.readFile(progressionConfigPath)
local progressionServiceSource = fs.readFile(progressionServicePath)
local contractsSource = fs.readFile(contractsPath)
local pingServiceSource = fs.readFile(pingServicePath)
local controllerSource = fs.readFile(controllerPath)
local progressionConfig = luau.load(progressionConfigSource, {
	debugName = "OperativeProgressionConfig",
	injectGlobals = true,
})()

assertThat(
	progressionConfig.UnlockIds.SquadRallyPing == "squad-rally-ping",
	"Rally ping must have a stable durable progression unlock ID"
)
local rallyUnlock = nil
for _, unlock in progressionConfig.Unlocks do
	if unlock.Id == progressionConfig.UnlockIds.SquadRallyPing then
		rallyUnlock = unlock
		break
	end
end
assertThat(rallyUnlock ~= nil, "Rally ping unlock must be authored in the durable progression map")
assertThat(rallyUnlock.RequiredRank == 2, "Rally ping must unlock at durable Operative Rank 2")

for _, required in {
	"function Service.hasOwnedUnlock(",
	"Service.readOwnedSnapshot(requesterId, ownerId)",
	"snapshot.Rank >= unlock.RequiredRank",
} do
	assertThat(contains(progressionServiceSource, required), `durable unlock derivation is missing {required}`)
end
for _, forbidden in { "SetAsync", "UpdateAsync", "DataStore", "UnlockedIds =", "Unlocked =" } do
	assertThat(
		not contains(progressionServiceSource, forbidden),
		`progression unlock adapter must not create persistence state: {forbidden}`
	)
end

assertThat(contains(contractsSource, 'Rally = "Rally"'), "shared ping contract must publish the Rally category")
assertThat(
	contains(contractsSource, "ServerPublishedLocationCategoryIds"),
	"safe snapshots must explicitly distinguish server-published categories from client intent"
)
assertThat(
	not contains(contractsSource, "ImplementedCategoryIds = table.freeze({\n\tLocation = \"Location\",\n\tRally"),
	"Rally must not become a client-implemented/requestable category"
)

for _, required in {
	"OperativeProgressionService.hasOwnedUnlock(",
	"OperativeProgressionConfig.UnlockIds.SquadRallyPing",
	"SquadPingContracts.CategoryIds.Rally",
	"local categoryId = publishedCategoryFor(player)",
} do
	assertThat(contains(pingServiceSource, required), `SquadPingService is missing server-owned Rally routing: {required}`)
end
for _, invariant in {
	"SquadPingConfig.CooldownSeconds",
	"SquadPingConfig.MaximumDistanceStuds",
	"SquadPingConfig.MaximumActivePerSender",
	"SquadPingConfig.MaximumActivePerSquad",
	"SquadPingConfig.LifetimeSeconds",
} do
	assertThat(contains(pingServiceSource, invariant), `Rally must preserve the bounded ping invariant {invariant}`)
end

assertThat(
	contains(controllerSource, "categoryId = SquadPingContracts.CategoryIds.Location"),
	"the client must continue to request only ordinary Location intent"
)
assertThat(contains(controllerSource, '"◆  RALLY\\nSQUAD PING"'), "Rally snapshots need distinct client presentation")
assertThat(contains(controllerSource, '"◇  LOCATION\\nSQUAD PING"'), "ordinary Location presentation must remain intact")
assertThat(
	contains(controllerSource, "Enum.KeyCode[SquadPingConfig.KeyboardKeyCodeName]"),
	"Rally must reuse the existing keyboard ping action"
)
assertThat(
	contains(controllerSource, "Enum.KeyCode[SquadPingConfig.GamepadKeyCodeName]"),
	"Rally must reuse the existing gamepad ping action"
)

print("Patch 0.4 Rally ping: rank-derived server identity reuses the existing bounded squad-ping owner")
