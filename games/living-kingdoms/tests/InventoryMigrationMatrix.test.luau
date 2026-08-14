--!strict

--[[
	Patch 0.7 migration matrix.

	Migration used to be implicit: normalizeRecord rebuilt a record from the
	fields it recognised and stamped the current schema on the result. That
	records nothing about which jump was taken and cannot refuse an unauthored
	one, so this exercises the declared step chain directly and then drives every
	supported source schema through the real load path.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local EQUIPMENT_TOKEN = {}
local equipmentContracts = {
	SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" },
	RarityIds = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare" },
	SourceIds = { Elite = "Elite", Boss = "Boss" },
}

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventoryContracts.luau"), {
	debugName = "PlayerInventoryContracts",
	environment = {
		script = { Parent = { Parent = { Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN } } } },
		require = function(): any
			return equipmentContracts
		end,
	},
	injectGlobals = true,
})()

local migrationSteps =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryMigrationSteps.luau"), {
		debugName = "InventoryMigrationSteps",
		environment = {
			script = { Parent = { PlayerInventoryContracts = {} } },
			require = function(): any
				return contracts
			end,
		},
		injectGlobals = true,
	})()

local recovery =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryRecoveryContracts.luau"), {
		debugName = "InventoryRecoveryContracts",
		injectGlobals = true,
	})()

-- The declared chain -------------------------------------------------------

local chainValid, chainReason = migrationSteps.validateChain()
check(chainValid, "the declared migration chain must be unbroken: " .. tostring(chainReason))

--[[
	Every step must move exactly one version. A step that jumped two would let a
	future author assume a shape no step ever produced.
]]
for _, step in migrationSteps.Steps do
	check(step.ToSchemaVersion == step.FromSchemaVersion + 1, "step " .. step.StepId .. " must move one version")
	check(#step.StepId >= 8 and #step.Summary >= 8, "every step must carry a usable identity and summary")
end

for _, supported in contracts.SupportedSchemaVersions do
	local plan = migrationSteps.plan(supported, contracts.CurrentSchemaVersion)
	check(plan.Accepted, "every supported schema must have an authored path forward: " .. tostring(supported))
	check(
		#plan.StepIds == contracts.CurrentSchemaVersion - supported,
		"the plan must take exactly one step per version crossed: " .. tostring(supported)
	)
	local expectedFrom = supported
	for _, step in plan.Steps do
		check(step.FromSchemaVersion == expectedFrom, "planned steps must run in order from " .. tostring(supported))
		expectedFrom = step.ToSchemaVersion
	end
	check(expectedFrom == contracts.CurrentSchemaVersion, "a plan must land exactly on the current schema")
end

local current = migrationSteps.plan(contracts.CurrentSchemaVersion, contracts.CurrentSchemaVersion)
check(current.Accepted and #current.StepIds == 0, "a current record needs no steps")
check(current.ReasonId == "AlreadyCurrent", "a no-op migration must say so")

--[[
	A downgrade is never authored. A record written by a newer deploy holds state
	this build cannot describe, so rewriting it at an older schema would discard
	exactly the fields it could not see.
]]
local downgrade = migrationSteps.plan(contracts.CurrentSchemaVersion, contracts.SupportedSchemaVersions[1])
check(not downgrade.Accepted, "a downgrade must never be planned")
check(downgrade.ReasonId == "SchemaDowngradeNotAuthored", "a downgrade must be named")

check(not migrationSteps.plan(contracts.CurrentSchemaVersion + 1, contracts.CurrentSchemaVersion).Accepted, "future")
check(not migrationSteps.plan("4", contracts.CurrentSchemaVersion).Accepted, "a non-numeric source must be refused")

-- Corruption classification -------------------------------------------------

check(recovery.isRecoverable("LoadFailed"), "an exhausted read is transient")
check(not recovery.isRecoverable("InvalidSavedRecord"), "a malformed record is not transient")
check(not recovery.isRecoverable("EquippedItemMismatch"), "a drifted equip is not transient")
--[[
	An unclassified reason is treated as corrupt on purpose: a reason nobody
	classified is not evidence that retrying is safe.
]]
check(not recovery.isRecoverable("SomeReasonNobodyClassified"), "an unknown reason must not be assumed retryable")
check(not recovery.isClassified("SomeReasonNobodyClassified"), "an unknown reason must be reported as unclassified")

for _, reasonId in { "InvalidSavedRecord", "UnsupportedSchemaVersion", "PlayerIdMismatch", "InvalidDismantleLedger" } do
	check(recovery.isClassified(reasonId), "every load failure reason must be classified: " .. reasonId)
end

local envelope = recovery.quarantineEnvelope("player:1:inventory", "InvalidSavedRecord", 1000, { Marker = "damaged" })
check(envelope.SourceKey == "player:1:inventory", "the envelope names its source")
check(envelope.Classification == "Corrupt", "the envelope classifies the failure")
check(envelope.Payload.Marker == "damaged", "the envelope preserves the damaged payload verbatim")
check(
	recovery.quarantineKeyFor("player:1:inventory", 1000) ~= "player:1:inventory",
	"a quarantine key must never collide with the source key it preserves"
)

print("InventoryMigrationMatrix: declared chain, every supported source schema, and corruption classification")
