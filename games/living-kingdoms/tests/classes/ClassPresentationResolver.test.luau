--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Classes/ClassContracts.luau"), {
	debugName = "ClassContracts",
	injectGlobals = true,
})()
local actionMap = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau"), {
	debugName = "InputActionMapConfig",
	injectGlobals = true,
})()
local CONTRACTS_TOKEN = {}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Classes/ClassPresentationResolver.luau"), {
	debugName = "ClassPresentationResolver",
	environment = {
		script = { Parent = { ClassContracts = CONTRACTS_TOKEN } },
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			error("unexpected presentation dependency", 2)
		end,
	},
	injectGlobals = true,
})()

for _, classId in contracts.ClassIds do
	local identity = resolver.identity(classId)
	assertThat(identity ~= nil, "every starting class needs presentation identity")
	assertThat(string.find(identity.shapeToken, "[", 1, true) == 1, "identity needs a written shape token")
	assertThat(identity.displayName ~= "" and identity.roleSummary ~= "", "identity text must be complete")
end

assertThat(resolver.resourceLabel(contracts.ClassIds.Medic, {
	{ resourceId = contracts.ClassResourceIds.MedicalCharge, currentAmount = 2, maximumAmount = 3 },
}) == "MEDICAL CHARGES  2 / 3", "medic owner must see current and maximum charges")
assertThat(resolver.resourceLabel(contracts.ClassIds.Engineer, {
	{ resourceId = contracts.ClassResourceIds.ResupplyCharge, currentAmount = 1, maximumAmount = 2 },
}) == "RESUPPLY CHARGES  1 / 2", "engineer owner must see current and maximum charges")
assertThat(
	resolver.resourceLabel(contracts.ClassIds.CombatSpecialist, {}) == "BRACE • COOLDOWN LIMITED",
	"combat specialist limitation must be explicit"
)

local active = {
	actionStateId = contracts.ClassActionStateIds.Active,
	actionId = contracts.ClassActionIds.FieldTreatment,
	targetOperativeEntityId = "operative.player:2",
	startedAtServerTimestamp = 10,
	completionServerTimestamp = 13,
	cooldownEndServerTimestamp = nil,
	statusReasonId = nil,
	revision = 2,
}
assertThat(
	resolver.ownerStatus(contracts.ClassIds.Medic, active, 11.5) == "FIELD TREATMENT ACTIVE  1.5s  •  Q TO CANCEL",
	"active channel must disclose remaining server time and cancel input"
)
local cooldown = table.clone(active)
cooldown.actionStateId = contracts.ClassActionStateIds.Cooldown
cooldown.completionServerTimestamp = nil
cooldown.cooldownEndServerTimestamp = 20
cooldown.statusReasonId = contracts.ClassActionRejectionReasonIds.DamageInterrupted
assertThat(
	resolver.ownerStatus(contracts.ClassIds.Medic, cooldown, 17) == "ACTION INTERRUPTED — HIT  •  READY IN 3.0s",
	"cooldown must preserve a concise interruption reason and remaining time"
)

local idle = table.clone(active)
idle.actionStateId = contracts.ClassActionStateIds.Idle
idle.actionId = nil
idle.targetOperativeEntityId = nil
idle.startedAtServerTimestamp = nil
idle.completionServerTimestamp = nil
idle.cooldownEndServerTimestamp = nil
idle.statusReasonId = nil
local classActionBinding = actionMap.Actions.ClassAction
assertThat(classActionBinding.KeyboardKeyCodeNames[1] == "Q", "canonical class action keyboard binding must remain Q")
assertThat(
	classActionBinding.GamepadKeyCodeNames[1] == "ButtonB",
	"canonical class action gamepad binding must remain ButtonB"
)
local idleStatus = resolver.ownerStatus(contracts.ClassIds.CombatSpecialist, idle, 17)
assertThat(idleStatus == "BRACE READY  •  Q / GAMEPAD B", "ready hint must match the remapped class-action controls")
assertThat(
	not string.find(idleStatus, "GAMEPAD X", 1, true),
	"ready hint must not regress to the world-prompt gamepad key"
)

for _, reasonId in contracts.ClassActionRejectionReasonIds do
	local label = resolver.rejectionLabel(reasonId)
	assertThat(label ~= nil and label ~= "", "every server rejection needs concise feedback")
	assertThat(label ~= reasonId, "feedback must not expose raw internal reason IDs")
end

local member = {
	operativeEntityId = "operative.player:2",
	classId = contracts.ClassIds.Engineer,
	actionStateId = contracts.ClassActionStateIds.Active,
	actionId = contracts.ClassActionIds.FieldResupply,
}
assertThat(resolver.squadActionCue(member) == "RESUPPLYING OPERATIVE", "active teammate action must be named")
member.actionStateId = contracts.ClassActionStateIds.Cooldown
assertThat(resolver.squadActionCue(member) == nil, "private teammate cooldown details must remain undisclosed")

local source = fs.readFile("games/living-kingdoms/src/shared/Classes/ClassPresentationResolver.luau")
for _, forbidden in { "game:GetService", "Instance.new", "RemoteEvent", "FireServer", "Workspace" } do
	assertThat(not string.find(source, forbidden, 1, true), "pure presentation resolver must not contain " .. forbidden)
end
assertThat(not string.find(source, "GAMEPAD X", 1, true), "class presentation copy must not advertise the prompt key")

print(
	"ClassPresentationResolver: redundant identity, resources, timing, remapped ready hint, cues, and failure copy passed"
)
