-- EnemyService: Enemy spawning, AI behavior, and kill rewards
-- Updated
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyDefs = require(ReplicatedStorage.Shared.Config.EnemyDefinitions)
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local RNGEngine = require(ReplicatedStorage.Shared.Utility.RNGEngine)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)

local EnemyService = {}

-- Horizontal distance helper (ignores Y to avoid vertical offset issues between player and enemy HRPs)
local function horizontalDistance(posA, posB)
	local dx = posA.X - posB.X
	local dz = posA.Z - posB.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Dependencies
local combatService
local lootService
local playerDataService
local inventoryService
local combatRemote
local lootNotificationRemote

local activeEnemies = {} -- [model] = {def, hp, target, lastAttack, state}
local spawnFolder

function EnemyService.setDependencies(combat, loot, pds, inv, cRemote, lnRemote)
	combatService = combat
	lootService = loot
	playerDataService = pds
	inventoryService = inv
	combatRemote = cRemote
	lootNotificationRemote = lnRemote
end

-- Creates an enemy model from a definition
local function createEnemyModel(def, position, isDungeonEnemy)
	local model = Instance.new("Model")
	model.Name = def.id .. "_" .. tostring(os.clock())
	model:SetAttribute("EnemyId", def.id)
	model:SetAttribute("EnemyName", def.name)
	model:SetAttribute("EnemyTier", def.tier)
	model:SetAttribute("HitSequence", 0)
	model:SetAttribute("LifeState", "alive")
	if isDungeonEnemy then
		model:SetAttribute("IsDungeonEnemy", true)
	end

	-- HumanoidRootPart (slightly larger for bigger enemies)
	local hrpSize = Vector3.new(2, 2, 1)
	if def.tier == "Boss" then
		hrpSize = Vector3.new(4, 5, 2)
	elseif def.tier == "Elite" then
		hrpSize = Vector3.new(2.5, 3, 1.5)
	end

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = hrpSize
	hrp.Color = def.color
	hrp.Material = Enum.Material.Plastic
	hrp.Anchored = false
	hrp.CanCollide = false
	hrp.Parent = model

	-- Body part
	local body = Instance.new("Part")
	body.Name = "Torso"
	body.Size = def.scale or Vector3.new(1, 1, 1)
	body.Color = def.color
	body.Material = Enum.Material.Plastic
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	local headSize = Vector3.new(1.2, 1.2, 1.2)
	if def.tier == "Boss" then
		headSize = Vector3.new(2, 2, 2)
	elseif def.tier == "Elite" then
		headSize = Vector3.new(1.5, 1.5, 1.5)
	end
	head.Size = headSize
	head.Color = def.color
	head.Material = Enum.Material.Plastic
	head.Anchored = false
	head.CanCollide = false
	head.Parent = model

	-- Position parts relative to origin, then use PivotTo to move the entire model
	local bodyHeight = def.scale and def.scale.Y or 1
	local centerY = bodyHeight / 2
	hrp.CFrame = CFrame.new(0, centerY, 0)
	body.CFrame = CFrame.new(0, centerY, 0)
	head.CFrame = CFrame.new(0, centerY + (headSize.Y / 2), 0)

	-- Welds
	local hrpWeld = Instance.new("WeldConstraint")
	hrpWeld.Part0 = hrp
	hrpWeld.Part1 = body
	hrpWeld.Parent = hrp

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = body

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = def.health
	humanoid.Health = def.health
	humanoid.WalkSpeed = def.speed
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	-- Health bar above enemy
	local healthBar = Instance.new("BillboardGui")
	healthBar.Name = "EnemyHealthBar"
	healthBar.Size = UDim2.new(0, 80, 0, 12)
	healthBar.StudsOffset = Vector3.new(0, def.scale and def.scale.Y + 2 or 3, 0)
	healthBar.AlwaysOnTop = true
	healthBar.MaxDistance = 100
	healthBar.Parent = hrp

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, 0, 1, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	barBg.BorderSizePixel = 1
	barBg.BorderColor3 = Color3.fromRGB(40, 40, 40)
	barBg.Parent = healthBar

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = def.tier == "Boss" and Color3.fromRGB(200, 30, 30) or (def.tier == "Elite" and Color3.fromRGB(180, 60, 200) or Color3.fromRGB(200, 80, 80))
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	-- PrimaryPart
	model.PrimaryPart = hrp

	-- Position entire model at spawn point (all parts move together correctly)
	model:PivotTo(CFrame.new(position))

	-- Store in spawn folder
	if spawnFolder then
		model.Parent = spawnFolder
	end

	-- Update health bar
	humanoid.HealthChanged:Connect(function(health)
		local pct = health / humanoid.MaxHealth
		barFill.Size = UDim2.new(pct, 0, 1, 0)
	end)

	return model
