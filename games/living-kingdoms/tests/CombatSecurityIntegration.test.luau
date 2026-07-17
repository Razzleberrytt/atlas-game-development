--!strict

-- LK-0207 two-operative integration/security fixture. It composes the existing
-- production P2 pure modules and audits the committed combat remote boundary.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local VALIDATOR_TOKEN = {}

local contracts = {
	CombatEntityKindIds = table.freeze({ Hostile = "Hostile" }),
	OperativeCombatStateIds = table.freeze({ Ready = "Ready", Reloading = "Reloading" }),
	TeamRelationshipIds = table.freeze({ Hostile = "Hostile" }),
	WeaponReadinessStateIds = table.freeze({ Ready = "Ready", Reloading = "Reloading", Empty = "Empty" }),
	TargetValidationRejectionReasonIds = table.freeze({
		OperativeStateInvalid = "OperativeStateInvalid",
		RelationshipNotHostile = "RelationshipNotHostile",
		HostileDead = "HostileDead",
		HostileUntargetable = "HostileUntargetable",
		NotVisible = "NotVisible",
		NoLineOfSight = "NoLineOfSight",
		OutOfRange = "OutOfRange",
		NoAmmunition = "NoAmmunition",
		WeaponNotReady = "WeaponNotReady",
	}),
	TargetSelectionReasonIds = table.freeze({
		ThreateningClosest = "ThreateningClosest",
		ValidClosest = "ValidClosest",
	}),
	AutomaticFireRejectionReasonIds = table.freeze({
		NoSelectedTarget = "NoSelectedTarget",
		SelectedTargetInvalid = "SelectedTargetInvalid",
		OperativeStateInvalid = "OperativeStateInvalid",
		NoAmmunition = "NoAmmunition",
		WeaponNotReady = "WeaponNotReady",
		CadenceBlocked = "CadenceBlocked",
	}),
	AuthoritativeFireStatusIds = table.freeze({ Fired = "Fired", Rejected = "Rejected" }),
	ShotObstructionResultIds = table.freeze({ TargetHit = "TargetHit", Blocked = "Blocked", Miss = "Miss" }),
	FirearmHitRejectionReasonIds = table.freeze({
		FireNotAccepted = "FireNotAccepted",
		MissingShotIdentity = "MissingShotIdentity",
		WeaponInvalid = "WeaponInvalid",
		TargetMismatch = "TargetMismatch",
		TargetInvalid = "TargetInvalid",
		TargetDead = "TargetDead",
		TargetNotHostile = "TargetNotHostile",
		NotVisible = "NotVisible",
		OutOfRange = "OutOfRange",
		LineOfSightBlocked = "LineOfSightBlocked",
		Miss = "Miss",
		ShotAlreadyResolved = "ShotAlreadyResolved",
	}),
	ReloadRejectionReasonIds = table.freeze({
		OperativeStateInvalid = "OperativeStateInvalid",
		WeaponInvalid = "WeaponInvalid",
		WeaponNotReady = "WeaponNotReady",
		AlreadyReloading = "AlreadyReloading",
		MagazineFull = "MagazineFull",
		NoReserveAmmunition = "NoReserveAmmunition",
		ReloadNotInProgress = "ReloadNotInProgress",
		ReloadNotComplete = "ReloadNotComplete",
		ReloadInterrupted = "ReloadInterrupted",
	}),
}

local config = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		DamageTypeId = "Ballistic",
		RangeStuds = 80,
		CadenceSeconds = 0.2,
		MagazineCapacity = 12,
		ReloadDurationSeconds = 2,
		DamagePerHit = 20,
	}),
}

local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = CONTRACTS_TOKEN },
		Config = { FirearmConfig = CONFIG_TOKEN },
	},
}
local baseEnvironment = {
	game = {
		GetService = function(_self: unknown, serviceName: string)
			assert(serviceName == "ReplicatedStorage", "unexpected service request")
			return replicatedStorage
		end,
	},
}

local function loadProduction(path: string, debugName: string, extraRequire: ((unknown) -> any)?)
	local environment = table.clone(baseEnvironment)
	environment.require = function(token: unknown)
		if token == CONTRACTS_TOKEN then
			return contracts
		end
		if token == CONFIG_TOKEN then
			return config
		end
		if extraRequire ~= nil then
			return extraRequire(token)
		end
		error("unexpected module request")
	end
	local loader = luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = environment,
		injectGlobals = true,
	})
	return loader()
end

local validator = loadProduction(
	"games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau",
	"TargetCandidateValidator",
	nil
)
local selectorEnvironment = table.clone(baseEnvironment)
selectorEnvironment.script = { Parent = { TargetCandidateValidator = VALIDATOR_TOKEN } }
selectorEnvironment.require = function(token: unknown)
	if token == CONTRACTS_TOKEN then
		return contracts
	end
	if token == VALIDATOR_TOKEN then
		return validator
	end
	error("unexpected selector module request")
