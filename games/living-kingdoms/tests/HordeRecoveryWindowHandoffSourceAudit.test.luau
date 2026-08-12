--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local hordeSource = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local directorSource = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")

local processEnemyIndex = string.find(hordeSource, "processEnemy(record, serverTimestamp)", 1, true)
local pressureReadIndex = string.find(hordeSource, "local pressureState = EnemyDirectorService.readPressureState()", 1, true)
local recoveryReadIndex = string.find(
	hordeSource,
	"local recoveryWindowEndServerTimestamp = pressureState.recoveryWindowEndServerTimestamp",
	1,
	true
)
local recoveryDeferIndex = string.find(
	hordeSource,
	"nextHordeServerTimestamp = math.max(nextHordeServerTimestamp, recoveryWindowEndServerTimestamp)",
	1,
	true
)
local scheduledDueIndex = string.find(hordeSource, "if serverTimestamp >= nextHordeServerTimestamp then", 1, true)

assertThat(
	string.find(directorSource, "function Service.readPressureState()", 1, true) ~= nil,
	"EnemyDirectorService must remain the canonical pressure-state owner"
)
assertThat(
	string.find(directorSource, "recoveryWindowEndServerTimestamp", 1, true) ~= nil,
	"EnemyDirectorService must expose the canonical recovery-window timestamp"
)
assertThat(pressureReadIndex ~= nil, "scheduled horde evaluation must read canonical EnemyDirector pressure state")
assertThat(recoveryReadIndex ~= nil, "scheduled horde evaluation must consume the canonical recovery deadline")
assertThat(recoveryDeferIndex ~= nil, "scheduled horde deadline must only be deferred with math.max")
assertThat(scheduledDueIndex ~= nil, "scheduled horde pulse must retain its existing due-time gate")
assertThat(
	processEnemyIndex ~= nil and pressureReadIndex ~= nil and processEnemyIndex < pressureReadIndex,
	"enemy special processing must remain independent and occur before scheduled-horde recovery deferral"
)
assertThat(
	recoveryDeferIndex ~= nil and scheduledDueIndex ~= nil and recoveryDeferIndex < scheduledDueIndex,
	"recovery deferral must happen before the scheduled horde due-time check"
)
assertThat(
	string.find(hordeSource, "local result = EnemyDirectorService.spawnEnemy({", 1, true) ~= nil,
	"horde entities must continue to delegate spawn authority to EnemyDirectorService"
)
assertThat(
	string.find(hordeSource, "RecoveryWindowSeconds", 1, true) == nil,
	"HordeExperienceService must not invent a duplicate recovery-window duration"
)
