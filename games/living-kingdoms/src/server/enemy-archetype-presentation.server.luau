--!strict

local EnemyArchetypePresentationService = require(script.Parent.Systems.EnemyArchetypePresentationService)

EnemyArchetypePresentationService.start()

game:BindToClose(function()
	EnemyArchetypePresentationService.stop()
end)
