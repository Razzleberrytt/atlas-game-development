--!strict

-- Reconciles the live HROI-0105 run-progression pool with the RPG-0101 canonical
-- catalog and global safety ceilings (RunRpgConfig / RunRpgContracts). Every live
-- HROI upgrade must use a canonical RPG upgrade ID, be marked Implemented in the
-- catalog with a matching display name, and every HROI modifier ceiling must sit
-- within the shared RPG-0101 global ModifierCeilings. This keeps the two systems
-- from drifting: new live upgrades must join the catalog, and no live power may
-- exceed a declared global bound.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local progressionConfig = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau"),
	{ debugName = "RunProgressionConfig", injectGlobals = true }
)()

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local rpgConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected RunRpgConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

-- Index the RPG catalog and count implemented entries.
local catalogById = {}
local implementedCount = 0
for _, definition in rpgConfig.UpgradeCatalog do
	catalogById[definition.upgradeId] = definition
	if definition.implementationStateId == contracts.ImplementationStateIds.Implemented then
		implementedCount += 1
	end
end

-- Every live HROI upgrade must be a canonical, implemented catalog entry with a
-- matching display name.
local liveUpgradeCount = 0
for _, definition in progressionConfig.UpgradeDefinitions do
	liveUpgradeCount += 1
	assertThat(
		contracts.isKnownRunUpgradeId(definition.Id),
		"live run upgrade " .. definition.Id .. " must use a canonical RPG-0101 upgrade ID"
	)
	local catalogEntry = catalogById[definition.Id]
	assertThat(catalogEntry ~= nil, "live run upgrade " .. definition.Id .. " must appear in the RPG catalog")
	assertThat(
		catalogEntry.implementationStateId == contracts.ImplementationStateIds.Implemented,
		"live run upgrade " .. definition.Id .. " must be marked Implemented in the RPG catalog"
	)
	assertThat(
		catalogEntry.displayName == definition.Name,
		"live run upgrade " .. definition.Id .. " must share the canonical RPG display name"
	)
end

assertThat(
	liveUpgradeCount == implementedCount,
	"the count of live run upgrades must equal the RPG catalog's implemented count"
)
assertThat(liveUpgradeCount == 7, "reconciliation expects the seven-upgrade v4 pool")

-- Every live HROI modifier ceiling must sit within the shared RPG-0101 global
-- safety bounds.
local ceilings = rpgConfig.ModifierCeilings
assertThat(
	progressionConfig.MaximumDamageMultiplier <= ceilings.maximumDamageMultiplier,
	"live damage ceiling must not exceed the RPG-0101 global damage ceiling"
)
assertThat(
	progressionConfig.MinimumCadenceMultiplier >= ceilings.minimumCadenceMultiplier,
	"live cadence floor must not undercut the RPG-0101 global cadence floor"
)
assertThat(
	progressionConfig.MaximumAmmoConservationChance <= ceilings.maximumAmmunitionConservationChance,
	"live ammo conservation ceiling must not exceed the RPG-0101 global ceiling"
)
assertThat(
	progressionConfig.MaximumXpGainMultiplier <= ceilings.maximumFieldXpMultiplier,
	"live Field XP ceiling must not exceed the RPG-0101 global Field XP ceiling"
)
assertThat(
	progressionConfig.MinimumReloadDurationMultiplier >= ceilings.minimumReloadDurationMultiplier,
	"live reload-duration floor must not undercut the RPG-0101 global reload floor"
)

print("RunRpgReconciliation: live pool uses canonical implemented IDs and honors every shared global ceiling")
