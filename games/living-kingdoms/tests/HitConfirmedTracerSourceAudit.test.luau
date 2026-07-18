--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local policy = fs.readFile("docs/specifications/basic-firearm-tracer-policy.md")
local presenter = fs.readFile("games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau")
local registry = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")

for _, required in {
	"server confirmed that damage was applied",
	"server disclosed an authoritative impact world position",
	"Blocked, rejected, duplicate, or otherwise non-damaging shots must not display a tracer",
	"approximately 0.055 seconds",
	"Skip degenerate paths shorter than 0.5 studs",
} do
	assertThat(string.find(policy, required, 1, true) ~= nil, "tracer policy missing: " .. required)
end

for _, required in {
	'local TRACER_LIFETIME_SECONDS = 0.055',
	'local MINIMUM_TRACER_DISTANCE_STUDS = 0.5',
	'rig.muzzleAttachment.WorldPosition',
	'if distance < MINIMUM_TRACER_DISTANCE_STUDS then',
	'tracer.Name = "AuthoritativeDamageTracer"',
	'tracer:SetAttribute("SourceShotId", shotId)',
	'tracer:SetAttribute("PresentationOnly", true)',
	'tracer.CanCollide = false',
	'tracer.CanTouch = false',
	'tracer.CanQuery = false',
	'Debris:AddItem(tracer, TRACER_LIFETIME_SECONDS)',
	'if didApplyDamage and impactWorldPosition ~= nil then',
	'spawnDamageTracer(rig, shotId, impactWorldPosition)',
} do
	assertThat(string.find(presenter, required, 1, true) ~= nil, "tracer presenter missing: " .. required)
end

local gateIndex = string.find(presenter, "if didApplyDamage and impactWorldPosition ~= nil then", 1, true)
local tracerCallIndex = string.find(presenter, "spawnDamageTracer(rig, shotId, impactWorldPosition)", 1, true)
assertThat(
	gateIndex ~= nil and tracerCallIndex ~= nil and gateIndex < tracerCallIndex,
	"tracer creation must remain below the authoritative damage gate"
)

for _, forbidden in {
	"FireServer",
	"InvokeServer",
	"OnServerEvent",
	"DamageResolver",
	"FirearmHitResolver",
	"Humanoid:TakeDamage",
	".Touched:Connect",
	"Raycast(",
	"loadedRounds",
	"reserveRounds",
	"CadenceSeconds",
	"ReloadDurationSeconds",
} do
	assertThat(not string.find(presenter, forbidden, 1, true), "tracer presenter must not contain " .. forbidden)
end

assertThat(
	string.find(registry, "hit-confirmed tracer", 1, true) ~= nil,
	"visual registry must honestly include the temporary tracer"
)
assertThat(
	string.find(roadmap, "Hit-confirmed tracer policy", 1, true) ~= nil,
	"VIS-0102 roadmap must record the completed tracer policy slice"
)
assertThat(
	string.find(roadmap, "tracer policy, production effects", 1, true) == nil,
	"roadmap must not leave tracer policy listed as pending"
)

print("HitConfirmedTracerSourceAudit: damage gating, muzzle origin, bounded cleanup, and authority checks passed")
