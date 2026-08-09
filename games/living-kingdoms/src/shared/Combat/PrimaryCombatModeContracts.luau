--!strict

-- Shared vocabulary for the one currently equipped primary combat mode. The
-- server owns the replicated player attribute; clients may only route input from
-- that disclosed fact and never choose their own mode.
local PrimaryCombatModeContracts = {}

export type PrimaryCombatModeId = "Firearm" | "Melee"

PrimaryCombatModeContracts.AttributeName = "LK_PrimaryCombatMode"
PrimaryCombatModeContracts.ModeIds = table.freeze({
	Firearm = "Firearm",
	Melee = "Melee",
})

function PrimaryCombatModeContracts.isModeId(value: unknown): boolean
	return value == PrimaryCombatModeContracts.ModeIds.Firearm or value == PrimaryCombatModeContracts.ModeIds.Melee
end

return table.freeze(PrimaryCombatModeContracts)
