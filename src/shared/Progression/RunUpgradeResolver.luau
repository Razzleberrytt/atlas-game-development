--!strict

local RunProgressionConfig = require(script.Parent.Parent.Config.RunProgressionConfig)
local RunModifierResolver = require(script.Parent.RunModifierResolver)

export type UpgradeStacks = { [string]: number }

export type CombatModifiers = {
	damageMultiplier: number,
	cadenceMultiplier: number,
	ammoConservationChance: number,
	cullDamageMultiplier: number,
	cullHealthThreshold: number,
	incomingDamageMultiplier: number,
	xpGainMultiplier: number,
	reloadDurationMultiplier: number,
	patternDamageMultiplier: number,
	specialEnemyDamageMultiplier: number,
	magazineCapacityMultiplier: number,
	lootPickupRadiusBonusStuds: number,
	lastMagazineDamageMultiplier: number,
	lastMagazineReserveFraction: number,
}

export type ChoiceResolution = {
	didApply: boolean,
	rejectionReasonId: string?,
	upgradeId: string?,
	stackAfter: number,
	stacksAfter: UpgradeStacks,
}

local RunUpgradeResolver = {}

local definitionsById: { [string]: any } = {}
for _, definition in RunProgressionConfig.UpgradeDefinitions do
	definitionsById[definition.Id] = definition
end

local function copyStacks(stacks: UpgradeStacks): UpgradeStacks
	return table.clone(stacks)
end

local function isValidStackCount(value: unknown): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 0 and value <= 4
end

local function validateStacks(stacks: UpgradeStacks): boolean
	if type(stacks) ~= "table" then
		return false
	end
	for upgradeId, count in stacks do
		local definition = definitionsById[upgradeId]
		if definition == nil or not isValidStackCount(count) or count > definition.MaximumStacks then
			return false
		end
	end
	return true
end

local function hasPrerequisites(definition: any, stacks: UpgradeStacks): boolean
	for _, prerequisiteId in definition.PrerequisiteIds do
		if (stacks[prerequisiteId] or 0) < 1 then
			return false
		end
	end
	return true
end

