--!strict

--[[
	VS-0104 shared contracts for deterministic expedition room assembly.
	Room definitions are handcrafted data; the assembler only chooses and orders
	compatible definitions. Spatial placement remains a later runtime concern.
]]

export type RoomRoleId = "Entry" | "Traversal" | "Combat" | "Secret" | "Elite" | "Boss"

export type RoomDefinition = {
	Id: string,
	Version: string,
	Role: RoomRoleId,
	Weight: number,
	MinimumDepth: number,
	MaximumDepth: number,
	AllowRepeats: boolean,
	Tags: { string },
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

return table.freeze({
	RoleIds = RoleIds,
})
