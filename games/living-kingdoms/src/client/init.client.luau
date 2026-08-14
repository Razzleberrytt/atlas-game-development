--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeRolloutConfig = require(ReplicatedStorage.Shared.Config.RuntimeRolloutConfig)

--[[
	Controller isolation.

	The bootstrap requires ~50 controllers and starts them in a deliberate order,
	and it used to do both bare. One controller erroring during require -- or
	during start -- took every controller after it with it, which is how a client
	ends up with a single PlayerGui child instead of the ~22 a healthy session
	has. The order still carries meaning, so nothing here reorders or defers
	anything; a failure is contained to the controller that caused it and named.
]]
local failedControllers: { string } = {}

local function safeRequire(name: string, loader: () -> any): any?
	local ok, moduleOrError = pcall(loader)
	if ok then
		return moduleOrError
	end
	table.insert(failedControllers, name)
	warn(string.format("[Client] controller %s failed to load: %s", name, tostring(moduleOrError)))
	return nil
end

--[[
	The call itself stays written out at each site rather than being reached
	through a method name. Several source audits pin the exact `X.start()` token
	to prove a controller is actually started, and routing the call through a
	string would make those audits pass while proving nothing.
]]
local function safeStep(name: string, step: () -> ())
	local ok, err = pcall(step)
	if not ok then
		table.insert(failedControllers, name)
		warn(string.format("[Client] controller step %s failed: %s", name, tostring(err)))
	end
end

-- Blueprint v2.7 R1: bind the legacy HordeNetwork.State compatibility listener
-- before requiring the rest of the client controller graph. This closes the
-- startup window where server publishes could accumulate with no listener.
if RuntimeRolloutConfig.EnableEarlyStateListener then
	local HordeStateEarlyListener = safeRequire("HordeStateEarlyListener", function()
		return require(script.State.HordeStateEarlyListener)
	end)
	safeStep("HordeStateEarlyListener.start", function()
		if HordeStateEarlyListener ~= nil then
			HordeStateEarlyListener.start()
		end
	end)
end

-- Blueprint v2.7 incident containment: reject only obviously broad Highlight
-- targets before the rest of the presentation graph starts.
if RuntimeRolloutConfig.RejectBroadHighlightTargets then
	local BroadHighlightGuardController = safeRequire("BroadHighlightGuardController", function()
		return require(script.Presentation.BroadHighlightGuardController)
	end)
	safeStep("BroadHighlightGuardController.start", function()
		if BroadHighlightGuardController ~= nil then
			BroadHighlightGuardController.start()
		end
	end)
end

