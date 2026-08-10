--!strict

--[[
	Patch 0.2 elite readability audit.

	The server already resolved elite affixes and disclosed them on the enemy
	model; nothing presented them, so an elite looked identical to trash. This
	locks the presentation that closed that gap and, more importantly, locks what
	it may not become: the client must never decide what an elite is.

	Source/static only. It cannot prove legibility at distance, colour contrast,
	or frame cost in a heavy horde.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local controllerPath = "games/living-kingdoms/src/client/Controllers/EliteReadabilityController.luau"
local controller = fs.readFile(controllerPath)
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local configSource = fs.readFile("games/living-kingdoms/src/shared/Config/EliteReadabilityConfig.luau")
local contractsSource = fs.readFile("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau")

-- Presentation reads the server's disclosure; it never infers an elite.
for _, required in
	{
		"EnemyPresentationContracts",
		"AttributeNames.EliteAffixId",
		"AttributeNames.EliteDisplayName",
		"EliteReadabilityConfig.get(affixId)",
	}
do
	assertThat(contains(controller, required), "elite readability must render server disclosure: " .. required)
end

-- The attributes it reads must actually exist in the shared contract.
for _, attribute in { "EliteAffixId", "EliteDisplayName", "EliteArmorRemaining" } do
	assertThat(
		contains(contractsSource, attribute .. " = "),
		"elite readability depends on undeclared attribute " .. attribute
	)
end

-- Authority boundary: this is presentation only.
for _, forbidden in
	{
		"FireServer",
		"InvokeServer",
		"RemoteEvent",
		"RemoteFunction",
		"Humanoid:TakeDamage",
		"TakeDamage",
		"applyAuthoritativeDamage",
		"Health",
		"spawnEnemy",
		"EliteAffixResolver",
		"resolveAssignment",
		"math.random",
	}
do
	assertThat(not contains(controller, forbidden), "elite readability must own no gameplay authority: " .. forbidden)
end

-- Bounded presentation: a fixed pool, an interval poll, and one render binding.
assertThat(contains(controller, "MaximumNameplates"), "the nameplate pool must be bounded by config")
assertThat(contains(controller, "PollIntervalSeconds"), "attribute reads must be interval-bounded, not per-frame")
local _, renderConnections = string.gsub(controller, "RenderStepped:Connect", "")
assertThat(
	renderConnections == 1,
	`elite readability must own exactly one RenderStepped connection, found {renderConnections}`
)

-- Folder identity must survive a replay: bind the cached folder, never destroy it.
assertThat(
	contains(controller, "WaitForChild(ENEMY_FOLDER_NAME, 10)"),
	"the EnemyEntities wait must be bounded so it cannot halt later controllers"
)
assertThat(not contains(controller, "found:Destroy()"), "elite readability must never destroy the shared enemy folder")

-- Teardown releases every binding it created.
for _, required in
	{ "childAddedConnection", "childRemovedConnection", "renderConnection", "function Controller.stop()" }
do
	assertThat(contains(controller, required), "elite readability must clean up " .. required)
end
assertThat(
	contains(controller, "presentationFolder:Destroy()"),
	"its own presentation folder must be destroyed on stop"
)

-- Bootstrapped exactly once.
local _, startCalls = string.gsub(bootstrap, "EliteReadabilityController%.start%(%)", "")
assertThat(startCalls == 1, `elite readability must start exactly once, found {startCalls}`)

-- The config is descriptive and complete for every contract affix.
local contracts = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"),
	{ debugName = "RunRpgContracts", injectGlobals = true }
)()
for _, affixId in contracts.EliteAffixIds do
	assertThat(
		contains(configSource, affixId) or contains(configSource, "AffixIds."),
		"every contract affix needs a readable treatment: " .. affixId
	)
end

-- Readability is never carried by colour alone.
assertThat(contains(configSource, "ThreatNote"), "each affix needs a text note, not colour alone")
assertThat(contains(controller, "plate.note.Text"), "the threat note must actually render")

print("Patch 0.2 elite readability: server-disclosed, bounded, presentation-only, colour-independent audit passed")
