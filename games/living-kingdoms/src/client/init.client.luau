--!strict

local CameraController = require(script.Controllers.CameraController)
local SurvivorController = require(script.Controllers.SurvivorController)
local WeaponController = require(script.Controllers.WeaponController)
local OperativeLifeController = require(script.Controllers.OperativeLifeController)
local PersonalFlashlightController = require(script.Controllers.PersonalFlashlightController)
local SquadPingController = require(script.Controllers.SquadPingController)

CameraController.init()
CameraController.start()

SurvivorController.init()
SurvivorController.start()

WeaponController.init()
WeaponController.start()

OperativeLifeController.start()
PersonalFlashlightController.start()
SquadPingController.start()

print("[Living Kingdoms] Client bootstrap started")