function RunUpgradeResolver.generateChoices(
	stacks: UpgradeStacks,
	offerSequence: number,
	squadKills: number,
	squadWeaponIds: { string }?
): { string }
	if
		not validateStacks(stacks)
		or type(offerSequence) ~= "number"
		or offerSequence ~= offerSequence
		or offerSequence % 1 ~= 0
		or offerSequence < 1
		or type(squadKills) ~= "number"
		or squadKills ~= squadKills
		or squadKills % 1 ~= 0
		or squadKills < 0
	then
		return table.freeze({})
	end

	local weaponIdSet: { [string]: boolean }? = nil
	if squadWeaponIds ~= nil then
		if type(squadWeaponIds) ~= "table" then
			return table.freeze({})
		end
		weaponIdSet = {}
		for _, weaponId in squadWeaponIds do
			if type(weaponId) ~= "string" or weaponId == "" then
				return table.freeze({})
			end
			weaponIdSet[weaponId] = true
		end
	end

	local eligible = {}
	for _, definition in RunProgressionConfig.UpgradeDefinitions do
		local isCompatible = definition.CompatibleWeaponIds == nil or weaponIdSet == nil
		if definition.CompatibleWeaponIds ~= nil and weaponIdSet ~= nil then
			for _, weaponId in definition.CompatibleWeaponIds do
				if weaponIdSet[weaponId] then
					isCompatible = true
					break
				end
			end
		end
		if
			isCompatible
			and hasPrerequisites(definition, stacks)
			and (stacks[definition.Id] or 0) < definition.MaximumStacks
		then
			table.insert(eligible, definition.Id)
		end
	end
	if #eligible == 0 then
		return table.freeze({})
	end

	local count = math.min(RunProgressionConfig.UpgradeChoiceCount, #eligible)
	local offset = ((offerSequence * 5 + squadKills * 3) % #eligible) + 1
	local choices = {}
	local chosenIds: { [string]: boolean } = {}
	local firstFamilyId: string? = nil

	local function chooseMatching(predicate: (any) -> boolean): boolean
		for step = 0, #eligible - 1 do
			local eligibleIndex = ((offset + step - 1) % #eligible) + 1
			local upgradeId = eligible[eligibleIndex]
			local definition = definitionsById[upgradeId]
			if not chosenIds[upgradeId] and predicate(definition) then
				chosenIds[upgradeId] = true
				table.insert(choices, upgradeId)
				if firstFamilyId == nil then
					firstFamilyId = definition.FamilyId
				end
				return true
			end
		end
		return false
	end

	-- Prefer a universally useful first card, then a second family before
	-- filling the remaining deterministic slot. This prevents narrow mono-family
	-- offers whenever a diverse legal choice exists.
	chooseMatching(function(definition)
		return definition.IsBroadlyUseful
	end)
	if #choices == 0 then
		chooseMatching(function(_definition)
			return true
		end)
	end
	if #choices < count then
		chooseMatching(function(definition)
			return definition.FamilyId ~= firstFamilyId
		end)
	end
	while #choices < count do
		if not chooseMatching(function(_definition)
			return true
		end) then
			break
		end
	end
	return table.freeze(choices)
end

function RunUpgradeResolver.applyChoice(
	stacks: UpgradeStacks,
	pendingChoiceIds: { string },
	selectedUpgradeId: string
): ChoiceResolution
	local stacksAfter = copyStacks(stacks)
	if not validateStacks(stacks) or type(pendingChoiceIds) ~= "table" or type(selectedUpgradeId) ~= "string" then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "InvalidUpgradeFacts",
			upgradeId = nil,
			stackAfter = 0,
			stacksAfter = table.freeze(stacksAfter),
		})
	end

	local wasOffered = false
	for _, upgradeId in pendingChoiceIds do
		if upgradeId == selectedUpgradeId then
			wasOffered = true
			break
		end
	end
	if not wasOffered then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "UpgradeNotOffered",
			upgradeId = nil,
			stackAfter = 0,
			stacksAfter = table.freeze(stacksAfter),
		})
	end

	local definition = definitionsById[selectedUpgradeId]
	local stackBefore = stacks[selectedUpgradeId] or 0
	if definition == nil or stackBefore >= definition.MaximumStacks then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "UpgradeAtMaximumStacks",
			upgradeId = nil,
			stackAfter = stackBefore,
			stacksAfter = table.freeze(stacksAfter),
		})
	end

	local stackAfter = stackBefore + 1
	stacksAfter[selectedUpgradeId] = stackAfter
	return table.freeze({
		didApply = true,
		rejectionReasonId = nil,
		upgradeId = selectedUpgradeId,
		stackAfter = stackAfter,
		stacksAfter = table.freeze(stacksAfter),
	})
end

