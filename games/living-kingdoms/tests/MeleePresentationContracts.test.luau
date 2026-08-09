--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("games/living-kingdoms/src/shared/Combat/MeleePresentationContracts.luau")
local contracts = luau.load(source, {
	debugName = "MeleePresentationContracts",
	injectGlobals = true,
})()

local valid = {
	kindId = contracts.MessageKindIds.HitConfirmed,
	strikeId = "melee:42:7",
	targetEntityId = "enemy:walker:1",
	damageAmount = 34,
	becameDead = false,
	serverTimestamp = 123.5,
}
assert(contracts.validateHitConfirmedMessage(valid) == true)
assert(contracts.validateHitConfirmedMessage({}) == false)
assert(contracts.validateHitConfirmedMessage("bad") == false)

local zeroDamage = table.clone(valid)
zeroDamage.damageAmount = 0
assert(contracts.validateHitConfirmedMessage(zeroDamage) == false)

local missingTarget = table.clone(valid)
missingTarget.targetEntityId = ""
assert(contracts.validateHitConfirmedMessage(missingTarget) == false)

local invalidKind = table.clone(valid)
invalidKind.kindId = "Miss"
assert(contracts.validateHitConfirmedMessage(invalidKind) == false)

assert(table.isfrozen(contracts.MessageKindIds), "melee presentation message IDs must be immutable")
assert(table.isfrozen(contracts), "melee presentation contract must be immutable")

print("MeleePresentationContracts: safe confirmed-hit message validation passed")
