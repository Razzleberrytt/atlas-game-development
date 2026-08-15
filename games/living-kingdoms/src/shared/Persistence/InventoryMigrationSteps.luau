--!strict

-- Explicit adjacent-version migration plan for the canonical player record.
local Contracts = require(script.Parent.PlayerInventoryContracts)

export type MigrationStep = {
	StepId: string,
	FromSchemaVersion: number,
	ToSchemaVersion: number,
	Summary: string,
}

export type MigrationPlan = {
	Accepted: boolean,
	ReasonId: string,
	FromSchemaVersion: number?,
	ToSchemaVersion: number?,
	StepIds: { string },
	Steps: { MigrationStep },
}

local InventoryMigrationSteps = {}

local STEPS: { MigrationStep } = table.freeze({
	table.freeze({
		StepId = "inventory-1-to-2-grant-index",
		FromSchemaVersion = 1,
		ToSchemaVersion = 2,
		Summary = "rebuild the applied-grant index from owned rewards",
	}),
	table.freeze({
		StepId = "inventory-2-to-3-dismantle-ledger",
		FromSchemaVersion = 2,
		ToSchemaVersion = 3,
		Summary = "introduce the dismantle transaction ledger",
	}),
	table.freeze({
		StepId = "inventory-3-to-4-grant-content-signatures",
		FromSchemaVersion = 3,
		ToSchemaVersion = 4,
		Summary = "introduce per-grant content identity",
	}),
	table.freeze({
		StepId = "inventory-4-to-5-character-progression",
		FromSchemaVersion = 4,
		ToSchemaVersion = 5,
		Summary = "introduce canonical long-horizon character XP in the player record",
	}),
})

InventoryMigrationSteps.Steps = STEPS

local function stepFrom(schemaVersion: number): MigrationStep?
	for _, step in STEPS do
		if step.FromSchemaVersion == schemaVersion then
			return step
		end
	end
	return nil
end

local function rejected(reasonId: string): MigrationPlan
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		FromSchemaVersion = nil,
		ToSchemaVersion = nil,
		StepIds = table.freeze({}),
		Steps = table.freeze({}),
	})
end

function InventoryMigrationSteps.validateChain(): (boolean, string)
	local expectedFrom = Contracts.SupportedSchemaVersions[1]
	for index, step in STEPS do
		if step.FromSchemaVersion ~= expectedFrom then
			return false, string.format("migration step %d does not continue the chain", index)
		end
		if step.ToSchemaVersion ~= step.FromSchemaVersion + 1 then
			return false, string.format("migration step %s is not a single-version step", step.StepId)
		end
		expectedFrom = step.ToSchemaVersion
	end
	if expectedFrom ~= Contracts.CurrentSchemaVersion then
		return false, "declared migration steps do not reach the current schema"
	end
	return true, "MigrationChainValid"
end

function InventoryMigrationSteps.plan(fromSchemaVersion: any, toSchemaVersion: any): MigrationPlan
	if not Contracts.isSupportedSchemaVersion(fromSchemaVersion) then
		return rejected("UnsupportedSourceSchema")
	end
	if not Contracts.isSupportedSchemaVersion(toSchemaVersion) then
		return rejected("UnsupportedTargetSchema")
	end
	if toSchemaVersion < fromSchemaVersion then
		return rejected("SchemaDowngradeNotAuthored")
	end

	local stepIds = {}
	local steps = {}
	local current = fromSchemaVersion
	while current < toSchemaVersion do
		local step = stepFrom(current)
		if step == nil then
			return rejected("MissingMigrationStep")
		end
		table.insert(stepIds, step.StepId)
		table.insert(steps, step)
		current = step.ToSchemaVersion
	end

	return table.freeze({
		Accepted = true,
		ReasonId = if #stepIds == 0 then "AlreadyCurrent" else "MigrationPlanned",
		FromSchemaVersion = fromSchemaVersion,
		ToSchemaVersion = toSchemaVersion,
		StepIds = table.freeze(stepIds),
		Steps = table.freeze(steps),
	})
end

return table.freeze(InventoryMigrationSteps)
