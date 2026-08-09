--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/MeleePresentationController.luau")

local function contains(needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

assert(
	contains("OperativeLifeContracts.OperativeLifeStateIds"),
	"presentation must use canonical life-state vocabulary"
)
assert(
	contains('LIFE_STATE_ATTRIBUTE = "LK_P3_LifeState"'),
	"presentation must read the existing replicated life-state fact"
)
assert(contains("local lifeStateConnections"), "presentation must reconcile when life state changes")
assert(
	contains("player:GetAttribute(AttributeName) == ModeIds.Melee")
		and contains("player:GetAttribute(LIFE_STATE_ATTRIBUTE) == LifeStateIds.Alive"),
	"melee presentation must require both melee mode and Alive state"
)
assert(
	contains("player:GetAttributeChangedSignal(LIFE_STATE_ATTRIBUTE)"),
	"life-state changes must trigger presentation reconciliation"
)
assert(contains("lifeStateConnection:Disconnect()"), "life-state listeners must be cleaned up")
assert(
	contains("if not shouldPresentMelee(player) then"),
	"local/remote model creation must fail closed when not alive"
)
assert(
	contains("if player == nil or not shouldPresentMelee(player) then"),
	"render/presentation paths must fail closed when not alive"
)
assert(not contains("FireServer"), "presentation must not own combat networking")
assert(not contains("commitHealthState"), "presentation must not mutate health")
assert(not contains("SetAttribute(LIFE_STATE_ATTRIBUTE"), "presentation must not mutate life state")

print("MeleeLifeStatePresentationSourceAudit: down/dead hatchet presentation fails closed")