end

-- Spawns an enemy at a position (with RNG affixes, dungeon modifiers, and boss modifiers)
function EnemyService.spawnEnemy(enemyId, position, isDungeonEnemy, options)
	options = options or {}
	local def = EnemyDefs.Enemies[enemyId]
	if not def then return nil end

	local effectiveDef = def

	-- Apply dungeon modifier effects
	local dungeonEffects = options.dungeonModifiers or {}
	if dungeonEffects.enemyHealthMult then
		effectiveDef = table.clone(effectiveDef)
		effectiveDef.health = effectiveDef.health * dungeonEffects.enemyHealthMult
	end
	if dungeonEffects.enemyDamageMult then
		effectiveDef = table.clone(effectiveDef)
		effectiveDef.damage = effectiveDef.damage * dungeonEffects.enemyDamageMult
	end
	if dungeonEffects.enemySpeedMult then
		effectiveDef = table.clone(effectiveDef)
		effectiveDef.speed = effectiveDef.speed * dungeonEffects.enemySpeedMult
	end
	if dungeonEffects.enemyDamageReduction then
		effectiveDef = table.clone(effectiveDef)
		effectiveDef._damageReduction = (effectiveDef._damageReduction or 0) + dungeonEffects.enemyDamageReduction
	end

	-- Apply boss modifiers
	local bossModifiers = options.bossModifiers
	if def.tier == "Boss" and bossModifiers then
		for _, mod in ipairs(bossModifiers) do
			effectiveDef = table.clone(effectiveDef)
			if mod.effects.healthMult then
				effectiveDef.health = effectiveDef.health * mod.effects.healthMult
			end
			if mod.effects.damageMult then
				effectiveDef.damage = effectiveDef.damage * mod.effects.damageMult
			end
			if mod.effects.damageReduction then
				effectiveDef._damageReduction = (effectiveDef._damageReduction or 0) + mod.effects.damageReduction
			end
			if mod.effects.scaleMult then
				effectiveDef = table.clone(effectiveDef)
			effectiveDef.scale = (effectiveDef.scale or Vector3.new(1,1,1)) * mod.effects.scaleMult
			end
			if mod.effects.attackSpeedMult then
				effectiveDef = table.clone(effectiveDef)
			effectiveDef.attackCooldown = (effectiveDef.attackCooldown or 1.5) / mod.effects.attackSpeedMult
			end
			effectiveDef.name = mod.name .. " " .. effectiveDef.name
		end
	effectiveDef._bossModifiers = bossModifiers
	end

	-- Apply elite affixes
	if def.tier == "Elite" and def.eliteAffixes then
		for _, affixId in def.eliteAffixes do
			local affix = EnemyDefs.EliteAffixes[affixId]
			if affix then
				effectiveDef = table.clone(effectiveDef)
				effectiveDef.health = (effectiveDef.health) * (affix.healthMultiplier or 1)
				effectiveDef.damage = (effectiveDef.damage) * (affix.damageMultiplier or 1)
				effectiveDef.speed = (effectiveDef.speed) * (affix.speedMultiplier or 1)
			effectiveDef.name = affix.name .. " " .. effectiveDef.name
			effectiveDef._damageReduction = affix.damageReduction or 0
			effectiveDef._isVolatile = affixId == "volatile"
			end
		end
	end

	-- Roll random enemy affixes for normal enemies (RNG engine)
	local enemyAffix = nil
	if def.tier == "Normal" then
		local depth = options.roomDepth or 0
		enemyAffix = RNGEngine.rollEnemyAffix(depth)
		if enemyAffix then
			effectiveDef = table.clone(effectiveDef)
			if enemyAffix.effects.healthMult then
				effectiveDef.health = effectiveDef.health * enemyAffix.effects.healthMult
			end
			if enemyAffix.effects.damageMult then
				effectiveDef.damage = effectiveDef.damage * enemyAffix.effects.damageMult
			end
			if enemyAffix.effects.speedMult then
				effectiveDef.speed = effectiveDef.speed * enemyAffix.effects.speedMult
			end
			if enemyAffix.effects.scaleMult then
				effectiveDef.scale = (effectiveDef.scale or Vector3.new(1,1,1)) * enemyAffix.effects.scaleMult
			end
			if enemyAffix.effects.damageReduction then
				effectiveDef._damageReduction = (effectiveDef._damageReduction or 0) + enemyAffix.effects.damageReduction
			end
			effectiveDef.name = enemyAffix.name .. " " .. effectiveDef.name
			effectiveDef.color = enemyAffix.color or effectiveDef.color
		end
	end

	local model = createEnemyModel(effectiveDef, position, isDungeonEnemy)

	local enemyData = {
		def = effectiveDef,
		baseDef = def,
		target = nil,
		lastAttack = 0,
		lastSpecialAttack = 0,
		state = "idle",
		damageReduction = effectiveDef._damageReduction or 0,
		isBoss = def.tier == "Boss",
		isDungeon = isDungeonEnemy or false,
		phase = 1,
		enemyAffix = enemyAffix,
		bossModifiers = bossModifiers,
		dungeonEffects = dungeonEffects,
		regen = (dungeonEffects.enemyRegen and effectiveDef.health * 0.02) or 0,
		isVolatile = effectiveDef._isVolatile or (dungeonEffects.volatileEnemies and true) or false,
		lifeSteal = (enemyAffix and enemyAffix.effects.lifeSteal) or 0,
		poisonDamage = (enemyAffix and enemyAffix.effects.poisonDamage) or 0,
		poisonDuration = (enemyAffix and enemyAffix.effects.poisonDuration) or 0,
		explodeOnDeath = (enemyAffix and enemyAffix.effects.explodeOnDeath) or false,
		explosionRadius = (enemyAffix and enemyAffix.effects.explosionRadius) or 0,
		explosionDamage = (enemyAffix and enemyAffix.effects.explosionDamage) or 0,
		berserkThreshold = nil,
		berserkDamageMult = nil,
	}

	-- Extract berserk from boss modifiers
	if bossModifiers then
		for _, mod in ipairs(bossModifiers) do
			if mod.effects.berserkThreshold then
				enemyData.berserkThreshold = mod.effects.berserkThreshold
				enemyData.berserkDamageMult = mod.effects.berserkDamageMult
			end
		end
	end

	activeEnemies[model] = enemyData

	return model