local CameraController = safeRequire("CameraController", function()
	return require(script.Controllers.CameraController)
end)
local SurvivorController = safeRequire("SurvivorController", function()
	return require(script.Controllers.SurvivorController)
end)
local MobileControlsController = safeRequire("MobileControlsController", function()
	return require(script.Controllers.MobileControlsController)
end)
local WeaponController = safeRequire("WeaponController", function()
	return require(script.Controllers.WeaponController)
end)
local PrimaryAttackModeController = safeRequire("PrimaryAttackModeController", function()
	return require(script.Controllers.PrimaryAttackModeController)
end)
local WeaponPresentationController = safeRequire("WeaponPresentationController", function()
	return require(script.Controllers.WeaponPresentationController)
end)
local MeleePresentationController = safeRequire("MeleePresentationController", function()
	return require(script.Controllers.MeleePresentationController)
end)
local WeaponAudioController = safeRequire("WeaponAudioController", function()
	return require(script.Controllers.WeaponAudioController)
end)
local ConfirmedHitMarkerController = safeRequire("ConfirmedHitMarkerController", function()
	return require(script.Controllers.ConfirmedHitMarkerController)
end)
local FloatingDamageTextController = safeRequire("FloatingDamageTextController", function()
	return require(script.Controllers.FloatingDamageTextController)
end)
local OperativeCarryPresentationController = safeRequire("OperativeCarryPresentationController", function()
	return require(script.Controllers.OperativeCarryPresentationController)
end)
local OperativeHelmetController = safeRequire("OperativeHelmetController", function()
	return require(script.Controllers.OperativeHelmetController)
end)
local EnemyPresentationController = safeRequire("EnemyPresentationController", function()
	return require(script.Controllers.EnemyPresentationController)
end)
local EnemyImpactPresentationController = safeRequire("EnemyImpactPresentationController", function()
	return require(script.Controllers.EnemyImpactPresentationController)
end)
local EnemyAudioController = safeRequire("EnemyAudioController", function()
	return require(script.Controllers.EnemyAudioController)
end)
local AmmunitionCachePresentationController = safeRequire("AmmunitionCachePresentationController", function()
	return require(script.Controllers.AmmunitionCachePresentationController)
end)
local ClassSelectionController = safeRequire("ClassSelectionController", function()
	return require(script.Controllers.ClassSelectionController)
end)
local ClassActionController = safeRequire("ClassActionController", function()
	return require(script.Controllers.ClassActionController)
end)
local WeaponSelectionController = safeRequire("WeaponSelectionController", function()
	return require(script.Controllers.WeaponSelectionController)
end)
local ClassSilhouetteController = safeRequire("ClassSilhouetteController", function()
	return require(script.Controllers.ClassSilhouetteController)
end)
local ClassSquadPresentationController = safeRequire("ClassSquadPresentationController", function()
	return require(script.Controllers.ClassSquadPresentationController)
end)
local OperativeLifeController = safeRequire("OperativeLifeController", function()
	return require(script.Controllers.OperativeLifeController)
end)
local OperativeLifeWorldPresentationController = safeRequire("OperativeLifeWorldPresentationController", function()
	return require(script.Controllers.OperativeLifeWorldPresentationController)
end)
local PersonalFlashlightController = safeRequire("PersonalFlashlightController", function()
	return require(script.Controllers.PersonalFlashlightController)
end)
local SquadPingController = safeRequire("SquadPingController", function()
	return require(script.Controllers.SquadPingController)
end)
local EnvironmentAmbienceController = safeRequire("EnvironmentAmbienceController", function()
	return require(script.Controllers.EnvironmentAmbienceController)
end)
local RouteGuidePresentationController = safeRequire("RouteGuidePresentationController", function()
	return require(script.Controllers.RouteGuidePresentationController)
end)
local LandmarkAccentPresentationController = safeRequire("LandmarkAccentPresentationController", function()
	return require(script.Controllers.LandmarkAccentPresentationController)
end)
local MatchResultController = safeRequire("MatchResultController", function()
	return require(script.Controllers.MatchResultController)
end)
local MissionController = safeRequire("MissionController", function()
	return require(script.Controllers.MissionController)
end)
local MissionObjectPresentationController = safeRequire("MissionObjectPresentationController", function()
	return require(script.Controllers.MissionObjectPresentationController)
end)
local ExpeditionLobbyController = safeRequire("ExpeditionLobbyController", function()
	return require(script.Controllers.ExpeditionLobbyController)
end)
local ExpeditionHUDController = safeRequire("ExpeditionHUDController", function()
	return require(script.Controllers.ExpeditionHUDController)
end)
local ExpeditionResultController = safeRequire("ExpeditionResultController", function()
	return require(script.Controllers.ExpeditionResultController)
end)
local ExpeditionReturnController = safeRequire("ExpeditionReturnController", function()
	return require(script.Controllers.ExpeditionReturnController)
end)
local ExpeditionLifecycleVisibilityController = safeRequire("ExpeditionLifecycleVisibilityController", function()
	return require(script.Controllers.ExpeditionLifecycleVisibilityController)
end)
local ExpeditionEnvironmentAnimationController = safeRequire("ExpeditionEnvironmentAnimationController", function()
	return require(script.Controllers.ExpeditionEnvironmentAnimationController)
end)
local ExpeditionAtmosphereController = safeRequire("ExpeditionAtmosphereController", function()
	return require(script.Controllers.ExpeditionAtmosphereController)
end)
local ExpeditionRoomRevealController = safeRequire("ExpeditionRoomRevealController", function()
	return require(script.Controllers.ExpeditionRoomRevealController)
end)
local ExpeditionEncounterBarrierController = safeRequire("ExpeditionEncounterBarrierController", function()
	return require(script.Controllers.ExpeditionEncounterBarrierController)
end)
local HordeHUDController = safeRequire("HordeHUDController", function()
	return require(script.Controllers.HordeHUDController)
end)
local HordeEffectsController = safeRequire("HordeEffectsController", function()
	return require(script.Controllers.HordeEffectsController)
end)
local HordeSpecialTelegraphController = safeRequire("HordeSpecialTelegraphController", function()
	return require(script.Controllers.HordeSpecialTelegraphController)
end)
local SpecialEncounterTelegraphController = safeRequire("SpecialEncounterTelegraphController", function()
	return require(script.Controllers.SpecialEncounterTelegraphController)
end)
local EliteReadabilityController = safeRequire("EliteReadabilityController", function()
	return require(script.Controllers.EliteReadabilityController)
end)
local RunBuildHUDController = safeRequire("RunBuildHUDController", function()
	return require(script.Controllers.RunBuildHUDController)
end)
local CriticalConditionController = safeRequire("CriticalConditionController", function()
	return require(script.Controllers.CriticalConditionController)
end)
local PresentationSettingsController = safeRequire("PresentationSettingsController", function()
	return require(script.Controllers.PresentationSettingsController)
end)
local SurvivalHUDController = safeRequire("SurvivalHUDController", function()
	return require(script.Controllers.SurvivalHUDController)
end)
local RPGMenuController = safeRequire("RPGMenuController", function()
	return require(script.Controllers.RPGMenuController)
end)
local OperativeProgressionPresentationController = safeRequire("OperativeProgressionPresentationController", function()
	return require(script.Controllers.OperativeProgressionPresentationController)
end)
local HubPreparationController = safeRequire("HubPreparationController", function()
	return require(script.Controllers.HubPreparationController)
end)

