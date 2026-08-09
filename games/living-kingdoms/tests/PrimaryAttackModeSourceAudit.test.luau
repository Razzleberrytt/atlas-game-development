--!strict

local fs = require("@lune/fs")

local function read(path: string): string
	return fs.readFile(path)
end

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local contracts = read("games/living-kingdoms/src/shared/Combat/PrimaryCombatModeContracts.luau")
local modeService = read("games/living-kingdoms/src/server/Systems/PrimaryCombatModeService.luau")
local intentService = read("games/living-kingdoms/src/server/Systems/MeleeIntentService.luau")
local meleeService = read("games/living-kingdoms/src/server/Systems/MeleeCombatService.luau")
local router = read("games/living-kingdoms/src/client/Controllers/PrimaryAttackModeController.luau")
local weapon = read("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local clientBootstrap = read("games/living-kingdoms/src/client/init.client.luau")
local serverMount = read("games/living-kingdoms/src/server/melee-input.server.luau")
local project = read("games/living-kingdoms/default.project.json")

assert(
	contains(contracts, 'AttributeName = "LK_PrimaryCombatMode"'),
	"primary combat mode needs one stable replicated fact"
)
assert(
	contains(modeService, "Players.PlayerAdded:Connect(ensurePlayer)"),
	"server must initialize combat mode for joins"
)
assert(contains(modeService, "ModeIds.Firearm"), "current default must remain firearm until opening migration")
assert(
	contains(modeService, "function Service.setMode"),
	"trusted server systems need the later melee/firearm handoff seam"
)
assert(not contains(modeService, "RemoteEvent"), "clients cannot choose their primary combat mode")

assert(
	not contains(project, '"MeleeNetwork"'),
	"later melee transport must not inflate the frozen committed Rojo remote surface"
)
assert(
	contains(serverMount, 'ReplicatedStorage:FindFirstChild("MeleeNetwork")'),
	"server mount must own runtime melee network creation"
)
assert(
	contains(serverMount, 'Instance.new("RemoteEvent")'),
	"server mount must create the narrow melee strike transport"
)
assert(contains(serverMount, 'intent.Name = "StrikeIntent"'), "runtime melee transport must expose only StrikeIntent")
assert(
	contains(intentService, "PrimaryCombatModeService.readMode(player) ~= ModeIds.Melee"),
	"server must reject melee intent outside melee mode"
)
assert(
	contains(intentService, "MeleeCombatService.tryStrike(player, requestId, aimDirection)"),
	"accepted melee intent must reuse authoritative melee combat"
)
assert(contains(intentService, 'typeof(aimDirection) ~= "Vector3"'), "server must validate the melee aim payload")
assert(contains(serverMount, "PrimaryCombatModeService.start()"), "server combat-mode owner must be mounted")
assert(contains(serverMount, "MeleeCombatService.start()"), "authoritative melee service must be mounted")
assert(contains(serverMount, "MeleeIntentService.start()"), "melee intent bridge must be mounted")

assert(contains(router, 'FIRE_ACTION_NAME = "LK_Fire"'), "melee must reuse the existing semantic primary-attack action")
assert(contains(router, "WeaponController.stop()"), "firearm input must stop before melee binds")
assert(
	contains(router, "ContextActionService:BindAction(FIRE_ACTION_NAME, onMeleeAction, true, Enum.KeyCode.ButtonR2)"),
	"melee must cover gamepad R2 plus generated touch through the same action"
)
assert(contains(router, "Enum.UserInputType.MouseButton1"), "melee must keep mouse primary attack")
assert(
	contains(router, 'ContextActionService:SetTitle(FIRE_ACTION_NAME, "Attack")'),
	"melee touch action must have a truthful label"
)
assert(contains(router, "strikeIntent:FireServer"), "client melee routing must send only intent")
assert(contains(router, "WeaponController.start()"), "firearm input must restore when server mode returns to firearm")
assert(not contains(router, "FireIntent"), "mode router cannot become a second firearm intent owner")
assert(not contains(router, "ReloadIntent"), "mode router cannot create a second reload owner")

-- BA-062's proven firearm device surface remains byte-for-byte represented by
-- its original owner; this slice routes around it rather than rewriting it.
assert(
	contains(weapon, "ContextActionService:BindAction(FIRE_ACTION_NAME, onFireAction, true, Enum.KeyCode.ButtonR2)"),
	"existing device-neutral firearm binding must remain intact"
)
assert(
	contains(weapon, "fireIntentRemote:FireServer(isFiring, direction)"),
	"existing firearm authority path must remain intact"
)
assert(
	contains(clientBootstrap, "WeaponController.start()\nPrimaryAttackModeController.start()"),
	"mode router must start after the firearm controller so initial melee mode can safely take ownership"
)
assert(
	contains(meleeService, "EnemyDirectorService.commitHealthState"),
	"melee intent must terminate at canonical enemy health ownership"
)

print("PrimaryAttackModeSourceAudit: mutually exclusive mouse/R2/touch firearm-melee routing passed")
