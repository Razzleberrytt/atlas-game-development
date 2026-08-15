--!strict

-- Compatibility facade during semantic controller migration.
-- New code should require Controllers.Input.CameraController.
return require(script.Parent.Input.CameraController)
