--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldHubCoreReadabilityConfig assertion failed", 2)
	end
end

local function loadConfig(name: string)
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/" .. name .. ".luau"), {
		debugName = name,
		injectGlobals = true,
	})()
end

local function resolveRelativePath(root: any, relativePath: string): any?
	local cursor = root
	for segment in string.gmatch(relativePath, "[^/]+") do
		if type(cursor) ~= "table" then
			return nil
		end
		cursor = cursor[segment]
	end
	return cursor
end

local composition = loadConfig("MainWorldHubCoreCompositionConfig")
local readability = loadConfig("MainWorldHubCoreReadabilityConfig")
local project = serde.decode("json", fs.readFile("games/living-kingdoms/main-world.project.json"))
local hubCore = project.tree.Workspace.LivingKingdomsMainWorld.HubCore

check(composition.ContentId == "main_world.hub_core")
check(composition.StreamingGroupId == "main_world.hub_core")
check(composition.RuntimeEnabled == false)
check(composition.SourceHold == true)
check(composition.DedicatedMainWorldOnly == true)
check(composition.OperationProjectMappingAllowed == false)
check(composition.Rules.StableSemanticIdsRequired == true)
check(composition.Rules.MissingInstancesDoNotChangeGameplayTruth == true)

check(readability.CompositionVersion == composition.Version)
check(readability.CoordinateSpaceId == composition.CoordinateSpaceId)
check(readability.StreamingGroupId == composition.StreamingGroupId)
check(readability.RuntimeEnabled == false)
check(readability.SourceHold == true)
check(readability.StudioEvidenceRequired == true)
check(readability.StudioEvidenceStatus == "PENDING")
check(#readability.Nodes == #composition.Components)

local seenIds = {}
local seenTargets = {}
for _, component in composition.Components do
	check(seenIds[component.id] == nil, "duplicate semantic id: " .. component.id)
	check(seenTargets[component.targetRelativePath] == nil, "duplicate target: " .. component.targetRelativePath)
	seenIds[component.id] = true
	seenTargets[component.targetRelativePath] = true

	local node = readability.nodeById(component.id)
	check(node ~= nil, "missing readability node: " .. component.id)
	check(node.role == component.role, "role drift: " .. component.id)
	check(node.targetRelativePath == component.targetRelativePath, "target drift: " .. component.id)
	check(node.instancePresenceRequiredForConsequentialTruth == false, "instance truth coupling: " .. component.id)

	local projectTarget = resolveRelativePath(hubCore, component.targetRelativePath)
	check(projectTarget ~= nil, "project target missing: " .. component.targetRelativePath)
	check(type(projectTarget["$path"]) == "string", "project target is not source-managed: " .. component.id)

	local sourceContract = loadConfig(component.sourceContractModule)
	check(sourceContract.Version == component.sourceContractVersion, "source contract version drift: " .. component.id)
end

check(composition.componentById("portal.expedition.primary").targetRelativePath == "ExpeditionGate/DungeonPortal")
check(composition.componentById("portal.expedition.primary").canonicalGameplayAuthority == "ExpeditionLobbyService")
check(composition.Authority.ExpeditionGameplayOwner == "ExpeditionLobbyService")
check(composition.Authority.RecoveredGameplayAuthorityAllowed == false)
check(composition.Authority.LegacyBootstrapAllowed == false)
check(composition.Authority.WorldFoundationServiceAllowed == false)

check(readability.SourceEvaluableExpectations.StableSemanticIds == true)
check(readability.SourceEvaluableExpectations.SingleBoundedStreamingGroup == true)
check(readability.SourceEvaluableExpectations.ProjectTargetsMustMatchComposition == true)
check(readability.SourceEvaluableExpectations.LocallyAbsentInstancesPreserveGameplayTruth == true)
check(readability.SourceEvaluableExpectations.PortalPresentationDoesNotOwnLaunchAuthority == true)

for expectation, status in readability.PendingStudioExpectations do
	check(status == "PENDING", expectation .. " must remain pending until evidence is run")
end

check(readability.Rules.DoNotMoveAuthoredGeometryForSourceReadabilityChecks == true)
check(readability.Rules.DoNotInventNumericAcceptanceThresholds == true)
check(readability.Rules.DoNotPromotePendingStudioEvidenceToPass == true)
check(readability.Rules.ResolvePresentationByStableSemanticId == true)
check(readability.Rules.ConsequentialGameplayTruthMustRemainCanonical == true)
check(project.placeId == nil and project.gameId == nil and project.servePlaceIds == nil)
