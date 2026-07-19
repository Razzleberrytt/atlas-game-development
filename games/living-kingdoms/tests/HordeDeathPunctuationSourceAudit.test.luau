--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local effects = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeEffectsController.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/HordeDeathPunctuationConfig.luau")
local hordeConfig = fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau")

for _, token in
	{
		"local function resolveDeathPunctuation",
		"HordeDeathPunctuationConfig.get(kindId)",
		"HordeRoleId",
		"CombatEntityId",
		"local entityId = readCombatEntityId(model)",
		"if entityId == nil then",
		"BruteFinalEntityMarker",
		"punctuationKindIds.Screamer",
		"punctuationKindIds.Bloater",
		"punctuationKindIds.BrutePhaseOne",
		"punctuationKindIds.BruteFinal",
		"definition.BloodDiameterStuds",
		"definition.BillboardLifetimeSeconds",
		"definition.ShakeMagnitude",
		"createBloodPool(root.Position, definition)",
		"createKillText(model, root.Position, definition)",
	}
 do
	assertThat(contains(effects, token), "special-role death punctuation is missing " .. token)
end

for _, title in { "CHOIR SILENCED", "ROT BURST ARMED", "BRUTE PHASE BROKEN", "BRUTE ERADICATED" } do
	assertThat(contains(config, title), "special-role death copy is missing " .. title)
end

for _, roleId in { "horde.role.screamer", "horde.role.bloater", "horde.role.brute" } do
	assertThat(contains(hordeConfig, roleId), "death punctuation role is not canonical: " .. roleId)
end

for _, forbidden in
	{
		"FireServer",
		"RemoteEvent.new",
		"DamageResolver",
		"commitHealthState",
		"applyAuthoritativeDamage",
		"TakeDamage",
		"ParticleEmitter",
		"task.delay",
		"task.spawn",
		"Instance.new(\"Sound\")",
	}
 do
	assertThat(not contains(effects, forbidden), "death punctuation cannot own gameplay or new event objects: " .. forbidden)
end

assertThat(
	contains(effects, "Debris:AddItem(pool, HordeConfig.Feedback.BloodLifetimeSeconds)"),
	"death pools must retain existing bounded Debris cleanup"
)
assertThat(
	contains(effects, "Debris:AddItem(attachmentPart, lifetime)"),
	"death billboards must retain bounded Debris cleanup"
)
assertThat(
	not contains(effects, "GetAttributeChangedSignal(\"HordeRoleId\")"),
	"special punctuation cannot add per-role attribute listeners"
)
assertThat(
	contains(effects, "model:GetAttributeChangedSignal(lifeAttribute):Connect(update)"),
	"special punctuation must reuse the existing life-state death trigger"
)

print("HordeDeathPunctuationSourceAudit: authoritative facts, missing-identity fallback, reused objects, bounded cleanup, and zero power passed")
