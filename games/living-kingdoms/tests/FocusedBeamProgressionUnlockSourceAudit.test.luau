--!strict

-- Patch 0.4 unlock breadth proof. Focused Beam is the first durable unlock whose
-- consequence is owned outside the squad-ping family: durable rank -> the
-- owner-bound progression adapter -> the existing PersonalFlashlightService light
-- descriptor. This audit locks that route and forbids a second persistence owner,
-- a client-claimed entitlement, or a parallel flashlight upgrade service.

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
local flashlightConfigSource = fs.readFile(root .. "src/shared/Config/PersonalFlashlightConfig.luau")
local contractsSource = fs.readFile(root .. "src/shared/Lighting/PersonalFlashlightContracts.luau")
local flashlightServiceSource = fs.readFile(root .. "src/server/Systems/PersonalFlashlightService.luau")
local controllerSource = fs.readFile(root .. "src/client/Controllers/PersonalFlashlightController.luau")

local progressionConfig = luau.load(progressionConfigSource, {
	debugName = "OperativeProgressionConfig",
	injectGlobals = true,
})()
local flashlightConfig = luau.load(flashlightConfigSource, {
	debugName = "PersonalFlashlightConfig",
	injectGlobals = true,
})()

assertThat(
	progressionConfig.UnlockIds.FocusedFlashlightBeam == "personal-focused-beam",
	"Focused Beam must have a stable durable progression unlock ID"
)
local focusedUnlock = nil
for _, unlock in progressionConfig.Unlocks do
	if unlock.Id == progressionConfig.UnlockIds.FocusedFlashlightBeam then
		focusedUnlock = unlock
		break
	end
end
assertThat(focusedUnlock ~= nil, "Focused Beam must be authored in the durable progression map")
assertThat(focusedUnlock.RequiredRank == 3, "Focused Beam must unlock at durable Operative Rank 3")
assertThat(
	focusedUnlock.RequiredRank <= #progressionConfig.Ranks,
	"an unlock may not require a rank the map cannot reach"
)

-- The unlock must be an authored data profile, never per-call arithmetic.
assertThat(
	flashlightConfig.FocusedRangeStuds > flashlightConfig.RangeStuds
		and flashlightConfig.FocusedConeAngleDegrees > flashlightConfig.ConeAngleDegrees,
	"the focused profile must be an authored improvement over the standard profile"
)
assertThat(
	flashlightConfig.FocusedPresentationRangeStuds > flashlightConfig.FocusedRangeStuds,
	"presentation must stay more generous than coverage so light never implies visibility"
)

assertThat(
	contains(contractsSource, "PersonalFlashlightContracts.CoverageProfileIds"),
	"the coverage profile must be a shared contract, not an ad-hoc string"
)
assertThat(
	contains(contractsSource, 'key ~= "coverageProfileId"')
		or contains(contractsSource, 'and key ~= "coverageProfileId"'),
	"the safe-state validator must whitelist the profile field explicitly"
)
assertThat(
	contains(contractsSource, "state.coverageProfileId or PersonalFlashlightContracts.CoverageProfileIds.Standard"),
	"an absent profile must fall back to the standard beam"
)

for _, required in
	{
		"OperativeProgressionService.hasOwnedUnlock(",
		"OperativeProgressionConfig.UnlockIds.FocusedFlashlightBeam",
		"local function resolveCoverage(player: Player): CoverageProfile",
		"coverage = resolveCoverage(player)",
		"rangeStuds = coverage.rangeStuds",
		"angleDegrees = coverage.coneAngleDegrees",
		"coverageProfileId = entry.coverage.coverageProfileId",
	}
do
	assertThat(
		contains(flashlightServiceSource, required),
		`PersonalFlashlightService is missing server-owned Focused Beam routing: {required}`
	)
end
assertThat(
	contains(flashlightServiceSource, "userId,\n\t\t\tuserId,") or contains(flashlightServiceSource, "userId, userId,"),
	"the flashlight owner must ask only about the operative's own durable account"
)
for _, forbidden in { "SetAsync", "UpdateAsync", "GetDataStore", "OnServerInvoke", "FireAllClients" } do
	assertThat(
		not contains(flashlightServiceSource, forbidden),
		`the Focused Beam route must not add persistence or broadcast surface: {forbidden}`
	)
end

-- The existing bounded flashlight invariants must survive the unlock.
for _, invariant in
	{
		"PersonalFlashlightConfig.ToggleCooldownSeconds",
		"RejectionReasonIds.NotAlive",
		"RejectionReasonIds.OwnershipMismatch",
		"BUDGET_EXCEEDED",
	}
do
	assertThat(
		contains(flashlightServiceSource, invariant),
		`Focused Beam must preserve the bounded flashlight invariant {invariant}`
	)
end

assertThat(
	contains(controllerSource, "PersonalFlashlightContracts.CoverageProfileIds.Focused"),
	"the client must render the disclosed profile"
)
assertThat(
	not contains(controllerSource, "hasOwnedUnlock") and not contains(controllerSource, "OperativeProgression"),
	"the client must never derive its own durable entitlement"
)
assertThat(
	not contains(controllerSource, "coverageProfileId = ")
		or contains(controllerSource, "coverageProfileId = profileId"),
	"the client may only adopt a server-disclosed profile"
)

for _, path in
	{
		root .. "src/server/Systems/FlashlightUpgradeService.luau",
		root .. "src/server/Systems/PersonalFlashlightProgressionService.luau",
	}
do
	assertThat(not fs.isFile(path), "Focused Beam must reuse PersonalFlashlightService, not a parallel owner")
end

print("Patch 0.4 Focused Beam: rank-derived personal coverage routes through the existing flashlight owner")
