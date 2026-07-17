--!strict

local CameraController = require(script.Controllers.CameraController)
local SurvivorController = require(script.Controllers.SurvivorController)
local WeaponController = require(script.Controllers.WeaponController)
local WeaponPresentationController = require(script.Controllers.WeaponPresentationController)
local EnemyPresentationController = require(script.Controllers.EnemyPresentationController)
local AmmunitionCachePresentationController = require(script.Controllers.AmmunitionCachePresentationController)
local ClassSelectionController = require(script.Controllers.ClassSelectionController)
local ClassSilhouetteController = require(script.Controllers.ClassSilhouetteController)
local OperativeLifeController = require(script.Controllers.OperativeLifeController)
local PersonalFlashlightController = require(script.Controllers.PersonalFlashlightController)
local SquadPingController = require(script.Controllers.SquadPingController)
local EnvironmentAmbienceController = require(script.Controllers.EnvironmentAmbienceController)
local MissionController = require(script.Controllers.MissionController)

CameraController.init()
CameraController.start()

SurvivorController.init()
SurvivorController.start()

WeaponController.init()
WeaponController.start()
WeaponPresentationController.start()
EnemyPresentationController.start()
AmmunitionCachePresentationController.start()

OperativeLifeController.start()
PersonalFlashlightController.start()
SquadPingController.start()
EnvironmentAmbienceController.start()
MissionController.start()
-- Mission presentation starts first; class selection then requests authoritative state.
ClassSelectionController.start()
ClassSilhouetteController.start()

print("[Living Kingdoms] Client bootstrap started")