end
local selectorLoader = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/TargetCandidateSelector.luau"), {
	debugName = "TargetCandidateSelector",
	environment = selectorEnvironment,
	injectGlobals = true,
})
local selector = selectorLoader()
local fireResolver =
	loadProduction("games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau", "AutomaticFireResolver", nil)
local hitResolver =
	loadProduction("games/living-kingdoms/src/server/Systems/FirearmHitResolver.luau", "FirearmHitResolver", nil)
local damageResolver =
	loadProduction("games/living-kingdoms/src/server/Systems/DamageResolver.luau", "DamageResolver", nil)
local reloadResolver =
	loadProduction("games/living-kingdoms/src/server/Systems/ReloadResolver.luau", "ReloadResolver", nil)

local function position(x: number, z: number)
	return { X = x, Y = 0, Z = z }
end

local function weaponState(loadedRounds: number, reserveRounds: number)
	return {
		weaponId = "weapon.basic_firearm",
		readinessStateId = "Ready",
		ammunition = {
			weaponId = "weapon.basic_firearm",
			loadedRounds = loadedRounds,
			reserveRounds = reserveRounds,
			magazineCapacity = 12,
		},
		cadence = {
			weaponId = "weapon.basic_firearm",
			lastFireServerTimestamp = nil,
			nextAllowedFireServerTimestamp = 0,
		},
		reloadState = nil,
	}
end

local function operative(entityId: string, loadedRounds: number)
	return {
		entityId = entityId,
		worldPosition = position(0, 0),
		combatStateId = "Ready",
		weaponReadiness = weaponState(loadedRounds, 24),
	}
end

local function candidate(entityId: string, x: number, threatEntityId: string?)
	return {
		entityId = entityId,
		entityKindId = "Hostile",
		teamId = "hostiles",
		relationshipId = "Hostile",
		worldPosition = position(x, 0),
		distanceStuds = 999999,
		isAlive = true,
		isTargetable = true,
		isVisible = true,
		hasLineOfSight = true,
		isActivelyThreatening = threatEntityId ~= nil,
		activelyThreateningOperativeEntityId = threatEntityId,
	}
end

local operativeA = operative("operative.a", 2)
local operativeB = operative("operative.b", 3)
local alphaForA = candidate("hostile.alpha", 20, "operative.a")
local bravoForA = candidate("hostile.bravo", 5, "operative.b")
local alphaForB = candidate("hostile.alpha", 5, "operative.a")
local bravoForB = candidate("hostile.bravo", 20, "operative.b")
local selectedA = selector.select(operativeA, { bravoForA, alphaForA })
local selectedB = selector.select(operativeB, { alphaForB, bravoForB })
assert(selectedA.targetEntityId == "hostile.alpha", "A did not prefer its own threat")
assert(selectedB.targetEntityId == "hostile.bravo", "B did not prefer its own threat")

local forgedSelection = table.clone(selectedB)
forgedSelection.operativeEntityId = "operative.b"
local forgedFire = fireResolver.resolve(
	{ entityId = "operative.a", combatStateId = "Ready" },
	forgedSelection,
	operativeA.weaponReadiness,
	10
)
assert(not forgedFire.decision.shouldFire, "A fired B's selection")
assert(forgedFire.decision.rejectionReasonId == "SelectedTargetInvalid", "wrong cross-operative rejection")

local firedA = fireResolver.resolve(
	{ entityId = "operative.a", combatStateId = "Ready" },
	selectedA,
	operativeA.weaponReadiness,
	10
)
operativeA.weaponReadiness = firedA.weaponStateAfter
assert(firedA.decision.shouldFire, "A's authoritative shot was rejected")
assert(operativeA.weaponReadiness.ammunition.loadedRounds == 1, "A did not consume exactly one round")
assert(operativeA.weaponReadiness.ammunition.reserveRounds == 24, "A changed reserve while firing")
assert(operativeB.weaponReadiness.ammunition.loadedRounds == 3, "A changed B's ammunition")

local tooFastA = fireResolver.resolve(
	{ entityId = "operative.a", combatStateId = "Ready" },
	selectedA,
	operativeA.weaponReadiness,
	10.1
)
assert(tooFastA.decision.rejectionReasonId == "CadenceBlocked", "A bypassed cadence")
local firedB = fireResolver.resolve(
	{ entityId = "operative.b", combatStateId = "Ready" },
	selectedB,
	operativeB.weaponReadiness,
	10.1
)
assert(firedB.decision.shouldFire, "B's independent cadence was blocked by A")
assert(firedB.weaponStateAfter.ammunition.loadedRounds == 2, "B consumed the wrong ammunition")
local boundaryA = fireResolver.resolve(
	{ entityId = "operative.a", combatStateId = "Ready" },
	selectedA,
	operativeA.weaponReadiness,
	10.2
)
assert(boundaryA.decision.shouldFire, "exact cadence boundary was rejected")
assert(boundaryA.weaponStateAfter.ammunition.loadedRounds == 0, "last loaded round did not fire")

