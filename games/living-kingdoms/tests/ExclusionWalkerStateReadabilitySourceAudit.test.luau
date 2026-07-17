--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local serverPresenter = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyPresentationService.luau")
local director = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
local behaviorResolver = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyBehaviorResolver.luau")
local enemyConfig = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau")
local contracts = fs.readFile("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau")
local resolver = fs.readFile("games/living-kingdoms/src/client/Presentation/EnemyPresentationPoseResolver.luau")
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

for _, attributeName in
	{
		"EnemyPresentationBehaviorStateId",
		"EnemyPresentationLifeStateId",
		"EnemyPresentationWindupSequence",
		"EnemyPresentationWindupStartedServerTimestamp",
		"EnemyPresentationWindupCommitServerTimestamp",
		"EnemyPresentationAttackSequence",
		"EnemyPresentationAttackServerTimestamp",
		"EnemyPresentationHitSequence",
		"EnemyPresentationHitServerTimestamp",
	}
do
	assertThat(string.find(contracts, attributeName, 1, true) ~= nil, "presentation contract missing " .. attributeName)
end

for _, required in
	{
		"AttackWindupSeconds = 0.6",
		"AttackWindupActionIds.Begin",
		"AttackWindupActionIds.Continue",
		"AttackWindupActionIds.Cancel",
		"AttackWindupActionIds.Commit",
		"serverTimestamp < commitAt",
		"windupTargetDistanceSquared <= attackRangeSquared",
	}
do
	assertThat(
		string.find(behaviorResolver .. enemyConfig, required, 1, true) ~= nil,
		"windup contract missing: " .. required
	)
end

for _, required in
	{
		"initializePresentationAttributes(entry)",
		"beginAttackWindup(entry, targetId, serverTimestamp)",
		"clearAttackWindup(entry)",
		"discloseCommittedAttack(entry, attack.serverTimestamp, presentationSequence)",
		"discloseCommittedHit(entry, serverTimestamp)",
		"PresentationAttributeNames.WindupSequence",
		"PresentationAttributeNames.AttackSequence",
		"PresentationAttributeNames.HitSequence",
		"PresentationLifeStateIds.Dead",
	}
do
	assertThat(string.find(director, required, 1, true) ~= nil, "server disclosure missing: " .. required)
end

for _, required in
	{
		"RunService.RenderStepped:Connect",
		"folder.DescendantAdded:Connect",
		"folder.ChildRemoved:Connect",
		"Workspace:GetServerTimeNow()",
		"PresentationAttributeNames.WindupStartedServerTimestamp",
		"PresentationAttributeNames.WindupCommitServerTimestamp",
		"behaviorStateId == BehaviorStateIds.WindingUp",
		"EnemyPresentationPoseResolver.resolve",
		"record.torsoMotor.C0 =",
		"record.sensor.Color =",
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
		"string.match",
		"Anchored =",
		"task.delay",
		"task.spawn",
	}
do
	assertThat(
		not string.find(controller, forbidden, 1, true),
		"Walker state controller must not contain network, scheduler, inference, or gameplay mutation token "
			.. forbidden
	)
end

for _, required in
	{
		'WindupEarlyLeft = "WindupEarlyLeft"',
		'WindupEarlyRight = "WindupEarlyRight"',
		'WindupLateLeft = "WindupLateLeft"',
		'WindupLateRight = "WindupLateRight"',
		"WindupLateProgress = 0.55",
		'StrikeActiveLeft = "StrikeActiveLeft"',
		'StrikeRecoveryRight = "StrikeRecoveryRight"',
		"AttackActiveSeconds = 0.16",
		"AttackRecoverySeconds = 0.52",
		'HitReaction = "HitReaction"',
		'StandDown = "StandDown"',
		'Dead = "Dead"',
		"if input.isDead then",
	}
do
	assertThat(string.find(resolver, required, 1, true) ~= nil, "Walker pose resolver missing: " .. required)
end

local requireIndex = string.find(bootstrap, "local EnemyPresentationController = require", 1, true)
local startIndex = string.find(bootstrap, "EnemyPresentationController.start()", 1, true)
assertThat(
	requireIndex ~= nil and startIndex ~= nil and requireIndex < startIndex,
	"client bootstrap must start presentation"
)
assertThat(string.find(manifest, '"serverPresentationAttributeCount": 9', 1, true) ~= nil, "manifest attribute count")
assertThat(string.find(manifest, '"clientFrameConnections": 1', 1, true) ~= nil, "manifest frame connection")
assertThat(string.find(manifest, '"connectionsPerEnemy": 0', 1, true) ~= nil, "manifest per-enemy connections")
assertThat(string.find(readme, "0.6-second server-owned windup", 1, true) ~= nil, "README windup contract")
assertThat(string.find(roadmap, "cancelable 0.6-second server-owned windup", 1, true) ~= nil, "roadmap windup")

print("ExclusionWalkerStateReadabilitySourceAudit: windup, disclosure, poses, authority, bounds, and docs passed")
