--!strict

--[[
	Resolves one server-authoritative firearm attempt from caller-owned state.
	Cadence, ammunition and firing-mode state are committed only through the
	returned weapon state. Automatic, semi-automatic and bounded burst behavior
	all share this resolver; no weapon owns a copied firing script.

	The caller intentionally supplies only a validated selected target, never
	client-authored damage, cadence, ammunition or hit results. A nil selected
	target is also the resolver's release/reset signal for semi/burst latches.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

local function resolveWeaponDefinition(weaponId: unknown)
	local getter = FirearmConfig.get
	if type(getter) == "function" then
		return getter(weaponId)
	end
	local basic = FirearmConfig.BasicFirearm
	return if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end

local MINIMUM_CADENCE_SECONDS = 0.05
local MAXIMUM_AMMO_CONSERVATION_CHANCE = 0.5
local FALLBACK_AUTOMATIC_MODE_ID = "Automatic"
local SEMI_AUTOMATIC_MODE_ID = "SemiAutomatic"
local BURST_MODE_ID = "Burst"

type AmmunitionState = CombatContracts.AmmunitionState
type AutomaticFireDecision = CombatContracts.AutomaticFireDecision
type AutomaticFireRejectionReasonId = CombatContracts.AutomaticFireRejectionReasonId
type AutomaticFireResolution = CombatContracts.AutomaticFireResolution
type CombatEntityId = CombatContracts.CombatEntityId
type OperativeCombatStateId = CombatContracts.OperativeCombatStateId
type ReloadState = CombatContracts.ReloadState
type SelectedTargetState = CombatContracts.SelectedTargetState
type WeaponCadenceState = CombatContracts.WeaponCadenceState
type WeaponReadinessState = CombatContracts.WeaponReadinessState

type FireModeState = {
	weaponId: string,
	firingModeId: string,
	triggerLatched: boolean,
	burstShotsRemaining: number,
}

export type OperativeAutomaticFireState = {
	entityId: CombatEntityId,
	combatStateId: OperativeCombatStateId,
}

type AutomaticFireResolver = {
	resolve: (
		operativeState: OperativeAutomaticFireState,
		selectedTarget: SelectedTargetState?,
		weaponState: WeaponReadinessState,
		serverTimestamp: number,
		cadenceSecondsOverride: number?,
		relicCadenceMultiplier: number?,
		classCadenceMultiplier: number?
	) -> AutomaticFireResolution,
}

local AutomaticFireResolver: AutomaticFireResolver = {} :: AutomaticFireResolver
local rejectionReasons = CombatContracts.AutomaticFireRejectionReasonIds

local function copyAmmunition(ammunition: AmmunitionState): AmmunitionState
	return {
		weaponId = ammunition.weaponId,
		loadedRounds = ammunition.loadedRounds,
		reserveRounds = ammunition.reserveRounds,
		magazineCapacity = ammunition.magazineCapacity,
	}
end

local function copyCadence(cadence: WeaponCadenceState): WeaponCadenceState
	return {
		weaponId = cadence.weaponId,
		lastFireServerTimestamp = cadence.lastFireServerTimestamp,
		nextAllowedFireServerTimestamp = cadence.nextAllowedFireServerTimestamp,
	}
end

local function copyReloadState(reloadState: ReloadState?): ReloadState?
	if reloadState == nil then
		return nil
	end
	return {
		weaponId = reloadState.weaponId,
		startedAtServerTimestamp = reloadState.startedAtServerTimestamp,
		completionServerTimestamp = reloadState.completionServerTimestamp,
	}
end

local function readFireModeState(weaponState: WeaponReadinessState, firingModeId: string): FireModeState
	local raw = (weaponState :: any).fireModeState
	if
		type(raw) == "table"
		and raw.weaponId == weaponState.weaponId
		and raw.firingModeId == firingModeId
		and type(raw.triggerLatched) == "boolean"
		and type(raw.burstShotsRemaining) == "number"
		and raw.burstShotsRemaining >= 0
		and raw.burstShotsRemaining % 1 == 0
	then
		return {
			weaponId = weaponState.weaponId,
			firingModeId = firingModeId,
			triggerLatched = raw.triggerLatched,
			burstShotsRemaining = raw.burstShotsRemaining,
		}
	end
	return {
		weaponId = weaponState.weaponId,
		firingModeId = firingModeId,
		triggerLatched = false,
		burstShotsRemaining = 0,
	}
end

local function copyWeaponState(weaponState: WeaponReadinessState): WeaponReadinessState
	local result: any = {
		weaponId = weaponState.weaponId,
		readinessStateId = weaponState.readinessStateId,
		ammunition = copyAmmunition(weaponState.ammunition),
		cadence = copyCadence(weaponState.cadence),
		reloadState = copyReloadState(weaponState.reloadState),
	}
	local raw = (weaponState :: any).fireModeState
	if type(raw) == "table" then
		result.fireModeState = {
			weaponId = raw.weaponId,
			firingModeId = raw.firingModeId,
			triggerLatched = raw.triggerLatched,
			burstShotsRemaining = raw.burstShotsRemaining,
		}
	end
	return result :: WeaponReadinessState
end

local function setFireModeState(weaponState: WeaponReadinessState, fireModeState: FireModeState): WeaponReadinessState
	local result = copyWeaponState(weaponState);
	(result :: any).fireModeState = fireModeState
	return result
end

local function createDecision(
	operativeState: OperativeAutomaticFireState,
	weaponState: WeaponReadinessState,
	targetEntityId: CombatEntityId?,
	serverTimestamp: number,
	shouldFire: boolean,
	rejectionReasonId: AutomaticFireRejectionReasonId?
): AutomaticFireDecision
	return {
		shouldFire = shouldFire,
		operativeEntityId = operativeState.entityId,
		weaponId = weaponState.weaponId,
		targetEntityId = targetEntityId,
		evaluatedAtServerTimestamp = serverTimestamp,
		rejectionReasonId = rejectionReasonId,
	}
end

local function rejection(
	operativeState: OperativeAutomaticFireState,
	weaponStateAfter: WeaponReadinessState,
	targetEntityId: CombatEntityId?,
	serverTimestamp: number,
	reasonId: AutomaticFireRejectionReasonId
): AutomaticFireResolution
	return {
		decision = createDecision(operativeState, weaponStateAfter, targetEntityId, serverTimestamp, false, reasonId),
		fireResult = {
			statusId = CombatContracts.AuthoritativeFireStatusIds.Rejected,
			shotId = nil,
			operativeEntityId = operativeState.entityId,
			weaponId = weaponStateAfter.weaponId,
			targetEntityId = targetEntityId,
			firedAtServerTimestamp = nil,
			ammunitionAfter = copyAmmunition(weaponStateAfter.ammunition),
			didHit = nil,
			hitEntityId = nil,
			rejectionReasonId = reasonId,
		},
		weaponStateAfter = weaponStateAfter,
	}
end

local function reject(
	operativeState: OperativeAutomaticFireState,
	weaponState: WeaponReadinessState,
	targetEntityId: CombatEntityId?,
	serverTimestamp: number,
	reasonId: AutomaticFireRejectionReasonId
): AutomaticFireResolution
	return rejection(operativeState, copyWeaponState(weaponState), targetEntityId, serverTimestamp, reasonId)
end

local function deterministicShotId(
	operativeEntityId: CombatEntityId,
	weaponId: CombatContracts.WeaponId,
	serverTimestamp: number
): CombatContracts.ShotId
	return string.format("shot:%s:%s:%.17g", operativeEntityId, weaponId, serverTimestamp)
end

local function stableUnitInterval(text: string): number
	local hash = 17
	for index = 1, #text do
		hash = (hash * 31 + string.byte(text, index) * index) % 2147483647
	end
	return (hash % 10000) / 10000
end

local function readProgressionNumber(attributeName: string, fallback: number): number
	local storageAsAny = ReplicatedStorage :: any
	if type(storageAsAny.FindFirstChild) ~= "function" then
		return fallback
	end
	local network = storageAsAny:FindFirstChild("ProgressionNetwork")
	if network == nil or type(network.GetAttribute) ~= "function" then
		return fallback
	end
	local value = network:GetAttribute(attributeName)
	return if type(value) == "number" and value == value then value else fallback
end

local RELIC_CADENCE_MULTIPLIER_FLOOR = 0.55
local CLASS_CADENCE_MULTIPLIER_FLOOR = 0.75

local function resolveCadenceSeconds(
	weaponId: string,
	override: number?,
	relicCadenceMultiplier: number?,
	classCadenceMultiplier: number?
): number?
	local definition = resolveWeaponDefinition(weaponId)
	if definition == nil then
		return nil
	end
	local configured = definition.CadenceSeconds
	local requested = override
	if requested == nil then
		local multiplier = readProgressionNumber("RunCadenceMultiplier", 1)
		local relicMultiplier = 1
		if relicCadenceMultiplier ~= nil then
			if
				type(relicCadenceMultiplier) ~= "number"
				or relicCadenceMultiplier ~= relicCadenceMultiplier
				or relicCadenceMultiplier < RELIC_CADENCE_MULTIPLIER_FLOOR
				or relicCadenceMultiplier > 1
			then
				return nil
			end
			relicMultiplier = relicCadenceMultiplier
		end
		local classMultiplier = 1
		if classCadenceMultiplier ~= nil then
			if
				type(classCadenceMultiplier) ~= "number"
				or classCadenceMultiplier ~= classCadenceMultiplier
				or classCadenceMultiplier < CLASS_CADENCE_MULTIPLIER_FLOOR
				or classCadenceMultiplier > 1
			then
				return nil
			end
			classMultiplier = classCadenceMultiplier
		end
		requested = configured * multiplier * relicMultiplier * classMultiplier
	end
	if
		type(requested) ~= "number"
		or requested ~= requested
		or requested < MINIMUM_CADENCE_SECONDS
		or requested > configured
	then
		return nil
	end
	return requested
end

local function resolveAmmoConservationChance(): number?
	local chance = readProgressionNumber("RunAmmoConservationChance", 0)
	if chance < 0 or chance > MAXIMUM_AMMO_CONSERVATION_CHANCE then
		return nil
	end
	return chance
end

local function resolveFiringMode(definition: any): string?
	local modeId = definition.FiringModeId
	if modeId == nil then
		return FALLBACK_AUTOMATIC_MODE_ID
	end
	if modeId == FALLBACK_AUTOMATIC_MODE_ID or modeId == SEMI_AUTOMATIC_MODE_ID or modeId == BURST_MODE_ID then
		return modeId
	end
	return nil
end

function AutomaticFireResolver.resolve(
	operativeState: OperativeAutomaticFireState,
	selectedTarget: SelectedTargetState?,
	weaponState: WeaponReadinessState,
	serverTimestamp: number,
	cadenceSecondsOverride: number?,
	relicCadenceMultiplier: number?,
	classCadenceMultiplier: number?
): AutomaticFireResolution
	local targetEntityId = if selectedTarget == nil then nil else selectedTarget.targetEntityId
	if operativeState.combatStateId ~= CombatContracts.OperativeCombatStateIds.Ready then
		return reject(
			operativeState,
			weaponState,
			targetEntityId,
			serverTimestamp,
			rejectionReasons.OperativeStateInvalid
		)
	end

	if
		selectedTarget ~= nil
		and (
			not selectedTarget.isValid
			or selectedTarget.operativeEntityId ~= operativeState.entityId
			or targetEntityId == nil
		)
	then
		return reject(
			operativeState,
			weaponState,
			targetEntityId,
			serverTimestamp,
			rejectionReasons.SelectedTargetInvalid
		)
	end

	local configuredWeapon = resolveWeaponDefinition(weaponState.weaponId)
	if configuredWeapon == nil then
		return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.WeaponNotReady)
	end
	local firingModeId = resolveFiringMode(configuredWeapon)
	if firingModeId == nil then
		return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.WeaponNotReady)
	end
	local fireModeState = readFireModeState(weaponState, firingModeId)

	if selectedTarget == nil then
		if firingModeId ~= FALLBACK_AUTOMATIC_MODE_ID then
			fireModeState.triggerLatched = false
			fireModeState.burstShotsRemaining = 0
			return rejection(
				operativeState,
				setFireModeState(weaponState, fireModeState),
				nil,
				serverTimestamp,
				rejectionReasons.NoSelectedTarget
			)
		end
		return reject(operativeState, weaponState, nil, serverTimestamp, rejectionReasons.NoSelectedTarget)
	end

	if firingModeId == SEMI_AUTOMATIC_MODE_ID and fireModeState.triggerLatched then
		return rejection(
			operativeState,
			setFireModeState(weaponState, fireModeState),
			targetEntityId,
			serverTimestamp,
			rejectionReasons.CadenceBlocked
		)
	end
	if firingModeId == BURST_MODE_ID then
		if fireModeState.triggerLatched and fireModeState.burstShotsRemaining <= 0 then
			return rejection(
				operativeState,
				setFireModeState(weaponState, fireModeState),
				targetEntityId,
				serverTimestamp,
				rejectionReasons.CadenceBlocked
			)
		end
		if not fireModeState.triggerLatched then
			local burstCount = configuredWeapon.BurstCount
			if type(burstCount) ~= "number" or burstCount < 2 or burstCount > 5 or burstCount % 1 ~= 0 then
				return reject(
					operativeState,
					weaponState,
					targetEntityId,
					serverTimestamp,
					rejectionReasons.WeaponNotReady
				)
			end
			fireModeState.burstShotsRemaining = burstCount
		end
	end

	local effectiveCadenceOverride = cadenceSecondsOverride
	if firingModeId == BURST_MODE_ID and fireModeState.burstShotsRemaining > 1 then
		local burstInterval = configuredWeapon.BurstIntervalSeconds
		if
			type(burstInterval) ~= "number"
			or burstInterval < MINIMUM_CADENCE_SECONDS
			or burstInterval > configuredWeapon.CadenceSeconds
		then
			return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.WeaponNotReady)
		end
		effectiveCadenceOverride = if effectiveCadenceOverride == nil
			then burstInterval
			else math.min(effectiveCadenceOverride, burstInterval)
	end
	local cadenceSeconds = resolveCadenceSeconds(
		weaponState.weaponId,
		effectiveCadenceOverride,
		relicCadenceMultiplier,
		classCadenceMultiplier
	)
	local ammoConservationChance = resolveAmmoConservationChance()
	if
		cadenceSeconds == nil
		or ammoConservationChance == nil
		or weaponState.ammunition.weaponId ~= weaponState.weaponId
		or weaponState.cadence.weaponId ~= weaponState.weaponId
		or weaponState.readinessStateId ~= CombatContracts.WeaponReadinessStateIds.Ready
	then
		return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.WeaponNotReady)
	end
	if weaponState.ammunition.loadedRounds <= 0 then
		return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.NoAmmunition)
	end
	if serverTimestamp < weaponState.cadence.nextAllowedFireServerTimestamp then
		if firingModeId == FALLBACK_AUTOMATIC_MODE_ID then
			return reject(operativeState, weaponState, targetEntityId, serverTimestamp, rejectionReasons.CadenceBlocked)
		end
		return rejection(
			operativeState,
			setFireModeState(weaponState, fireModeState),
			targetEntityId,
			serverTimestamp,
			rejectionReasons.CadenceBlocked
		)
	end

	local shotId = deterministicShotId(operativeState.entityId, weaponState.weaponId, serverTimestamp)
	local ammunitionAfter = copyAmmunition(weaponState.ammunition)
	if stableUnitInterval(shotId) >= ammoConservationChance then
		ammunitionAfter.loadedRounds -= 1
	end
	local cadenceAfter = copyCadence(weaponState.cadence)
	cadenceAfter.lastFireServerTimestamp = serverTimestamp
	cadenceAfter.nextAllowedFireServerTimestamp = serverTimestamp + cadenceSeconds
	if firingModeId == SEMI_AUTOMATIC_MODE_ID then
		fireModeState.triggerLatched = true
	elseif firingModeId == BURST_MODE_ID then
		fireModeState.triggerLatched = true
		fireModeState.burstShotsRemaining = math.max(0, fireModeState.burstShotsRemaining - 1)
	end

	local weaponStateAfter: any = {
		weaponId = weaponState.weaponId,
		readinessStateId = weaponState.readinessStateId,
		ammunition = ammunitionAfter,
		cadence = cadenceAfter,
		reloadState = copyReloadState(weaponState.reloadState),
	}
	if firingModeId ~= FALLBACK_AUTOMATIC_MODE_ID then
		weaponStateAfter.fireModeState = fireModeState
	end

	return {
		decision = createDecision(operativeState, weaponState, targetEntityId, serverTimestamp, true, nil),
		fireResult = {
			statusId = CombatContracts.AuthoritativeFireStatusIds.Fired,
			shotId = shotId,
			operativeEntityId = operativeState.entityId,
			weaponId = weaponState.weaponId,
			targetEntityId = targetEntityId,
			firedAtServerTimestamp = serverTimestamp,
			ammunitionAfter = copyAmmunition(ammunitionAfter),
			didHit = nil,
			hitEntityId = nil,
			rejectionReasonId = nil,
		},
		weaponStateAfter = weaponStateAfter :: WeaponReadinessState,
	}
end

return table.freeze(AutomaticFireResolver)
