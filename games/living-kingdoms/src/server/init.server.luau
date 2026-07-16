--!strict

local MovementValidationSystem = require(script.Systems.MovementValidationSystem)
local MovementStateReplicationSystem = require(script.Systems.MovementStateReplicationSystem)

MovementValidationSystem.start()
MovementStateReplicationSystem.start()

print("[Living Kingdoms] Server bootstrap started")
