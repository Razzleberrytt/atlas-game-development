--!strict

--[[
	BA-052 first outdoor discovery definition.

	The Lookout Cache is now consumed by a narrow server-owned interaction service
	anchored to the source-generated Forest Service Lookout. The BA-050 imported
	route remains held; activating this optional discovery does not activate that
	legacy route geometry, persistence, or a parallel reward/progression owner.
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
	AnchorLandmarkId = "LookoutTower",
	StreamingIdentityId = "streaming.discovery.first-descent.lookout-cache",
	GameplayMeaningId = "OptionalVantageCache",
	PresentationIntentId = "ReadableOptionalDetour",
	RewardSourceId = RunRpgContracts.RewardSourceIds.AuthoredContainer,
	Optional = true,
	Interaction = table.freeze({
		ActionText = "Search",
		HoldDurationSeconds = 0.75,
		MaximumDistanceStuds = 10,
	}),
})

local FirstOutdoorDiscoveryConfig = {
	Version = "BA-052-v2-runtime-live",
	RuntimeConsumptionActive = true,
	RuntimeConsumptionScopeId = "LookoutCacheInteractionOnly",
	Discoveries = table.freeze({ Discovery }),
	ById = table.freeze({
		[Discovery.Id] = Discovery,
	}),
}

assert(FirstOutdoorDiscoveryConfig.RuntimeConsumptionActive == true, "BA-052 Lookout Cache interaction must remain live")
assert(
	FirstOutdoorDiscoveryConfig.RuntimeConsumptionScopeId == "LookoutCacheInteractionOnly",
	"BA-052 runtime scope must not imply BA-050 route activation"
)
assert(FirstOutdoorRouteConfig.RuntimeConsumptionActive == false, "BA-052 cannot activate the BA-050 imported route")
assert(#FirstOutdoorDiscoveryConfig.Discoveries == 1, "the first route currently authors one optional discovery")
assert(Discovery.Optional == true, "the Lookout Cache must remain optional")
assert(
	Discovery.DiscoverySlotId == FirstOutdoorRouteConfig.DiscoverySlotIds.LookoutTower,
	"Lookout Cache must bind to the BA-050 lookout discovery slot"
)
assert(Discovery.Interaction.MaximumDistanceStuds > 0, "Lookout Cache interaction distance must be positive")
assert(Discovery.Interaction.HoldDurationSeconds >= 0, "Lookout Cache hold duration cannot be negative")

local anchor = WorldContentConfig.ById[Discovery.AnchorWorldContentId]
assert(anchor ~= nil, "Lookout Cache must reference canonical world content")
assert(anchor.kind == "landmark" and anchor.active == true, "Lookout Cache anchor must remain an active landmark")
assert(
	Discovery.RewardSourceId == RunRpgContracts.RewardSourceIds.AuthoredContainer,
	"optional discovery must use the canonical authored-container reward source"
)
assert(
	Discovery.StreamingIdentityId ~= Discovery.AnchorWorldContentId,
	"discovery identity must not alias its landmark anchor"
)

return table.freeze(FirstOutdoorDiscoveryConfig)
