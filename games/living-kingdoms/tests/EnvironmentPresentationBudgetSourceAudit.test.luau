--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local configPath = "games/living-kingdoms/src/shared/Config/EnvironmentPresentationBudgetConfig.luau"
local sourcePath = "games/living-kingdoms/src/server/EnvironmentPresentationBudget.server.luau"

local config = luau.load(fs.readFile(configPath), {
	debugName = configPath,
	environment = {},
	injectGlobals = true,
})()
local source = fs.readFile(sourcePath)

assert(config.Version == "environment-presentation-budget-v1", "environment presentation budget version changed")
assert(config.SettleSeconds <= 5, "environment presentation audit settle window is too long")
assert(config.Budgets.PresentationRootCount <= 12, "presentation root budget is too loose")
assert(config.Budgets.ModelCount <= 140, "presentation model budget is too loose")
assert(config.Budgets.BasePartCount <= 900, "presentation BasePart budget is too loose")
assert(config.Budgets.ParticleEmitterCount <= 40, "presentation emitter budget is too loose")
assert(config.Budgets.LightCount <= 24, "presentation local-light budget is too loose")
assert(config.Budgets.InteractiveCount == 0, "presentation content must never own interaction authority")
assert(config.Budgets.ScriptCount == 0, "presentation content must never own runtime script authority")
assert(config.Budgets.CollidablePartCount == 0, "presentation content must remain non-colliding")
assert(config.Budgets.TouchPartCount == 0, "presentation content must remain non-touching")
assert(config.Budgets.QueryablePartCount == 0, "presentation content must remain outside gameplay queries")

for _, required in
	{
		'instance:GetAttribute("EnvironmentPresentationOnly") == true',
		"collectPresentationRoots",
		"hasPresentationAncestor",
		'instance:IsA("BasePart")',
		"instance.CanCollide",
		"instance.CanTouch",
		"instance.CanQuery",
		'instance:IsA("ParticleEmitter")',
		'instance:IsA("Light")',
		'instance:IsA("ProximityPrompt")',
		'instance:IsA("ClickDetector")',
		'instance:IsA("Script")',
		'instance:IsA("LocalScript")',
		'instance:IsA("ModuleScript")',
		'worldRoot:SetAttribute("EnvironmentPresentationBudgetStatus", status)',
		"task.wait(BudgetConfig.SettleSeconds)",
		"Workspace.ChildAdded:Connect",
	}
do
	assert(string.find(source, required, 1, true), "presentation budget audit is missing contract: " .. required)
end

for _, forbidden in
	{
		"RunService.Heartbeat",
		"RunService.RenderStepped",
		"RunService.Stepped",
		"while true",
		"Destroy()",
		"CanCollide = false",
		"CanQuery = false",
		"CanTouch = false",
	}
do
	assert(
		not string.find(source, forbidden, 1, true),
		"presentation budget audit mutates or polls runtime content: " .. forbidden
	)
end

print(
	"EnvironmentPresentationBudgetSourceAudit: one-shot measurement, hard ceilings, and zero-authority boundaries passed"
)
