--!strict

-- Focused Patch 0.3 MaxHealthPercent integration fixture. It proves that the
-- authoritative life owner rebases health by percentage, that max health cannot
-- be smuggled through an ordinary life transition, and that inventory lifecycle
-- changes route back through the same owner.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local COMBAT_TOKEN = {}
local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local HEALTH_RESOLVER_TOKEN = {}
local HEALING_RESOLVER_TOKEN = {}
local RELIC_MODIFIER_TOKEN = {}

local lifeStateIds = table.freeze({ Alive = "Alive", Incapacitated = "Incapacitated", Dead = "Dead" })
local combatContracts = {
	OperativeCombatStateIds = table.freeze({
		Ready = "Ready",
		Reloading = "Reloading",
		Incapacitated = "Incapacitated",
		Dead = "Dead",
		Disabled = "Disabled",
	}),
	WeaponReadinessStateIds = table.freeze({
		Ready = "Ready",
		Reloading = "Reloading",
		Empty = "Empty",
		Disabled = "Disabled",
	}),
}
local config = { MaximumHealth = 100, SoloRecoveriesPerOperation = 1 }
local contracts = { OperativeLifeStateIds = lifeStateIds }

local function signal()
	local callbacks = {}
	local nextId = 0
	return {
		Connect = function(_self, callback)
			nextId += 1
			local id = nextId
			callbacks[id] = callback
			return {
				Disconnect = function()
					callbacks[id] = nil
				end,
			}
		end,
		Fire = function(_self, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
	}
end

local players = {
	CharacterAutoLoads = true,
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	_members = {},
	GetPlayers = function(self)
		local result = {}
		for player in self._members do
			table.insert(result, player)
		end
		return result
	end,
}
local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = COMBAT_TOKEN },
		Config = { OperativeLifeConfig = CONFIG_TOKEN },
		Health = { OperativeLifeContracts = CONTRACTS_TOKEN },
	},
}

local function fakePlayer(userId: number)
	local player = {
		_className = "Player",
		UserId = userId,
		Parent = players,
		Character = nil,
		CharacterAdded = signal(),
		IsA = function(_self, className)
			return className == "Player"
		end,
		LoadCharacter = function() end,
	}
	players._members[player] = true
	return player
end

local equipmentMaximumHealthMultiplier: any = 1
local environment = {
	game = {
		GetService = function(_self, serviceName: string)
			if serviceName == "Players" then
				return players
			end
			if serviceName == "ReplicatedStorage" then
				return replicatedStorage
			end
			error("unexpected service " .. serviceName)
		end,
	},
	require = function(token)
		if token == COMBAT_TOKEN then
			return combatContracts
		end
		if token == CONFIG_TOKEN then
			return config
		end
		if token == CONTRACTS_TOKEN then
			return contracts
		end
		if token == HEALTH_RESOLVER_TOKEN then
			return {
				resolveDamage = function()
					error("damage path not used")
				end,
			}
		end
		if token == HEALING_RESOLVER_TOKEN then
			return {
				resolve = function()
					error("healing path not used")
				end,
			}
		end
		if token == RELIC_MODIFIER_TOKEN then
			return {
				read = function()
					return {
						equipmentMaximumHealthMultiplier = equipmentMaximumHealthMultiplier,
						secondWindSurvivalHealth = 0,
					}
				end,
				consumeSecondWindCharge = function()
					return false
				end,
			}
		end
		error("unexpected module")
	end,
	script = {
		Parent = {
			OperativeHealingResolver = HEALING_RESOLVER_TOKEN,
			OperativeHealthResolver = HEALTH_RESOLVER_TOKEN,
			RelicModifierService = RELIC_MODIFIER_TOKEN,
		},
	},
	typeof = function(value)
		return if type(value) == "table" and value._className ~= nil then "Instance" else type(value)
	end,
	Vector3 = { zero = { X = 0, Y = 0, Z = 0 } },
	Enum = { HumanoidStateType = { Dead = "Dead" } },
	task = {
		spawn = function(callback)
			callback()
		end,
		defer = function(callback)
			callback()
		end,
		delay = function(_seconds, callback)
			callback()
		end,
	},
}

local Service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau"), {
	debugName = "OperativeLifeServiceMaxHealth",
	environment = environment,
	injectGlobals = true,
})()

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function transition(snapshot: any, timestamp: number)
	return {
		didTransition = true,
		lifeStateIdBefore = snapshot.lifeStateId,
		lifeStateIdAfter = snapshot.lifeStateId,
		transitionServerTimestamp = timestamp,
		snapshotAfter = snapshot,
	}
end

local player = fakePlayer(808)
local registered = Service.registerPlayer(player)
assert(registered ~= nil, "max-health fixture registration failed")
assert(registered.revision == 0, "initial revision must be zero")
assert(registered.snapshot.healthState.currentHealth == 100, "neutral registration must start at base health")
assert(registered.snapshot.healthState.maximumHealth == 100, "neutral registration must start at base maximum")

