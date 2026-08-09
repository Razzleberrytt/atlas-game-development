--!strict

local fs = require("@lune/fs")

local client = fs.readFile("games/living-kingdoms/src/client/Controllers/PrimaryAttackModeController.luau")
local server = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeCombatService.luau")

local function position(source: string, needle: string): number
	local found = string.find(source, needle, 1, true)
	assert(found ~= nil, "missing melee life-state input contract: " .. needle)
	return found :: number
end

assert(
	string.find(client, "OperativeLifeContracts.OperativeLifeStateIds", 1, true) ~= nil,
	"client prediction should use canonical shared life-state vocabulary"
)
assert(
	string.find(client, 'LIFE_STATE_ATTRIBUTE = "LK_P3_LifeState"', 1, true) ~= nil,
	"client prediction must read the existing replicated life-state fact"
)

local textFocusGuard = position(client, "UserInputService:GetFocusedTextBox() ~= nil")
local lifeGuard = position(client, "localPlayer:GetAttribute(LIFE_STATE_ATTRIBUTE) ~= LifeStateIds.Alive")
local aimRead = position(client, "local direction = currentAimDirection()")
local predictedSwing = position(client, "MeleePresentationController.playLocalSwing()")
local remoteIntent = position(client, "strikeIntent:FireServer")
assert(textFocusGuard < lifeGuard, "text-input suppression must remain first")
assert(lifeGuard < aimRead, "down/dead melee input must fail before camera/aim work")
assert(lifeGuard < predictedSwing, "down/dead operatives cannot receive false predicted swing feedback")
assert(lifeGuard < remoteIntent, "down/dead operatives should not send useless melee intent traffic")

assert(
	string.find(client, "server still independently owns and revalidates combat eligibility", 1, true) ~= nil,
	"client life-state suppression must remain explicitly non-authoritative"
)
assert(
	string.find(server, "OperativeLifeService.isCombatAllowed(player)", 1, true) ~= nil,
	"server melee combat must continue to independently own life eligibility"
)
assert(
	string.find(server, "return rejected(Reasons.CombatNotAllowed", 1, true) ~= nil,
	"server must still reject life-ineligible melee attempts"
)

print("MeleeLifeStateInputGuardSourceAudit: down/dead prediction fails closed while server remains authoritative")