safeStep("CameraController.init", function()
	if CameraController ~= nil then
		CameraController.init()
	end
end)
safeStep("CameraController.start", function()
	if CameraController ~= nil then
		CameraController.start()
	end
end)
safeStep("SurvivorController.init", function()
	if SurvivorController ~= nil then
		SurvivorController.init()
	end
end)
safeStep("SurvivorController.start", function()
	if SurvivorController ~= nil then
		SurvivorController.start()
	end
end)
safeStep("WeaponController.init", function()
	if WeaponController ~= nil then
		WeaponController.init()
	end
end)
safeStep("WeaponController.start", function()
	if WeaponController ~= nil then
		WeaponController.start()
	end
end)
safeStep("PrimaryAttackModeController.start", function()
	if PrimaryAttackModeController ~= nil then
		PrimaryAttackModeController.start()
	end
end)
safeStep("MobileControlsController.start", function()
	if MobileControlsController ~= nil then
		MobileControlsController.start()
	end
end)
safeStep("WeaponPresentationController.start", function()
	if WeaponPresentationController ~= nil then
		WeaponPresentationController.start()
	end
end)
safeStep("MeleePresentationController.start", function()
	if MeleePresentationController ~= nil then
		MeleePresentationController.start()
	end
end)
safeStep("WeaponAudioController.start", function()
	if WeaponAudioController ~= nil then
		WeaponAudioController.start()
	end
end)
safeStep("ConfirmedHitMarkerController.start", function()
	if ConfirmedHitMarkerController ~= nil then
		ConfirmedHitMarkerController.start()
	end
end)
safeStep("FloatingDamageTextController.start", function()
	if FloatingDamageTextController ~= nil then
		FloatingDamageTextController.start()
	end
end)
safeStep("OperativeCarryPresentationController.start", function()
	if OperativeCarryPresentationController ~= nil then
		OperativeCarryPresentationController.start()
	end
end)
safeStep("OperativeHelmetController.start", function()
	if OperativeHelmetController ~= nil then
		OperativeHelmetController.start()
	end
end)
safeStep("EnemyPresentationController.start", function()
	if EnemyPresentationController ~= nil then
		EnemyPresentationController.start()
	end
end)
safeStep("EnemyImpactPresentationController.start", function()
	if EnemyImpactPresentationController ~= nil then
		EnemyImpactPresentationController.start()
	end
end)
safeStep("EnemyAudioController.start", function()
	if EnemyAudioController ~= nil then
		EnemyAudioController.start()
	end
end)
safeStep("AmmunitionCachePresentationController.start", function()
	if AmmunitionCachePresentationController ~= nil then
		AmmunitionCachePresentationController.start()
	end
end)
safeStep("OperativeLifeController.start", function()
	if OperativeLifeController ~= nil then
		OperativeLifeController.start()
	end
end)
safeStep("PersonalFlashlightController.start", function()
	if PersonalFlashlightController ~= nil then
		PersonalFlashlightController.start()
	end
end)
safeStep("SquadPingController.start", function()
	if SquadPingController ~= nil then
		SquadPingController.start()
	end
end)
safeStep("EnvironmentAmbienceController.start", function()
	if EnvironmentAmbienceController ~= nil then
		EnvironmentAmbienceController.start()
	end
end)
safeStep("ExpeditionEnvironmentAnimationController.start", function()
	if ExpeditionEnvironmentAnimationController ~= nil then
		ExpeditionEnvironmentAnimationController.start()
	end
end)
safeStep("ExpeditionAtmosphereController.start", function()
	if ExpeditionAtmosphereController ~= nil then
		ExpeditionAtmosphereController.start()
	end
end)
safeStep("ExpeditionRoomRevealController.start", function()
	if ExpeditionRoomRevealController ~= nil then
		ExpeditionRoomRevealController.start()
	end
end)
safeStep("ExpeditionEncounterBarrierController.start", function()
	if ExpeditionEncounterBarrierController ~= nil then
		ExpeditionEncounterBarrierController.start()
	end
end)
safeStep("RouteGuidePresentationController.start", function()
	if RouteGuidePresentationController ~= nil then
		RouteGuidePresentationController.start()
	end
end)
safeStep("LandmarkAccentPresentationController.start", function()
	if LandmarkAccentPresentationController ~= nil then
		LandmarkAccentPresentationController.start()
	end
end)
safeStep("MissionController.start", function()
	if MissionController ~= nil then
		MissionController.start()
	end
end)
safeStep("MatchResultController.start", function()
	if MatchResultController ~= nil then
		MatchResultController.start()
	end
end)
safeStep("MissionObjectPresentationController.start", function()
	if MissionObjectPresentationController ~= nil then
		MissionObjectPresentationController.start()
	end
end)
safeStep("ExpeditionLobbyController.start", function()
	if ExpeditionLobbyController ~= nil then
		ExpeditionLobbyController.start()
	end
end)
safeStep("ExpeditionHUDController.start", function()
	if ExpeditionHUDController ~= nil then
		ExpeditionHUDController.start()
	end
end)
safeStep("ExpeditionResultController.start", function()
	if ExpeditionResultController ~= nil then
		ExpeditionResultController.start()
	end
end)
safeStep("ExpeditionReturnController.start", function()
	if ExpeditionReturnController ~= nil then
		ExpeditionReturnController.start()
	end
end)
safeStep("ExpeditionLifecycleVisibilityController.start", function()
	if ExpeditionLifecycleVisibilityController ~= nil then
		ExpeditionLifecycleVisibilityController.start()
	end
end)
safeStep("HordeHUDController.start", function()
	if HordeHUDController ~= nil then
		HordeHUDController.start()
	end
end)
safeStep("SurvivalHUDController.start", function()
	if SurvivalHUDController ~= nil then
		SurvivalHUDController.start()
	end
end)
safeStep("RPGMenuController.start", function()
	if RPGMenuController ~= nil then
		RPGMenuController.start()
	end
end)
safeStep("OperativeProgressionPresentationController.start", function()
	if OperativeProgressionPresentationController ~= nil then
		OperativeProgressionPresentationController.start()
	end
end)
safeStep("HordeEffectsController.start", function()
	if HordeEffectsController ~= nil then
		HordeEffectsController.start()
	end
end)
safeStep("HordeSpecialTelegraphController.start", function()
	if HordeSpecialTelegraphController ~= nil then
		HordeSpecialTelegraphController.start()
	end
end)
safeStep("SpecialEncounterTelegraphController.start", function()
	if SpecialEncounterTelegraphController ~= nil then
		SpecialEncounterTelegraphController.start()
	end
end)
-- Patch 0.2 elite readability. Starts beside the other enemy-disclosure
-- presenters so it binds EnemyEntities in the same phase as the telegraphs.
safeStep("EliteReadabilityController.start", function()
	if EliteReadabilityController ~= nil then
		EliteReadabilityController.start()
	end
end)
safeStep("RunBuildHUDController.start", function()
	if RunBuildHUDController ~= nil then
		RunBuildHUDController.start()
	end
end)
safeStep("CriticalConditionController.start", function()
	if CriticalConditionController ~= nil then
		CriticalConditionController.start()
	end
end)
safeStep("PresentationSettingsController.start", function()
	if PresentationSettingsController ~= nil then
		PresentationSettingsController.start()
	end
end)
safeStep("ClassSelectionController.start", function()
	if ClassSelectionController ~= nil then
		ClassSelectionController.start()
	end
end)
safeStep("ClassActionController.start", function()
	if ClassActionController ~= nil then
		ClassActionController.start()
	end
end)
safeStep("WeaponSelectionController.start", function()
	if WeaponSelectionController ~= nil then
		WeaponSelectionController.start()
	end
end)
safeStep("ClassSilhouetteController.start", function()
	if ClassSilhouetteController ~= nil then
		ClassSilhouetteController.start()
	end
end)
safeStep("ClassSquadPresentationController.start", function()
	if ClassSquadPresentationController ~= nil then
		ClassSquadPresentationController.start()
	end
end)
safeStep("OperativeLifeWorldPresentationController.start", function()
	if OperativeLifeWorldPresentationController ~= nil then
		OperativeLifeWorldPresentationController.start()
	end
end)
safeStep("HubPreparationController.start", function()
	if HubPreparationController ~= nil then
		HubPreparationController.start()
	end
end)

print("[Living Kingdoms] Client bootstrap started")

--[[
	A stalled or failed controller is reported rather than left to be inferred
	from missing UI. The count is the fastest signal that something did not come
	up, and the names say which.
]]
if #failedControllers > 0 then
	warn(
		string.format(
			"[Client] %d controller step(s) failed: %s",
			#failedControllers,
			table.concat(failedControllers, ", ")
		)
	)
end