-- Full-health equip keeps the player full while increasing the authoritative max.
equipmentMaximumHealthMultiplier = 1.08
local equipped = Service.reconcileMaximumHealth(player)
assert(equipped ~= nil and equipped.revision == 1, "equipping Armor must advance the life revision")
assert(equipped.snapshot.healthState.maximumHealth == 108, "8% Armor must produce 108 maximum health")
assert(equipped.snapshot.healthState.currentHealth == 108, "full-health equip must remain full")

-- Put the operative at exactly half health through the normal revisioned commit.
local half = deepCopy(equipped.snapshot)
half.healthState.currentHealth = 54
local damaged = Service.commitAcceptedTransition(player, equipped.revision, transition(half, 10))
assert(damaged.didCommit and damaged.revision == 2, "half-health setup must commit")

-- Unequip preserves the health fraction: 54/108 becomes 50/100, not a heal.
equipmentMaximumHealthMultiplier = 1
local unequipped = Service.reconcileMaximumHealth(player)
assert(unequipped ~= nil and unequipped.revision == 3, "unequip must advance the life revision")
assert(unequipped.snapshot.healthState.maximumHealth == 100, "unequip must restore base maximum")
assert(unequipped.snapshot.healthState.currentHealth == 50, "unequip must preserve the 50% health fraction")

-- Re-equipping returns to 54/108 rather than granting extra effective health.
equipmentMaximumHealthMultiplier = 1.08
local reequipped = Service.reconcileMaximumHealth(player)
assert(reequipped ~= nil and reequipped.revision == 4, "re-equip must advance the life revision")
assert(reequipped.snapshot.healthState.currentHealth == 54, "re-equip must preserve health fraction")
assert(reequipped.snapshot.healthState.maximumHealth == 108, "re-equip must restore Armor maximum")

-- Ordinary life transitions are not allowed to author a new maximum health.
local smuggled = deepCopy(reequipped.snapshot)
smuggled.healthState.maximumHealth = 150
smuggled.healthState.currentHealth = 75
local smuggleResult = Service.commitAcceptedTransition(player, reequipped.revision, transition(smuggled, 11))
assert(not smuggleResult.didCommit, "resolver transition smuggled a maximum-health mutation")
assert(Service.read(player).revision == 4, "rejected maximum-health mutation advanced revision")

-- Incapacitated operatives remain at zero when Armor changes.
local downed = deepCopy(reequipped.snapshot)
downed.lifeStateId = "Incapacitated"
downed.healthState.currentHealth = 0
downed.incapacitationState = { startedAtServerTimestamp = 12, bleedOutDeadlineServerTimestamp = 42 }
local down = Service.commitAcceptedTransition(player, reequipped.revision, {
	didTransition = true,
	lifeStateIdBefore = "Alive",
	lifeStateIdAfter = "Incapacitated",
	transitionServerTimestamp = 12,
	snapshotAfter = downed,
})
assert(down.didCommit, "downed max-health fixture setup failed")
equipmentMaximumHealthMultiplier = 1
local downUnequipped = Service.reconcileMaximumHealth(player)
assert(downUnequipped.snapshot.lifeStateId == "Incapacitated", "Armor change altered downed state")
assert(downUnequipped.snapshot.healthState.currentHealth == 0, "Armor change revived a downed operative")
assert(downUnequipped.snapshot.healthState.maximumHealth == 100, "downed unequip did not restore base maximum")

-- Replay resets to full health at the current authoritative equipment maximum.
equipmentMaximumHealthMultiplier = 1.08
Service.start()
Service.resetForReplay()
local replay = Service.read(player)
assert(replay.snapshot.lifeStateId == "Alive", "replay did not restore Alive state")
assert(replay.snapshot.healthState.maximumHealth == 108, "replay ignored equipped Armor maximum")
assert(replay.snapshot.healthState.currentHealth == 108, "replay did not restore full equipped health")
Service.stop()

-- Missing/malformed equipment modifier facts fail closed to the base maximum.
local neutralPlayer = fakePlayer(809)
equipmentMaximumHealthMultiplier = nil
local neutral = Service.registerPlayer(neutralPlayer)
assert(neutral ~= nil and neutral.snapshot.healthState.maximumHealth == 100, "missing modifier did not fail neutral")
Service.unregisterPlayer(neutralPlayer)
players._members[neutralPlayer] = nil

-- Source-route audit: inventory load, equip and dismantle all explicitly reconcile
-- the life owner, and Armor is selected through the slot-aware path.
local inventoryNetworkSource = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")
assert(
	string.find(inventoryNetworkSource, "InventoryLiveService.loadPlayer", 1, true) ~= nil
		and string.find(inventoryNetworkSource, "OperativeLifeService.reconcileMaximumHealth(player)", 1, true)
			~= nil,
	"inventory load does not reconcile maximum health"
)
assert(string.find(inventoryNetworkSource, "equipOwnedItem.OnServerInvoke", 1, true) ~= nil, "equip route missing")
assert(
	string.find(inventoryNetworkSource, "dismantleOwnedItem.OnServerInvoke", 1, true) ~= nil,
	"dismantle route missing"
)
local compositionSource = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")
assert(
	string.find(compositionSource, 'resolveForSlot(record, "Armor")', 1, true) ~= nil,
	"server composition seam does not select authoritative Armor"
)

print("EquipmentMaxHealthIntegration: authoritative ratio-preserving Armor health path passed")
