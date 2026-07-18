--!strict

--[[
	HROI-0105 shared vocabulary and safe validators for squad run-upgrade choices.
	This module cannot generate offers, accept selections, apply stacks, award XP,
	or change combat.
]]

local RunUpgradeContracts = {}

export type UpgradeId = "upgrade.ballistic_calibration" | "upgrade.rapid_cycling" | "upgrade.quick_hands"

export type UpgradeOffer = {
	offerId: string,
	upgradeIds: { UpgradeId },
}

export type UpgradeStacks = { [UpgradeId]: number }

export type CombatModifiers = {
	damageBonus: number,
	cadenceMultiplier: number,
	reloadMultiplier: number,
}

export type SelectionIntent = {
	requestId: string,
	offerId: string,
	upgradeId: UpgradeId,
}

RunUpgradeContracts.UpgradeIds = table.freeze({
	BallisticCalibration = "upgrade.ballistic_calibration",
	RapidCycling = "upgrade.rapid_cycling",
	QuickHands = "upgrade.quick_hands",
})

local validUpgradeIds: { [string]: boolean } = {}
for _, upgradeId in RunUpgradeContracts.UpgradeIds do
	validUpgradeIds[upgradeId] = true
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isWholeNonnegative(value: unknown): boolean
	return isFiniteNumber(value) and value >= 0 and value % 1 == 0
end

local function isNonEmptyString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and value ~= "" and #value <= maximumLength
end

local function hasOnlyKeys(value: { [any]: any }, allowed: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or allowed[key] ~= true then
			return false
		end
	end
	return true
end

function RunUpgradeContracts.isUpgradeId(value: unknown): boolean
	return type(value) == "string" and validUpgradeIds[value] == true
end

function RunUpgradeContracts.validateSelectionIntent(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local payload = value :: { [any]: any }
	if not hasOnlyKeys(payload, { requestId = true, offerId = true, upgradeId = true }) then
		return false
	end
	return isNonEmptyString(payload.requestId, 160)
		and isNonEmptyString(payload.offerId, 200)
		and RunUpgradeContracts.isUpgradeId(payload.upgradeId)
end

function RunUpgradeContracts.validateOffer(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local offer = value :: { [any]: any }
	if not isNonEmptyString(offer.offerId, 200) or type(offer.upgradeIds) ~= "table" or #offer.upgradeIds ~= 3 then
		return false
	end
	local seen: { [string]: boolean } = {}
	for _, upgradeId in offer.upgradeIds do
		if not RunUpgradeContracts.isUpgradeId(upgradeId) or seen[upgradeId] then
			return false
		end
		seen[upgradeId] = true
	end
	return true
end

function RunUpgradeContracts.validateStacks(value: unknown, maximumStacks: number): boolean
	if type(value) ~= "table" or not isWholeNonnegative(maximumStacks) then
		return false
	end
	local stacks = value :: { [any]: any }
	for _, upgradeId in RunUpgradeContracts.UpgradeIds do
		local count = stacks[upgradeId]
		if not isWholeNonnegative(count) or count > maximumStacks then
			return false
		end
	end
	return true
end

function RunUpgradeContracts.validateModifiers(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local modifiers = value :: { [any]: any }
	return isFiniteNumber(modifiers.damageBonus)
		and modifiers.damageBonus >= 0
		and isFiniteNumber(modifiers.cadenceMultiplier)
		and modifiers.cadenceMultiplier > 0
		and modifiers.cadenceMultiplier <= 1
		and isFiniteNumber(modifiers.reloadMultiplier)
		and modifiers.reloadMultiplier > 0
		and modifiers.reloadMultiplier <= 1
end

return table.freeze(RunUpgradeContracts)
