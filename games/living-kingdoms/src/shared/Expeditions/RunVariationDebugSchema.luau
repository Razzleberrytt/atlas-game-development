--!strict

local Schema = {}

Schema.CompositionReadbackVersion = "P06-COMPOSITION-READBACK-v3"
Schema.ActiveCompositionVersion = "P06-ACTIVE-COMPOSITION-v2"
Schema.TerminalRunSummaryVersion = "P06-TERMINAL-RUN-SUMMARY-v1"
Schema.MaximumCompositionIdentityLength = 16_384
Schema.FailureReasonIds = table.freeze({
	DuplicateEncounterSlot = "DuplicateEncounterSlot",
	CardinalityMismatch = "CardinalityMismatch",
	IdentityTooLarge = "IdentityTooLarge",
})

function Schema.escapeIdentityValue(value: string): string
	return (
		string.gsub(value, "([^%w%._%-])", function(character: string): string
			return string.format("%%%02X", string.byte(character))
		end)
	)
end

function Schema.formatCompositionIdentity(
	seed: number,
	roomPlanIdentity: string,
	variationIdentity: string,
	originalUnitCount: number,
	appliedUnitCount: number,
	compositionIdentities: { string }
): string
	return string.format(
		"%s|seed=%d|roomPlan=%s|variation=%s|units=%d>%d|records=%s",
		Schema.CompositionReadbackVersion,
		seed,
		Schema.escapeIdentityValue(roomPlanIdentity),
		Schema.escapeIdentityValue(variationIdentity),
		originalUnitCount,
		appliedUnitCount,
		table.concat(compositionIdentities, ";")
	)
end

function Schema.formatActiveCompositionIdentity(runId: string, compositionIdentity: string): string
	return string.format(
		"%s|run=%s|composition=%s",
		Schema.ActiveCompositionVersion,
		Schema.escapeIdentityValue(runId),
		Schema.escapeIdentityValue(compositionIdentity)
	)
end

return table.freeze(Schema)
