--!strict

local fs = require("@lune/fs")

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local serverMount = fs.readFile("games/living-kingdoms/src/server/melee-runtime.server.luau")
local clientInput = fs.readFile("games/living-kingdoms/src/client/melee-input.client.luau")
local service = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeCombatService.luau")

assert(contains(serverMount, 'FindFirstChild("MeleeIntent")'), "server mount must reuse one named melee intent")
assert(contains(serverMount, 'meleeIntent.Name = "MeleeIntent"'), "server must create the dedicated intent when absent")
assert(contains(serverMount, "MeleeCombatService.start()"), "live mount must start the authoritative melee owner")
assert(
	contains(serverMount, "MeleeCombatService.tryStrike(player, requestId, aimDirection)"),
	"remote must forward only player/request/aim into the authoritative melee owner"
)
assert(not contains(serverMount, "EnemyDirectorService"), "network mount cannot own enemy target or health authority")
assert(not contains(serverMount, "DamagePerHit"), "network mount cannot apply melee damage")

assert(contains(clientInput, 'ACTION_NAME = "LK_MeleeStrike"'), "client needs one stable melee action")
assert(contains(clientInput, "Enum.KeyCode.V"), "keyboard melee binding must remain explicit")
assert(contains(clientInput, "Enum.KeyCode.ButtonX"), "gamepad melee binding must remain explicit")
assert(contains(clientInput, 'SetTitle(ACTION_NAME, "Strike")'), "touch input must remain readable")
assert(contains(clientInput, "camera.CFrame.LookVector"), "client may contribute only its current aim direction")
assert(contains(clientInput, "meleeIntent:FireServer(requestId, direction)"), "client should send only request id and aim")
assert(not contains(clientInput, "targetEntityId"), "client cannot nominate a melee target")
assert(not contains(clientInput, "DamagePerHit"), "client cannot apply melee damage")
assert(not contains(clientInput, "FireIntent"), "melee input cannot masquerade as firearm fire")
assert(not contains(clientInput, "ReloadIntent"), "melee input cannot inherit reload state")

assert(contains(service, "EnemyDirectorService.readEnemyCombatFacts()"), "server melee owner must still derive targets")
assert(contains(service, "Workspace:Raycast"), "server melee owner must still enforce occlusion")
assert(contains(service, "EnemyDirectorService.commitHealthState"), "server melee owner must still commit damage")

print("Melee input runtime: dedicated client intent and authoritative server boundary passed")
