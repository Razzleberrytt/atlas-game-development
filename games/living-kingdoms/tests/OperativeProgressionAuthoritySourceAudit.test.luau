--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeProgressionService.luau")
local networkSource = fs.readFile("games/living-kingdoms/src/server/operative-progression.server.luau")

assertThat(
	serviceSource:find("InventoryLiveService.getRecord(ownerId)", 1, true) ~= nil,
	"operative progression must read the existing durable inventory owner"
)
assertThat(
	serviceSource:find("record.AppliedRewardGrantIds", 1, true) ~= nil,
	"operative progression must derive from the canonical persisted reward-grant ledger"
)
assertThat(
	serviceSource:find("OperativeProgressionResolver.resolve", 1, true) ~= nil,
	"runtime adapter must delegate rank math to the shared pure resolver"
)
assertThat(
	serviceSource:find("CrossPlayerProgressionAccess", 1, true) ~= nil,
	"owner-only durable progression reads need an explicit cross-player guard"
)
assertThat(
	serviceSource:find("DataStoreService", 1, true) == nil,
	"operative progression must not create a second persistence owner"
)
assertThat(serviceSource:find(":applyReward", 1, true) == nil, "progression reads must not mutate durable rewards")
assertThat(serviceSource:find(":save", 1, true) == nil, "progression reads must not write persistence")
assertThat(serviceSource:find(":update", 1, true) == nil, "progression reads must not write persistence")

assertThat(
	networkSource:find('network.Name = "OperativeProgressionNetwork"', 1, true) ~= nil,
	"durable rank should use a distinct read-only disclosure surface"
)
assertThat(
	networkSource:find('Instance.new("RemoteFunction")', 1, true) ~= nil,
	"durable rank disclosure should be request/response"
)
assertThat(
	networkSource:find('Instance.new("RemoteEvent")', 1, true) == nil,
	"initial durable rank slice must expose no client mutation event"
)
assertThat(
	networkSource:find("readOwnedSnapshot(player.UserId, player.UserId)", 1, true) ~= nil,
	"network owner identity must come only from the invoking Player"
)
assertThat(
	networkSource:find("OnServerEvent", 1, true) == nil,
	"client must have no event path for authoring durable progression"
)
