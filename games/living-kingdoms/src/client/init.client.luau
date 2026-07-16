--!strict

local CameraController = require(script.Controllers.CameraController)
local SurvivorController = require(script.Controllers.SurvivorController)

CameraController.init()
CameraController.start()

SurvivorController.init()
SurvivorController.start()

print("[Living Kingdoms] Client bootstrap started")
