--!strict

-- Patch 0.2 elite readability config fixture. Every affix the contracts declare
-- must resolve to a bounded, text-carrying treatment, and unknown input must
-- resolve to nothing rather than a default elite.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contractsToken = { "RunRpgContracts" }
local contracts = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"),
	{ debugName = "RunRpgContracts", injectGlobals = true }
)()

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EliteReadabilityConfig.luau"), {
	debugName = "EliteReadabilityConfig",
	injectGlobals = true,
	environment = {
		game = {
			GetService = function(_, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "config may only reach ReplicatedStorage")
				return { Shared = { RPG = { RunRpgContracts = contractsToken } } }
			end,
		},
		require = function(target: unknown)
			assertThat(target == contractsToken, "config required an unexpected dependency")
			return contracts
		end,
		Color3 = {
			fromRGB = function(r: number, g: number, b: number)
				assertThat(
					r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255,
					"accent colour components must be valid"
				)
				return table.freeze({ R = r, G = g, B = b })
			end,
		},
	},
})()

-- Every contract affix resolves, and carries meaning in text as well as colour.
local seenNames: { [string]: boolean } = {}
local affixCount = 0
for _, affixId in contracts.EliteAffixIds do
	affixCount += 1
	local treatment = config.get(affixId)
	assertThat(treatment ~= nil, "affix has no readable treatment: " .. affixId)
	assertThat(treatment.AffixId == affixId, "treatment must report its own affix id")
	assertThat(
		type(treatment.FallbackDisplayName) == "string" and treatment.FallbackDisplayName ~= "",
		"every affix needs a fallback display name so a disclosed elite is never unlabelled"
	)
	assertThat(
		type(treatment.ThreatNote) == "string" and treatment.ThreatNote ~= "",
		"every affix needs a text note so meaning does not depend on colour"
	)
	assertThat(treatment.AccentColor ~= nil, "every affix needs an accent colour")
	assertThat(not seenNames[treatment.FallbackDisplayName], "affix display names must be distinguishable")
	seenNames[treatment.FallbackDisplayName] = true
end
assertThat(affixCount == 5, `expected the five contract affixes, found {affixCount}`)

-- Unknown or malformed input must not resolve to some default elite.
assertThat(config.get("elite-affix.does-not-exist") == nil, "unknown affix must not resolve")
assertThat(config.get(nil) == nil, "nil affix must not resolve")
assertThat(config.get(42) == nil, "non-string affix must not resolve")
assertThat(config.get("") == nil, "empty affix must not resolve")

-- Bounds are real and small: this surface may not become a per-enemy allocation.
assertThat(config.MaximumNameplates > 0 and config.MaximumNameplates <= 12, "nameplate pool must stay small")
assertThat(
	config.PollIntervalSeconds >= 0.05 and config.PollIntervalSeconds <= 1,
	"poll interval must be bounded and non-trivial"
)
assertThat(
	config.MaximumVisibleDistanceStuds > 0 and config.MaximumVisibleDistanceStuds <= 400,
	"visible distance must be bounded"
)
assertThat(config.NameplateHeightStuds > 0, "nameplate must sit above the enemy")

assertThat(table.isfrozen(config), "config must be immutable")
assertThat(table.isfrozen(config.Treatments), "treatments must be immutable")

print("Patch 0.2 EliteReadabilityConfig: complete affix coverage, text-carrying treatments, and bounded pool passed")
