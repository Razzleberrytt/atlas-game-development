--!strict

-- Recovery loot is isolated from the primary server bootstrap so it can add
-- tactical healing and Field Intel without replacing the newer ammo-loot owner.
-- Deferring one scheduler turn lets the canonical bootstrap start combat, life,
-- and progression authority before the companion service begins collection.
local RecoveryLootService = require(script.Parent.Systems.RecoveryLootService)

task.defer(RecoveryLootService.start)
