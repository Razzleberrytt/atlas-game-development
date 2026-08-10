--!strict

-- Patch 0.4 bounded utility proof. Persistent Markers is the third durable
-- squad-ping variant, so it both extends one server-owned fact (expiry) and
-- collapses repeated entitlement plumbing into one fail-closed helper.

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
local progressionSource = fs.readFile(root .. "src/shared/Config/OperativeProgressionConfig.luau")
local pingConfigSource = fs.readFile(root .. "src/shared/Config/SquadPingConfig.luau")
local pingServiceSource = fs.readFile(root .. "src/server/Systems/SquadPingService.luau")
local controllerSource = fs.readFile(root .. "src/client/Controllers/SquadPingController.luau")

local progression = luau.load(progressionSource, {
	debugName = "OperativeProgressionConfig",
	injectGlobals = true,
})()
local pingConfig = luau.load(pingConfigSource, {
	debugName = "SquadPingConfig",
	injectGlobals = true,
})()

assertThat(
	progression.UnlockIds.PersistentMarkers == "squad-persistent-markers",
	"Persistent Markers must have a stable durable progression unlock ID"
)
local authoredUnlock = nil
for _, unlock in progression.Unlocks do
	if unlock.Id == progression.UnlockIds.PersistentMarkers then
		authoredUnlock = unlock
		break
	end
end
assertThat(authoredUnlock ~= nil, "Persistent Markers must be authored in durable progression")
assertThat(authoredUnlock.RequiredRank == 5, "Persistent Markers must be a Vanguard / Rank 5 unlock")
assertThat(
	pingConfig.PersistentMarkerLifetimeSeconds == 9,
	"Persistent Markers must use the bounded authored nine-second lifetime"
)
assertThat(pingConfig.LifetimeSeconds == 6, "the baseline marker lifetime must remain six seconds")
assertThat(
	pingConfig.PersistentMarkerLifetimeSeconds > pingConfig.LifetimeSeconds
		and pingConfig.PersistentMarkerLifetimeSeconds <= pingConfig.LifetimeSeconds * 1.5,
	"the durable marker lifetime must be useful but bounded to at most 1.5x baseline"
)

for _, required in
	{
		"local function hasDurableUnlock(player: Player, unlockId: string?): boolean",
		"OperativeProgressionService.hasOwnedUnlock(player.UserId, player.UserId, unlockId)",
		"local function lifetimeFor(player: Player): number",
		"OperativeProgressionConfig.UnlockIds.PersistentMarkers",
		"SquadPingConfig.PersistentMarkerLifetimeSeconds",
		"expiresAtServerTimestamp = now + lifetimeFor(player)",
	}
do
	assertThat(contains(pingServiceSource, required), `Persistent Markers server route is missing {required}`)
end

local _, entitlementCallCount = string.gsub(pingServiceSource, "hasOwnedUnlock", "")
assertThat(
	entitlementCallCount == 1,
	"the third squad-ping durable variant must consolidate entitlement plumbing into one helper"
)

-- The side-grade changes only expiry. Existing limits, range, cooldown, safe
-- client intent, and server-published identity remain owned by the same service.
for _, invariant in
	{
		"SquadPingConfig.CooldownSeconds",
		"SquadPingConfig.MaximumDistanceStuds",
		"SquadPingConfig.MaximumActivePerSender",
		"SquadPingConfig.MaximumActivePerSquad",
		"SquadPingContracts.validateClientIntent(intent)",
	}
do
	assertThat(contains(pingServiceSource, invariant), `Persistent Markers must preserve {invariant}`)
end

for _, forbidden in { "SetAsync", "UpdateAsync", "GetDataStore", "Instance.new(\"RemoteEvent\")" } do
	assertThat(not contains(pingServiceSource, forbidden), `Persistent Markers must not add authority surface: {forbidden}`)
end
assertThat(
	not contains(pingServiceSource, "payload.PersistentMarkers")
		and not contains(pingServiceSource, "intent.PersistentMarkers"),
	"the client must never claim Persistent Markers entitlement"
)
assertThat(
	not contains(controllerSource, "PersistentMarkers")
		and contains(controllerSource, "ping.expiresAtServerTimestamp"),
	"the client must consume server-owned expiry without deciding durable entitlement"
)

print("Patch 0.4 Persistent Markers: Vanguard utility reuses squad-ping expiry and consolidates entitlement routing")
