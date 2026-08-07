--!strict

local EnemyLootConfig = require(script.Parent.Parent.Config.EnemyLootConfig)

export type DropResolution = {
	didDrop: boolean,
	rejectionReasonId: string?,
	dropId: string?,
	lootKindId: string?,
	rarityId: string?,
	displayName: string?,
	rounds: number,
	lifetimeSeconds: number,
	roll: number?,
}

export type WeaponDropResolution = {
	didDrop: boolean,
	rejectionReasonId: string?,
	dropId: string?,
	weaponId: string?,
	lifetimeSeconds: number,
	roll: number?,
}

local EnemyLootResolver = {}

local function rejected(reasonId: string): DropResolution
	return table.freeze({
		didDrop = false,
		rejectionReasonId = reasonId,
		dropId = nil,
		lootKindId = nil,
		rarityId = nil,
		displayName = nil,
		rounds = 0,
		lifetimeSeconds = 0,
		roll = nil,
	})
end

local function stableHash(entityId: string, deathSequence: number): number
	local hash = deathSequence % 2147483647
	for index = 1, #entityId do
		hash = (hash * 33 + string.byte(entityId, index)) % 2147483647
	end
	return hash
end

function EnemyLootResolver.resolveDrop(entityId: string, deathSequence: number, activeDropCount: number): DropResolution
	if
		type(entityId) ~= "string"
		or entityId == ""
		or type(deathSequence) ~= "number"
		or deathSequence ~= deathSequence
		or deathSequence % 1 ~= 0
		or deathSequence < 1
		or type(activeDropCount) ~= "number"
		or activeDropCount ~= activeDropCount
		or activeDropCount % 1 ~= 0
		or activeDropCount < 0
	then
		return rejected("InvalidDeathFacts")
	end
	if activeDropCount >= EnemyLootConfig.MaximumActiveDrops then
		return rejected("ActiveDropCapReached")
	end

	local hash = stableHash(entityId, deathSequence)
	local roll = hash % EnemyLootConfig.DropRollModulo
	local definition
	if roll < EnemyLootConfig.RareDropRolls then
		definition = EnemyLootConfig.Definitions.Rare
	elseif roll < EnemyLootConfig.RareDropRolls + EnemyLootConfig.CommonDropRolls then
		definition = EnemyLootConfig.Definitions.Common
	else
		return table.freeze({
			didDrop = false,
			rejectionReasonId = "NoDropRolled",
			dropId = nil,
			lootKindId = nil,
			rarityId = nil,
			displayName = nil,
			rounds = 0,
			lifetimeSeconds = 0,
			roll = roll,
		})
	end

	return table.freeze({
		didDrop = true,
		rejectionReasonId = nil,
		dropId = string.format("enemy-loot:%d:%d", deathSequence, hash),
		lootKindId = definition.LootKindId,
		rarityId = definition.RarityId,
		displayName = definition.DisplayName,
		rounds = definition.Rounds,
		lifetimeSeconds = definition.LifetimeSeconds,
		roll = roll,
	})
end

function EnemyLootResolver.resolveWeaponDrop(
	entityId: string,
	deathSequence: number,
	activeDropCount: number
): WeaponDropResolution
	if type(entityId) ~= "string" or entityId == "" or deathSequence < 1 or deathSequence % 1 ~= 0 then
		return table.freeze({
			didDrop = false,
			rejectionReasonId = "InvalidDeathFacts",
			dropId = nil,
			weaponId = nil,
			lifetimeSeconds = 0,
			roll = nil,
		})
	end
	if activeDropCount >= EnemyLootConfig.MaximumActiveDrops then
		return table.freeze({
			didDrop = false,
			rejectionReasonId = "ActiveDropCapReached",
			dropId = nil,
			weaponId = nil,
			lifetimeSeconds = 0,
			roll = nil,
		})
	end
	local hash = stableHash(entityId .. ":weapon", deathSequence)
	local roll = hash % EnemyLootConfig.WeaponDropRollModulo
	if roll >= EnemyLootConfig.WeaponDropWinningRolls then
		return table.freeze({
			didDrop = false,
			rejectionReasonId = "NoWeaponDropRolled",
			dropId = nil,
			weaponId = nil,
			lifetimeSeconds = 0,
			roll = roll,
		})
	end
	local weapons = EnemyLootConfig.DiscoverableWeaponIds
	local weaponId = weapons[(math.floor(hash / EnemyLootConfig.WeaponDropRollModulo) % #weapons) + 1]
	return table.freeze({
		didDrop = true,
		rejectionReasonId = nil,
		dropId = string.format("enemy-weapon-loot:%d:%d", deathSequence, hash),
		weaponId = weaponId,
		lifetimeSeconds = EnemyLootConfig.WeaponDropLifetimeSeconds,
		roll = roll,
	})
end

return table.freeze(EnemyLootResolver)
