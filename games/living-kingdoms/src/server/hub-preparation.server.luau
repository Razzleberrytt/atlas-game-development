--!strict

-- Presentation-only forward operations shell. Keeping this bootstrap separate
-- makes the ownership boundary obvious: the canonical gameplay services remain
-- in init.server.luau and expedition-lobby.server.luau.

local HubPreparationService = require(script.Parent.Systems.HubPreparationService)

HubPreparationService.start()
