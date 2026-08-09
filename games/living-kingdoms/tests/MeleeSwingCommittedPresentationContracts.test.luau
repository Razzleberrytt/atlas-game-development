--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("games/living-kingdoms/src/shared/Combat/MeleePresentationContracts.luau")
local contracts = luau.load(source, {
	debugName = "MeleePresentationContractsSwingCommitted",
	injectGlobals = true,
})()

local valid = {
	kindId = contracts.MessageKindIds.SwingCommitted,
	attackerUserId = 42,
	strikeId = "melee:42:7",
	serverTimestamp = 123.5,
}
assert(contracts.validateSwingCommittedMessage(valid) == true)

local invalidUserId = table.clone(valid)
invalidUserId.attackerUserId = 0
assert(contracts.validateSwingCommittedMessage(invalidUserId) == false)

local fractionalUserId = table.clone(valid)
fractionalUserId.attackerUserId = 42.5
assert(contracts.validateSwingCommittedMessage(fractionalUserId) == false)

local emptyStrike = table.clone(valid)
emptyStrike.strikeId = ""
assert(contracts.validateSwingCommittedMessage(emptyStrike) == false)

local wrongKind = table.clone(valid)
wrongKind.kindId = contracts.MessageKindIds.HitConfirmed
assert(contracts.validateSwingCommittedMessage(wrongKind) == false)

print("MeleeSwingCommittedPresentationContracts: safe remote swing message validation passed")
