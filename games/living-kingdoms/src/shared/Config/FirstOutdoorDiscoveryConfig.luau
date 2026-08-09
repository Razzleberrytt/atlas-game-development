--!strict

--[[
	BA-052 dormant discovery definition for the first outdoor route.
	Stable content IDs only: no Workspace paths, reward mutation, persistence,
	or presentation/runtime ownership is introduced here.
]]

local FirstOutdoorRouteConfig = require(script.Parent.FirstOutdoorRouteConfig)
local WorldContentConfig = require(script.Parent.WorldContentConfig)
local RunRpgContracts = require(script.Parent.Parent.RPG.RunRpgContracts)

local Discovery = table.freeze({
	Id = "discovery.first-descent.lookout-cache",
	Version = "1.0.0",
	DisplayName = "Lookout Cache",
	RouteId = FirstOutdoorRouteConfig.RouteId,
	DiscoverySlotId = FirstOutdoorRouteConfig.DiscoverySlotIds.LookoutTower,
	AnchorWorldContentId = "landmark.lookout_tower",
	StreamingIdentityId = "streaming.discovery.first-descent.lookout-cache",
	GameplayMeaningId = "OptionalVantageCache",
	PresentationIntentId = "ReadableOptionalDetour",
	RewardSourceId = RunRpgContracts.RewardSourceIds.AuthoredContainer,
	Optional = true,
})

local FirstOutdoorDiscoveryConfig = {
	Version = "BA-052-v1",
	RuntimeConsumptionActive = false,
	Discoveries = table.freeze({ Discovery }),
	ById = table.freeze({
		[Discovery.Id] = Discovery,
	}),
}

assert(FirstOutdoorDiscoveryConfig.RuntimeConsumptionActive == false, "BA-052 discovery data must remain dormant")
assert(FirstOutdoorRouteConfig.RuntimeConsumptionActive == false, "BA-052 cannot activate the BA-050 route")
assert(#FirstOutdoorDiscoveryConfig.Discoveries == 1, "the first route currently authors one optional discovery")
assert(Discovery.Optional == true, "the Lookout Cache must remain optional")
assert(
	Discovery.DiscoverySlotId == FirstOutdoorRouteConfig.DiscoverySlotIds.LookoutTower,
	"Lookout Cache must bind to the BA-050 lookout discovery slot"
)

local anchor = WorldContentConfig.ById[Discovery.AnchorWorldContentId]
assert(anchor ~= nil, "Lookout Cache must reference canonical world content")
assert(anchor.kind == "landmark" and anchor.active == true, "Lookout Cache anchor must remain an active landmark")
assert(
	Discovery.RewardSourceId == RunRpgContracts.RewardSourceIds.AuthoredContainer,
	"optional discovery must use the canonical authored-container reward reference"
)
assert(Discovery.StreamingIdentityId ~= Discovery.AnchorWorldContentId, "discovery identity must not alias its landmark anchor")

return table.freeze(FirstOutdoorDiscoveryConfig)