local targetContext = {
	entityId = "hostile.alpha",
	worldPosition = position(20, 0),
	isAlive = true,
	isTargetable = true,
	relationshipId = "Hostile",
	isVisible = true,
}
local shotContext = {
	operativeEntityId = "operative.a",
	weaponId = "weapon.basic_firearm",
	selectedTargetEntityId = "hostile.alpha",
	operativeWorldPosition = position(0, 0),
	obstructionResultId = "TargetHit",
}
local hitA = hitResolver.resolve(firedA.fireResult, shotContext, targetContext)
local alphaHealth = { entityId = "hostile.alpha", currentHealth = 40, processedShotIds = {} }
local damageA = damageResolver.resolve(hitA, alphaHealth, 10.01)
assert(damageA.didApplyDamage and damageA.targetHealthStateAfter.currentHealth == 20, "configured damage failed")
assert(damageA.damageEvent.damageAmount == 20, "damage amount was not authoritative")
assert(damageA.damageEvent.damageTypeId == "Ballistic", "damage type was not authoritative")
local duplicateA = damageResolver.resolve(hitA, damageA.targetHealthStateAfter, 10.02)
assert(not duplicateA.didApplyDamage and duplicateA.rejectionReasonId == "ShotAlreadyResolved", "ShotId replay applied")

local blockedContext = table.clone(shotContext)
blockedContext.obstructionResultId = "Blocked"
local blockedHit = hitResolver.resolve(boundaryA.fireResult, blockedContext, targetContext)
local blockedDamage = damageResolver.resolve(blockedHit, damageA.targetHealthStateAfter, 10.21)
assert(not blockedDamage.didApplyDamage, "obstructed shot applied damage")
assert(blockedDamage.targetHealthStateAfter.currentHealth == 20, "obstructed shot changed health")

local reloadOperativeA = {
	entityId = "operative.a",
	combatStateId = "Ready",
	equippedWeaponId = "weapon.basic_firearm",
}
local reloadWeaponA = weaponState(6, 4)
local reloadWeaponB = weaponState(7, 9)
local reloadBeginA = reloadResolver.begin(reloadOperativeA, reloadWeaponA, 20)
assert(reloadBeginA.didBegin, "A reload did not begin")
assert(
	reloadWeaponB.ammunition.loadedRounds == 7 and reloadWeaponB.ammunition.reserveRounds == 9,
	"A changed B reload state"
)
local reloadBeforeA =
	reloadResolver.complete(reloadBeginA.operativeStateAfter, reloadBeginA.weaponStateAfter, 21.999999)
assert(
	not reloadBeforeA.didComplete and reloadBeforeA.rejectionReasonId == "ReloadNotComplete",
	"early reload completed"
)
local reloadCompleteA = reloadResolver.complete(reloadBeginA.operativeStateAfter, reloadBeginA.weaponStateAfter, 22)
assert(reloadCompleteA.didComplete, "authoritative two-second reload did not complete")
assert(reloadCompleteA.weaponStateAfter.ammunition.loadedRounds == 10, "reload transfer was incorrect")
assert(reloadCompleteA.weaponStateAfter.ammunition.reserveRounds == 0, "reload reserve transfer was incorrect")

local projectSource = fs.readFile("games/living-kingdoms/default.project.json")
local serverSources = table.concat({
	fs.readFile("games/living-kingdoms/src/server/Systems/AutomaticCombatDevelopmentHarness.luau"),
	fs.readFile("games/living-kingdoms/src/server/init.server.luau"),
}, "\n")
local clientSource = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local combatNetworkStart = assert(string.find(projectSource, '"CombatNetwork"', 1, true))
local combatNetworkEnd = assert(string.find(projectSource, '"Shared"', combatNetworkStart, true))
local combatNetworkSource = string.sub(projectSource, combatNetworkStart, combatNetworkEnd - 1)
local _, remoteDefinitionCount = string.gsub(combatNetworkSource, '"%$className"%s*:%s*"RemoteEvent"', "")
assert(remoteDefinitionCount == 2, "combat remote surface changed")
local _, serverListenerCount = string.gsub(serverSources, "OnServerEvent:Connect", "")
assert(serverListenerCount == 1, "client-to-server combat listener surface changed")
assert(
	string.find(serverSources, "reloadIntentRemote.OnServerEvent:Connect", 1, true),
	"reload intent listener missing"
)
assert(
	not string.find(serverSources, "presentationRemote.OnServerEvent", 1, true),
	"presentation gained authority path"
)
local _, fireServerCount = string.gsub(clientSource, ":FireServer", "")
assert(fireServerCount == 1, "client gained another combat request path")
assert(
	string.find(clientSource, "reloadIntentRemote:FireServer(FirearmConfig.BasicFirearm.WeaponId)", 1, true),
	"reload request payload widened"
)
assert(
	string.find(serverSources, "if started or not RunService:IsStudio() then", 1, true),
	"development harness is not Studio-gated"
)

print(
	"CombatSecurityIntegration: two-operative authority, isolation, cadence, damage, reload, remotes, and Studio gate passed"
)
