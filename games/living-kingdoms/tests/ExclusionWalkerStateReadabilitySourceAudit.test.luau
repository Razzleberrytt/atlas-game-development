--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local serverPresenter =
	fs.readFile("games/living-kingdoms/src/server/Systems/EnemyPresentationService.luau")
local controller =
	fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau")
local resolver =
	fs.readFile("games/living-kingdoms/src/client/Presentation/EnemyPresentationPoseResolver.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local manifest = fs.readFile("games/living-kingdoms/assets/visual/enemy/standard-hostile/asset-manifest.json")
local readme = fs.readFile("games/living-kingdoms/assets/visual/enemy/standard-hostile/README.md")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")

for _, required in
	{
		'Instance.new("Motor6D")',
		'"TorsoMotor"',
		'"ForearmLeftMotor"',
		'"ForearmRightMotor"',
		'"LegLeftMotor"',
		'"LegRightMotor"',
		'presentation:SetAttribute("PresentationMotorCount", 5)',
	}
do
	assertThat(string.find(serverPresenter, required, 1, true) ~= nil, "motorized Walker rig missing: " .. required)
end

for _, required in
	{
		'RunService.RenderStepped:Connect',
		'folder.DescendantAdded:Connect',
		'folder.ChildRemoved:Connect',
		'Workspace:GetServerTimeNow()',
		'EnemyPresentationPoseResolver.resolve',
		'record.humanoid.MoveDirection.Magnitude',
		'record.humanoid.WalkSpeed',
		'string.match(label.Text, "Health:%s*(%-?%d+)")',
		'record.torsoMotor.C0 =',
		'record.sensor.Color =',
	}
do
	assertThat(string.find(controller, required, 1, true) ~= nil, "Walker state controller missing: " .. required)
end

local _, renderConnectionCount = string.gsub(controller, "RenderStepped:Connect", "")
assertThat(renderConnectionCount == 1, "Walker state readability must use exactly one client frame connection")
local _, descendantConnectionCount = string.gsub(controller, "DescendantAdded:Connect", "")
assertThat(descendantConnectionCount == 1, "Walker state readability must use one folder descendant listener")
local _, removedConnectionCount = string.gsub(controller, "ChildRemoved:Connect", "")
assertThat(removedConnectionCount == 1, "Walker state readability must use one folder removal listener")

for _, forbidden in
	{
		"FireServer",
		"InvokeServer",
		"RemoteEvent",
		"RemoteFunction",
		"OnClientEvent",
		"GetPropertyChangedSignal",
		".Changed:Connect",
		"Humanoid:MoveTo",
		"TakeDamage",
		"applyAuthoritativeDamage",
		"SetNetworkOwner",
		"root.CFrame =",
		"root.Position =",
		"humanoid.WalkSpeed =",
		"healthLabel.Text =",
		"Anchored =",
		"task.delay",
		"task.spawn",
	}
do
	assertThat(
		not string.find(controller, forbidden, 1, true),
		"Walker state controller must not contain network, scheduler, or gameplay mutation token " .. forbidden
	)
end

for _, required in
	{
		'HitReaction = "HitReaction"',
		'ThreatReady = "ThreatReady"',
		'StandDown = "StandDown"',
		'Dead = "Dead"',
		'secondsSinceHit <= 0.28',
		'if input.isDead then',
	}
do
	assertThat(string.find(resolver, required, 1, true) ~= nil, "Walker pose resolver missing: " .. required)
end

local requireIndex = string.find(bootstrap, "local EnemyPresentationController = require", 1, true)
local startIndex = string.find(bootstrap, "EnemyPresentationController.start()", 1, true)
assertThat(
	requireIndex ~= nil and startIndex ~= nil and requireIndex < startIndex,
	"client bootstrap must require and start Walker state presentation"
)

assertThat(
	string.find(manifest, '"clientFrameConnections": 1', 1, true) ~= nil,
	"Walker manifest must record the one client frame connection"
)
assertThat(
	string.find(manifest, '"connectionsPerEnemy": 0', 1, true) ~= nil,
	"Walker manifest must preserve zero per-enemy connections"
)
assertThat(
	string.find(readme, "client-local pose controller", 1, true) ~= nil,
	"Walker README must document the local state layer"
)
assertThat(
	string.find(roadmap, "client-local pose controller", 1, true) ~= nil,
	"VIS-0103 roadmap must record the state readability slice"
)
assertThat(
	string.find(roadmap, "committed strike/recovery remains pending", 1, true) ~= nil,
	"roadmap must not falsely claim server-confirmed strike animation"
)

print("ExclusionWalkerStateReadabilitySourceAudit: motor, lifecycle, authority, and documentation checks passed")
