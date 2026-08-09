--!strict

--[[
	BA-052 live discovery definition for the first outdoor route.
	Stable content IDs remain independent from raw Workspace paths. Runtime
	consumption is intentionally limited to the already-source-managed Lookout
	landmark and does not activate BA-050 imported route geometry.
]]

local FirstOutdoorRouteConfig = require(script.Parent.FirstOutdoorRouteConfig)
local WorldContentConfig = require(script.Parent.WorldContentConfig)
local RunRpgContracts = require(script.Parent.Parent.RPG.RunRpgContracts)

local Discovery = table.freeze({
	Id = "discovery.first-descent.lookout-cache",
	Version = "1.1.0",
	DisplayName = "Lookout Cache",
	RouteId = FirstOutdoorRouteConfig.RouteId,
	DiscoverySlotId = FirstOutdoorRouteConfig.DiscoverySlotIds.LookoutTower,
	AnchorWorldContentId = "landmark.lookout_tower",
	RuntimeLandmarkId = "LookoutTower",
	StreamingIdentityId = "streaming.discovery.first-descent.lookout-cache",
	GameplayMeaningId = "OptionalVantageCache",
	PresentationIntentId = "ReadableOptionalDetour",
	RewardSourceId = RunRpgContracts.RewardSourceIds.AuthoredContainer,
	Optional = true,
	Interaction = table.freeze({
		MaximumDistanceStuds = 10,
		HoldDurationSeconds = 0.65,
		SurfaceOffsetStuds = 1.25,
	}),
})

local FirstOutdoorDiscoveryConfig = {
	Version = "BA-052-v2-live-lookout-cache",
	RuntimeConsumptionActive = true,
	RuntimeConsumptionScopeId = "ApproachLookoutCacheOnly",
	Discoveries = table.freeze({ Discovery }),
	ById = table.freeze({
		[Discovery.Id] = Discovery,
	}),
}

assert(FirstOutdoorDiscoveryConfig.RuntimeConsumptionActive == true, "BA-052 Lookout Cache runtime must be enabled")
assert(
	FirstOutdoorDiscoveryConfig.RuntimeConsumptionScopeId == "ApproachLookoutCacheOnly",
	"BA-052 runtime scope must remain bounded to the Lookout Cache"
)
assert(FirstOutdoorRouteConfig.RuntimeConsumptionActive == false, "BA-052 cannot activate the BA-050 imported route")
assert(#FirstOutdoorDiscoveryConfig.Discoveries == 1, "the first route currently authors one optional discovery")
assert(Discovery.Optional == true, "the Lookout Cache must remain optional")
assert(
	Discovery.DiscoverySlotId == FirstOutdoorRouteConfig.DiscoverySlotIds.LookoutTower,
	"Lookout Cache must bind to the BA-050 lookout discovery slot"
)
assert(Discovery.RuntimeLandmarkId == "LookoutTower", "Lookout Cache must bind to the source-managed Lookout landmark")
assert(Discovery.Interaction.MaximumDistanceStuds > 0, "Lookout Cache interaction range must be positive")
assert(Discovery.Interaction.HoldDurationSeconds >= 0, "Lookout Cache hold duration cannot be negative")

local anchor = WorldContentConfig.ById[Discovery.AnchorWorldContentId]
assert(anchor ~= nil, "Lookout Cache must reference canonical world content")
assert(anchor.kind == "landmark" and anchor.active == true, "Lookout Cache anchor must remain an active landmark")
assert(
	Discovery.RewardSourceId == RunRpgContracts.RewardSourceIds.AuthoredContainer,
	"optional discovery must use the canonical authored-container reward reference"
)
assert(
	Discovery.StreamingIdentityId ~= Discovery.AnchorWorldContentId,
	"discovery identity must not alias its landmark anchor"
)

return table.freeze(FirstOutdoorDiscoveryConfig)
