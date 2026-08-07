--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local bootstrap = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionServerBootstrap.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLiveRuntimeService.luau")
local owner = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomBarrierStateService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionEncounterBarrierController.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assertThat(
	string.find(bootstrap, "getActiveEncounterContext", 1, true) ~= nil,
	"composition root must expose a read-only active encounter context"
)
assertThat(
	string.find(runtime, "ExpeditionRoomBarrierStateService.update(bootstrap:getActiveEncounterContext())", 1, true) ~= nil,
	"live runtime must drive barrier state from authoritative encounter context"
)
assertThat(
	string.find(owner, 'setState(nextRoom, "Locked"', 1, true) ~= nil,
	"combat encounters must lock their authoritative room"
)
assertThat(
	string.find(owner, 'setState(activeRoom, "Cleared"', 1, true) ~= nil,
	"completed encounters must discharge the previous room"
)
assertThat(
	string.find(owner, "MAX_", 1, true) == nil,
	"server owner should operate only on the bounded expedition room root"
)
assertThat(
	string.find(controller, "MAX_TRACKED_ROOMS = 48", 1, true) ~= nil,
	"client room scanning must be bounded"
)
assertThat(
	string.find(controller, "MAX_TRACKED_BARRIERS = 96", 1, true) ~= nil,
	"client barrier tracking must be bounded"
)
assertThat(
	string.find(clientBootstrap, "ExpeditionEncounterBarrierController.start()", 1, true) ~= nil,
	"encounter barrier controller must be mounted"
)

for _, forbidden in { "FireServer", "InvokeServer", "OnServerEvent", "TakeDamage", "advancePhase", "completeActive" } do
	assertThat(
		not string.find(controller, forbidden, 1, true),
		"client barrier presentation must not contain " .. forbidden
	)
end
