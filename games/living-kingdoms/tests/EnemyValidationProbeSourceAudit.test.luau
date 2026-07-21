--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local probe = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyValidationProbeService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

assertThat(probe:find("RunService:IsStudio()", 1, true) ~= nil, "probe must remain Studio-only")
assertThat(probe:find("BindableFunction", 1, true) ~= nil, "probe must use a server-only bindable")
assertThat(probe:find("RemoteEvent", 1, true) == nil, "probe must not add a client remote")
assertThat(probe:find("RemoteFunction", 1, true) == nil, "probe must not add a client function")
assertThat(probe:find("Heartbeat", 1, true) == nil, "probe must not add a scheduler")
assertThat(probe:find("task.spawn", 1, true) == nil, "probe must not add a task loop")
assertThat(
	probe:find("EnemyDirectorService.readPressureState", 1, true) ~= nil,
	"probe must read retained pressure state"
)
assertThat(
	probe:find("EnemyDirectorService.readEnemyCombatFacts", 1, true) ~= nil,
	"probe must read retained combat facts"
)
assertThat(probe:find("table.freeze", 1, true) ~= nil, "probe snapshots must be frozen")
assertThat(
	bootstrap:find("EnemyValidationProbeService.start()", 1, true) ~= nil,
	"bootstrap must start the Studio probe"
)
