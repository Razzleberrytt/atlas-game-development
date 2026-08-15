--!strict

--[[
	Wave 2 reusable encounter presets. These are composition requests only: the
	encounter service / EnemyDirectorService retain spawn legality and combat
	authority, while Agent 5 remains free to choose when/where a dungeon requests
	one of these definitions.
]]

local EnemyContracts = require(script.Parent.Parent.Combat.EnemyContracts)
local RunRpgContracts = require(script.Parent.Parent.RPG.RunRpgContracts)

local Ids = EnemyContracts.EnemyArchetypeIds
local AffixIds = RunRpgContracts.EliteAffixIds

local EnemyEncounterConfig = {
	Version = "Wave2-Encounters-v1",
	Presets = table.freeze({
		RusherPack = table.freeze({
			Id = "encounter.rusher_pack",
			Budget = 5,
			MinimumCount = 5,
			MaximumCount = 5,
			ArchetypeIds = table.freeze({ Ids.ExclusionWalker }),
			RequiredCounts = table.freeze({
				[Ids.ExclusionWalker] = 5,
			}),
			EliteChance = 0,
			DifficultyMultiplier = 1,
		}),
		RangedCrossfire = table.freeze({
			Id = "encounter.ranged_crossfire",
			Budget = 11,
			MinimumCount = 5,
			MaximumCount = 5,
			ArchetypeIds = table.freeze({ Ids.BlightSpitter, Ids.ExclusionWalker }),
			RequiredCounts = table.freeze({
				[Ids.BlightSpitter] = 3,
				[Ids.ExclusionWalker] = 2,
			}),
			EliteChance = 0,
			DifficultyMultiplier = 1,
		}),
		HeavySupport = table.freeze({
			Id = "encounter.heavy_support",
			Budget = 7,
			MinimumCount = 4,
			MaximumCount = 5,
			ArchetypeIds = table.freeze({ Ids.GriefBrute, Ids.RazorRunner, Ids.ExclusionWalker }),
			RequiredCounts = table.freeze({
				[Ids.GriefBrute] = 1,
				[Ids.RazorRunner] = 2,
			}),
			SpawnWeights = table.freeze({
				[Ids.GriefBrute] = 0.5,
				[Ids.RazorRunner] = 2,
				[Ids.ExclusionWalker] = 4,
			}),
			EliteChance = 0.08,
			DifficultyMultiplier = 1,
		}),
		EliteVanguard = table.freeze({
			Id = "encounter.elite_vanguard",
			Budget = 5,
			MinimumCount = 3,
			MaximumCount = 3,
			ArchetypeIds = table.freeze({ Ids.GriefBrute, Ids.ExclusionWalker }),
			RequiredCounts = table.freeze({
				[Ids.GriefBrute] = 1,
				[Ids.ExclusionWalker] = 2,
			}),
			EliteChance = 1,
			RequestedEliteAffixId = AffixIds.Frenzied,
			DifficultyMultiplier = 1,
		}),
	}),
}

return table.freeze(EnemyEncounterConfig)
