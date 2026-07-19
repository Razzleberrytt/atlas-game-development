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

local server = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local specialConfig = fs.readFile("games/living-kingdoms/src/shared/Config/HordeSpecialTelegraphConfig.luau")
local deathConfig = fs.readFile("games/living-kingdoms/src/shared/Config/HordeDeathPunctuationConfig.luau")
local effects = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeEffectsController.luau")
local telegraph = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeSpecialTelegraphController.luau")
local audio = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyAudioController.luau")

for _, token in
	{
		'Interrupted = "Interrupted"',
		"SpecialStateIds.Interrupted",
		"record.pendingSpecialKindId = nil",
		"record.pendingSpecialCommitServerTimestamp = nil",
		"SpecialAttributeNames.CommitServerTimestamp, 0",
		"pendingSpecialKindId == SpecialKindIds.ScreamerReinforcement",
		"interruptPendingSpecial(record)",
	}
do
	assertThat(contains(server .. specialConfig, token), "authoritative Screamer interrupt contract is missing " .. token)
end

assertThat(
	not contains(server, "record.model:SetAttribute(SpecialAttributeNames.KindId, nil)"),
	"interrupted Screamer corpses must preserve the authoritative special kind"
)
assertThat(
	not contains(server, "record.specialSequence += 1\n\trecord.pendingSpecialKindId = nil"),
	"interrupting a summon cannot advance the warning sequence"
)
assertThat(
	contains(effects, "punctuationKindIds.ScreamerInterrupted"),
	"death feedback must expose dedicated interrupt punctuation"
)
assertThat(
	contains(effects, "specialStateId == SpecialStateIds.Windup or specialStateId == SpecialStateIds.Interrupted"),
	"death feedback must tolerate authoritative replication ordering"
)
assertThat(contains(deathConfig, "SUMMON INTERRUPTED"), "interrupt punctuation copy is missing")
assertThat(
	contains(telegraph, "readStringAttribute(model, AttributeNames.StateId) ~= StateIds.Windup"),
	"the existing fixed telegraph must deactivate when the server leaves Windup"
)
assertThat(
	contains(audio, "if specialSequence > record.lastSpecialSequence then"),
	"warning audio must remain sequence-gated"
)

for _, forbidden in
	{
		"RemoteEvent.new",
		"OnServerEvent",
		"FireServer",
		"task.delay",
		"task.spawn",
		"Instance.new(\"Sound\")",
		"ParticleEmitter",
	}
do
	assertThat(not contains(effects, forbidden), "interrupt confirmation cannot add authority or event objects: " .. forbidden)
end

print("ScreamerInterruptConfirmationSourceAudit: authoritative cancellation, durable outcome, reused presentation, and zero power passed")
