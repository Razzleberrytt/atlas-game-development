--!strict

-- Stable replicated presentation-state IDs and prototype observation values.
return table.freeze({
	MovementStateAttribute = "SurvivorMovementState",
	FacingDirectionAttribute = "SurvivorFacingDirection",
	IdleState = "Idle",
	MovingState = "Moving",
	ObservationIntervalSeconds = 0.1,
	MinimumMovingSpeed = 1,
})
