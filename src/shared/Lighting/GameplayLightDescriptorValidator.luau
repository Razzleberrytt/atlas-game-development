--!strict

-- Pure descriptor validation only. This module performs no spatial query,
-- runtime lookup, budget ownership, identity generation, timestamp creation,
-- activation transition, or input mutation.
local GameplayLightContracts = require(script.Parent.GameplayLightContracts)
local GameplayLightingConfig = require(script.Parent.Parent.Config.GameplayLightingConfig)

local GameplayLightDescriptorValidator = {}

local function accepted()
	return table.freeze({
		isValid = true,
		rejectionReasonId = nil,
	})
end

local function rejected(rejectionReasonId: string)
	return table.freeze({
		isValid = false,
		rejectionReasonId = rejectionReasonId,
	})
end

local function isNonemptyString(value: unknown): boolean
	return typeof(value) == "string" and #value > 0
end

local function isFinite(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isKnownValue(values: { [string]: string }, value: unknown): boolean
	if typeof(value) ~= "string" then
		return false
	end

	return values[value] == value
end

local function timestampsAreValid(activation: { [string]: any }): boolean
	local activatedAt = activation.activatedAtServerTimestamp
	local expiresAt = activation.expiresAtServerTimestamp

	if activatedAt ~= nil and (not isFinite(activatedAt) or activatedAt < 0) then
		return false
	end
	if expiresAt ~= nil and (not isFinite(expiresAt) or expiresAt < 0) then
		return false
	end

	return true
end

local function lifetimeIsValid(sourceTypeId: string, activation: { [string]: any }): boolean
	local stateId = activation.stateId
	local activatedAt = activation.activatedAtServerTimestamp
	local expiresAt = activation.expiresAtServerTimestamp

	if stateId == GameplayLightContracts.GameplayLightActivationStateIds.Inactive then
		return activatedAt == nil and expiresAt == nil
	end

	if activatedAt == nil then
		return false
	end

	local requiresExpiry = sourceTypeId == GameplayLightContracts.GameplayLightSourceTypeIds.ApprovedTemporary
		or stateId == GameplayLightContracts.GameplayLightActivationStateIds.Expired
	if requiresExpiry and expiresAt == nil then
		return false
	end
	if expiresAt == nil then
		return true
	end

	local lifetime = expiresAt - activatedAt
	return lifetime >= GameplayLightingConfig.MinimumTemporaryLightLifetimeSeconds
		and lifetime <= GameplayLightingConfig.MaximumTemporaryLightLifetimeSeconds
end

local function coverageIsValid(coverage: unknown): boolean
	if typeof(coverage) ~= "table" then
		return false
	end

	if coverage.kind == GameplayLightContracts.GameplayLightCoverageKindIds.Radius then
		local radius = coverage.radiusStuds
		return isFinite(radius)
			and radius >= GameplayLightingConfig.MinimumCoverageRadiusStuds
			and radius <= GameplayLightingConfig.MaximumCoverageRadiusStuds
	elseif coverage.kind == GameplayLightContracts.GameplayLightCoverageKindIds.ForwardCone then
		local range = coverage.rangeStuds
		local angle = coverage.angleDegrees
		return isFinite(range)
			and range >= GameplayLightingConfig.MinimumConeRangeStuds
			and range <= GameplayLightingConfig.MaximumConeRangeStuds
			and isFinite(angle)
			and angle >= GameplayLightingConfig.MinimumConeAngleDegrees
			and angle <= GameplayLightingConfig.MaximumConeAngleDegrees
	elseif coverage.kind == GameplayLightContracts.GameplayLightCoverageKindIds.AuthoredZone then
		return isNonemptyString(coverage.authoredZoneProfileId)
	end

	return false
end

-- Stable first failure: descriptor, source identity, source type, visibility
-- profile, activation state, timestamp, lifetime, coverage, then ownership.
function GameplayLightDescriptorValidator.validate(descriptor: unknown)
	if typeof(descriptor) ~= "table" or typeof(descriptor.activation) ~= "table" then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidDescriptor)
	end
	if not isNonemptyString(descriptor.sourceId) then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidSourceIdentity)
	end
	if not isKnownValue(GameplayLightContracts.GameplayLightSourceTypeIds, descriptor.sourceTypeId) then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidSourceType)
	end
	if not isKnownValue(GameplayLightContracts.VisibilityProfileIds, descriptor.visibilityProfileId) then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.UnknownVisibilityProfile)
	end
	if not isKnownValue(GameplayLightContracts.GameplayLightActivationStateIds, descriptor.activation.stateId) then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidActivationState)
	end
	if not timestampsAreValid(descriptor.activation) then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidTimestamp)
	end
	if not lifetimeIsValid(descriptor.sourceTypeId, descriptor.activation) then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidLifetime)
	end
	if not coverageIsValid(descriptor.coverage) then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidCoverage)
	end

	local requiresOwner = descriptor.sourceTypeId
		~= GameplayLightContracts.GameplayLightSourceTypeIds.AuthoredEnvironmental
	if requiresOwner then
		if not isNonemptyString(descriptor.ownerEntityId) then
			return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidOwnerIdentity)
		end
	elseif descriptor.ownerEntityId ~= nil then
		return rejected(GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidOwnerIdentity)
	end

	return accepted()
end

return table.freeze(GameplayLightDescriptorValidator)
