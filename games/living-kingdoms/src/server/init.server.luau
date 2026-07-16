--!strict

local MovementValidationSystem = require(script.Systems.MovementValidationSystem)
local MovementStateReplicationSystem = require(script.Systems.MovementStateReplicationSystem)
local AutomaticCombatDevelopmentHarness = require(script.Systems.AutomaticCombatDevelopmentHarness)

MovementValidationSystem.start()
MovementStateReplicationSystem.start()
AutomaticCombatDevelopmentHarness.start()

print("[Living Kingdoms] Server bootstrap started")
