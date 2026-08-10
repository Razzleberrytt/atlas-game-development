--!strict

-- Patch 0.4 ability side-grade proof. Self-Treatment is the first durable unlock
-- that reaches the class/ability layer: durable rank -> the owner-bound
-- progression adapter -> one bounded fact on the existing FieldTreatmentResolver
-- eligibility gate. It must change only *who* a Medic may treat, never the cost,
-- cadence, range, channel, or interruption rules, and it must not scatter rank
-- checks through ClassService callers.

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
local progressionConfigSource = fs.readFile(root .. "src/shared/Config/OperativeProgressionConfig.luau")
local classConfigSource = fs.readFile(root .. "src/shared/Config/ClassConfig.luau")
local resolverSource = fs.readFile(root .. "src/server/Systems/FieldTreatmentResolver.luau")
local classServiceSource = fs.readFile(root .. "src/server/Systems/ClassService.luau")

local progressionConfig = luau.load(progressionConfigSource, {
	debugName = "OperativeProgressionConfig",
	injectGlobals = true,
})()

assertThat(
	progressionConfig.UnlockIds.MedicSelfTreatment == "medic-self-treatment",
	"Self-Treatment must have a stable durable progression unlock ID"
)
local unlock = nil
for _, candidate in progressionConfig.Unlocks do
	if candidate.Id == progressionConfig.UnlockIds.MedicSelfTreatment then
		unlock = candidate
		break
	end
end
assertThat(unlock ~= nil, "Self-Treatment must be authored in the durable progression map")
assertThat(unlock.RequiredRank == 4, "Self-Treatment must unlock at durable Operative Rank 4")
assertThat(unlock.RequiredRank <= #progressionConfig.Ranks, "an unlock may not require an unreachable rank")

-- The unlock buys an option, not a number: the authored treatment tuning is
-- untouched, so no permanent combat-stat growth entered durable progression.
for _, unchanged in
	{
		"resourceCost = 1",
		"channelDurationSeconds = 3",
		"cooldownSeconds = 4",
		"healAmount = 25",
	}
do
	assertThat(
		contains(classConfigSource, unchanged),
		`Self-Treatment must not retune authored Field Treatment values: {unchanged}`
	)
end

assertThat(
	contains(resolverSource, "mayTreatSelf: boolean?"),
	"the entitlement must be one optional caller-supplied fact"
)
assertThat(
	contains(resolverSource, "facts.isSelfTarget and facts.mayTreatSelf ~= true"),
	"an absent or non-true entitlement must keep the original self-target prohibition"
)
assertThat(
	contains(resolverSource, '(value.mayTreatSelf == nil or type(value.mayTreatSelf) == "boolean")'),
	"the resolver must validate the entitlement rather than trust any truthy value"
)
for _, preserved in
	{
		"ReasonIds.InsufficientResource",
		"ReasonIds.TargetNotAlive",
		"ReasonIds.TargetNotInjured",
		"ReasonIds.OutOfRange",
		"ReasonIds.NoLineOfSight",
		"ReasonIds.DamageInterrupted",
		"ReasonIds.MovementInterrupted",
	}
do
	assertThat(contains(resolverSource, preserved), `Self-Treatment must preserve the treatment rule {preserved}`)
end

for _, required in
	{
		"local function mayTreatSelf(player: Player): boolean",
		"OperativeProgressionService.hasOwnedUnlock(",
		"OperativeProgressionConfig.UnlockIds.MedicSelfTreatment",
		"mayTreatSelf = mayTreatSelf(player),",
	}
do
	assertThat(
		contains(classServiceSource, required),
		`ClassService is missing server-owned Self-Treatment routing: {required}`
	)
end
assertThat(
	contains(classServiceSource, "userId,\n\t\t\tuserId,") or contains(classServiceSource, "userId, userId,"),
	"the class owner must ask only about the acting operative's own durable account"
)

-- One derivation point, not scattered rank checks.
local _, unlockCallCount = string.gsub(classServiceSource, "hasOwnedUnlock", "")
assertThat(unlockCallCount == 1, "durable unlock derivation must live in exactly one bounded adapter")

for _, forbidden in { "SetAsync", "UpdateAsync", "GetDataStore" } do
	assertThat(
		not contains(classServiceSource, forbidden),
		`the Self-Treatment route must not add persistence surface: {forbidden}`
	)
end
assertThat(
	not contains(classServiceSource, "intent.mayTreatSelf") and not contains(classServiceSource, "payload.mayTreatSelf"),
	"the entitlement must never be read from client intent"
)

print("Patch 0.4 Self-Treatment: rank-derived ability option routes through the existing class action owner")
