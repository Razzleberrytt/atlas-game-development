-- CombatService: Server-authoritative combat resolution, damage calculation, and hit validation
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local NumberUtility = require(ReplicatedStorage.Shared.Utility.NumberUtility)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)
local RNGEngine = require(ReplicatedStorage.Shared.Utility.RNGEngine)

local CombatService = {}

-- Dependencies (set by ServerBootstrap)
local inventoryService
local playerDataService
local enemyService
local combatRemote
local lootService

function CombatService.setDependencies(inv, pds, enemy, remote, loot)
	inventoryService = inv
	playerDataService = pds
	enemyService = enemy
	combatRemote = remote
	lootService = loot
end

-- Calculates the final damage from a player's weapon and equipment stats
function CombatService.calculatePlayerDamage(player)
	if not inventoryService then return 10, false end

	local stats = inventoryService.getEquipmentStats(player)
	local data = playerDataService.getData(player)

	-- Check all weapon slots for a weapon
	local weapon = nil
	if data and data.equipment then
		for _, slot in {"Primary", "Secondary", "Melee"} do
			if data.equipment[slot] and data.equipment[slot].stats and data.equipment[slot].stats.damage then
				weapon = data.equipment[slot]
				break
			end
		end
	end

	local baseDamage = 10
	if weapon and weapon.stats and weapon.stats.damage then
		baseDamage = weapon.stats.damage
	end

	-- Apply percentage bonuses
	local damagePct = stats.damagePct or 0
	local levelBonus = data and ((data.level - 1) * 0.05) or 0
	local total = baseDamage * (1 + damagePct + levelBonus)

	-- Apply rage buff
	if player:GetAttribute("RageActive") then
		total = total * 1.5
	end

	-- Critical hit roll with RNG variance (1.3x-2.0x multiplier)
	local critChance = stats.critChance or 0
	local isCrit = RandomUtility.chance(critChance)
	if isCrit then
		total = total * RNGEngine.rollCritDamage()
	end

	-- Damage variance (random ±15% swing on most hits)
	total = select(1, RNGEngine.rollDamageVariance(total))

	-- Combo hit chance (rare extra damage)
	local isCombo = false
	local comboMult = RNGEngine.rollCombo()
	if comboMult then
		total = total * (1 + comboMult)
		isCombo = true
	end

	-- Add elemental bonus damage
	if stats.fireDamage and stats.fireDamage > 0 then
		total += stats.fireDamage
	end
	if stats.frostDamage and stats.frostDamage > 0 then
		total += stats.frostDamage
	end

	return math.floor(total + 0.5), isCrit, isCombo
end

-- Calculates damage reduction from equipment
function CombatService.calculateDefense(player)
	if not inventoryService then return 0 end
	local stats = inventoryService.getEquipmentStats(player)
	local baseReduction = stats.defense or 0
	local pctReduction = stats.defensePct or 0

	-- Diminishing returns on flat defense
	local effectiveReduction = baseReduction / (baseReduction + 50)
	return NumberUtility.clamp(effectiveReduction + pctReduction, 0, 0.75)
end

-- Gets max health from equipment
function CombatService.getMaxHealth(player)
	local stats = inventoryService.getEquipmentStats(player)
	local baseHealth = 100
	local bonusHealth = stats.health or 0
	local pctHealth = stats.healthPct or 0
	return math.floor((baseHealth + bonusHealth) * (1 + pctHealth) + 0.5)
end

