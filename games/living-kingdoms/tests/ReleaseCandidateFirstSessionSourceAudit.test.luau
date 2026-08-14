--!strict

-- Release-candidate audit over the existing dormant BA-060 onboarding sequence.
-- It keeps onboarding as information architecture until the runtime/evidence
-- gate authorizes presentation activation.

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then error(message, 2) end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local source = fs.readFile("games/living-kingdoms/src/shared/Config/FirstSessionOnboardingConfig.luau")

for _, required in {
	"RuntimeConsumptionActive = false",
	"arrive-forward-operations",
	"choose-specialist",
	"choose-loadout",
	"open-expedition-terminal",
	"complete-first-descent",
	"make-run-reward-choice",
	"read-operation-result",
	"return-to-preparation",
	"deliberately-start-next-run",
} do
	assertThat(contains(source, required), "RC first-session path is missing: " .. required)
end

for _, forbidden in { "FireServer", "OnServerEvent", "TeleportService", "DataStoreService", "Instance.new" } do
	assertThat(not contains(source, forbidden), "dormant first-session config must not activate runtime authority: " .. forbidden)
end

assertThat(contains(source, "optionalCount == 1"), "first session must retain one optional discovery beat")
assertThat(contains(source, "StepKindIds.Replay"), "first session must end in deliberate replay intent")

print("RC 1.0 first-session path: complete information architecture exists and remains dormant pending runtime evidence")
