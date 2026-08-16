--!strict

-- RPG-0111 relic HUD and its network surface. The server publishes only safe
-- copied snapshots of an operative's own build and accepts exactly two
-- identity-free requests; the client controller renders that snapshot and can
-- establish nothing.

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function count(source: string, token: string): number
	local total = 0
	local index = 1
	while true do
		local found = string.find(source, token, index, true)
		if found == nil then
			break
		end
		total += 1
		index = found + 1
	end
	return total
end

local service = fs.readFile("games/living-kingdoms/src/server/Systems/RunBuildService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/RunBuildHUDController.luau")
local choiceCoordinator = fs.readFile("games/living-kingdoms/src/client/Controllers/Input/ChoiceInputCoordinator.luau")
local bootstrapServer = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local bootstrapClient = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

-- The network is created once, by the server, through the canonical atomic
-- builder with exactly the surface RPG-0111 needs: one state channel, one read,
-- and the two identity-free intents.
local runBuildNetworkContract =
	'ensureNetwork("RunBuildNetwork", { "State", "SubmitRelicChoice", "SubmitRelicReplacement" }, { "ReadState" })'
assertThat(
	contains(bootstrapServer, runBuildNetworkContract),
	"the server must own the exact run-build network contract"
)
assertThat(contains(bootstrapServer, "ensureRunBuildNetwork()"), "the run-build network must be created at bootstrap")

-- Every published payload is the store's safe snapshot, never internal state.
assertThat(
	contains(service, "local snapshot = store:readSafeSnapshot(operativeId(player))")
		and contains(service, "stateRemote:FireClient(player, snapshot)"),
	"clients may only receive the store's safe snapshot"
)
assertThat(
	count(service, "stateRemote:FireClient") == 2,
	"the only server-to-client sends are the safe snapshot and the bounded rejection"
)
assertThat(
	contains(service, "readStateRemote.OnServerInvoke = function(player: Player)")
		and contains(service, "return store:readSafeSnapshot(operativeId(player))"),
	"the read function must answer with the caller's own safe snapshot"
)

-- Requests are identity-free and rate limited, and the operative is derived from
-- the calling player rather than the payload.
assertThat(
	contains(service, "RunBuildService.submitRelicChoice(player, intent :: any)")
		and contains(service, "RunBuildService.submitRelicReplacement(player, intent :: any)"),
	"both intents must route through the existing validated entry points"
)
assertThat(
	contains(service, "operativeId(player)") and not contains(service, "intent.operativeId"),
	"the server must derive the operative from the caller, never from the payload"
)
assertThat(
	contains(service, "if not acceptsRequest(player) then"),
	"both intents must pass the shared request cooldown"
)
assertThat(
	contains(service, "RunRpgConfig.Limits.minimumChoiceRequestIntervalSeconds"),
	"the cooldown must come from the shared configured limit"
)
assertThat(contains(service, 'if select("#", ...) ~= 0 then'), "extra remote arguments must be rejected")
assertThat(
	contains(service, "choiceConnection:Disconnect()")
		and contains(service, "replacementConnection:Disconnect()")
		and contains(service, "readStateRemote.OnServerInvoke = nil :: any")
		and contains(service, "table.clear(lastRequestTimestamps)"),
	"teardown must release every request surface and its per-player state"
)

-- The client establishes nothing: it sends only the two contract intents and
-- renders what it is told.
assertThat(count(controller, ":FireServer(") == 2, "the controller may make exactly the two contract requests")
assertThat(
	contains(controller, "submitChoiceRemote:FireServer({")
		and contains(controller, "submitReplacementRemote:FireServer({"),
	"the controller must use the two declared intents"
)
assertThat(
	contains(controller, "rewardSequence = rewardSequence") and contains(controller, "relicId = relicId"),
	"requests must carry only the server-authored sequence and the offered relic"
)
assertThat(
	not contains(controller, "damage") and not contains(controller, "Health"),
	"the relic HUD must not touch combat or life values"
)
assertThat(
	contains(controller, "activeRewardSequence = reward.rewardSequence"),
	"the reward sequence must come from the server snapshot, not the client"
)
assertThat(contains(controller, "snapshot.revision < lastRevision"), "a stale snapshot must not overwrite a newer one")
assertThat(
	contains(controller, "if snapshot.operationGeneration ~= activeGeneration then"),
	"a new operation must discard a half-finished replacement decision"
)
assertThat(
	contains(controller, "RunRpgConfig.Limits.maximumEquippedRelicsPerOperative")
		and contains(controller, "RunRpgConfig.Limits.relicChoiceCountPerReward"),
	"the slot and choice counts must come from the shared configured limits"
)

-- Readability: slot and reward state is carried by text, not colour alone.
assertThat(
	contains(controller, '"SLOT %d\\nEMPTY"') and contains(controller, '"SLOT %d\\n%s%s"'),
	"an empty slot and an occupied slot must be distinguishable by text"
)
assertThat(
	contains(controller, "DISCARD?") and contains(controller, "Choose the slot to discard for %s."),
	"the replacement flow must name the discard target in text"
)
assertThat(
	contains(controller, "CHARGE") and contains(controller, "slot.counterValue"),
	"charge and counter state must be readable on the relic bar"
)
assertThat(
	contains(controller, "RELIC REQUEST REJECTED: "),
	"a rejected request must be explained rather than silently dropped"
)
assertThat(contains(controller, "definition.description"), "relic choices must explain their implemented effect")
assertThat(
	contains(controller, 'ChoiceInputCoordinator.register("RelicChoice"')
		and contains(choiceCoordinator, "Enum.KeyCode.One")
		and contains(choiceCoordinator, "Enum.KeyCode.Two")
		and contains(choiceCoordinator, "Enum.KeyCode.Three"),
	"relic choices must support keyboard selection through the shared numbered-input owner"
)
assertThat(contains(controller, "LK_InputModalOpen"), "relic choices must release the first-person cursor")

-- Exactly one connection per surface, and teardown releases them.
assertThat(count(controller, "OnClientEvent:Connect") == 1, "the HUD must use one disclosure connection")
assertThat(
	contains(controller, "for _, connection in buttonConnections do") and contains(controller, "screenGui:Destroy()"),
	"teardown must release every button connection and the GUI"
)
assertThat(
	contains(bootstrapClient, "RunBuildHUDController.start()"),
	"the relic HUD must be bootstrapped on the client"
)

print("RunBuildHUDIntegration: bounded relic network surface, snapshot-only rendering, and readable state passed")