end

-- Finds the nearest player within detection range
local function findNearestPlayer(position, range)
	local nearest = nil
	local nearestDist = range

	for _, player in Players:GetPlayers() do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if hrp and humanoid and humanoid.Health > 0 then
				local dist = horizontalDistance(hrp.Position, position)
				if dist <= nearestDist then
					nearest = player
					nearestDist = dist
				end
			end
		end
	end

	return nearest
end

-- Enemy AI update loop
local function updateEnemyAI(model, data, dt)
	if not model.Parent then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local def = data.def

	-- Enemy regen (dungeon modifier)
	if data.regen and data.regen > 0 and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + data.regen * dt)
	end

	-- Berserk: increase damage when HP drops below threshold
	if data.berserkThreshold and not data._berserkActive then
		local hpPct = humanoid.Health / humanoid.MaxHealth
		if hpPct <= data.berserkThreshold then
			data._berserkActive = true
			data._berserkDamageMult = data.berserkDamageMult or 2
			if combatRemote then
				combatRemote:FireAllClients({
					type = "enemy_berserk",
					enemy = model,
				})
			end
		end
	end

	-- Find target if none or target is invalid
	local needNewTarget = false
	if not data.target then
		needNewTarget = true
	else
		local targetChar = data.target.Character
		if not targetChar then
			needNewTarget = true
		else
			local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
		if not targetHumanoid or targetHumanoid.Health <= 0 then
				needNewTarget = true
			end
		end
	end
	if needNewTarget then
		data.target = findNearestPlayer(hrp.Position, def.detectionRange)
	end

	if not data.target then
		return -- idle
	end

	local targetChar = data.target.Character
	if not targetChar then return end
	local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetHrp then return end

	local dist = horizontalDistance(hrp.Position, targetHrp.Position)
	local behavior = def.behavior or "melee_chase"

	-- Boss special attacks
	if data.isBoss and def.specialAttacks then
		local now = os.clock()
		if now - (data.lastSpecialAttack or 0) >= 6 then -- minimum 6s between special attacks
			for _, special in def.specialAttacks do
				-- Only use phase-appropriate attacks
				if not special.phase or special.phase <= data.phase then
					if dist <= special.range and now - (data.lastSpecialAttack or 0) >= special.cooldown then
						data.lastSpecialAttack = now
						data.state = "special_attacking"

						-- Teleport boss special attack to all clients
						if combatRemote then
							combatRemote:FireAllClients({
								type = "boss_special",
								enemy = model,
								attackName = special.name,
								target = data.target,
								damage = special.damage,
								range = special.range,
							})
						end

						-- Apply damage after a short delay (telegraph)
						task.delay(1.0, function()
							if model and model.Parent and humanoid.Health > 0 then
								local stillTarget = data.target
								if stillTarget and stillTarget.Character then
									local tChar = stillTarget.Character
									local tHrp = tChar:FindFirstChild("HumanoidRootPart")
									if tHrp then
										local newDist = horizontalDistance(hrp.Position, tHrp.Position)
										if newDist <= special.range + 5 then -- slight forgiveness
											combatService.dealDamageToPlayer(stillTarget, special.damage)
										end
									end
								end
							end
						end)
						break
					end
				end
			end
		end
	end

	-- Ranged kite behavior: keep distance and attack from range
	if behavior == "ranged_kite" then
		local idealRange = def.attackRange * 0.7
		if dist > def.attackRange then
			-- Move toward target
			humanoid:MoveTo(Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z))
			data.state = "chasing"
		elseif dist < idealRange then
			-- Back away from target (horizontal only)
			local awayDir = Vector3.new(hrp.Position.X - targetHrp.Position.X, 0, hrp.Position.Z - targetHrp.Position.Z)
			if awayDir.Magnitude > 0.1 then
				awayDir = awayDir.Unit
			else
				awayDir = Vector3.new(1, 0, 0)
			end
			local retreatPos = Vector3.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z) + awayDir * (idealRange - dist + 5)
			humanoid:MoveTo(retreatPos)
			data.state = "kiting"
		else
			-- In range, stop and attack
			humanoid:MoveTo(hrp.Position)
			local now = os.clock()
			if now - data.lastAttack >= def.attackCooldown then
				data.lastAttack = now
				data.state = "attacking"

				-- Deal damage to player
				local damage = def.damage
				if data._berserkActive then
					damage = damage * data._berserkDamageMult
				end
				combatService.dealDamageToPlayer(data.target, damage)

				-- Life steal
				if data.lifeSteal and data.lifeSteal > 0 then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + damage * data.lifeSteal)
				end

				-- Poison on hit
				if data.poisonDamage and data.poisonDamage > 0 then
					local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
					if targetHum then
						task.spawn(function()
							local ticks = math.floor((data.poisonDuration or 3) / 1)
							for i = 1, ticks do
								task.wait(1)
								if targetHum and targetHum.Health > 0 then
									targetHum:TakeDamage(data.poisonDamage)
								end
							end
						end)
					end
				end

				-- Visual attack presentation
				model:SetAttribute("AttackSequence", (model:GetAttribute("AttackSequence") or 0) + 1)
				if combatRemote then
					combatRemote:FireAllClients({
						type = "enemy_attack",
						enemy = model,
						target = data.target,
						isRanged = true,
					})
				end
			end
		end
	else
		-- Melee chase behavior (default)
		if dist > def.attackRange then
			humanoid:MoveTo(Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z))
			data.state = "chasing"
		else
			-- In range, attempt attack
			local now = os.clock()
			if now - data.lastAttack >= def.attackCooldown then
				data.lastAttack = now
				data.state = "attacking"

				-- Deal damage to player
				local damage = def.damage
				if data.isBoss and data.phase > 1 then
					damage = damage * (1 + (data.phase - 1) * 0.2)
				end
				if data._berserkActive then
					damage = damage * data._berserkDamageMult
				end

				combatService.dealDamageToPlayer(data.target, damage)

				-- Life steal
				if data.lifeSteal and data.lifeSteal > 0 then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + damage * data.lifeSteal)
				end

				-- Poison on hit
				if data.poisonDamage and data.poisonDamage > 0 then
					local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
					if targetHum then
						task.spawn(function()
							local ticks = math.floor((data.poisonDuration or 3) / 1)
							for i = 1, ticks do
								task.wait(1)
								if targetHum and targetHum.Health > 0 then
									targetHum:TakeDamage(data.poisonDamage)
								end
							end
						end)
					end
				end

				-- Visual attack presentation
				model:SetAttribute("AttackSequence", (model:GetAttribute("AttackSequence") or 0) + 1)
				if combatRemote then
					combatRemote:FireAllClients({
						type = "enemy_attack",
						enemy = model,
						target = data.target,
					})
				end
			end
		end
	end

	-- Boss phase transitions
	if data.isBoss and def.phases then
		local hpPct = humanoid.Health / humanoid.MaxHealth
		for i, threshold in def.phaseThresholds do
			if hpPct <= threshold and data.phase <= i then
				data.phase = i + 1
				model:SetAttribute("BossPhase", data.phase)
				-- Increase boss speed in later phases
			humanoid.WalkSpeed = def.speed * (1 + (data.phase - 1) * 0.15)
			if combatRemote then
				combatRemote:FireAllClients({
					type = "boss_phase",
					enemy = model,
					phase = data.phase,
				})
			end
			end
		end
	end
