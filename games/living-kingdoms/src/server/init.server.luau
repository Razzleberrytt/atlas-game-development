--!strict

local MovementValidationSystem = require(script.Systems.MovementValidationSystem)
local MovementStateReplicationSystem = require(script.Systems.MovementStateReplicationSystem)
local AutomaticCombatDevelopmentHarness = require(script.Systems.AutomaticCombatDevelopmentHarness)
local OperativeLifeDevelopmentHarness = require(script.Systems.OperativeLifeDevelopmentHarness)
local OperativeLifeService = require(script.Systems.OperativeLifeService)
local OperativeLifeRuntimeService = require(script.Systems.OperativeLifeRuntimeService)
local OperativeReviveSessionService = require(script.Systems.OperativeReviveSessionService)
local SquadFailureService = require(script.Systems.SquadFailureService)

OperativeLifeService.start()
SquadFailureService.start()
OperativeLifeRuntimeService.start()
OperativeReviveSessionService.start()
OperativeLifeDevelopmentHarness.start()
MovementValidationSystem.start()
MovementStateReplicationSystem.start()
AutomaticCombatDevelopmentHarness.start()

print("[Living Kingdoms] Server bootstrap started")
