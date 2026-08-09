--!strict

local fs = require("@lune/fs")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local server = fs.readFile("games/living-kingdoms/src/server/expedition-reward-results.server.luau")
local client = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionResultController.luau")
local resolver = fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionRewardDispositionResolver.luau")

assert(
	contains(server, "ExpeditionRewardDispositionResolver.shouldPersist(summary.OutcomeId)"),
	"terminal equipment persistence must be gated by authoritative outcome disposition"
)
assert(
	contains(server, "RewardDispositionId = ExpeditionRewardDispositionResolver.resolve(summary.OutcomeId)"),
	"the sanitized result must disclose the server-derived reward disposition"
)
assert(
	contains(server, "persistRewards(summary)"),
	"completed expedition rewards must retain the existing durable distribution path"
)
assert(
	contains(resolver, "ExpeditionContracts.OutcomeIds.Completed") and contains(resolver, "RewardDispositionIds.Banked"),
	"completed expeditions must bank claimed equipment"
)
assert(
	contains(resolver, "ExpeditionContracts.OutcomeIds.Failed")
		and contains(resolver, "ExpeditionContracts.OutcomeIds.Abandoned")
		and contains(resolver, "RewardDispositionIds.Forfeited"),
	"failed and abandoned expeditions must forfeit claimed equipment"
)
assert(
	contains(client, 'rewardDispositionId == "Forfeited"')
		and contains(client, '"EQUIPMENT FORFEITED"')
		and contains(client, "not added to your durable inventory"),
	"failed-run debrief must truthfully distinguish forfeited equipment from banked equipment"
)
assert(contains(client, '"EQUIPMENT SECURED"'), "successful runs must still disclose secured equipment")

for _, forbidden in
	{
		"DiscoveryMemoryService",
		"Achievement",
		"UnlockedStarting",
		"PrimaryCombatModeService",
	}
do
	assert(
		not contains(server, forbidden) and not contains(resolver, forbidden),
		"run reward forfeiture must not erase durable discovery/unlock state: " .. forbidden
	)
end

print("ExpeditionRewardBankingSourceAudit: completed banks; failed and abandoned forfeit without durable rollback")