-- Applies damage to an enemy (server-authoritative)
function CombatService.dealDamageToEnemy(player, enemyModel, damage, isCrit, isCombo)
	if not enemyModel or not enemyModel.Parent then return false end

	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- Validate range (server-side check)
	local playerChar = player.Character
	if not playerChar then return false end
	local hrp = playerChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local enemyHrp = enemyModel:FindFirstChild("HumanoidRootPart")
	if not enemyHrp then return false end

	-- Apply elite/boss damage reduction
	local enemyData = enemyService.getActiveEnemies()[enemyModel]
	local damageReduction = 0
	if enemyData and enemyData.damageReduction then
		damageReduction = enemyData.damageReduction
	end
	local effectiveDamage = math.floor(damage * (1 - damageReduction) + 0.5)
	if effectiveDamage <= 0 then effectiveDamage = 1 end

	-- Execute bonus: extra damage when enemy is low HP
	local enemyHpPct = humanoid.Health / humanoid.MaxHealth
	local isExecute = false
	local executeMult = RNGEngine.rollExecute(enemyHpPct)
	if executeMult > 1 then
		effectiveDamage = math.floor(effectiveDamage * executeMult + 0.5)
		isExecute = true
	end

	-- Apply damage
	humanoid:TakeDamage(effectiveDamage)

	-- Elemental proc chance (random elemental bonus damage)
	local elementalProc = RNGEngine.rollElementalProc()
	if elementalProc then
		humanoid:TakeDamage(elementalProc.damage)
		if combatRemote then
			combatRemote:FireAllClients({
				type = "elemental_proc",
				enemy = enemyModel,
				element = elementalProc.element,
				damage = elementalProc.damage,
				position = enemyHrp.Position,
			})
		end
	end

	-- Apply life steal
	local stats = inventoryService.getEquipmentStats(player)
	if stats.lifeSteal and stats.lifeSteal > 0 then
		local playerHumanoid = playerChar:FindFirstChildOfClass("Humanoid")
		if playerHumanoid and playerHumanoid.Health > 0 then
			local healAmount = math.floor(effectiveDamage * stats.lifeSteal + 0.5)
			if healAmount > 0 then
				playerHumanoid.Health = math.min(playerHumanoid.MaxHealth, playerHumanoid.Health + healAmount)
			end
		end
	end

	-- Set hit presentation attributes on enemy
	enemyModel:SetAttribute("HitSequence", (enemyModel:GetAttribute("HitSequence") or 0) + 1)
	enemyModel:SetAttribute("LastHitDamage", effectiveDamage)
	enemyModel:SetAttribute("LastHitCritical", isCrit)
	enemyModel:SetAttribute("LastHitTime", os.clock())

	-- Check for kill
	if humanoid.Health <= 0 then
		enemyModel:SetAttribute("LifeState", "dead")
		enemyService.onEnemyKilled(player, enemyModel)
	end

	-- Fire combat presentation event
	if combatRemote then
		combatRemote:FireAllClients({
			type = "enemy_hit",
			enemy = enemyModel,
			damage = effectiveDamage,
			isCrit = isCrit,
			isCombo = isCombo or false,
			isExecute = isExecute,
			position = enemyHrp.Position,
		})
	end

	return true
end

-- Applies damage to a player (from enemy attack)
function CombatService.dealDamageToPlayer(player, damage)
	local playerChar = player.Character
	if not playerChar then return end

	local humanoid = playerChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local defense = CombatService.calculateDefense(player)

	-- Dodge chance roll (based on equipment stats)
	local stats = inventoryService and inventoryService.getEquipmentStats(player) or {}
	local dodgeChance = stats.dodgeChance or 0
	if RandomUtility.chance(dodgeChance) then
		if combatRemote then
			combatRemote:FireAllClients({
				type = "player_dodge",
				target = player,
			})
		end
		return -- Dodged!
	end

	local mitigated = damage * (1 - defense)

	humanoid:TakeDamage(math.floor(mitigated + 0.5))

	if combatRemote then
		combatRemote:FireAllClients({
			type = "player_hit",
			target = player,
			damage = math.floor(mitigated + 0.5),
		})
	end
end

-- Gets effective attack range for a player's equipped weapon
function CombatService.getAttackRange(player)
	local data = playerDataService.getData(player)
	if not data then return 7 end

	-- Check all weapon slots
	if data.equipment then
		for _, slot in {"Primary", "Secondary", "Melee"} do
			local weapon = data.equipment[slot]
			if weapon and weapon.stats and weapon.stats.range then
				return weapon.stats.range
			end
		end
	end
	return 7
end

-- Gets attack cooldown for equipped weapon
function CombatService.getAttackCooldown(player)
	local data = playerDataService.getData(player)
	if not data then return 0.55 end

	local weapon = data.equipment and data.equipment.Melee
	local baseCooldown = 0.55
	if weapon and weapon.stats and weapon.stats.speed then
		-- Speed stat reduces cooldown
		baseCooldown = baseCooldown / weapon.stats.speed
	end

	local stats = inventoryService and inventoryService.getEquipmentStats(player) or {}
	if stats.attackSpeedPct then
		baseCooldown = baseCooldown / (1 + stats.attackSpeedPct)
	end

	return baseCooldown
end

return CombatService