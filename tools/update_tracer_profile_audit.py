from pathlib import Path

AUDIT_PATH = Path("games/living-kingdoms/tests/HitConfirmedTracerSourceAudit.test.luau")
AUDIT_PATH.write_text(
    '''--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
\tif not condition then
\t\terror(message, 2)
\tend
end

local policy = fs.readFile("docs/specifications/basic-firearm-tracer-policy.md")
local presenter = fs.readFile("games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau")
local feelConfig = fs.readFile("games/living-kingdoms/src/shared/Config/WeaponFeelConfig.luau")
local registry = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")

for _, required in {
\t"server confirmed that damage was applied",
\t"server disclosed an authoritative impact world position",
\t"Blocked, rejected, duplicate, or otherwise non-damaging shots must not display a tracer",
\t"bounded profile for the disclosed configured firearm",
\t"approximately 0.035 seconds for the compact SMG to 0.12 seconds for the long-range sniper rifle",
\t"Skip degenerate paths shorter than 0.5 studs",
} do
\tassertThat(string.find(policy, required, 1, true) ~= nil, "tracer policy missing: " .. required)
end

for _, required in {
\t'local MINIMUM_TRACER_DISTANCE_STUDS = 0.5',
\t'rig.muzzleAttachment.WorldPosition',
\t'if distance < MINIMUM_TRACER_DISTANCE_STUDS then',
\t'tracer.Name = "AuthoritativeDamageTracer"',
\t'tracer:SetAttribute("SourceShotId", shotId)',
\t'tracer:SetAttribute("PresentationOnly", true)',
\t'tracer.CanCollide = false',
\t'tracer.CanTouch = false',
\t'tracer.CanQuery = false',
\t'Debris:AddItem(tracer, profile.TracerLifetimeSeconds)',
\t'profile.TracerWidth',
\t'profile.TracerTransparency',
\t'if didApplyDamage and impactWorldPosition ~= nil then',
\t'spawnDamageTracer(rig, shotId, impactWorldPosition, profile)',
} do
\tassertThat(string.find(presenter, required, 1, true) ~= nil, "tracer presenter missing: " .. required)
end

for _, required in {
\t"TracerWidth = 0.03",
\t"TracerLifetimeSeconds = 0.035",
\t"TracerLifetimeSeconds = 0.12",
\t"assert(entry.TracerWidth > 0 and entry.TracerWidth <= 0.15",
} do
\tassertThat(string.find(feelConfig, required, 1, true) ~= nil, "tracer profile bounds missing: " .. required)
end

local gateIndex = string.find(presenter, "if didApplyDamage and impactWorldPosition ~= nil then", 1, true)
local tracerCallIndex = string.find(presenter, "spawnDamageTracer(rig, shotId, impactWorldPosition, profile)", 1, true)
assertThat(
\tgateIndex ~= nil and tracerCallIndex ~= nil and gateIndex < tracerCallIndex,
\t"tracer creation must remain below the authoritative damage gate"
)

for _, forbidden in {
\t"FireServer",
\t"InvokeServer",
\t"OnServerEvent",
\t"DamageResolver",
\t"FirearmHitResolver",
\t"Humanoid:TakeDamage",
\t".Touched:Connect",
\t"Raycast(",
\t"loadedRounds",
\t"reserveRounds",
\t"CadenceSeconds",
\t"ReloadDurationSeconds",
} do
\tassertThat(not string.find(presenter, forbidden, 1, true), "tracer presenter must not contain " .. forbidden)
end

assertThat(
\tstring.find(registry, "hit-confirmed tracer", 1, true) ~= nil,
\t"visual registry must honestly include the temporary tracer"
)
assertThat(
\tstring.find(roadmap, "Hit-confirmed tracer policy", 1, true) ~= nil,
\t"VIS-0102 roadmap must record the completed tracer policy slice"
)
assertThat(
\tstring.find(roadmap, "tracer policy, production effects", 1, true) == nil,
\t"roadmap must not leave tracer policy listed as pending"
)

print("HitConfirmedTracerSourceAudit: damage gating, per-loadout bounds, muzzle origin, cleanup, and authority passed")
''',
    encoding="utf-8",
)
print("Updated tracer source audit for bounded per-loadout presentation profiles")
