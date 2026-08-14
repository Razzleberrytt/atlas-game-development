--!strict

--[[
	Blueprint v2.7 repository-side inventory checkpoint.

	This audit records only facts that can be proven from canonical source. It is
	not Studio/runtime evidence and must not be used to promote the project above
	E1 or to claim that the active-place queue/highlight incident is closed.
]]

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function count(source: string, token: string): number
	local occurrences = 0
	local startIndex = 1
	while true do
		local found = string.find(source, token, startIndex, true)
		if found == nil then
			return occurrences
		end
		occurrences += 1
		startIndex = found + #token
	end
end

local function luauFilesUnder(root: string, collected: { string }): { string }
	for _, entry in fs.readDir(root) do
		local path = root .. "/" .. entry
		if fs.isDir(path) then
			luauFilesUnder(path, collected)
		elseif string.sub(entry, -5) == ".luau" then
			table.insert(collected, path)
		end
	end
	return collected
end

local project = fs.readFile("games/living-kingdoms/default.project.json")
local hordeRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local hordeConfig = fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local earlyListener = fs.readFile("games/living-kingdoms/src/client/State/HordeStateEarlyListener.luau")
local hordeHud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")
local massacre = fs.readFile("games/living-kingdoms/src/client/Controllers/MassacreCrescendoController.luau")
local ambience = fs.readFile("games/living-kingdoms/src/client/Controllers/EnvironmentAmbienceController.luau")
local enemyImpact = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyImpactPresentationController.luau")
local routeGuide = fs.readFile("games/living-kingdoms/src/client/Controllers/RouteGuidePresentationController.luau")
local landmarkAccent =
	fs.readFile("games/living-kingdoms/src/client/Controllers/LandmarkAccentPresentationController.luau")

-- Static RemoteEvent mapping and the confirmed canonical producer.
assertThat(contains(project, '"HordeNetwork"'), "Rojo mapping must retain HordeNetwork")
assertThat(contains(project, '"State"'), "Rojo mapping must retain HordeNetwork.State")
assertThat(
	contains(hordeRuntime, 'local stateRemote = network:WaitForChild("State") :: RemoteEvent'),
	"HordeExperienceService must identify the legacy State remote explicitly"
)
assertThat(contains(hordeRuntime, "stateRemote:FireClient(player"), "legacy State producer must remain inventoried")
assertThat(contains(hordeRuntime, "local function publishAll"), "periodic legacy publisher must remain inventoried")
assertThat(contains(hordeRuntime, "revision += 1"), "legacy revision behavior must remain visible to the audit")
assertThat(
	contains(hordeRuntime, "HordeConfig.Pressure.StatePublishIntervalSeconds"),
	"legacy timed publish cadence must remain inventoried"
)
assertThat(
	contains(hordeConfig, "StatePublishIntervalSeconds = 0.5"),
	"static baseline must retain the current 0.5-second authored publish interval until deliberately migrated"
)
assertThat(
	contains(serverBootstrap, "HordeExperienceService.start()"),
	"server bootstrap must expose whether the legacy publisher is started"
)

-- Post-R1 preparation target: one physical compatibility RemoteEvent listener in
-- HordeStateEarlyListener, with domain controllers subscribing to its local
-- application bridge. This branch is not runtime-accepted merely because the
-- source shape is prepared.
assertThat(
	contains(earlyListener, "stateRemote.OnClientEvent:Connect(onState)"),
	"bridge must remain the physical State listener"
)
assertThat(
	contains(earlyListener, "function HordeStateEarlyListener.subscribe"),
	"bridge must expose local subscriptions"
)
assertThat(
	contains(earlyListener, "function HordeStateEarlyListener.getActiveListenerCount"),
	"bridge must expose its real RemoteEvent listener count"
)
assertThat(
	contains(earlyListener, "activeListenerCount += 1"),
	"bridge must increment its counter only after connecting the RemoteEvent"
)
assertThat(
	contains(earlyListener, "activeListenerCount -= 1"),
	"bridge must decrement its counter when disconnecting the RemoteEvent"
)
assertThat(
	contains(earlyListener, 'SetAttribute("V27_EarlyStateListenerCount", listenerCount)'),
	"bridge must publish the listener count for Studio evidence"
)
assertThat(
	count(earlyListener, "OnClientEvent:Connect") == 1,
	"bridge must own exactly one physical RemoteEvent connection"
)
assertThat(contains(earlyListener, "if started then"), "bridge start must be idempotent")
assertThat(contains(earlyListener, "if not started then"), "bridge stop must be idempotent")
assertThat(
	contains(earlyListener, "latestSnapshot = message"),
	"bridge must retain the latest valid snapshot for replay"
)
assertThat(
	contains(earlyListener, "task.defer(callback, snapshot)"),
	"late bridge subscribers must receive the retained snapshot"
)
assertThat(contains(clientBootstrap, "HordeStateEarlyListener.start()"), "bridge must start from client bootstrap")
for _, listener in
	{
		{ name = "HordeHUDController", source = hordeHud, callback = "onState", active = true },
		{ name = "MassacreCrescendoController", source = massacre, callback = "onState", active = false },
		{ name = "EnvironmentAmbienceController", source = ambience, callback = "onHordeState", active = true },
	}
