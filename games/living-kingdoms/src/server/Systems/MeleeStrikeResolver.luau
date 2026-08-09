--!strict

--[[
	Pure melee target resolver. It chooses one living hostile inside the configured
	close-range aim cone. It performs no networking, damage mutation, raycasts,
	ammunition handling, or Workspace reads; the server runtime owns those facts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeContracts = require(ReplicatedStorage.Shared.Combat.MeleeContracts)
local MeleeCombatConfig = require(ReplicatedStorage.Shared.Config.MeleeCombatConfig)

local Resolver = {}
local Reasons = MeleeContracts.RejectionReasonIds

local function finiteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function usableDirection(direction: Vector3): boolean
	return finiteNumber(direction.X)
		and finiteNumber(direction.Y)
		and finiteNumber(direction.Z)
		and direction.Magnitude > 0.001
end

function Resolver.selectTarget(
	operativeWorldPosition: Vector3,
	aimDirection: Vector3,
	candidates: { MeleeContracts.MeleeTargetCandidate }
): MeleeContracts.MeleeTargetSelection
	if not usableDirection(aimDirection) then
		return {
			targetEntityId = nil,
			distanceStuds = nil,
			aimDot = nil,
			rejectionReasonId = Reasons.InvalidIntent,
		}
	end

	local normalizedAim = aimDirection.Unit
	local minimumAimDot = math.cos(math.rad(MeleeCombatConfig.OpeningWeapon.AimHalfAngleDegrees))
	local maximumDistance = MeleeCombatConfig.OpeningWeapon.RangeStuds
	local bestEntityId: string? = nil
	local bestDistance = math.huge
	local bestAimDot = -1

	for _, candidate in candidates do
		if candidate.isAlive then
			local offset = candidate.worldPosition - operativeWorldPosition
			local distance = offset.Magnitude
			if distance > 0.001 and distance <= maximumDistance then
				local aimDot = normalizedAim:Dot(offset.Unit)
				if aimDot >= minimumAimDot then
					local isBetter = distance < bestDistance
						or (distance == bestDistance and aimDot > bestAimDot)
						or (
							distance == bestDistance
							and aimDot == bestAimDot
							and (bestEntityId == nil or candidate.entityId < bestEntityId)
						)
					if isBetter then
						bestEntityId = candidate.entityId
						bestDistance = distance
						bestAimDot = aimDot
					end
				end
			end
		end
	end

	if bestEntityId == nil then
		return {
			targetEntityId = nil,
			distanceStuds = nil,
			aimDot = nil,
			rejectionReasonId = Reasons.NoTarget,
		}
	end
	return {
		targetEntityId = bestEntityId,
		distanceStuds = bestDistance,
		aimDot = bestAimDot,
		rejectionReasonId = nil,
	}
end

return table.freeze(Resolver)
