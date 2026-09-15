--!strict

local fs = require("@lune/fs")

local controllerPath = "games/living-kingdoms/src/client/Controllers/MatchResultController.luau"
local lifecyclePath = "games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau"
local controller = fs.readFile(controllerPath)
local lifecycle = fs.readFile(lifecyclePath)

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

assert(
	contains(controller, "RETURN TO THE EXPEDITION LOBBY AND READY UP FOR ANOTHER OPERATION."),
	"the result screen must name the deliberate replay path"
)
assert(
	not contains(controller, "A fresh operation begins in"),
	"the result screen must not promise an automatic restart"
)
assert(
	not contains(controller, "MatchResultConfig.ReplayDebriefSeconds"),
	"replay guidance must not imply the retired timer-driven path"
)
assert(
	contains(lifecycle, "function OperationLifecycleService.prepareForLaunch()"),
	"replay guidance must remain aligned with the canonical server launch seam"
)
assert(
	contains(lifecycle, "A resolved operation now stays resolved until"),
	"the lifecycle owner must document deliberate launch behavior"
)
assert(
	not contains(controller, "FireServer") and not contains(controller, "InvokeServer"),
	"the result screen must remain presentation-only"
)

print("MatchResultReplayGuidanceSourceAudit: debrief names the deliberate, server-owned replay path")
