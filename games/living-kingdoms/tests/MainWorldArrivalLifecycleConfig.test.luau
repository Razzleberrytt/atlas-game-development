--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldArrivalLifecycleConfig assertion failed", 2)
	end
end

local function loadConfig(name: string)
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/" .. name .. ".luau"), {
		debugName = name,
		injectGlobals = true,
	})()
end

local lifecycle = loadConfig("MainWorldLifecycleConfig")
local arrival = loadConfig("RecoveredSpawnLocationConfig")
local portal = loadConfig("RecoveredDungeonPortalConfig")
local composition = loadConfig("MainWorldHubCoreCompositionConfig")
local bootstrap = loadConfig("MainWorldBootstrapAllowlistConfig")
local project = serde.decode("json", fs.readFile("games/living-kingdoms/main-world.project.json"))
local model =
	serde.decode("json", fs.readFile("games/living-kingdoms/assets/recovered-world/models/MainWorldArrival.model.json"))

check(lifecycle.Version == "P0.5-MAIN-WORLD-LIFECYCLE-v1")
check(lifecycle.RuntimeEnabled == false)
check(lifecycle.DedicatedMainWorldOnly == true)
check(lifecycle.InitialStateId == lifecycle.StateIds.Arrival)
check(lifecycle.Arrival.ColdJoinStartsHere == true)
check(lifecycle.Arrival.ContentId == arrival.SourceContentId)
check(lifecycle.Arrival.SourceContractVersion == arrival.Version)
check(lifecycle.Arrival.TargetPath == "Workspace/LivingKingdomsMainWorld/HubCore/Arrival/SpawnLocation")
check(lifecycle.Arrival.PreparationStateId == lifecycle.StateIds.Preparation)

check(lifecycle.ExpeditionGate.ContentId == portal.Interaction.CanonicalContentId)
check(lifecycle.ExpeditionGate.SourceContractVersion == portal.Version)
check(lifecycle.ExpeditionGate.CanonicalLaunchAuthority == portal.Interaction.CanonicalAuthority)
check(lifecycle.ExpeditionGate.LaunchStateId == lifecycle.StateIds.Expedition)

check(lifecycle.Debrief.StateId == lifecycle.StateIds.Debrief)
check(lifecycle.Debrief.CanonicalResultAuthority == "ExpeditionResultService")
check(lifecycle.Debrief.CanonicalReplayDecisionAuthority == "ExpeditionResultService")
check(lifecycle.Debrief.ReturnDecisionId == "ReturnToPreparation")
check(lifecycle.Debrief.ReplayDecisionId == "Replay")
check(lifecycle.Debrief.ReturnStateId == lifecycle.StateIds.Preparation)
check(lifecycle.OutcomeRouting.Completed.NextStateId == lifecycle.StateIds.Debrief)
check(lifecycle.OutcomeRouting.Failed.NextStateId == lifecycle.StateIds.Debrief)
check(lifecycle.OutcomeRouting.Abandoned.NextStateId == lifecycle.StateIds.Debrief)

check(lifecycle.Transport.PolicyDefined == false)
check(lifecycle.Transport.RequiresAuthorizedPublishedPlaceIds == true)
check(lifecycle.Transport.TeleportAuthorityOwnedHere == false)
check(lifecycle.Rules.LaunchRequiresCanonicalLobbyAcceptance == true)
check(lifecycle.Rules.ResultMustFinalizeBeforeDebriefDecision == true)
check(lifecycle.Rules.SuccessAndFailureShareDebriefPath == true)
check(lifecycle.Rules.ReplayDecisionMustUseCanonicalResultOwner == true)
check(lifecycle.Rules.ClientConsequentialAuthorityAllowed == false)
check(lifecycle.Rules.NoTransportGuessing == true)

local arrivalComponent = composition.componentById(arrival.SourceContentId)
check(arrivalComponent ~= nil)
check(arrivalComponent.sourcePath == arrival.SourcePath)
check(arrivalComponent.targetRelativePath == "Arrival/SpawnLocation")
check(bootstrap.RuntimeEnabled == false)

check(model.ClassName == "SpawnLocation")
local properties = model.Properties
check(properties.Anchored == arrival.Spawn.anchored)
check(properties.CanCollide == arrival.Spawn.canCollide)
check(properties.CanQuery == arrival.Spawn.canQuery)
check(properties.CanTouch == arrival.Spawn.canTouch)
check(properties.CastShadow == arrival.Spawn.castShadow)
check(properties.CFrame[1] == arrival.Spawn.position.x)
check(properties.CFrame[2] == arrival.Spawn.position.y)
check(properties.CFrame[3] == arrival.Spawn.position.z)
check(properties.Size[1] == arrival.Spawn.size.x)
check(properties.Size[2] == arrival.Spawn.size.y)
check(properties.Size[3] == arrival.Spawn.size.z)
check(properties.Material.Enum == arrival.Spawn.materialEnumValue)
check(properties.Shape.Enum == arrival.Spawn.shapeEnumValue)
check(properties.Reflectance == arrival.Spawn.reflectance)
check(properties.Transparency == arrival.Spawn.transparency)
check(properties.Enabled == arrival.Spawn.enabled)
check(properties.Neutral == arrival.Spawn.neutral)
check(properties.TeamColor.BrickColor == arrival.Spawn.teamColorEnumValue)

local hubCore = project.tree.Workspace.LivingKingdomsMainWorld.HubCore
local expectedHubCorePath =
	"assets/recovered-world/models/main-world-studio-2026-08-11/MainWorld-HubCore.model.json"
check(hubCore["$path"] == expectedHubCorePath)
check(project.placeId == nil and project.gameId == nil and project.servePlaceIds == nil)
