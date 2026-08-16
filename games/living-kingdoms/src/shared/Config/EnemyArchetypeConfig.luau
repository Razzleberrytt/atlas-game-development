--!strict

--[[
	Wave 2 canonical encounter-facing enemy archetype catalog. Ordinary archetype
	balance is sourced from EnemyConfig so the behavior resolver and encounter
	composer cannot drift. The existing Blight Spitter remains a dedicated special
	runtime but participates in encounter composition through this common shape.
]]

local EnemyContracts = require(script.Parent.Parent.Combat.EnemyContracts)
local EnemyConfig = require(script.Parent.EnemyConfig)
local SpecialEnemyConfig = require(script.Parent.SpecialEnemyConfig)

export type WeakPointDefinition = { partName: string, damageMultiplier: number }
export type RewardMetadata = { baseFieldXp: number, lootProfileId: string }
export type EnemyArchetypeDefinition = {
	ArchetypeId: EnemyContracts.EnemyArchetypeId,
	DisplayName: string,
	RuntimeKind: "Ordinary" | "Special",
	MaximumHealth: number,
	PursuitSpeedStudsPerSecond: number,
	RoamSpeedStudsPerSecond: number,
	DetectionRadiusStuds: number,
	PursuitDropRadiusStuds: number,
	PreferredRangeMinimumStuds: number,
	PreferredRangeMaximumStuds: number,
	AttackRangeStuds: number,
	AttackDamage: number,
	AttackWindupSeconds: number,
	AttackCooldownSeconds: number,
	RoamWanderRadiusStuds: number,
	RoamRetargetIntervalSeconds: number,
	MovementBehaviorId: EnemyContracts.EnemyMovementBehaviorId,
	AttackBehaviorId: EnemyContracts.EnemyAttackBehaviorId,
	WeakPoint: WeakPointDefinition?,
	RewardMetadata: RewardMetadata,
	Tags: { string },
	FactionId: string,
	EliteEligible: boolean,
	SpawnCost: number,
	EncounterWeight: number,
}

local Ids = EnemyContracts.EnemyArchetypeIds
local MovementIds = EnemyContracts.EnemyMovementBehaviorIds
local AttackIds = EnemyContracts.EnemyAttackBehaviorIds
local spitter = SpecialEnemyConfig.BlightSpitter
local bloom = SpecialEnemyConfig.Bloom

local function ordinary(definition): EnemyArchetypeDefinition
	return table.freeze({
		ArchetypeId = definition.ArchetypeId,
		DisplayName = definition.DisplayName,
		RuntimeKind = "Ordinary",
		MaximumHealth = definition.MaximumHealth,
		PursuitSpeedStudsPerSecond = definition.PursuitSpeedStudsPerSecond,
		RoamSpeedStudsPerSecond = definition.RoamSpeedStudsPerSecond,
		DetectionRadiusStuds = definition.DetectionRadiusStuds,
		PursuitDropRadiusStuds = definition.PursuitDropRadiusStuds,
		PreferredRangeMinimumStuds = 0,
		PreferredRangeMaximumStuds = definition.AttackRangeStuds,
		AttackRangeStuds = definition.AttackRangeStuds,
		AttackDamage = definition.AttackDamage,
		AttackWindupSeconds = definition.AttackWindupSeconds,
		AttackCooldownSeconds = definition.AttackCooldownSeconds,
		RoamWanderRadiusStuds = definition.RoamWanderRadiusStuds,
		RoamRetargetIntervalSeconds = definition.RoamRetargetIntervalSeconds,
		MovementBehaviorId = definition.MovementBehaviorId,
		AttackBehaviorId = definition.AttackBehaviorId,
		WeakPoint = table.freeze({
			partName = definition.WeakPointPartName,
			damageMultiplier = definition.WeakPointDamageMultiplier,
		}),
		RewardMetadata = table.freeze({
			baseFieldXp = definition.BaseFieldXp,
			lootProfileId = definition.LootProfileId,
		}),
		Tags = definition.Tags,
		FactionId = definition.FactionId,
		EliteEligible = definition.EliteEligible,
		SpawnCost = definition.SpawnCost,
		EncounterWeight = definition.EncounterWeight,
	})
end

