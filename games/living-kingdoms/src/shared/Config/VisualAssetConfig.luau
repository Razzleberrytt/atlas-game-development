--!strict

--[[
	VIS-0101 inventory of the current production-facing presentation surface.
	Every entry names the existing placeholder or missing presentation honestly.
	This registry loads no assets and changes no runtime behavior.
]]

local VisualAssetContracts = require(script.Parent.Parent.Visual.VisualAssetContracts)

local FamilyIds = VisualAssetContracts.FamilyIds
local Keys = VisualAssetContracts.AssetKeys
local SourceKindIds = VisualAssetContracts.SourceKindIds
local StatusIds = VisualAssetContracts.StatusIds

local function record(
	assetKey: string,
	familyId: string,
	statusId: string,
	runtimeOwnerPath: string,
	sourceReference: string,
	expectedRootName: string?,
	requiredAttachmentNames: { string },
	gameplayFootprintId: string?,
	allowsCosmeticVariants: boolean
)
	return table.freeze({
		assetKey = assetKey,
		familyId = familyId,
		version = 1,
		statusId = statusId,
		sourceKindId = SourceKindIds.ProjectPlaceholder,
		sourceReference = sourceReference,
		runtimeOwnerPath = runtimeOwnerPath,
		canonicalFallbackAssetKey = nil,
		expectedRootName = expectedRootName,
		requiredAttachmentNames = table.freeze(requiredAttachmentNames),
		gameplayFootprintId = gameplayFootprintId,
		allowsCosmeticVariants = allowsCosmeticVariants,
	})
end

