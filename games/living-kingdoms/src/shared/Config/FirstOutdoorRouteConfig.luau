--!strict

--[[
	BA-050 authored outdoor-route data for the first playable expedition approach.

	This module intentionally describes sequence and stable references only. It does
	not reconstruct the held 189-Part legacy WorldPath, spawn encounters, grant
	discovery rewards, move players, or launch the dungeon. BA-051 and BA-052 may
	bind authored gameplay definitions to the route-local slots later; runtime
	consumption remains disabled until the appropriate integration gate.
]]

local WorldContentConfig = require(script.Parent.WorldContentConfig)
local RecoveredWorldPathConfig = require(script.Parent.RecoveredWorldPathConfig)
local FirstDungeonContentConfig = require(script.Parent.FirstDungeonContentConfig)

local StepKinds = table.freeze({
	Entrance = "Entrance",
	Landmark = "Landmark",
	EncounterSlot = "EncounterSlot",
	DiscoverySlot = "DiscoverySlot",
	DungeonHandoff = "DungeonHandoff",
})

local EncounterSlotIds = table.freeze({
	LoggingRoad = "encounter-slot.outdoor.first-descent.logging-road",
	Campground = "encounter-slot.outdoor.first-descent.campground",
	MilitaryRoadblock = "encounter-slot.outdoor.first-descent.military-roadblock",
})

local DiscoverySlotIds = table.freeze({
	LookoutTower = "discovery-slot.outdoor.first-descent.lookout-tower",
})

type RouteStep = {
	Id: string,
	Order: number,
	Kind: string,
	WorldContentId: string?,
	EncounterSlotId: string?,
	DiscoverySlotId: string?,
	Optional: boolean,
	DungeonSequenceId: string?,
	DungeonEntryRoomId: string?,
}

local function step(
	id: string,
	order: number,
	kind: string,
	worldContentId: string?,
	encounterSlotId: string?,
	discoverySlotId: string?,
	optional: boolean,
	dungeonSequenceId: string?,
	dungeonEntryRoomId: string?
): RouteStep
	return table.freeze({
		Id = id,
		Order = order,
		Kind = kind,
		WorldContentId = worldContentId,
		EncounterSlotId = encounterSlotId,
		DiscoverySlotId = discoverySlotId,
		Optional = optional,
		DungeonSequenceId = dungeonSequenceId,
		DungeonEntryRoomId = dungeonEntryRoomId,
	})
end

local FirstOutdoorRouteConfig = {
	Version = "BA-050-v1",
	RouteId = "outdoor-route.first-descent",
	RouteVersion = "1.0.0",
	DisplayName = "Ranger Trail to the First Descent",
	WorldPathContentId = RecoveredWorldPathConfig.SourceContentId,
	RuntimeConsumptionActive = false,
	StepKinds = StepKinds,
	EncounterSlotIds = EncounterSlotIds,
	DiscoverySlotIds = DiscoverySlotIds,
	Steps = table.freeze({
		step("ranger-station-entrance", 1, StepKinds.Entrance, "landmark.ranger_station", nil, nil, false, nil, nil),
		step("logging-road", 2, StepKinds.Landmark, "landmark.logging_road", nil, nil, false, nil, nil),
		step(
			"logging-road-encounter-slot",
			3,
			StepKinds.EncounterSlot,
			"landmark.logging_road",
			EncounterSlotIds.LoggingRoad,
			nil,
			false,
			nil,
			nil
		),
		step("lookout-tower", 4, StepKinds.Landmark, "landmark.lookout_tower", nil, nil, false, nil, nil),
		step(
			"lookout-discovery-slot",
			5,
			StepKinds.DiscoverySlot,
			"landmark.lookout_tower",
			nil,
			DiscoverySlotIds.LookoutTower,
			true,
			nil,
			nil
		),
		step("campground", 6, StepKinds.Landmark, "landmark.campground", nil, nil, false, nil, nil),
		step(
			"campground-encounter-slot",
			7,
			StepKinds.EncounterSlot,
			"landmark.campground",
			EncounterSlotIds.Campground,
			nil,
			false,
			nil,
			nil
		),
		step("creek-crossing", 8, StepKinds.Landmark, "landmark.creek_crossing", nil, nil, false, nil, nil),
		step("rocky-overlook", 9, StepKinds.Landmark, "landmark.rocky_overlook", nil, nil, false, nil, nil),
		step(
			"military-roadblock",
			10,
			StepKinds.Landmark,
			"landmark.military_roadblock",
			nil,
			nil,
			false,
			nil,
			nil
		),
		step(
			"military-roadblock-encounter-slot",
			11,
			StepKinds.EncounterSlot,
			"landmark.military_roadblock",
			EncounterSlotIds.MilitaryRoadblock,
			nil,
			false,
			nil,
			nil
		),
		step(
			"extraction-clearing",
			12,
			StepKinds.Landmark,
			"landmark.extraction_clearing",
			nil,
			nil,
			false,
			nil,
			nil
		),
		step(
			"first-descent-handoff",
			13,
			StepKinds.DungeonHandoff,
			nil,
			nil,
			nil,
			false,
			FirstDungeonContentConfig.SequenceId,
			FirstDungeonContentConfig.RoomSequence[1]
		),
	}),
}