do
	assertThat(
		contains(listener.source, "HordeStateEarlyListener"),
		listener.name .. " must consume horde state through the application bridge"
	)
	assertThat(
		contains(listener.source, "HordeStateEarlyListener.subscribe(" .. listener.callback .. ")"),
		listener.name .. " must subscribe its existing state handler through the bridge"
	)
	assertThat(
		not contains(listener.source, "stateRemote.OnClientEvent:Connect"),
		listener.name .. " must not bind State directly"
	)
	assertThat(
		not contains(listener.source, 'WaitForChild("HordeNetwork"'),
		listener.name .. " must not own HordeNetwork transport"
	)
	assertThat(
		count(listener.source, "HordeStateEarlyListener.subscribe(" .. listener.callback .. ")") == 1,
		listener.name .. " must own exactly one bridge subscription call site"
	)
	if listener.active then
		assertThat(
			contains(clientBootstrap, listener.name .. ".start()"),
			listener.name .. " must remain visible in application bootstrap inventory"
		)
	else
		assertThat(
			not contains(clientBootstrap, listener.name),
			listener.name .. " must remain disabled at application bootstrap"
		)
	end
end

local earlyListenerPath = "games/living-kingdoms/src/client/State/HordeStateEarlyListener.luau"
for _, path in luauFilesUnder("games/living-kingdoms/src/client", {}) do
	local source = fs.readFile(path)
	if path == earlyListenerPath then
		assertThat(contains(source, 'WaitForChild("HordeNetwork"'), "bridge must own HordeNetwork transport")
	else
		assertThat(
			not contains(source, 'WaitForChild("HordeNetwork"'),
			"only HordeStateEarlyListener may resolve HordeNetwork transport: " .. path
		)
	end
end

-- Known-good narrow Highlight references help distinguish canonical source from
-- the still-unattributed broad blue/yellow Highlight observed in the active place.
assertThat(
	contains(enemyImpact, 'Instance.new("Highlight")'),
	"enemy impact feedback must remain explicitly inventoried as a Highlight owner"
)
assertThat(contains(enemyImpact, "highlight.Adornee = model"), "enemy impact Highlight must target one enemy model")
assertThat(
	not contains(enemyImpact, "highlight.Adornee = Workspace"),
	"enemy impact Highlight must never target Workspace"
)
assertThat(
	contains(hordeRuntime, 'created.Name = "HordeRoleHighlight"'),
	"horde role Highlight reference must remain inventoried"
)
assertThat(contains(hordeRuntime, "created.Adornee = record.model"), "horde role Highlight must target one enemy model")
assertThat(contains(hordeRuntime, "created.FillTransparency = 1"), "persistent role Highlight fill must stay invisible")
assertThat(
	contains(hordeRuntime, "created.OutlineTransparency = 1"),
	"persistent role Highlight outline must stay invisible"
)

-- Canonical route and landmark presentation currently use bounded geometry,
-- not Highlights. A broad route/landmark Highlight seen in Studio therefore
-- requires active-place/stale-source attribution rather than assumption.
assertThat(not contains(routeGuide, 'Instance.new("Highlight")'), "route guide must not allocate Highlights")
assertThat(not contains(landmarkAccent, 'Instance.new("Highlight")'), "landmark accents must not allocate Highlights")

print(
	"V27ActivePlaceStaticInventorySourceAudit: one physical State listener, bridge consumers, and narrow Highlight facts locked"
)
