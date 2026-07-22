--!strict

-- P5-0106 production automatic-combat runtime: darkness-bounded visibility,
-- the line-of-sight raycast budget, threat priority, the fire→hit→damage→death
-- pipeline against director-owned enemies, reload intent validation, life-state
-- restrictions, the revive combat-state boundary, teardown, and source audits.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0106 combat runtime fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local enemyContracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local worldConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")
local combatContracts = loadSimple("games/living-kingdoms/src/shared/Combat/CombatContracts.luau", "CombatContracts")
local scarcityContracts = loadSimple(
	"games/living-kingdoms/src/shared/Combat/AmmunitionScarcityContracts.luau",
	"AmmunitionScarcityContracts"
)

local ENEMY_CONTRACTS_TOKEN = {}
local WORLD_TOKEN = {}
local ENEMY_CONFIG_TOKEN = {}
local COMBAT_CONTRACTS_TOKEN = {}
local SCARCITY_CONTRACTS_TOKEN = {}
local FIREARM_CONFIG_TOKEN = {}
local HORDE_CONFIG_TOKEN = {}
local VALIDATOR_TOKEN = {}
local CLASS_SERVICE_TOKEN = {}

local hordeConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau", "HordeExperienceConfig")
local magazineResolver = loadSimple(
	"games/living-kingdoms/src/server/Systems/RunMagazineCapacityResolver.luau",
	"RunMagazineCapacityResolver"
)

local enemyConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
	debugName = "EnemyConfig",
	environment = {
		script = {
			Parent = {
				WorldFoundationConfig = WORLD_TOKEN,
				Parent = { Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			end
			if token == WORLD_TOKEN then
				return worldConfig
			end
			error("unexpected EnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local firearmConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirearmConfig.luau"), {
	debugName = "FirearmConfig",
	environment = {
		script = { Parent = { Parent = { Combat = { CombatContracts = COMBAT_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			if token == COMBAT_CONTRACTS_TOKEN then
				return combatContracts
			end
			error("unexpected FirearmConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local sharedReplicatedStorage
local function loadProduction(
	path: string,
	debugName: string,
	scriptParent: { [string]: unknown }?,
	extraRequire: ((unknown) -> any)?
)
	local loader = luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = {
			game = {
				GetService = function(_self: unknown, serviceName: string)
					assert(serviceName == "ReplicatedStorage", "unexpected service request: " .. serviceName)
					return sharedReplicatedStorage
				end,
			},
			script = if scriptParent ~= nil then { Parent = scriptParent } else nil,
			require = function(token: unknown)
				if token == COMBAT_CONTRACTS_TOKEN then
					return combatContracts
				end
				if token == FIREARM_CONFIG_TOKEN then
					return firearmConfig
				end
				if extraRequire ~= nil then
					return extraRequire(token)
				end
				error("unexpected module request in " .. debugName)
			end,
		},
		injectGlobals = true,
	})
	return loader()
end

sharedReplicatedStorage = {
	Shared = {
		Combat = {
			CombatContracts = COMBAT_CONTRACTS_TOKEN,
			AmmunitionScarcityContracts = SCARCITY_CONTRACTS_TOKEN,
			EnemyContracts = ENEMY_CONTRACTS_TOKEN,
		},
		Config = {
			FirearmConfig = FIREARM_CONFIG_TOKEN,
			HordeExperienceConfig = HORDE_CONFIG_TOKEN,
			EnemyConfig = ENEMY_CONFIG_TOKEN,
			WorldFoundationConfig = WORLD_TOKEN,
		},
	},
}

local supplyResolver = loadProduction(
	"games/living-kingdoms/src/server/Domain/AmmunitionSupplyResolver.luau",
	"AmmunitionSupplyResolver",
	nil,
	function(token)
		if token == SCARCITY_CONTRACTS_TOKEN then
			return scarcityContracts
		end
		error("unexpected supply resolver dependency")
	end
)

local validator =
	loadProduction("games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau", "TargetCandidateValidator")
local selector = loadProduction(
	"games/living-kingdoms/src/server/Systems/TargetCandidateSelector.luau",
	"TargetCandidateSelector",
	{ TargetCandidateValidator = VALIDATOR_TOKEN },
	function(token)
		if token == VALIDATOR_TOKEN then
			return validator
		end
		error("unexpected selector dependency")
	end
)
local fireResolver =
	loadProduction("games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau", "AutomaticFireResolver")
local hitResolver =
	loadProduction("games/living-kingdoms/src/server/Systems/FirearmHitResolver.luau", "FirearmHitResolver")
local damageResolver = loadProduction("games/living-kingdoms/src/server/Systems/DamageResolver.luau", "DamageResolver")
local reloadResolver = loadProduction("games/living-kingdoms/src/server/Systems/ReloadResolver.luau", "ReloadResolver")

local function signal()
	local listeners = {}
	local value = {}
	function value:Connect(callback)
		table.insert(listeners, callback)
		local connected = true
		return {
			Disconnect = function()
				if not connected then
					return
				end
				connected = false
				local index = table.find(listeners, callback)
				if index ~= nil then
					table.remove(listeners, index)
				end
			end,
		}
	end
	function value:Fire(...)
		for _, listener in table.clone(listeners) do
			listener(...)
		end
	end
	function value:count()
		return #listeners
	end
	return value
end

-- Enemy director mock with the production read/commit surface.
local enemies = {}
local commitCalls = {}
local enemyFactReadCount = 0
local gameplayVisibilityRadiusStuds = enemyConfig.Combat.GameplayVisibilityRadiusStuds
local enemyDirector = {
	readGameplayVisibilityRadiusStuds = function()
		return gameplayVisibilityRadiusStuds
	end,
	readEnemyCombatFacts = function()
		enemyFactReadCount += 1
		local facts = {}
		for _, enemy in enemies do
			if enemy.isAlive then
				table.insert(facts, {
					entityId = enemy.entityId,
					worldPosition = enemy.position,
					isAlive = true,
					targetOperativeEntityId = enemy.targetOperativeEntityId,
					model = enemy.model,
				})
			end
		end
		return facts
	end,
	readHealthState = function(entityId)
		for _, enemy in enemies do
			if enemy.entityId == entityId then
				local processed = {}
				for shotId in enemy.processedShotIds do
					processed[shotId] = true
				end
				return {
					revision = enemy.revision,
					isAlive = enemy.isAlive,
					maximumHealth = enemyConfig.Walker.MaximumHealth,
					healthState = {
						entityId = enemy.entityId,
						currentHealth = enemy.currentHealth,
						processedShotIds = processed,
					},
				}
			end
		end
		return nil
	end,
	commitHealthState = function(entityId, expectedRevision, healthStateAfter, serverTimestamp)
		table.insert(commitCalls, {
			entityId = entityId,
			expectedRevision = expectedRevision,
			healthStateAfter = healthStateAfter,
			serverTimestamp = serverTimestamp,
		})
		for _, enemy in enemies do
			if enemy.entityId == entityId then
				if expectedRevision ~= enemy.revision or healthStateAfter.currentHealth > enemy.currentHealth then
					return false
				end
				enemy.currentHealth = healthStateAfter.currentHealth
				enemy.processedShotIds = healthStateAfter.processedShotIds
				enemy.revision += 1
				if enemy.currentHealth <= 0 then
					enemy.isAlive = false
				end
				return true
			end
		end
		return false
	end,
}

local function addEnemy(entityId: string, x: number, z: number, overrides: { [string]: any }?)
	local enemy = {
		entityId = entityId,
		position = roblox.Vector3.new(x, 3, z),
		isAlive = true,
		targetOperativeEntityId = nil,
		model = {
			name = entityId,
			GetAttribute = function()
				return nil
			end,
		},
		revision = 1,
		currentHealth = enemyConfig.Walker.MaximumHealth,
		processedShotIds = {},
	}
	for key, value in overrides or {} do
		enemy[key] = value
	end
	table.insert(enemies, enemy)
	return enemy
end

-- Life-service mock.
local combatAllowedByPlayer = {}
local restrictionCalls = {}
local lifeSignal = signal()
local lifeService = {
	isCombatAllowed = function(player)
		return combatAllowedByPlayer[player] == true
	end,
	applyCombatRestrictions = function(player, combatState)
		table.insert(restrictionCalls, player)
		local copy = {}
		for key, value in combatState do
			copy[key] = value
		end
		copy.selectedTargetEntityId = nil
		local weaponState = {}
		for key, value in combatState.weaponState do
			weaponState[key] = value
		end
		weaponState.reloadState = nil
		weaponState.readinessStateId = "Disabled"
		copy.weaponState = weaponState
		return copy
	end,
	subscribe = function(callback)
		return lifeSignal:Connect(callback)
	end,
}

local neutralRelicModifiers = table.freeze({
	killChainExtensionSeconds = 0,
	specialEnemyDamageMultiplier = 1,
	lowReserveDamageMultiplier = 1,
	lowReserveFraction = 0,
	woundedReloadDurationMultiplier = 1,
	woundedHealthFraction = 0,
	executionDamageMultiplier = 1,
	executionHealthFraction = 0,
	bloodBatteryKillThreshold = 0,
	bloodBatteryHealAmount = 0,
	shotgunPatternDamageMultiplier = 1,
	sniperPatternDamageMultiplier = 1,
	sniperSpecialEnemyDamageMultiplier = 1,
	lootRoundsAdditiveBonus = 0,
	sustainedFireShotThreshold = 0,
	sustainedFireCadenceMultiplier = 1,
	sustainedFireDamageMultiplier = 1,
})

-- Relic modifier adapter mock: no operative has a relic equipped, so every read
-- returns the neutral bundle and the combat pass must behave exactly as before.
local relicForgetCalls = {}
local relicClearCalls = 0
local relicModifierService = {
	read = function()
		return neutralRelicModifiers
	end,
	readSustainedShots = function()
		return 0
	end,
	recordSustainedShot = function() end,
	resetSustainedShots = function() end,
	forget = function(player)
		table.insert(relicForgetCalls, player)
	end,
	clear = function()
		relicClearCalls += 1
	end,
}

-- Roblox service mocks.
local now = 0
local raycastCalls = {}
local raycastResultsByEntityId = {}
local raycastParamsCreated = 0
local workspaceMock = {
	GetServerTimeNow = function()
		return now
	end,
	Raycast = function(_, origin, direction, _parameters)
		table.insert(raycastCalls, { origin = origin, direction = direction })
		local destination = origin + direction
		for _, enemy in enemies do
			if enemy.position.X == destination.X and enemy.position.Z == destination.Z then
				local blocked = raycastResultsByEntityId[enemy.entityId]
				if blocked == true then
					return {
						Instance = {
							IsDescendantOf = function()
								return false
							end,
						},
					}
				end
				return nil
			end
		end
		return nil
	end,
}
local playerAddedSignal = signal()
local playerRemovingSignal = signal()
local heartbeatSignal = signal()
local reloadIntentSignal = signal()
local presentationMessages = {}
local presentationRemote = {
	FireClient = function(_, player, payload)
		table.insert(presentationMessages, { player = player, payload = payload })
	end,
	FireAllClients = function(_, payload)
		table.insert(presentationMessages, { player = "all", payload = payload })
	end,
}
local reloadIntentRemote = { OnServerEvent = reloadIntentSignal }
local combatNetwork = {
	WaitForChild = function(_, name)
		if name == "ReloadIntent" then
			return reloadIntentRemote
		end
		assert(name == "CombatPresentation")
		return presentationRemote
	end,
}
local currentPlayers = {}
local playersMock = {
	GetPlayers = function()
		return table.clone(currentPlayers)
	end,
	PlayerAdded = playerAddedSignal,
	PlayerRemoving = playerRemovingSignal,
}

local replicatedStorageMock = setmetatable({
	WaitForChild = function(_, name)
		assert(name == "CombatNetwork")
		return combatNetwork
	end,
	FindFirstChild = function()
		return nil
	end,
}, { __index = sharedReplicatedStorage })

local FIRE_TOKEN = {}
local DAMAGE_TOKEN = {}
local DIRECTOR_TOKEN = {}
local HIT_TOKEN = {}
local LIFE_TOKEN = {}
local MATCH_RESULT_TOKEN = {}
-- The P10-0104 contribution ledger is inert authority: these fixtures only need
-- to prove the owner records through it, never that recording changes gameplay.
local matchResultCalls = {}
local matchResultService = setmetatable({}, {
	__index = function(_self, key)
		return function(...)
			table.insert(matchResultCalls, { name = key, arguments = { ... } })
			return true
		end
	end,
})
local RELIC_TOKEN = {}
local RELOAD_TOKEN = {}
local SELECTOR_TOKEN = {}
local PATTERN_TOKEN = {}
local MAGAZINE_TOKEN = {}
local SUPPLY_TOKEN = {}
local configuredEngineerInspector = nil
local configuredEngineerCommitter = nil

local scheduled = {}
local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau"), {
	debugName = "OperativeCombatRuntimeService",
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return playersMock
				elseif name == "ReplicatedStorage" then
					return replicatedStorageMock
				elseif name == "RunService" then
					return { Heartbeat = heartbeatSignal }
				end
				return workspaceMock
			end,
		},
		script = {
			Parent = {
				Parent = { Domain = { AmmunitionSupplyResolver = SUPPLY_TOKEN } },
				AutomaticFireResolver = FIRE_TOKEN,
				ClassService = CLASS_SERVICE_TOKEN,
				DamageResolver = DAMAGE_TOKEN,
				EnemyDirectorService = DIRECTOR_TOKEN,
				FirearmHitResolver = HIT_TOKEN,
				OperativeLifeService = LIFE_TOKEN,
				MatchResultService = MATCH_RESULT_TOKEN,
				RelicModifierService = RELIC_TOKEN,
				ReloadResolver = RELOAD_TOKEN,
				WeaponTargetSelector = SELECTOR_TOKEN,
				WeaponPatternResolver = PATTERN_TOKEN,
				RunMagazineCapacityResolver = MAGAZINE_TOKEN,
			},
		},
		require = function(token)
			if token == COMBAT_CONTRACTS_TOKEN then
				return combatContracts
			elseif token == SCARCITY_CONTRACTS_TOKEN then
				return scarcityContracts
			elseif token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			elseif token == FIREARM_CONFIG_TOKEN then
				return firearmConfig
			elseif token == HORDE_CONFIG_TOKEN then
				return hordeConfig
			elseif token == FIRE_TOKEN then
				return fireResolver
			elseif token == CLASS_SERVICE_TOKEN then
				return table.freeze({
					configureEngineerResupplyBoundary = function(inspector, committer)
						configuredEngineerInspector = inspector
						configuredEngineerCommitter = committer
					end,
					evaluateActionsAt = function() end,
					interruptBraceForReload = function() end,
					readBraceCadenceMultiplier = function()
						return 1
					end,
				})
			elseif token == DAMAGE_TOKEN then
				return damageResolver
			elseif token == DIRECTOR_TOKEN then
				return enemyDirector
			elseif token == HIT_TOKEN then
				return hitResolver
			elseif token == LIFE_TOKEN then
				return lifeService
			elseif token == MATCH_RESULT_TOKEN then
				return matchResultService
			elseif token == RELIC_TOKEN then
				return relicModifierService
			elseif token == RELOAD_TOKEN then
				return reloadResolver
			elseif token == SELECTOR_TOKEN then
				return selector
			elseif token == PATTERN_TOKEN then
				return table.freeze({
					resolve = function()
						return table.freeze({})
					end,
				})
			elseif token == MAGAZINE_TOKEN then
				return magazineResolver
			elseif token == SUPPLY_TOKEN then
				return supplyResolver
			end
			error("unexpected OperativeCombatRuntimeService dependency")
		end,
		task = {
			delay = function(delaySeconds, callback)
				table.insert(scheduled, { delaySeconds = delaySeconds, callback = callback })
			end,
		},
		RaycastParams = {
			new = function()
				raycastParamsCreated += 1
				return {}
			end,
		},
		Enum = { RaycastFilterType = { Exclude = "Exclude" } },
		print = function() end,
	},
	injectGlobals = true,
})()

local function makePlayer(userId: number, x: number, z: number)
	local root = {
		Position = roblox.Vector3.new(x, 2, z),
		IsA = function(_, className)
			return className == "BasePart"
		end,
	}
	local characterAddedSignal = signal()
	local player = {
		UserId = userId,
		CharacterAdded = characterAddedSignal,
		root = root,
	}
	player.Character = {
		FindFirstChild = function(_, name)
			return if name == "HumanoidRootPart" then root else nil
		end,
		FindFirstChildOfClass = function(_, className)
			return if className == "Humanoid" then { Health = 100 } else nil
		end,
	}
	return player
end

local function messagesOfKind(kindId: string)
	local matches = {}
	for _, message in presentationMessages do
		if message.payload.kindId == kindId then
			table.insert(matches, message)
		end
	end
	return matches
end

local function reset(players: { any })
	service.stop()
	table.clear(enemies)
	table.clear(commitCalls)
	table.clear(raycastCalls)
	table.clear(raycastResultsByEntityId)
	table.clear(presentationMessages)
	table.clear(restrictionCalls)
	table.clear(scheduled)
	table.clear(combatAllowedByPlayer)
	table.clear(currentPlayers)
	enemyFactReadCount = 0
	raycastParamsCreated = 0
	for _, player in players do
		table.insert(currentPlayers, player)
		combatAllowedByPlayer[player] = true
	end
	now = 0
	service.start()
end

local visibilityRadius = enemyConfig.Combat.GameplayVisibilityRadiusStuds
local raycastBudget = enemyConfig.Combat.MaximumLineOfSightRaycastsPerEvaluation

-- One evaluation snapshots director facts once for the whole squad and reuses
-- each operative's raycast parameters on later passes.
local operativeA = makePlayer(1, 0, 0)
local operativeB = makePlayer(2, 4, 0)
reset({ operativeA, operativeB })
addEnemy("enemy.shared-snapshot", 30, 0, { currentHealth = 100000 })
now = 1
service.evaluateAt(now)
assert(enemyFactReadCount == 1, "one squad evaluation must read enemy facts exactly once")
assert(raycastParamsCreated == 4, "each operative must lazily allocate one primary and one pierce parameter")
now += firearmConfig.BasicFirearm.CadenceSeconds
service.evaluateAt(now)
assert(enemyFactReadCount == 2, "each later evaluation must take one fresh shared enemy snapshot")
assert(raycastParamsCreated == 4, "later evaluations must reuse the per-operative raycast parameters")

-- Acquisition, disclosure, fire, damage, cadence.
reset({ operativeA })
addEnemy("enemy.close", 30, 0)
now = 1
service.evaluateAt(now)
local selectedMessages = messagesOfKind("TargetSelected")
assert(#selectedMessages == 1 and selectedMessages[1].payload.targetEntityId == "enemy.close")
assert(selectedMessages[1].payload.operativeEntityId == "operative.player:1")
local shotMessages = messagesOfKind("ShotFired")
assert(#shotMessages == 1, "a loaded weapon must fire at the acquired target")
assert(#commitCalls == 1 and commitCalls[1].entityId == "enemy.close")
assert(commitCalls[1].expectedRevision == 1)
assert(
	commitCalls[1].healthStateAfter.currentHealth
		== enemyConfig.Walker.MaximumHealth - firearmConfig.BasicFirearm.DamagePerHit,
	"one hit must apply exactly the configured firearm damage"
)
local firstShotId = shotMessages[1].payload.shotId
assert(commitCalls[1].healthStateAfter.processedShotIds[firstShotId] == true, "the shot must be duplicate-protected")
-- Cadence: immediately after firing, no second shot.
now = 1 + firearmConfig.BasicFirearm.CadenceSeconds - 0.01
service.evaluateAt(now)
assert(#messagesOfKind("ShotFired") == 1, "cadence must block the second shot")
now = 1 + firearmConfig.BasicFirearm.CadenceSeconds
service.evaluateAt(now)
assert(#messagesOfKind("ShotFired") == 2)

-- Enemy death from operative fire clears the target on the next pass.
enemies[1].currentHealth = 0
enemies[1].isAlive = false
now += 1
service.evaluateAt(now)
assert(#messagesOfKind("TargetCleared") == 1, "a dead enemy must clear the disclosed target")

-- Darkness bounds engagement: within firearm range but beyond the visibility
-- radius is not a candidate.
reset({ operativeA })
addEnemy("enemy.far", visibilityRadius + 1, 0)
now = 1
service.evaluateAt(now)
assert(#messagesOfKind("TargetSelected") == 0, "darkness must hide hostiles beyond the engagement radius")
assert(#raycastCalls == 0, "invisible candidates must not consume raycasts")

-- Raycast budget: only the nearest budgeted candidates are sighted; a fully
-- blocked budget yields no target.
reset({ operativeA })
for index = 1, raycastBudget + 2 do
	addEnemy("enemy.wall:" .. index, 10 + index * 4, 0)
	raycastResultsByEntityId["enemy.wall:" .. index] = true
end
now = 1
service.evaluateAt(now)
assert(#raycastCalls == raycastBudget, "the per-evaluation raycast budget must hold")
assert(#messagesOfKind("TargetSelected") == 0, "blocked line of sight must prevent acquisition")
assert(#messagesOfKind("ShotFired") == 0)

-- Threat priority: the enemy actively pursuing this operative wins over a
-- closer non-threatening one.
reset({ operativeA })
addEnemy("enemy.near", 20, 0)
addEnemy("enemy.threat", 40, 0, { targetOperativeEntityId = "operative.player:1" })
now = 1
service.evaluateAt(now)
local prioritized = messagesOfKind("TargetSelected")
assert(#prioritized == 1 and prioritized[1].payload.targetEntityId == "enemy.threat")

-- Life-state restriction clears the target and disables combat.
reset({ operativeA })
addEnemy("enemy.watcher", 30, 0)
now = 1
service.evaluateAt(now)
assert(#messagesOfKind("TargetSelected") == 1)
combatAllowedByPlayer[operativeA] = false
now = 2
service.evaluateAt(now)
assert(#messagesOfKind("TargetCleared") == 1)
assert(#restrictionCalls >= 1, "restricted operatives must run the shared combat restriction")
now = 3
service.evaluateAt(now)
assert(#messagesOfKind("ShotFired") <= 1, "restricted operatives cannot fire")

-- Reload flow: full magazine rejects silently; an emptied magazine reloads
-- with the authoritative timing; rate limiting holds.
reset({ operativeA })
now = 1
reloadIntentSignal:Fire(operativeA, firearmConfig.BasicFirearm.WeaponId)
assert(#messagesOfKind("ReloadStarted") == 0, "a full magazine must not begin a reload")
-- Empty the magazine against a target.
addEnemy("enemy.pincushion", 30, 0, { currentHealth = 100000 })
for shot = 1, firearmConfig.BasicFirearm.MagazineCapacity do
	now += firearmConfig.BasicFirearm.CadenceSeconds
	service.evaluateAt(now)
end
assert(#messagesOfKind("ShotFired") == firearmConfig.BasicFirearm.MagazineCapacity)
now += 1
reloadIntentSignal:Fire(operativeA, 5)
reloadIntentSignal:Fire(operativeA, firearmConfig.BasicFirearm.WeaponId, "extra")
assert(#messagesOfKind("ReloadStarted") == 0, "malformed reload intents must be ignored")
reloadIntentSignal:Fire(operativeA, firearmConfig.BasicFirearm.WeaponId)
local startedReload = messagesOfKind("ReloadStarted")
assert(#startedReload == 1, "an empty magazine must accept reload intent")
assert(startedReload[1].player == "all", "accepted reload start must be squad-visible")
assert(startedReload[1].payload.operativeEntityId == "operative.player:1")
assert(startedReload[1].payload.completionServerTimestamp == now + firearmConfig.BasicFirearm.ReloadDurationSeconds)
assert(#scheduled == 1 and scheduled[1].delaySeconds == firearmConfig.BasicFirearm.ReloadDurationSeconds)
-- Rate limit: an immediate second intent is dropped.
reloadIntentSignal:Fire(operativeA, firearmConfig.BasicFirearm.WeaponId)
assert(#messagesOfKind("ReloadStarted") == 1, "the server request cooldown must hold")
-- Completion through the scheduled callback.
now += firearmConfig.BasicFirearm.ReloadDurationSeconds
scheduled[1].callback()
local completedReload = messagesOfKind("ReloadCompleted")
assert(#completedReload == 1, "the scheduled completion must transfer ammunition")
assert(completedReload[1].player == "all", "authoritative reload completion must be squad-visible")
assert(completedReload[1].payload.operativeEntityId == "operative.player:1")
now += firearmConfig.BasicFirearm.CadenceSeconds
service.evaluateAt(now)
assert(
	#messagesOfKind("ShotFired") == firearmConfig.BasicFirearm.MagazineCapacity + 1,
	"a completed reload must restore fire"
)

-- Revive combat-state boundary.
local read = service.readReviveCombatState(operativeA)
assert(read ~= nil and type(read.generation) == "number")
assert(read.combatState.selectedTargetState == nil)
assert(type(read.combatState.weaponState) == "table" and type(read.combatState.processedShotIds) == "table")
assert(
	not service.commitReviveCombatState(operativeA, read.generation + 1, read.combatState),
	"stale generations must fail"
)
assert(service.commitReviveCombatState(operativeA, read.generation, read.combatState))
assert(service.readReviveCombatState({ UserId = 999 }) == nil, "unknown players expose no combat state")

-- Engineer resupply uses the combat owner, source deduplication, and reserve cap.
assert(type(configuredEngineerInspector) == "function" and type(configuredEngineerCommitter) == "function")
local compatible, hasCapacity = configuredEngineerInspector(operativeA)
assert(compatible and hasCapacity, "known firearm with reserve capacity must be eligible")
local reserveBeforeSupply = service.readReviveCombatState(operativeA).combatState.weaponState.ammunition.reserveRounds
local didSupply, grantedRounds = configuredEngineerCommitter(operativeA, "class-resupply:test:1", 12)
assert(didSupply and grantedRounds == 12, "engineer supply must commit the configured rounds")
local afterSupply = service.readReviveCombatState(operativeA)
assert(
	afterSupply.combatState.weaponState.ammunition.reserveRounds == reserveBeforeSupply + 12,
	"engineer grant must reach reserve"
)
assert(
	not configuredEngineerCommitter(operativeA, "class-resupply:test:1", 12),
	"duplicate engineer supply ID must fail"
)
afterSupply.combatState.weaponState.ammunition.reserveRounds = firearmConfig.BasicFirearm.MaximumReserveRounds - 1
assert(service.commitReviveCombatState(operativeA, afterSupply.generation, afterSupply.combatState))
local didPartial, partialRounds = configuredEngineerCommitter(operativeA, "class-resupply:test:2", 12)
assert(didPartial and partialRounds == 1, "engineer supply must clamp to remaining reserve capacity")
local engineerState = service.readEngineerResupplyState(operativeA)
assert(engineerState.grantedRoundsBySupplyId["class-resupply:test:1"] == 12, "first grant telemetry")
assert(engineerState.grantedRoundsBySupplyId["class-resupply:test:2"] == 1, "partial grant telemetry")

-- Teardown: stop clears every connection and state.
service.stop()
assert(configuredEngineerInspector == nil and configuredEngineerCommitter == nil, "boundary must clear on stop")
assert(heartbeatSignal:count() == 0 and reloadIntentSignal:count() == 0)
assert(playerAddedSignal:count() == 0 and playerRemovingSignal:count() == 0)
assert(lifeSignal:count() == 0)
assert(service.readReviveCombatState(operativeA) == nil)
service.stop()

-- Source and bootstrap audits: the production runtime is bootstrapped, sends
-- only presentation, and never widens the client request surface.
local source = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
assert(string.find(bootstrap, "OperativeCombatRuntimeService.start()", 1, true) ~= nil)
assert(string.find(bootstrap, "AutomaticCombatDevelopmentHarness", 1, true) == nil)
assert(string.find(source, "IsStudio", 1, true) == nil, "the production runtime must run everywhere")
for _, prohibited in { "RemoteFunction", "InvokeClient", "math.random" } do
	assert(not string.find(source, prohibited, 1, true), "combat runtime must stay narrow: " .. prohibited)
end
local _, broadcastCount = string.gsub(source, "presentationRemote:FireAllClients", "")
assert(broadcastCount == 2, "only accepted shots and reload lifecycle may broadcast to the squad")
assert(
	string.find(
		source,
		"presentationRemote:FireAllClients({\n\t\tkindId = CombatContracts.PresentationMessageKindIds.ShotFired",
		1,
		true
	) ~= nil,
	"accepted ShotFired disclosure must remain squad-visible"
)
assert(
	string.find(source, "local function broadcastReloadPresentation", 1, true) ~= nil,
	"reload lifecycle must use one bounded squad broadcast helper"
)
local _, listenerCount = string.gsub(source, "OnServerEvent:Connect", "")
assert(listenerCount == 1, "reload intent must remain the only client combat input")
local reviveSource = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveSessionService.luau")
assert(
	string.find(reviveSource, "OperativeCombatRuntimeService.readReviveCombatState", 1, true) ~= nil,
	"revive coordination must use the production combat owner"
)

print(
	"OperativeCombatRuntimeService: P5-0106 visibility, budget, priority, fire pipeline, reload, revive, and audits passed"
)
