--!strict

-- The authoritative enemy director creates EnemyEntities. Waiting for that
-- folder keeps presentation startup ordered without coupling either service's
-- ownership or adding a client-facing remote.

local Workspace = game:GetService("Workspace")

local EnemyArchetypePresentationService = require(script.Parent.Systems.EnemyArchetypePresentationService)

Workspace:WaitForChild("EnemyEntities")
EnemyArchetypePresentationService.start()
