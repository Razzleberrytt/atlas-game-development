--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local deathSource = fs.readFile("games/living-kingdoms/src/shared/Config/HordeDeathPunctuationConfig.luau")
local deathConfig = luau.load(deathSource, {
	debugName = "HordeDeathPunctuationConfig",
	injectGlobals = true,
})()

local interrupt = deathConfig.get(deathConfig.KindIds.ScreamerInterrupted)
local ordinary = deathConfig.get(deathConfig.KindIds.Screamer)
assert(interrupt ~= nil, "Screamer interrupt punctuation is missing")
assert(ordinary ~= nil, "ordinary Screamer punctuation is missing")
assert(interrupt.Title == "SUMMON INTERRUPTED", "interrupt copy drifted")
assert(interrupt.ShakeMagnitude > ordinary.ShakeMagnitude, "interrupt must punctuate more strongly than an ordinary kill")
assert(interrupt.BloodDiameterStuds >= ordinary.BloodDiameterStuds, "interrupt pool cannot be weaker than ordinary Screamer death")
assert(interrupt.ShakeMagnitude <= deathConfig.MaximumShakeMagnitude, "interrupt shake exceeded the shared cap")
assert(interrupt.ShakeDurationSeconds <= 0.35, "interrupt shake duration exceeded the shared cap")
assert(interrupt.BillboardLifetimeSeconds <= 2, "interrupt billboard exceeded the shared cap")

print("ScreamerInterruptConfirmationConfig: dedicated copy and stronger bounded punctuation passed")
