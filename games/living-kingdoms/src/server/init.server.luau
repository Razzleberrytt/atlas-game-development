--!strict

local MovementValidationSystem = require(script.Systems.MovementValidationSystem)
local MovementStateReplicationSystem = require(script.Systems.MovementStateReplicationSystem)
local ReloadDevelopmentHarness = require(script.Systems.ReloadDevelopmentHarness)

MovementValidationSystem.start()
MovementStateReplicationSystem.start()
ReloadDevelopmentHarness.start()

print("[Living Kingdoms] Server bootstrap started")
