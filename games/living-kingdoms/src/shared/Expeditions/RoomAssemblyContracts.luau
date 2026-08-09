--!strict

--[[
	VS-0104 shared contracts for deterministic expedition room assembly.
	Room definitions are handcrafted data; the assembler only chooses and orders
	compatible definitions. Spatial placement remains a later runtime concern.
]]

export type RoomRoleId = "Entry" | "Traversal" | "Combat" | "Secret" | "Elite" | "Boss"

-- BA-030 content slot: which authored encounter composition a spawner should
-- resolve once it enters this room. This names a *category* only; concrete
-- enemy archetype selection remains a future runtime spawner's decision, not
-- this contract's.
export type EncounterSlotId = "None" | "LightPatrol" | "StandardSquad" | "EliteGuard" | "BossEncounter"

-- BA-030 reward reference. Values are the same two strings as
-- EquipmentRewardContracts.RewardSourceId ("Elite" | "Boss") by design, kept
-- as a local literal union instead of a cross-module require so this file
-- stays a standalone, dependency-free contract.
export type RoomRewardSourceId = "Elite" | "Boss"

export type RoomDefinition = {
	Id: string,
	Version: string,
	Role: RoomRoleId,
	Weight: number,
	MinimumDepth: number,
	MaximumDepth: number,
	AllowRepeats: boolean,
	Tags: { string },
	EncounterSlotId: EncounterSlotId,
	-- 0 for non-encounter rooms; otherwise a small positive integer a future
	-- spawner may use to scale wave size, matching the existing 1/2/3 pattern
	-- already hardcoded in ExpeditionServerBootstrap.resolveEncounter.
	EncounterIntensity: number,
	-- nil for every room except the authored Elite/Boss slots.
	RewardSourceId: RoomRewardSourceId?,
}

export type RoomPlanNode = {
	Index: number,
	Depth: number,
	RoomId: string,
	RoomVersion: string,
	Role: RoomRoleId,
	PreviousIndex: number?,
	NextIndex: number?,
}

export type RoomPlan = {
	Seed: number,
	DefinitionId: string,
	DefinitionVersion: string,
	Nodes: { RoomPlanNode },
	EntryIndex: number,
	EliteIndex: number,
	BossIndex: number,
}

local RoleIds = table.freeze({
	Entry = "Entry" :: RoomRoleId,
	Traversal = "Traversal" :: RoomRoleId,
	Combat = "Combat" :: RoomRoleId,
	Secret = "Secret" :: RoomRoleId,
	Elite = "Elite" :: RoomRoleId,
	Boss = "Boss" :: RoomRoleId,
})

local EncounterSlotIds = table.freeze({
	None = "None" :: EncounterSlotId,
	LightPatrol = "LightPatrol" :: EncounterSlotId,
	StandardSquad = "StandardSquad" :: EncounterSlotId,
	EliteGuard = "EliteGuard" :: EncounterSlotId,
	BossEncounter = "BossEncounter" :: EncounterSlotId,
})

local RoomRewardSourceIds = table.freeze({
	Elite = "Elite" :: RoomRewardSourceId,
	Boss = "Boss" :: RoomRewardSourceId,
})

return table.freeze({
	RoleIds = RoleIds,
	EncounterSlotIds = EncounterSlotIds,
	RoomRewardSourceIds = RoomRewardSourceIds,
})
