--!strict

--[[
	VIS-0101 shared visual-asset vocabulary. These declarations describe approved
	presentation identities, placeholder state, fallback relationships, expected
	rig/attachment contracts, and source records. They own no Instances, asset
	loading, gameplay state, remotes, animation, effects, audio, or skin selection.
]]

local VisualAssetContracts = {}

export type VisualAssetFamilyId =
	"Weapon"
	| "Operative"
	| "ClassEquipment"
	| "Enemy"
	| "Supply"
	| "Objective"
	| "Extraction"
	| "World"
	| "Effect"
	| "Audio"
	| "Interface"

export type VisualAssetStatusId =
	"PrimitivePlaceholder"
	| "DefaultAvatarPlaceholder"
	| "MissingPresentation"
	| "TemporaryPresentation"
	| "ProductionApproved"

export type VisualAssetSourceKindId = "ProjectPlaceholder" | "ProjectOriginal" | "Commissioned" | "LicensedLibrary"

export type VisualAssetRecord = {
	assetKey: string,
	familyId: VisualAssetFamilyId,
	version: number,
	statusId: VisualAssetStatusId,
	sourceKindId: VisualAssetSourceKindId,
	sourceReference: string,
	runtimeOwnerPath: string,
	canonicalFallbackAssetKey: string?,
	expectedRootName: string?,
	requiredAttachmentNames: { string },
	gameplayFootprintId: string?,
	allowsCosmeticVariants: boolean,
}

VisualAssetContracts.FamilyIds = table.freeze({
	Weapon = "Weapon",
	Operative = "Operative",
	ClassEquipment = "ClassEquipment",
	Enemy = "Enemy",
	Supply = "Supply",
	Objective = "Objective",
	Extraction = "Extraction",
	World = "World",
	Effect = "Effect",
	Audio = "Audio",
	Interface = "Interface",
})

VisualAssetContracts.StatusIds = table.freeze({
	PrimitivePlaceholder = "PrimitivePlaceholder",
	DefaultAvatarPlaceholder = "DefaultAvatarPlaceholder",
	MissingPresentation = "MissingPresentation",
	TemporaryPresentation = "TemporaryPresentation",
	ProductionApproved = "ProductionApproved",
})

VisualAssetContracts.SourceKindIds = table.freeze({
	ProjectPlaceholder = "ProjectPlaceholder",
	ProjectOriginal = "ProjectOriginal",
	Commissioned = "Commissioned",
	LicensedLibrary = "LicensedLibrary",
})

VisualAssetContracts.AssetKeys = table.freeze({
	WeaponBasicFirearmModel = "visual.weapon.basic-firearm.model",
	OperativeBaseRig = "visual.operative.base-rig",
	ClassCombatSpecialistEquipment = "visual.class.combat-specialist.equipment",
	ClassMedicEquipment = "visual.class.medic.equipment",
	ClassEngineerEquipment = "visual.class.engineer.equipment",
	EnemyStandardHostileModel = "visual.enemy.standard-hostile.model",
	SupplyAmmunitionCacheModel = "visual.supply.ammunition-cache.model",
	ObjectiveRelayConsoleModel = "visual.objective.relay-console.model",
	ExtractionBeaconModel = "visual.extraction.beacon.model",
	WorldBlackwaterFoundation = "visual.world.blackwater-foundation",
	WorldRangerStation = "visual.world.landmark.ranger-station",
	WorldLoggingRoad = "visual.world.landmark.logging-road",
	WorldLookoutTower = "visual.world.landmark.lookout-tower",
	WorldCampground = "visual.world.landmark.campground",
	WorldCreekCrossing = "visual.world.landmark.creek-crossing",
	WorldRockyOverlook = "visual.world.landmark.rocky-overlook",
	WorldMilitaryRoadblock = "visual.world.landmark.military-roadblock",
	WorldExtractionClearing = "visual.world.landmark.extraction-clearing",
	EffectBasicFirearmFire = "visual.effect.basic-firearm.fire",
	EffectStandardHostileAttack = "visual.effect.standard-hostile.attack",
	AudioBasicFirearm = "visual.audio.basic-firearm",
	AudioStandardHostile = "visual.audio.standard-hostile",
	AudioBlackwaterAmbience = "visual.audio.blackwater-ambience",
	InterfaceAmmunition = "visual.interface.ammunition",
	InterfaceLifeState = "visual.interface.life-state",
	InterfaceMission = "visual.interface.mission",
	InterfaceClassSelection = "visual.interface.class-selection",
	InterfaceSquadPing = "visual.interface.squad-ping",
})

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 1
		and value % 1 == 0
end

local function isStringArray(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	for index, entry in value :: { [unknown]: unknown } do
		if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or not isNonEmptyString(entry) then
			return false
		end
	end
	return true
end

local function containsValue(dictionary: { [string]: string }, candidate: unknown): boolean
	for _, value in dictionary do
		if value == candidate then
			return true
		end
	end
	return false
end

function VisualAssetContracts.isKnownAssetKey(value: unknown): boolean
	return containsValue(VisualAssetContracts.AssetKeys, value)
end

function VisualAssetContracts.validateRecord(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local record = value :: { [string]: unknown }
	if not VisualAssetContracts.isKnownAssetKey(record.assetKey) then
		return false
	end
	if not containsValue(VisualAssetContracts.FamilyIds, record.familyId) then
		return false
	end
	if not containsValue(VisualAssetContracts.StatusIds, record.statusId) then
		return false
	end
	if not containsValue(VisualAssetContracts.SourceKindIds, record.sourceKindId) then
		return false
	end
	if not isPositiveInteger(record.version) then
		return false
	end
	if not isNonEmptyString(record.sourceReference) or not isNonEmptyString(record.runtimeOwnerPath) then
		return false
	end
	if
		record.canonicalFallbackAssetKey ~= nil
		and not VisualAssetContracts.isKnownAssetKey(record.canonicalFallbackAssetKey)
	then
		return false
	end
	if record.expectedRootName ~= nil and not isNonEmptyString(record.expectedRootName) then
		return false
	end
	if record.gameplayFootprintId ~= nil and not isNonEmptyString(record.gameplayFootprintId) then
		return false
	end
	return isStringArray(record.requiredAttachmentNames) and type(record.allowsCosmeticVariants) == "boolean"
end

return table.freeze(VisualAssetContracts)
