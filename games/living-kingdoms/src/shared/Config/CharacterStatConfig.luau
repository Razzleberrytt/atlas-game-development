--!strict

-- Character stats are intentionally small in Wave 2. The goal is to give
-- leveling and equipment a shared deterministic vocabulary without creating a
-- skill tree or duplicating combat/item ownership.

local StatIds = table.freeze({
	MaxHealth = "MaxHealth",
	DamageMultiplier = "DamageMultiplier",
	MovementSpeed = "MovementSpeed",
	CooldownDurationMultiplier = "CooldownDurationMultiplier",
})

local OperationIds = table.freeze({
	Add = "Add",
	Multiply = "Multiply",
})

local SourceCategories = table.freeze({
	Progression = "Progression",
	Equipment = "Equipment",
	Temporary = "Temporary",
})

local AttributeIds = table.freeze({
	Vitality = "Vitality",
	Power = "Power",
	Agility = "Agility",
})

local Config = {
	Version = "CHARACTER-STATS-v1",
	StatIds = StatIds,
	OperationIds = OperationIds,
	SourceCategories = SourceCategories,
	AttributeIds = AttributeIds,

	Stats = table.freeze({
		[StatIds.MaxHealth] = table.freeze({
			BaseValue = 100,
			MinimumValue = 1,
			MaximumValue = 500,
		}),
		[StatIds.DamageMultiplier] = table.freeze({
			BaseValue = 1,
			MinimumValue = 0.1,
			MaximumValue = 5,
		}),
		[StatIds.MovementSpeed] = table.freeze({
			BaseValue = 16,
			MinimumValue = 8,
			MaximumValue = 32,
		}),
		[StatIds.CooldownDurationMultiplier] = table.freeze({
			BaseValue = 1,
			MinimumValue = 0.5,
			MaximumValue = 2,
		}),
	}),

	-- One point per level gives every level a tangible reward, while the earned
	-- point cap prevents permanent progression from dwarfing equipment/co-op
	-- tuning over a thousand-level character horizon.
	Rewards = table.freeze({
		AttributePointsPerLevel = 1,
		MaximumEarnedAttributePoints = 60,
		PerkPointInterval = 5,
		MaximumEarnedPerkPoints = 20,
		AutomaticMaxHealthPerLevel = 0.25,
		MaximumAutomaticMaxHealthBonus = 25,
	}),

	Attributes = table.freeze({
		[AttributeIds.Vitality] = table.freeze({
			MaximumAllocatedPoints = 30,
			ModifiersPerPoint = table.freeze({
				table.freeze({ StatId = StatIds.MaxHealth, Operation = OperationIds.Add, Value = 2 }),
			}),
		}),
		[AttributeIds.Power] = table.freeze({
			MaximumAllocatedPoints = 30,
			ModifiersPerPoint = table.freeze({
				table.freeze({ StatId = StatIds.DamageMultiplier, Operation = OperationIds.Add, Value = 0.01 }),
			}),
		}),
		[AttributeIds.Agility] = table.freeze({
			MaximumAllocatedPoints = 30,
			ModifiersPerPoint = table.freeze({
				table.freeze({ StatId = StatIds.MovementSpeed, Operation = OperationIds.Add, Value = 0.1 }),
				table.freeze({ StatId = StatIds.CooldownDurationMultiplier, Operation = OperationIds.Add, Value = -0.005 }),
			}),
		}),
	}),
}

assert(Config.Rewards.AttributePointsPerLevel > 0, "levels must award at least one build point")
assert(Config.Rewards.MaximumEarnedAttributePoints > 0, "attribute reward cap must be positive")
assert(Config.Rewards.PerkPointInterval > 0, "perk interval must be positive")
assert(Config.Rewards.AutomaticMaxHealthPerLevel >= 0, "automatic health scaling cannot be negative")

return table.freeze(Config)
