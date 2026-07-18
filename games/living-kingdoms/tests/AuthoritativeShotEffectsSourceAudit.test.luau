--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/BasicFirearmPresentationFactory.luau")
local presenter = fs.readFile("games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau")
local presentationController = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau")
local weaponController = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local visualConfig = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")

assertThat(
	string.find(contracts, "didApplyDamage: boolean", 1, true) ~= nil,
	"shot disclosure must carry the authoritative damage result"
)
assertThat(
	string.find(contracts, "impactWorldPosition: Vector3?", 1, true) ~= nil,
	"shot disclosure must carry only an optional impact position"
)

assertThat(
	string.find(runtime, "presentationRemote:FireAllClients({", 1, true) ~= nil,
	"accepted shot presentation must be squad-visible"
)
assertThat(
	string.find(runtime, "local didApplyDamage = didCommit and damageResolution.didApplyDamage", 1, true) ~= nil,
	"server disclosure must require both a committed health state and applied damage"
)
assertThat(
	string.find(runtime, "impactWorldPosition = if didApplyDamage then fact.worldPosition else nil", 1, true) ~= nil,
	"blocked, rejected, or stale damage commits must not fabricate an impact position"
)
assertThat(
	string.find(runtime, "presentationRemote:FireClient(player, payload)", 1, true) ~= nil,
	"private ammunition disclosure must remain recipient-specific"
)

for _, required in {
	'"MuzzleFlash"',
	'"MuzzleLight"',
	"muzzleFlash.Transparency = 1",
	"muzzleLight.Enabled = false",
} do
	assertThat(string.find(factory, required, 1, true) ~= nil, "missing firearm flash component " .. required)
end

assertThat(
	string.find(presenter, "if didApplyDamage and impactWorldPosition ~= nil then", 1, true) ~= nil,
	"impact presentation must remain gated by authoritative damage"
)
assertThat(string.find(presenter, "Debris:AddItem(casing", 1, true) ~= nil, "casing cleanup must be bounded")
assertThat(string.find(presenter, "Debris:AddItem(impact", 1, true) ~= nil, "impact cleanup must be bounded")
assertThat(
	string.find(presenter, 'casing:SetAttribute("PresentationOnly", true)', 1, true) ~= nil,
	"casings must identify themselves as presentation-only"
)

for _, forbidden in {
	"FireServer",
	"InvokeServer",
	"OnServerEvent",
	"DamageResolver",
	"FirearmHitResolver",
	"loadedRounds -=",
	"reserveRounds -=",
	"Humanoid:TakeDamage",
	"SoundId =",
} do
	assertThat(not string.find(presenter, forbidden, 1, true), "effect presenter must not contain " .. forbidden)
end

assertThat(
	string.find(presentationController, "playerForOperativeEntityId", 1, true) ~= nil,
	"broadcast shots must resolve the disclosed operative to the correct rig"
)
assertThat(
	string.find(presentationController, "WeaponShotEffectPresenter.present", 1, true) ~= nil,
	"validated shots must reach the temporary effects presenter"
)
assertThat(
	string.find(presentationController, 'typeof(payload.impactWorldPosition) == "Vector3"', 1, true) ~= nil,
	"damage impacts must validate their world position"
)
assertThat(
	string.find(weaponController, "isLocalOperativeEntityId(payload.operativeEntityId)", 1, true) ~= nil,
	"the local combat HUD must ignore squadmates' broadcast shots"
)
assertThat(
	string.find(visualConfig, "Accepted shots now drive temporary code-built muzzle flash", 1, true) ~= nil,
	"the asset registry must honestly classify the temporary shot effects"
)