local DefinitionsById: { [string]: EnemyArchetypeDefinition } = {
	[Ids.ExclusionWalker] = ordinary(EnemyConfig.Walker),
	[Ids.RazorRunner] = ordinary(EnemyConfig.RazorRunner),
	[Ids.GriefBrute] = ordinary(EnemyConfig.GriefBrute),
	[Ids.BlightSpitter] = table.freeze({
		ArchetypeId = Ids.BlightSpitter,
		DisplayName = spitter.DisplayName,
		RuntimeKind = "Special",
		MaximumHealth = spitter.MaximumHealth,
		PursuitSpeedStudsPerSecond = spitter.PursuitSpeedStudsPerSecond,
		RoamSpeedStudsPerSecond = spitter.RoamSpeedStudsPerSecond,
		DetectionRadiusStuds = spitter.DetectionRadiusStuds,
		PursuitDropRadiusStuds = spitter.DetectionRadiusStuds + 24,
		PreferredRangeMinimumStuds = math.max(18, spitter.BloomEngagementRangeStuds * 0.55),
		PreferredRangeMaximumStuds = spitter.BloomEngagementRangeStuds,
		AttackRangeStuds = spitter.BloomEngagementRangeStuds,
		AttackDamage = bloom.ImpactDamage,
		AttackWindupSeconds = bloom.ChargeWindupSeconds,
		AttackCooldownSeconds = bloom.CooldownSeconds,
		RoamWanderRadiusStuds = EnemyConfig.Walker.RoamWanderRadiusStuds,
		RoamRetargetIntervalSeconds = EnemyConfig.Walker.RoamRetargetIntervalSeconds,
		MovementBehaviorId = MovementIds.RangedApproach,
		AttackBehaviorId = AttackIds.CorrosiveBloom,
		WeakPoint = table.freeze({ partName = "ThroatSac", damageMultiplier = 1.6 }),
		RewardMetadata = table.freeze({ baseFieldXp = 30, lootProfileId = "enemy.special" }),
		Tags = table.freeze({ "Special", "Ranged", "AreaDenial" }),
		FactionId = "faction.exclusion",
		EliteEligible = false,
		SpawnCost = 3,
		EncounterWeight = 1.2,
	}),
}

local EncounterArchetypeIds = table.freeze({ Ids.ExclusionWalker, Ids.RazorRunner, Ids.GriefBrute, Ids.BlightSpitter })

local EnemyArchetypeConfig = {
	Version = "Wave2-Archetypes-v1",
	DefinitionsById = table.freeze(DefinitionsById),
	EncounterArchetypeIds = EncounterArchetypeIds,
}

local function finitePositive(value: number): boolean
	return value == value and value > 0 and value ~= math.huge
end

function EnemyArchetypeConfig.get(archetypeId: unknown): EnemyArchetypeDefinition?
	if type(archetypeId) ~= "string" then
		return nil
	end
	return DefinitionsById[archetypeId]
end

function EnemyArchetypeConfig.isEncounterEligible(archetypeId: unknown): boolean
	if type(archetypeId) ~= "string" then
		return false
	end
	return DefinitionsById[archetypeId] ~= nil
end

function EnemyArchetypeConfig.validateDefinition(definition: unknown): (boolean, string?)
	if type(definition) ~= "table" then
		return false, "DefinitionMissing"
	end
	local value = definition :: any
	if type(value.ArchetypeId) ~= "string" or type(value.DisplayName) ~= "string" or value.DisplayName == "" then
		return false, "IdentityInvalid"
	end
	if value.RuntimeKind ~= "Ordinary" and value.RuntimeKind ~= "Special" then
		return false, "RuntimeKindInvalid"
	end
	for _, fieldName in
		{
			"MaximumHealth",
			"PursuitSpeedStudsPerSecond",
			"RoamSpeedStudsPerSecond",
			"DetectionRadiusStuds",
			"PursuitDropRadiusStuds",
			"AttackRangeStuds",
			"AttackDamage",
			"AttackWindupSeconds",
			"AttackCooldownSeconds",
			"RoamWanderRadiusStuds",
			"RoamRetargetIntervalSeconds",
			"SpawnCost",
			"EncounterWeight",
		}
	do
		if type(value[fieldName]) ~= "number" or not finitePositive(value[fieldName]) then
			return false, "NumericFieldInvalid:" .. fieldName
		end
	end
	if
		type(value.PreferredRangeMinimumStuds) ~= "number"
		or value.PreferredRangeMinimumStuds < 0
		or type(value.PreferredRangeMaximumStuds) ~= "number"
		or value.PreferredRangeMaximumStuds < value.PreferredRangeMinimumStuds
		or value.AttackRangeStuds < value.PreferredRangeMaximumStuds
	then
		return false, "PreferredRangeInvalid"
	end
	if value.PursuitDropRadiusStuds < value.DetectionRadiusStuds then
		return false, "PursuitDropInvalid"
	end
	if
		type(value.EliteEligible) ~= "boolean"
		or type(value.Tags) ~= "table"
		or type(value.RewardMetadata) ~= "table"
	then
		return false, "MetadataInvalid"
	end
	return true, nil
end

for archetypeId, definition in DefinitionsById do
	local valid, reason = EnemyArchetypeConfig.validateDefinition(definition)
	assert(valid, string.format("invalid enemy archetype %s: %s", archetypeId, tostring(reason)))
end

return table.freeze(EnemyArchetypeConfig)
