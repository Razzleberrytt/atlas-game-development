--!strict

-- BA-071: guard against resurrecting the preserved legacy RPG stack.
--
-- The 2026-08-07 Studio import preserved a complete second gameplay stack:
-- its own bootstrap, combat, enemy, inventory, loot, persistence and
-- monetization services. Every one of them duplicates a canonical authority,
-- and booting one beside its replacement is a named stop condition.
--
-- This audit is deliberately structural rather than behavioural. It proves the
-- preserved material stays unreachable from the active project and that the
-- canonical owners are still the ones wired in.

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, value: string): boolean
	return string.find(source, value, 1, true) ~= nil
end

-- Whole-identifier match, so `EnemyLootService` never trips the `LootService`
-- guard. Luau frontier patterns give the word boundary Lua otherwise lacks.
local function mentionsIdentifier(source: string, identifier: string): boolean
	return string.find(source, "%f[%w_]" .. identifier .. "%f[^%w_]") ~= nil
end

local function luauFilesUnder(root: string, collected: { string }): { string }
	for _, entry in fs.readDir(root) do
		local path = root .. "/" .. entry
		if fs.isDir(path) then
			luauFilesUnder(path, collected)
		elseif string.sub(entry, -5) == ".luau" then
			table.insert(collected, path)
		end
	end
	return collected
end

local GAME = "games/living-kingdoms"
local SOURCE_ROOT = GAME .. "/src"
local IMPORT_ROOT = GAME .. "/imports/studio-2026-08-07"

-- Every module classified CANONICAL_REPLACEMENT or DEAD_OR_STALE by BA-003,
-- plus the legacy dependencies that never existed in the place at all.
local FORBIDDEN_IN_SOURCE = {
	"RPGServerBootstrap",
	"RPGClientController",
	"CombatService",
	"EnemyService",
	"InventoryService",
	"LootService",
	"PlayerDataService",
	"MonetizationService",
	"HubTownService",
	"QuestService",
	"DungeonService",
	"SurvivalGatheringService",
	"RNGEngine",
	"RandomUtility",
	"NumberUtility",
	"AffixDefinitions",
	"ItemDefinitions",
	"LootTables",
	"EnemyDefinitions",
	"DungeonDefinitions",
	"PlayerDataTypes",
	"HubTownConfig",
	"HubTownContracts",
	"AbilityDefinitions",
}

-- The canonical owner that each forbidden legacy module was replaced by.
-- Both halves matter: the legacy path must stay absent AND the canonical
-- owner must stay present, so a swap cannot pass this audit.
local CANONICAL_OWNERS = {
	SOURCE_ROOT .. "/server/init.server.luau",
	SOURCE_ROOT .. "/client/init.client.luau",
	SOURCE_ROOT .. "/server/Systems/ExpeditionServerBootstrap.luau",
	SOURCE_ROOT .. "/server/Systems/DamageResolver.luau",
	SOURCE_ROOT .. "/server/Systems/OperativeCombatRuntimeService.luau",
	SOURCE_ROOT .. "/server/Systems/EnemyDirectorService.luau",
	SOURCE_ROOT .. "/server/Systems/InventoryLiveService.luau",
	SOURCE_ROOT .. "/server/Systems/InventorySessionLeaseService.luau",
	SOURCE_ROOT .. "/server/Systems/LootDropResolver.luau",
	SOURCE_ROOT .. "/server/Systems/EnemyLootService.luau",
	SOURCE_ROOT .. "/server/Systems/PlayerInventoryPersistenceService.luau",
	SOURCE_ROOT .. "/server/Systems/RobloxInventoryDataStoreAdapter.luau",
}

for _, owner in CANONICAL_OWNERS do
	assertThat(fs.isFile(owner), "canonical owner is missing, legacy resurrection guard is void: " .. owner)
end

