--!strict

--[[
	Patch 0.7 schema migration authoring contract.

	Migration used to be implicit: normalizeRecord rebuilt a record from whatever
	fields it recognised and stamped the current schema on the result. That works
	while every jump happens to be safe, but it records nothing about which jump
	was taken, cannot refuse an unauthored one, and gives an operator no way to
	tell a 1 -> 4 migration from a 3 -> 4 one after the fact.

	Steps are declared here, one per adjacent schema pair, and a migration is the
	ordered sequence between two versions. Sequencing matters: a record at 1 must
	pass through 2 and 3 to reach 4, so every future step can assume the shape the
	step before it produced rather than every historical shape at once.
]]

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

--[[
	The declared steps must form one unbroken chain from the oldest supported
	schema to the current one. A gap would let a record migrate into a version
	nothing knows how to produce, so it is caught here at load rather than
	discovered by a stranded player.
]]
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
	--[[
		A downgrade is never authored. A record written by a newer deploy holds
		state this build cannot describe, so rewriting it at an older schema
		would discard exactly the fields it could not see.
	]]
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
