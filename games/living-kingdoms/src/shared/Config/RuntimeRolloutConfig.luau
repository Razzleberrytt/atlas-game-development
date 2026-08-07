--!strict

-- Blueprint v2.7 temporary architectural rollout flags. These are not product
-- feature toggles; each flag exists only to stage/rollback the active-place
-- network and presentation incident cutover.
local RuntimeRolloutConfig = {
	Version = "V2.7-R1-CONTAINMENT",
	EnableEarlyStateListener = true,
	RejectBroadHighlightTargets = true,
}

return table.freeze(RuntimeRolloutConfig)
