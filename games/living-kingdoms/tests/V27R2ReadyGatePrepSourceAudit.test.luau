--!strict

-- Blueprint v2.7 R2 preparation audit. This branch may prepare keyed readiness
-- infrastructure, but it must not activate R2 delivery before R1 and listener
-- consolidation receive accepted runtime evidence.
local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = fs.readFile("games/living-kingdoms/src/shared/Config/RuntimeRolloutConfig.luau")
local publisher = fs.readFile("games/living-kingdoms/src/server/Networking/ReadyGatedStatePublisher.luau")
local hordeRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local project = fs.readFile("games/living-kingdoms/default.project.json")

assertThat(contains(config, 'Version = "V2.7-R2-PREP"'), "stacked branch must identify itself as R2 preparation")
assertThat(
	contains(config, "EnableReadyGatedStatePublisher = false"),
	"R2 publisher must remain disabled until prerequisite runtime evidence is accepted"
)

for _, required in {
	"owner + remoteId + semanticKey",
	"SuppressedUnchanged",
	"SuppressedBeforeReady",
	"BufferedLatest",
	"function ReadyGatedStatePublisher.publish",
	"function ReadyGatedStatePublisher.markReady",
	"function ReadyGatedStatePublisher.remove",
	"remotePending[semanticKey] =",
	"self._pending[owner] = nil",
} do
	assertThat(contains(publisher, required), "R2 preparation publisher is missing invariant: " .. required)
end

assertThat(
	contains(publisher, "semantic.SuppressedUnchanged") == false,
	"R2 publisher must not implement R3 unchanged-token suppression early"
)
assertThat(
	contains(hordeRuntime, "stateRemote:FireClient(player"),
	"active horde runtime must retain legacy direct delivery while R2 prep is dormant"
)
assertThat(
	not contains(hordeRuntime, "ReadyGatedStatePublisher"),
	"dormant R2 preparation must not be wired into HordeExperienceService yet"
)
assertThat(
	not contains(serverBootstrap, "ReadyGatedStatePublisher"),
	"dormant R2 preparation must not be started from server bootstrap yet"
)
assertThat(
	not contains(clientBootstrap, "ClientReady"),
	"dormant R2 preparation must not emit a readiness signal yet"
)
assertThat(
	not contains(project, '"ClientReady"'),
	"dormant R2 preparation must not add an active ClientReady remote yet"
)

print("V27R2ReadyGatePrepSourceAudit: keyed readiness primitive prepared, R3 suppression absent, and active R2 wiring remains disabled")
