--!strict

local MissionContracts = require(script.Parent.Parent.Mission.MissionContracts)
local FirearmConfig = require(script.Parent.FirearmConfig)

local Config = {
	Version = "HROI-0120-v2-pistol-only-insertion",
	OpenMissionPhaseId = MissionContracts.MissionPhaseIds.Insertion,
	DefaultWeaponId = FirearmConfig.DefaultSelectableWeaponId,
	SelectableWeaponIds = FirearmConfig.SelectableWeaponIds,
	MinimumRequestIntervalSeconds = 0.15,
	MaximumProcessedRequestIdsPerOperative = 64,
}

assert(#Config.SelectableWeaponIds == 1, "insertion exposes only the survival pistol")
assert(FirearmConfig.get(Config.DefaultWeaponId) ~= nil, "default loadout weapon must exist")
assert(
	Config.MinimumRequestIntervalSeconds > 0 and Config.MinimumRequestIntervalSeconds <= 1,
	"loadout requests must be bounded"
)
assert(
	Config.MaximumProcessedRequestIdsPerOperative > 0 and Config.MaximumProcessedRequestIdsPerOperative <= 256,
	"request history must be bounded"
)

return table.freeze(Config)
