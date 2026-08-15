--!strict

-- Boots the server-authoritative character XP owner. No mutation RemoteEvent is
-- mounted here: gameplay systems require CharacterProgressionService directly.

local CharacterProgressionService = require(script.Parent.Systems.CharacterProgressionService)

CharacterProgressionService.start()

print("[Living Kingdoms] Character progression service mounted")