function RunUpgradeResolver.deriveCombatModifiers(stacks: UpgradeStacks): CombatModifiers
	if not validateStacks(stacks) then
		local neutral = RunModifierResolver.neutral()
		return table.freeze({
			damageMultiplier = neutral.damageMultiplier,
			cadenceMultiplier = neutral.cadenceMultiplier,
			ammoConservationChance = neutral.ammunitionConservationChance,
			cullDamageMultiplier = neutral.cullDamageMultiplier,
			cullHealthThreshold = RunProgressionConfig.CullHealthThreshold,
			incomingDamageMultiplier = neutral.incomingDamageMultiplier,
			xpGainMultiplier = neutral.fieldXpMultiplier,
			reloadDurationMultiplier = neutral.reloadDurationMultiplier,
			patternDamageMultiplier = neutral.patternDamageMultiplier,
			specialEnemyDamageMultiplier = neutral.specialEnemyDamageMultiplier,
			magazineCapacityMultiplier = neutral.magazineCapacityMultiplier,
			lootPickupRadiusBonusStuds = neutral.lootPickupRadiusBonusStuds,
			lastMagazineDamageMultiplier = neutral.conditionalDamageMultiplier,
			lastMagazineReserveFraction = RunProgressionConfig.LastMagazineReserveFraction,
		})
	end

	local damageBonus = 0
	local cadenceReduction = 0
	local ammoConservationChance = 0
	local cullDamageBonus = 0
	local incomingDamageReduction = 0
	local xpGainBonus = 0
	local reloadDurationReduction = 0
	local patternDamageBonus = 0
	local specialEnemyDamageBonus = 0
	local magazineCapacityBonus = 0
	local lootPickupRadiusBonusStuds = 0
	local lastMagazineDamageBonus = 0
	for _, definition in RunProgressionConfig.UpgradeDefinitions do
		local stackCount = stacks[definition.Id] or 0
		if definition.DamageMultiplierPerStack ~= nil then
			damageBonus += stackCount * definition.DamageMultiplierPerStack
		end
		if definition.CadenceReductionPerStack ~= nil then
			cadenceReduction += stackCount * definition.CadenceReductionPerStack
		end
		if definition.AmmoConservationChancePerStack ~= nil then
			ammoConservationChance += stackCount * definition.AmmoConservationChancePerStack
		end
		if definition.CullDamageMultiplierPerStack ~= nil then
			cullDamageBonus += stackCount * definition.CullDamageMultiplierPerStack
		end
		if definition.IncomingDamageReductionPerStack ~= nil then
			incomingDamageReduction += stackCount * definition.IncomingDamageReductionPerStack
		end
		if definition.XpGainMultiplierPerStack ~= nil then
			xpGainBonus += stackCount * definition.XpGainMultiplierPerStack
		end
		if definition.ReloadDurationReductionPerStack ~= nil then
			reloadDurationReduction += stackCount * definition.ReloadDurationReductionPerStack
		end
		if definition.PatternDamageMultiplierPerStack ~= nil then
			patternDamageBonus += stackCount * definition.PatternDamageMultiplierPerStack
		end
		if definition.SpecialEnemyDamageMultiplierPerStack ~= nil then
			specialEnemyDamageBonus += stackCount * definition.SpecialEnemyDamageMultiplierPerStack
		end
		if definition.MagazineCapacityMultiplierPerStack ~= nil then
			magazineCapacityBonus += stackCount * definition.MagazineCapacityMultiplierPerStack
		end
		if definition.LootPickupRadiusBonusStudsPerStack ~= nil then
			lootPickupRadiusBonusStuds += stackCount * definition.LootPickupRadiusBonusStudsPerStack
		end
		if definition.LastMagazineDamageMultiplierPerStack ~= nil then
			lastMagazineDamageBonus += stackCount * definition.LastMagazineDamageMultiplierPerStack
		end
	end

	local resolved = RunModifierResolver.resolve({
		damageBonus = damageBonus,
		cadenceReduction = cadenceReduction,
		ammunitionConservationChance = ammoConservationChance,
		cullDamageBonus = cullDamageBonus,
		incomingDamageReduction = incomingDamageReduction,
		fieldXpBonus = xpGainBonus,
		reloadDurationReduction = reloadDurationReduction,
		patternDamageBonus = patternDamageBonus,
		specialEnemyDamageBonus = specialEnemyDamageBonus,
		magazineCapacityBonus = magazineCapacityBonus,
		lootPickupRadiusBonusStuds = lootPickupRadiusBonusStuds,
		conditionalDamageBonus = lastMagazineDamageBonus,
	})
	return table.freeze({
		damageMultiplier = resolved.damageMultiplier,
		cadenceMultiplier = resolved.cadenceMultiplier,
		ammoConservationChance = resolved.ammunitionConservationChance,
		cullDamageMultiplier = resolved.cullDamageMultiplier,
		cullHealthThreshold = RunProgressionConfig.CullHealthThreshold,
		incomingDamageMultiplier = resolved.incomingDamageMultiplier,
		xpGainMultiplier = resolved.fieldXpMultiplier,
		reloadDurationMultiplier = resolved.reloadDurationMultiplier,
		patternDamageMultiplier = resolved.patternDamageMultiplier,
		specialEnemyDamageMultiplier = resolved.specialEnemyDamageMultiplier,
		magazineCapacityMultiplier = resolved.magazineCapacityMultiplier,
		lootPickupRadiusBonusStuds = resolved.lootPickupRadiusBonusStuds,
		lastMagazineDamageMultiplier = resolved.conditionalDamageMultiplier,
		lastMagazineReserveFraction = RunProgressionConfig.LastMagazineReserveFraction,
	})
end

function RunUpgradeResolver.readDefinition(upgradeId: string): any?
	return definitionsById[upgradeId]
end

return table.freeze(RunUpgradeResolver)