end

-- Starts the AI update loop
function EnemyService.startAI()
	task.spawn(function()
		local lastUpdate = os.clock()
		while task.wait(0.2) do
			local now = os.clock()
			local dt = now - lastUpdate
			lastUpdate = now

			for model, data in activeEnemies do
				updateEnemyAI(model, data, dt)
			end
		end
	end)
end

-- Called when an enemy is killed by a player
function EnemyService.onEnemyKilled(player, model)
	local data = activeEnemies[model]
	if not data then
		print("[EnemyService] onEnemyKilled: no data for model")
		return
	end

	local def = data.def

	-- Volatile death / explosion on death
	if data.isVolatile or data.explodeOnDeath then
		local enemyHrp = model:FindFirstChild("HumanoidRootPart")
		if enemyHrp then
			local explosionPos = enemyHrp.Position
			local radius = data.explosionRadius or 8
			local baseDamage = data.explosionDamage or def.damage * 2

			-- Visual explosion on all clients
			if combatRemote then
				combatRemote:FireAllClients({
					type = "enemy_explosion",
					position = explosionPos,
					radius = radius,
				})
			end

			-- Damage nearby players with falloff
			for _, player in Players:GetPlayers() do
				local char = player.Character
				if char then
					local pHrp = char:FindFirstChild("HumanoidRootPart")
					local pHum = char:FindFirstChildOfClass("Humanoid")
					if pHrp and pHum and pHum.Health > 0 then
						local dist = horizontalDistance(pHrp.Position, explosionPos)
						if dist <= radius then
							local falloff = 1 - (dist / radius)
							combatService.dealDamageToPlayer(player, baseDamage * falloff)
						end
					end
				end
			end
		end
	end

	local level = 1
	local luck = 0
	if playerDataService then
		local pData = playerDataService.getData(player)
		if pData then
			level = pData.level
			luck = playerDataService.getLuck(player)
		end

		-- Award experience and gold
		print(string.format("[EnemyService] Killing %s: awarding %d XP, %d gold", def.name, def.expReward, def.goldReward))
		playerDataService.addExperience(player, def.expReward)
		playerDataService.addCurrency(player, def.goldReward)
	else
		print("[EnemyService] WARNING: playerDataService not set!")
	end

	-- Update kill stats
	if playerDataService then
		local pData = playerDataService.getData(player)
		if pData then
			pData.totalKills = (pData.totalKills or 0) + 1
			if def.tier == "Boss" then
				pData.bossKills = (pData.bossKills or 0) + 1
			end
		end
	end

	-- Roll loot
	if lootService and def.lootTable then
		print(string.format("[EnemyService] Rolling loot table: %s for %s", def.lootTable, def.name))
		local loot = lootService.rollLoot(def.lootTable, level, nil, luck)
		if loot then
			print(string.format("[EnemyService] Loot rolled: %d gold, %d items, %d materials (luck: %d)", loot.gold, #loot.items, #loot.materials, luck))

			-- Add gold
			playerDataService.addCurrency(player, loot.gold)

			-- Add items to inventory
			if inventoryService then
				for _, item in loot.items do
					inventoryService.addItem(player, item)
					playerDataService.trackItemFound(player, item)
				end
				for _, mat in loot.materials do
					local matItem = {
						id = "loot_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
						defId = mat.defId,
						type = "Material",
						name = mat.defId,
						rarity = "Common",
						level = 1,
						stats = {},
						affixes = {},
						count = mat.count,
					}
					inventoryService.addItem(player, matItem)
				end

				-- Sync inventory
				playerDataService.syncInventory(player)
			end

			-- Send loot notification
			if lootNotificationRemote then
				local serialized = {}
				for _, item in loot.items do
					table.insert(serialized, lootService.serializeItem(item))
				end
				lootNotificationRemote:FireClient(player, {
					items = serialized,
					gold = loot.gold,
					source = def.name,
				})
				print(string.format("[EnemyService] Loot notification sent to %s (%d items, %d gold)", player.Name, #serialized, loot.gold))
			else
				print("[EnemyService] WARNING: lootNotificationRemote not set!")
			end
		else
			print("[EnemyService] WARNING: lootService.rollLoot returned nil!")
		end
	elseif not lootService then
		print("[EnemyService] WARNING: lootService not set!")
	elseif not def.lootTable then
		print("[EnemyService] WARNING: no lootTable for " .. def.name)
	end

	-- Remove enemy from active list
	activeEnemies[model] = nil

	-- Clean up model after death animation delay
	task.delay(2, function()
		if model and model.Parent then
			model.Parent = nil
		end
	end)
end

-- Sets the spawn folder
function EnemyService.setSpawnFolder(folder)
	spawnFolder = folder
end

-- Gets all active enemies
function EnemyService.getActiveEnemies()
	return activeEnemies
end

-- Clears all enemies (e.g., on dungeon reset)
function EnemyService.clearAllEnemies()
	for model, _ in activeEnemies do
		if model and model.Parent then
			model.Parent = nil
		end
	end
	activeEnemies = {}
end

-- Clears only dungeon enemies (keeps outdoor enemies alive)
function EnemyService.clearDungeonEnemies()
	for model, data in activeEnemies do
		if data.isDungeon and model and model.Parent then
			model.Parent = nil
			activeEnemies[model] = nil
		end
	end
end

return EnemyService