local Registry = table.freeze({
	record(
		Keys.WeaponBasicFirearmModel,
		FamilyIds.Weapon,
		StatusIds.MissingPresentation,
		"src/client/Presentation/BasicFirearmPresentationFactory.luau",
		"Blackwater Support LMG uses a project-original procedural fallback and deterministic source candidate; canonical imported production approval remains pending.",
		"BasicFirearm",
		{ "RightGripAttachment", "Muzzle", "Magazine", "Ejection" },
		"weapon.basic-firearm",
		true
	),
	record(
		Keys.WeaponBreachShotgunModel,
		FamilyIds.Weapon,
		StatusIds.PrimitivePlaceholder,
		"src/client/Presentation/BreachShotgunPresentationFactory.luau",
		"Morrow Breach Shotgun uses a dedicated project-original multi-part fallback with a vented heat shield, pump, box magazine, shell rack, and side light; Studio approval and a canonical imported production asset remain pending.",
		"WeaponPresentation",
		{ "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" },
		"weapon.breach-shotgun",
		true
	),
	record(
		Keys.WeaponSniperRifleModel,
		FamilyIds.Weapon,
		StatusIds.PrimitivePlaceholder,
		"src/client/Presentation/SniperRiflePresentationFactory.luau",
		"Longwatch Sniper Rifle uses a dedicated project-original multi-part fallback with a free-floated heavy barrel, full optic stack, working bolt presentation, precision stock, and folded bipod; Studio approval and a canonical imported production asset remain pending.",
		"WeaponPresentation",
		{ "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" },
		"weapon.sniper-rifle",
		true
	),
	record(
		Keys.WeaponServicePistolModel,
		FamilyIds.Weapon,
		StatusIds.PrimitivePlaceholder,
		"src/client/Presentation/ServicePistolPresentationFactory.luau",
		"Vigil Service Pistol uses a dedicated project-original multi-part fallback with a moving detailed slide, visible barrel hood, duty frame, iron sights, magazine assembly, and weapon light; Studio approval and a canonical imported production asset remain pending.",
		"WeaponPresentation",
		{ "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" },
		"weapon.service-pistol",
		true
	),
	record(
		Keys.WeaponSubmachineGunModel,
		FamilyIds.Weapon,
		StatusIds.PrimitivePlaceholder,
		"src/client/Presentation/SubmachineGunPresentationFactory.luau",
		"Razor Compact SMG uses a dedicated project-original multi-part fallback with a short barrel shroud, folding wire stock, curved magazine, reflex optic, vertical foregrip, and identity panels; Studio approval and a canonical imported production asset remain pending.",
		"WeaponPresentation",
		{ "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" },
		"weapon.submachine-gun",
		true
	),
	record(
		Keys.OperativeBaseRig,
		FamilyIds.Operative,
		StatusIds.DefaultAvatarPlaceholder,
		"src/server/Systems/OperativeLifeService.luau",
		"Connected players currently use the Roblox character shell bound through HumanoidRootPart.",
		"OperativeRig",
		{ "HumanoidRootPart", "RightGripAttachment" },
		"operative.player",
		true
	),
	record(
		Keys.ClassCombatSpecialistEquipment,
		FamilyIds.ClassEquipment,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/ClassSilhouetteController.luau",
		"Combat Specialist uses a project-original ten-part procedural fallback with broad reinforced shoulders, paired ammunition cases, a back roll, and a diagonal chest band; canonical rig and Studio approval remain pending.",
		"OperativeClassSilhouette",
		{},
		"class.combat-specialist",
		true
	),
	record(
		Keys.ClassMedicEquipment,
		FamilyIds.ClassEquipment,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/ClassSilhouetteController.luau",
		"Medic uses a project-original ten-part procedural fallback with a compact pack, twin tall canisters, paired satchels, and a round beacon; canonical rig and Studio approval remain pending.",
		"OperativeClassSilhouette",
		{},
		"class.medic",
		true
	),
	record(
		Keys.ClassEngineerEquipment,
		FamilyIds.ClassEquipment,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/ClassSilhouetteController.luau",
		"Engineer uses a project-original ten-part procedural fallback with a wide utility pack, squared tool cases, a frame bar, and an asymmetric antenna; canonical rig and Studio approval remain pending.",
		"OperativeClassSilhouette",
		{},
		"class.engineer",
		true
	),
	record(
		Keys.EnemyStandardHostileModel,
		FamilyIds.Enemy,
		StatusIds.PrimitivePlaceholder,
		"src/server/Systems/EnemyPresentationService.luau",
		"Exclusion Walker uses a fixed 18-part procedural shell attached to the unchanged authoritative 3 x 5.6 x 3 HumanoidRootPart; canonical imported rig approval remains pending.",
		"ExclusionWalker",
		{ "HumanoidRootPart", "AttackOrigin" },
		"enemy.exclusion_walker",
		true
	),
	record(
		Keys.SupplyAmmunitionCacheModel,
		FamilyIds.Supply,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/AmmunitionCachePresentationController.luau",
		"The server-owned collidable cache root and prompt remain unchanged while a 13-part client-local procedural supply case provides available and per-operative consumed readability.",
		"SupplyCachePresentation",
		{},
		"supply.authored-cache",
		false
	),
	record(
		Keys.ObjectiveRelayConsoleModel,
		FamilyIds.Objective,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/MissionObjectPresentationController.luau",
		"The authoritative relay body, lamp, and prompt remain unchanged while an eleven-part client-local procedural shell provides standby, restore, and online readability from validated safe mission snapshots.",
		"RelayConsolePresentation",
		{},
		"objective.restore-lookout-relay",
		false
	),
	record(
		Keys.ExtractionBeaconModel,
		FamilyIds.Extraction,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/MissionObjectPresentationController.luau",
		"The server creates extraction only after unlock; a twelve-part client-local procedural package then provides open, holdout, success, and failure readability from validated safe mission snapshots.",
		"ExtractionBeaconPresentation",
		{},
		"mission.extraction-clearing",
		false
	),
	record(
		Keys.WorldBlackwaterFoundation,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/server/Systems/WorldFoundationService.luau",
		"Terrain, routes, vegetation, structures, props, and lighting are deterministic graybox geometry.",
		"LivingKingdomsWorld",
		{},
		"world.blackwater",
		false
	),
	record(
		Keys.WorldRangerStation,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/LandmarkAccentPresentationController.luau",
		"The authored station retains all geometry, collision, signage, spawn, and lights while four client-local roof and mast accents improve its static silhouette.",
		"LandmarkSilhouettePresentation",
		{},
		"RangerStation",
		false
	),
	record(
		Keys.WorldLoggingRoad,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/RouteGuidePresentationController.luau",
		"Existing authored logging-road and switchback-trail segments retain all server geometry and collision while paired client-local guide posts improve route-edge readability without destination labels or extraction cues.",
		"RouteGuidePresentation",
		{},
		"LoggingRoad",
		false
	),
	record(
		Keys.WorldLookoutTower,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/server/Systems/WorldFoundationService.luau",
		"Lookout Tower is generated from primitive structural Parts.",
		"LookoutTower",
		{},
		"LookoutTower",
		false
	),
	record(
		Keys.WorldCampground,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/LandmarkAccentPresentationController.luau",
		"The authored campground retains shelter, props, signage, and collision while four client-local tent and dormant-fire accents use the shared world material language to improve static readability.",
		"LandmarkSilhouettePresentation",
		{},
		"Campground",
		false
	),
	record(
		Keys.WorldCreekCrossing,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/LandmarkAccentPresentationController.luau",
		"The authored crossing retains water, banks, bridge geometry, collision, and warning prop while four client-local warning and fallen-tree accents improve static readability.",
		"LandmarkSilhouettePresentation",
		{},
		"CreekCrossing",
		false
	),
	record(
		Keys.WorldRockyOverlook,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/LandmarkAccentPresentationController.luau",
		"The authored overlook retains rock, plateau, guardrail, distant-light, signage, and collision geometry while four client-local guardrail and cliff-edge accents improve static readability.",
		"LandmarkSilhouettePresentation",
		{},
		"RockyOverlook",
		false
	),
	record(
		Keys.WorldMilitaryRoadblock,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/client/Controllers/LandmarkAccentPresentationController.luau",
		"The authored roadblock retains all barriers, vehicles, collision, signs, and lights while six client-local checkpoint accents improve its static silhouette.",
		"LandmarkSilhouettePresentation",
		{},
		"MilitaryRoadblock",
		false
	),
	record(
		Keys.WorldExtractionClearing,
		FamilyIds.World,
		StatusIds.PrimitivePlaceholder,
		"src/server/Systems/WorldFoundationService.luau",
		"Extraction Clearing is a primitive authored landmark awaiting the final extraction package.",
		"ExtractionClearing",
		{},
		"ExtractionClearing",
		false
	),
	record(
		Keys.EffectBasicFirearmFire,
		FamilyIds.Effect,
		StatusIds.TemporaryPresentation,
		"src/client/Presentation/WeaponShotEffectPresenter.luau",
		"Accepted shots now drive temporary code-built muzzle flash, casing ejection, hit-confirmed tracer, and authoritative damage-impact presentation; production effects remain pending.",
		"BasicFirearmFireEffects",
		{ "Muzzle", "Ejection" },
		"weapon.basic-firearm",
		false
	),
	record(
		Keys.EffectStandardHostileAttack,
		FamilyIds.Effect,
		StatusIds.MissingPresentation,
		"src/server/Systems/EnemyDirectorService.luau",
		"Enemy melee commits authoritatively without an approved anticipation, strike, or impact effect set.",
		"StandardHostileAttackEffects",
		{ "AttackOrigin" },
		"enemy.exclusion_walker",
		false
	),
	record(
		Keys.AudioBasicFirearm,
		FamilyIds.Audio,
		StatusIds.TemporaryPresentation,
		"src/client/Controllers/WeaponAudioController.luau",
		"Accepted shots and reload starts now drive a client-local pooled 2D fire and reload sound set from approved free Creator Store audio; a production-approved firearm audio pass remains pending.",
		"BasicFirearmAudio",
		{},
		"weapon.basic-firearm",
		false
	),
	record(
		Keys.AudioStandardHostile,
		FamilyIds.Audio,
		StatusIds.MissingPresentation,
		"src/server/Systems/EnemyDirectorService.luau",
		"No approved hostile alert, pursuit, attack, hit, or death sound set is registered.",
		"StandardHostileAudio",
		{},
		"enemy.exclusion_walker",
		false
	),
	record(
		Keys.AudioBlackwaterAmbience,
		FamilyIds.Audio,
		StatusIds.TemporaryPresentation,
		"src/client/Controllers/EnvironmentAmbienceController.luau",
		"Current environment ambience is a temporary code-driven presentation pass.",
		"BlackwaterAmbience",
		{},
		"world.blackwater",
		false
	),
	record(
		Keys.InterfaceAmmunition,
		FamilyIds.Interface,
		StatusIds.TemporaryPresentation,
		"src/client/Controllers/WeaponController.luau",
		"Ammunition display is functional temporary UI.",
		"AmmunitionInterface",
		{},
		"weapon.basic-firearm",
		false
	),
	record(
		Keys.InterfaceLifeState,
		FamilyIds.Interface,
		StatusIds.TemporaryPresentation,
		"src/client/Controllers/OperativeLifeWorldPresentationController.luau",
		"The temporary local life UI remains, and authoritative incapacitated, revive-progress, solo-recovery, and death states now receive client-local world-space geometry and text cues from server-disclosed Player attributes.",
		"OperativeLifeWorldCue",
		{},
		"operative.life",
		false
	),
	record(
		Keys.InterfaceMission,
		FamilyIds.Interface,
		StatusIds.TemporaryPresentation,
		"src/client/Controllers/MissionController.luau",
		"Mission objective, radio, countdown, and outcome display is explicitly temporary UI.",
		"MissionInterface",
		{},
		"mission.blackwater-relay",
		false
	),
	record(
		Keys.InterfaceClassSelection,
		FamilyIds.Interface,
		StatusIds.TemporaryPresentation,
		"src/client/Controllers/ClassSelectionController.luau",
		"Starting-class selection is a functional temporary three-button panel.",
		"ClassSelectionInterface",
		{},
		"class.selection",
		false
	),
	record(
		Keys.InterfaceSquadPing,
		FamilyIds.Interface,
		StatusIds.TemporaryPresentation,
		"src/client/Controllers/SquadPingController.luau",
		"Squad ping markers are functional temporary presentation.",
		"SquadPingInterface",
		{},
		"squad.ping",
		false
	),
})

local byKey = {}
local knownCount = 0
for _ in Keys do
	knownCount += 1
end

for _, entry in Registry do
	assert(VisualAssetContracts.validateRecord(entry), "visual asset registry contains an invalid record")
	assert(byKey[entry.assetKey] == nil, "visual asset keys must be unique")
	assert(
		not string.find(entry.sourceReference, "rbxassetid://", 1, true),
		"VIS-0101 must not register numeric assets"
	)
	byKey[entry.assetKey] = entry
end

assert(#Registry == knownCount, "every known visual asset key requires exactly one registry record")
for _, assetKey in Keys do
	assert(byKey[assetKey] ~= nil, "every known visual asset key requires a registry record")
end

local Config = {
	Version = "VIS-0101-v1",
	Registry = Registry,
	ByKey = table.freeze(byKey),
}

return table.freeze(Config)