assert(FirstOutdoorRouteConfig.RuntimeConsumptionActive == false, "BA-050 route data must remain dormant")
assert(
	RecoveredWorldPathConfig.SourceHold == true and RecoveredWorldPathConfig.RuntimeEnabled == false,
	"BA-050 must not activate the recovered legacy WorldPath geometry"
)
assert(
	FirstOutdoorRouteConfig.WorldPathContentId == RecoveredWorldPathConfig.SourceContentId,
	"outdoor route must preserve the recovered canonical route identity"
)

local routeDescriptor = WorldContentConfig.ById[FirstOutdoorRouteConfig.WorldPathContentId]
assert(routeDescriptor ~= nil and routeDescriptor.kind == "route", "outdoor route must reference canonical route content")
assert(routeDescriptor.active == false, "held route identity must not be promoted by BA-050")

local validStepKinds = {
	[StepKinds.Entrance] = true,
	[StepKinds.Landmark] = true,
	[StepKinds.EncounterSlot] = true,
	[StepKinds.DiscoverySlot] = true,
	[StepKinds.DungeonHandoff] = true,
}

local seenStepIds: { [string]: boolean } = {}
local seenEncounterSlotIds: { [string]: boolean } = {}
local seenDiscoverySlotIds: { [string]: boolean } = {}
local encounterSlotCount = 0
local discoverySlotCount = 0
local handoffCount = 0

for index, routeStep in FirstOutdoorRouteConfig.Steps do
	assert(routeStep.Order == index, "outdoor route step orders must remain contiguous")
	assert(seenStepIds[routeStep.Id] == nil, "duplicate outdoor route step id: " .. routeStep.Id)
	seenStepIds[routeStep.Id] = true
	assert(validStepKinds[routeStep.Kind] == true, "unknown outdoor route step kind")
	assert(routeStep.WorldContentId ~= "portal.expedition.primary", "launch portal cannot be used as dungeon handoff")

	if routeStep.WorldContentId ~= nil then
		local descriptor = WorldContentConfig.ById[routeStep.WorldContentId]
		assert(descriptor ~= nil, "outdoor route references unknown world content: " .. routeStep.WorldContentId)
		assert(descriptor.kind == "landmark", "outdoor traversal anchors must use canonical landmarks")
		assert(descriptor.active == true, "outdoor traversal cannot depend on an inactive landmark")
	end

	if routeStep.Kind == StepKinds.EncounterSlot then
		assert(routeStep.EncounterSlotId ~= nil, "encounter route step requires a route-local slot id")
		assert(routeStep.DiscoverySlotId == nil, "encounter route step cannot also be a discovery slot")
		assert(routeStep.Optional == false, "first-route encounter slots remain required sequence beats")
		assert(seenEncounterSlotIds[routeStep.EncounterSlotId] == nil, "duplicate outdoor encounter slot")
		seenEncounterSlotIds[routeStep.EncounterSlotId] = true
		encounterSlotCount += 1
	elseif routeStep.Kind == StepKinds.DiscoverySlot then
		assert(routeStep.DiscoverySlotId ~= nil, "discovery route step requires a route-local slot id")
		assert(routeStep.EncounterSlotId == nil, "discovery route step cannot also be an encounter slot")
		assert(routeStep.Optional == true, "the first outdoor discovery branch must remain optional")
		assert(seenDiscoverySlotIds[routeStep.DiscoverySlotId] == nil, "duplicate outdoor discovery slot")
		seenDiscoverySlotIds[routeStep.DiscoverySlotId] = true
		discoverySlotCount += 1
	elseif routeStep.Kind == StepKinds.DungeonHandoff then
		assert(routeStep.WorldContentId == nil, "dungeon handoff must not pretend a world portal owns the transition")
		assert(routeStep.DungeonSequenceId == FirstDungeonContentConfig.SequenceId, "handoff must target First Descent")
		assert(
			routeStep.DungeonEntryRoomId == FirstDungeonContentConfig.RoomSequence[1],
			"handoff must target the canonical First Descent entry room"
		)
		handoffCount += 1
	else
		assert(routeStep.EncounterSlotId == nil, "non-encounter route step cannot claim an encounter slot")
		assert(routeStep.DiscoverySlotId == nil, "non-discovery route step cannot claim a discovery slot")
	end
end

assert(FirstOutdoorRouteConfig.Steps[1].Kind == StepKinds.Entrance, "outdoor route must begin at an entrance")
assert(
	FirstOutdoorRouteConfig.Steps[1].WorldContentId == "landmark.ranger_station",
	"first outdoor route must begin at the Ranger Station"
)
assert(encounterSlotCount == 3, "first outdoor route must expose three BA-051 encounter slots")
assert(discoverySlotCount == 1, "first outdoor route must expose one BA-052 discovery slot")
assert(handoffCount == 1, "first outdoor route must contain exactly one dungeon handoff")
assert(
	FirstOutdoorRouteConfig.Steps[#FirstOutdoorRouteConfig.Steps].Kind == StepKinds.DungeonHandoff,
	"outdoor route must terminate at the dungeon handoff"
)

return table.freeze(FirstOutdoorRouteConfig)
