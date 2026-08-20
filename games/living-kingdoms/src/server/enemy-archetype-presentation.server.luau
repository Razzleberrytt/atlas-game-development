--!strict

-- The authoritative enemy director creates EnemyEntities. Waiting for that
-- folder keeps presentation startup ordered without coupling either service's
-- ownership or adding a client-facing remote.

local Workspace = game:GetService("Workspace")

local EnemyArchetypePresentationService = require(script.Parent.Systems.EnemyArchetypePresentationService)

-- Bounded: presentation must not start against a world that never produced the
-- folder, and an unbounded wait would park this script forever instead of
-- reporting why the archetype rigs never appeared.
local ENEMY_FOLDER_WAIT_SECONDS = 20

if Workspace:WaitForChild("EnemyEntities", ENEMY_FOLDER_WAIT_SECONDS) == nil then
	warn("[Living Kingdoms] Enemy archetype presentation skipped: EnemyEntities was not ready")
	return
end
EnemyArchetypePresentationService.start()
