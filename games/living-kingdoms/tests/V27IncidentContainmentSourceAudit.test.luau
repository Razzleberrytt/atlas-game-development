--!strict

-- Blueprint v2.7 static containment audit. This proves source ordering and
-- conservative target rules only; it is not Studio/runtime acceptance evidence.
local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local listener = fs.readFile("games/living-kingdoms/src/client/State/HordeStateEarlyListener.luau")
local guard = fs.readFile("games/living-kingdoms/src/client/Presentation/BroadHighlightGuardController.luau")
local rolloutConfig = fs.readFile("games/living-kingdoms/src/shared/Config/RuntimeRolloutConfig.luau")

local hasExplicitSupportedRolloutVersion = contains(rolloutConfig, 'Version = "V2.7-R1-CONTAINMENT"')
	or contains(rolloutConfig, 'Version = "V2.7-R2-PREP"')
assertThat(hasExplicitSupportedRolloutVersion, "rollout config version must identify an explicit supported v2.7 stage")
assertThat(contains(rolloutConfig, "EnableRuntimeCounters = true"), "R1 diagnostics must default on")
assertThat(contains(rolloutConfig, "EnableEarlyStateListener = true"), "R1 early listener must default on")
assertThat(contains(rolloutConfig, "RejectBroadHighlightTargets = true"), "broad Highlight containment must default on")
assertThat(contains(bootstrap, "RuntimeRolloutConfig.EnableEarlyStateListener"), "bootstrap must gate the R1 listener")
assertThat(
	contains(bootstrap, "RuntimeRolloutConfig.RejectBroadHighlightTargets"),
	"bootstrap must gate Highlight containment"
)

local listenerStart = string.find(bootstrap, "HordeStateEarlyListener.start()", 1, true)
local guardStart = string.find(bootstrap, "BroadHighlightGuardController.start()", 1, true)
local firstGameplayRequire = string.find(bootstrap, "require(script.Controllers.CameraController)", 1, true)
assertThat(listenerStart ~= nil, "early Horde State listener must start")
assertThat(guardStart ~= nil, "broad Highlight guard must start")
assertThat(firstGameplayRequire ~= nil, "client bootstrap must retain gameplay controller graph")
assertThat(
	listenerStart < firstGameplayRequire,
	"Horde State listener must bind before gameplay controllers are required"
)
assertThat(
	guardStart < firstGameplayRequire,
	"Highlight guard must bind before presentation/gameplay controllers are required"
)

assertThat(contains(listener, 'WaitForChild("HordeNetwork"'), "early listener must bind canonical HordeNetwork")
assertThat(
	contains(listener, 'WaitForChild("State", NETWORK_WAIT_SECONDS)'),
	"early listener must bind canonical bounded State remote"
)
assertThat(
	contains(listener, "stateRemote.OnClientEvent:Connect(onState)"),
	"early listener must consume State immediately"
)
assertThat(contains(listener, "latestSnapshot = message"), "early listener must retain latest current state")
assertThat(
	contains(listener, "function HordeStateEarlyListener.subscribe"),
	"early listener must support later listener consolidation"
)
assertThat(contains(listener, 'SetAttribute("V27_EarlyStateListenerBound"'), "listener bound diagnostic must exist")
assertThat(contains(listener, 'SetAttribute("V27_StateMessagesReceived"'), "message-count diagnostic must exist")
assertThat(contains(listener, 'SetAttribute("V27_StateInvalidMessages"'), "invalid-message diagnostic must exist")
assertThat(contains(listener, 'SetAttribute("V27_StateLastRevision"'), "last-revision diagnostic must exist")
for _, forbidden in { "FireServer", "InvokeServer", "TakeDamage", "Humanoid", 'Instance.new("Highlight")' } do
	assertThat(
		not contains(listener, forbidden),
		"early listener must own no gameplay/presentation authority: " .. forbidden
	)
end

assertThat(contains(guard, "MAXIMUM_TOP_LEVEL_TARGET_PARTS = 64"), "guard must keep a bounded broad-root threshold")
assertThat(contains(guard, "target == Workspace or target == Workspace.Terrain"), "guard must reject Workspace/Terrain")
assertThat(contains(guard, "target.Parent ~= Workspace"), "guard must leave nested/narrow targets alone")
assertThat(contains(guard, 'target:IsA("Model") or target:IsA("Folder")'), "guard must scope top-level broad roots")
assertThat(contains(guard, "instance.Enabled = false"), "guard must disable rejected broad Highlights")
assertThat(
	contains(guard, 'instance:SetAttribute("LK_BroadTargetRejected", true)'),
	"guard must mark rejected Highlights"
)
assertThat(
	contains(guard, 'Workspace:SetAttribute("V27_BroadHighlightGuardActive"'),
	"guard active diagnostic must exist"
)
assertThat(
	contains(guard, 'Workspace:SetAttribute("V27_BroadHighlightRejectedCount"'),
	"guard rejection diagnostic must exist"
)
assertThat(
	contains(guard, 'Workspace:SetAttribute("V27_BroadHighlightLastTarget"'),
	"last broad-target diagnostic must exist"
)
for _, forbidden in
	{ "FireServer", "InvokeServer", "TakeDamage", "CombatImpactHighlight", "HordeRoleHighlight", "EnemyEntities" }
do
	assertThat(
		not contains(guard, forbidden),
		"guard must not target gameplay or known narrow Highlight owners: " .. forbidden
	)
end

print(
	"V27IncidentContainmentSourceAudit: staged v2.7 rollout, early State listener diagnostics, and conservative broad-Highlight rejection locked"
)
