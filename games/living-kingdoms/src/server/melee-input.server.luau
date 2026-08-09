--!strict

-- Application-scoped mount for the server-owned primary combat mode and the
-- narrow melee intent bridge. Enemy/life services remain the existing combat
-- authorities; this mount adds no second health, target, or progression owner.
local MeleeCombatService = require(script.Parent.Systems.MeleeCombatService)
local MeleeIntentService = require(script.Parent.Systems.MeleeIntentService)
local PrimaryCombatModeService = require(script.Parent.Systems.PrimaryCombatModeService)

PrimaryCombatModeService.start()
MeleeCombatService.start()
MeleeIntentService.start()

game:BindToClose(function()
	MeleeIntentService.stop()
	MeleeCombatService.stop()
	PrimaryCombatModeService.stop()
end)

print("[Living Kingdoms] Melee input runtime mounted")
