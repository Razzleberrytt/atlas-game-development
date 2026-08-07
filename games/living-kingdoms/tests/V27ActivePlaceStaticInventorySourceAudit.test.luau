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

local project = fs.readFile("games/living-kingdoms/default.project.json")
local hordeRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local hordeConfig = fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau")
local serverBootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local clientBootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local earlyListener = fs.readFile("games/living-kingdoms/src/client/State/HordeStateEarlyListener.luau")
local hordeHud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")
local massacre = fs.readFile("games/living-kingdoms/src/client/Controllers/MassacreCrescendoController.luau")
local enemyImpact = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyImpactPresentationController.luau")
local routeGuide = fs.readFile("games/living-kingdoms/src/client/Controllers/RouteGuidePresentationController.luau")
local landmarkAccent = fs.readFile("games/living-kingdoms/src/client/Controllers/LandmarkAccentPresentationController.luau")

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

-- R1 adds one early compatibility bridge while two domain listeners still exist.
-- This intentionally produces three static listeners during containment; R2/R3
-- must consolidate CL-002/CL-003 onto the bridge before compatibility removal.
assertThat(contains(earlyListener, "stateRemote.OnClientEvent:Connect(onState)"), "R1 bridge must remain a State listener")
assertThat(contains(clientBootstrap, "HordeStateEarlyListener.start()"), "R1 bridge must start from client bootstrap")
for _, listener in {
	{ name = "HordeHUDController", source = hordeHud },
	{ name = "MassacreCrescendoController", source = massacre },
} do
	assertThat(contains(listener.source, "HordeNetwork"), listener.name .. " must retain explicit HordeNetwork ownership")
	assertThat(contains(listener.source, 'WaitForChild("State")'), listener.name .. " must retain explicit State ownership")
	assertThat(
		contains(listener.source, "stateRemote.OnClientEvent:Connect"),
		listener.name .. " must remain a statically visible compatibility listener until migrated"
	)
	assertThat(
		contains(clientBootstrap, listener.name .. ".start()"),
		listener.name .. " must remain visible in application bootstrap inventory"
	)
end

-- Known-good narrow Highlight references help distinguish canonical source from
-- the still-unattributed broad blue/yellow Highlight observed in the active place.
assertThat(
	contains(enemyImpact, 'Instance.new("Highlight")'),
	"enemy impact feedback must remain explicitly inventoried as a Highlight owner"
)
assertThat(contains(enemyImpact, "highlight.Adornee = model"), "enemy impact Highlight must target one enemy model")
assertThat(not contains(enemyImpact, "highlight.Adornee = Workspace"), "enemy impact Highlight must never target Workspace")
assertThat(
	contains(hordeRuntime, 'created.Name = "HordeRoleHighlight"'),
	"horde role Highlight reference must remain inventoried"
)
assertThat(contains(hordeRuntime, "created.Adornee = record.model"), "horde role Highlight must target one enemy model")
assertThat(contains(hordeRuntime, "created.FillTransparency = 1"), "persistent role Highlight fill must stay invisible")
assertThat(contains(hordeRuntime, "created.OutlineTransparency = 1"), "persistent role Highlight outline must stay invisible")

-- Canonical route and landmark presentation currently use bounded geometry,
-- not Highlights. A broad route/landmark Highlight seen in Studio therefore
-- requires active-place/stale-source attribution rather than assumption.
assertThat(not contains(routeGuide, 'Instance.new("Highlight")'), "route guide must not allocate Highlights")
assertThat(not contains(landmarkAccent, 'Instance.new("Highlight")'), "landmark accents must not allocate Highlights")

print("V27ActivePlaceStaticInventorySourceAudit: canonical producer, three containment listeners, and narrow Highlight facts locked")
