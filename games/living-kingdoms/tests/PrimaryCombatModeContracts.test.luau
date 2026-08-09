--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("games/living-kingdoms/src/shared/Combat/PrimaryCombatModeContracts.luau")
local contracts = luau.load(source, {
	debugName = "PrimaryCombatModeContracts",
	injectGlobals = true,
})()

assert(contracts.AttributeName == "LK_PrimaryCombatMode")
assert(contracts.ModeIds.Firearm == "Firearm")
assert(contracts.ModeIds.Melee == "Melee")
assert(contracts.isModeId("Firearm") == true)
assert(contracts.isModeId("Melee") == true)
assert(contracts.isModeId("firearm") == false)
assert(contracts.isModeId(1) == false)
assert(table.isfrozen(contracts.ModeIds), "combat mode vocabulary must be immutable")
assert(table.isfrozen(contracts), "combat mode contract must be immutable")

print("PrimaryCombatModeContracts: server-owned Firearm/Melee vocabulary passed")
