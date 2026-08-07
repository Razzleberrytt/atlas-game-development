--!strict

-- Canonical initial P3 operative health and life-state values. This shared
-- module validates declarations only; it owns no operative or transition state.
local OperativeLifeConfig = {
	MaximumHealth = 100,
	BleedOutDurationSeconds = 30,
	ReviveRangeStuds = 8,
	ReviveDurationSeconds = 4,
	ReviveHealth = 30,
	SoloRecoveryDurationSeconds = 8,
	SoloRecoveriesPerOperation = 1,
	SquadFailureGraceSeconds = 3,
}

local function isFinitePositive(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge and value > 0
end

assert(isFinitePositive(OperativeLifeConfig.MaximumHealth), "MaximumHealth must be finite and greater than zero")
assert(isFinitePositive(OperativeLifeConfig.ReviveHealth), "ReviveHealth must be finite and greater than zero")
assert(
	OperativeLifeConfig.ReviveHealth <= OperativeLifeConfig.MaximumHealth,
	"ReviveHealth must not exceed MaximumHealth"
)
assert(
	isFinitePositive(OperativeLifeConfig.BleedOutDurationSeconds),
	"BleedOutDurationSeconds must be finite and greater than zero"
)
assert(
	isFinitePositive(OperativeLifeConfig.ReviveDurationSeconds),
	"ReviveDurationSeconds must be finite and greater than zero"
)
assert(
	isFinitePositive(OperativeLifeConfig.SoloRecoveryDurationSeconds),
	"SoloRecoveryDurationSeconds must be finite and greater than zero"
)
assert(isFinitePositive(OperativeLifeConfig.ReviveRangeStuds), "ReviveRangeStuds must be finite and greater than zero")
assert(
	OperativeLifeConfig.SoloRecoveriesPerOperation == 1 and OperativeLifeConfig.SoloRecoveriesPerOperation % 1 == 0,
	"SoloRecoveriesPerOperation must be the integer one"
)
assert(
	isFinitePositive(OperativeLifeConfig.SquadFailureGraceSeconds),
	"SquadFailureGraceSeconds must be finite and greater than zero"
)

return table.freeze(OperativeLifeConfig)
