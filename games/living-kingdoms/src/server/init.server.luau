--!strict

local MovementValidationSystem = require(script.Systems.MovementValidationSystem)
local MovementStateReplicationSystem = require(script.Systems.MovementStateReplicationSystem)
local AutomaticCombatDevelopmentHarness = require(script.Systems.AutomaticCombatDevelopmentHarness)
local OperativeLifeDevelopmentHarness = require(script.Systems.OperativeLifeDevelopmentHarness)
local OperativeLifeService = require(script.Systems.OperativeLifeService)
local SquadFailureService = require(script.Systems.SquadFailureService)

OperativeLifeService.start()
SquadFailureService.start()
OperativeLifeDevelopmentHarness.start()
MovementValidationSystem.start()
MovementStateReplicationSystem.start()
AutomaticCombatDevelopmentHarness.start()

print("[Living Kingdoms] Server bootstrap started")
