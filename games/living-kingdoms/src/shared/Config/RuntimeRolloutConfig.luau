--!strict

-- Blueprint v2.7 temporary architectural rollout flags. These are not product
-- feature toggles; each flag exists only to stage/rollback the active-place
-- network and presentation incident cutover.
local RuntimeRolloutConfig = {
	Version = "V2.7-R2-PREP",
	EnableRuntimeCounters = true,
	EnableEarlyStateListener = true,
	EnableReadyGatedStatePublisher = false,
	RejectBroadHighlightTargets = true,
}

return table.freeze(RuntimeRolloutConfig)