-- 1. No active source file may name a preserved legacy module.
local sourceFiles = luauFilesUnder(SOURCE_ROOT, {})
assertThat(#sourceFiles > 0, "no Luau source files found; the audit would pass vacuously")

for _, path in sourceFiles do
	local source = fs.readFile(path)
	for _, identifier in FORBIDDEN_IN_SOURCE do
		assertThat(
			not mentionsIdentifier(source, identifier),
			"legacy module " .. identifier .. " is referenced by active source: " .. path
		)
	end
	assertThat(
		not contains(source, "imports/studio-"),
		"active source must not reach into the preserved import package: " .. path
	)
	assertThat(
		not contains(source, "legacy-src"),
		"active source must not reach into the preserved legacy sources: " .. path
	)
end

-- 2. The preserved material must stay outside the mapped source tree.
assertThat(fs.isDir(IMPORT_ROOT), "the preserved import package must remain in the repository")
assertThat(
	fs.isDir(IMPORT_ROOT .. "/recovered/legacy-src"),
	"the recovered legacy sources must remain preserved outside src"
)
assertThat(
	not fs.isDir(SOURCE_ROOT .. "/legacy-src"),
	"preserved legacy sources must never be copied into the mapped source tree"
)

-- 3. Rojo must not map anything except the three canonical roots. A single
-- extra $path pointing at imports/ would boot the whole legacy stack.
local project = fs.readFile(GAME .. "/default.project.json")
local mappedPaths: { string } = {}
for mapped in string.gmatch(project, '"%$path"%s*:%s*"([^"]+)"') do
	table.insert(mappedPaths, mapped)
end
table.sort(mappedPaths)

assertThat(#mappedPaths == 3, "expected exactly three Rojo $path mappings, found " .. #mappedPaths)
assertThat(mappedPaths[1] == "src/client", "first Rojo mapping must be src/client")
assertThat(mappedPaths[2] == "src/server", "second Rojo mapping must be src/server")
assertThat(mappedPaths[3] == "src/shared", "third Rojo mapping must be src/shared")

for _, mapped in mappedPaths do
	assertThat(not contains(mapped, "imports"), "Rojo must never map the preserved import package")
	assertThat(not contains(mapped, "recovered"), "Rojo must never map recovered legacy material")
	assertThat(not contains(mapped, "readable-reference"), "Rojo must never map the readable reference layer")
end

-- 4. The import's own do-not-boot record must stay intact, so the rule is
-- discoverable from the package itself and not only from this audit.
local importManifest = fs.readFile(IMPORT_ROOT .. "/manifest.json")
assertThat(
	contains(importManifest, "archive_only_do_not_boot"),
	"the import manifest must keep marking the legacy authority services do-not-boot"
)
assertThat(
	contains(
		importManifest,
		'"runtime_activation":"no legacy authoritative bootstrap/services activated by this import"'
	),
	"the import manifest must keep its no-legacy-activation merge policy"
)

-- 5. The BA-003 matrix must keep classifying the six replaced authorities, so
-- the disposition record and this guard cannot drift apart.
local matrix = fs.readFile("docs/migration/legacy-script-disposition-matrix.json")
local REPLACED_AUTHORITIES = {
	"ServerScriptService/RPGServerBootstrap.server.luau",
	"ServerScriptService/Services/CombatService.luau",
	"ServerScriptService/Services/EnemyService.luau",
	"ServerScriptService/Services/InventoryService.luau",
	"ServerScriptService/Services/LootService.luau",
	"ServerScriptService/Services/PlayerDataService.luau",
}
for _, path in REPLACED_AUTHORITIES do
	assertThat(contains(matrix, path), "BA-003 matrix must keep classifying the replaced authority: " .. path)
end

print(
	"LegacyServiceResurrectionSourceAudit: "
		.. #sourceFiles
		.. " source files clear of legacy bootstrap/combat/enemy/inventory/loot/persistence/monetization paths, "
		.. "Rojo mapping confined to the three canonical roots, do-not-boot record intact"
)
