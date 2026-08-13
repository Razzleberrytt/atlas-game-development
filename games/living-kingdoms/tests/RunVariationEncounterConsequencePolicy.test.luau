--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "run variation encounter consequence policy assertion failed", 2)
	end
end

local CONTRACTS_TOKEN = {}
local contracts = {
	EncounterSlotIds = {
		None = "None",
		LightPatrol = "LightPatrol",
		StandardSquad = "StandardSquad",
		EliteGuard = "EliteGuard",
		BossEncounter = "BossEncounter",
	},
}

local policy = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationEncounterConsequencePolicy.luau"),
	{
		debugName = "RunVariationEncounterConsequencePolicy",
		environment = {
			script = {
				Parent = {
					RoomAssemblyContracts = CONTRACTS_TOKEN,
				},
			},
			require = function(token: unknown): any
				if token == CONTRACTS_TOKEN then
					return contracts
				end
				error("unexpected consequence policy dependency")
			end,
		},
		injectGlobals = true,
	}
)()

local function record(
	encounterSlotId: string,
	baseIntensity: number,
	effectiveIntensity: number,
	modifierApplied: boolean
): any
	return {
		NodeIndex = 3,
		RoomId = "warden-barracks",
		EncounterSlotId = encounterSlotId,
		BaseIntensity = baseIntensity,
		EffectiveIntensity = effectiveIntensity,
		ModifierApplied = modifierApplied,
	}
end

local unchanged = policy.resolve(record("StandardSquad", 2, 2, false))
assert(unchanged.UnitCountDelta == 0, "unchanged pressure must not change authored unit budget")
assert(unchanged.MinimumRetainedUnits == 1, "encounter policy must keep at least one authored unit")
assert(unchanged.AllowNewArchetypes == false, "policy must not authorize new archetypes")
assert(unchanged.AllowRewardChanges == false, "policy must not authorize reward changes")
assert(table.isfrozen(unchanged), "resolved consequence must be immutable")

local denser = policy.resolve(record("StandardSquad", 2, 3, true))
assert(denser.UnitCountDelta == 1, "one higher pressure tier must add one authored-unit budget slot")
assert(denser.ApplicationKind == "AuthoredUnitCountDelta", "consequence application kind must stay explicit")

local quieter = policy.resolve(record("StandardSquad", 2, 1, true))
assert(quieter.UnitCountDelta == -1, "one lower pressure tier must remove one authored-unit budget slot")

local elitePressure = policy.resolve(record("EliteGuard", 1, 2, true))
assert(elitePressure.UnitCountDelta == 1, "elite pressure may add one authored-unit budget slot")

local patrol = policy.resolve(record("LightPatrol", 1, 1, false))
assert(patrol.UnitCountDelta == 0, "clamped light patrol pressure must remain unchanged")

local noEncounter = policy.resolve(record("None", 0, 0, false))
assert(noEncounter.UnitCountDelta == 0, "non-encounter rooms must never gain a unit budget")
assert(noEncounter.MinimumRetainedUnits == 0, "non-encounter rooms retain no authored units")

local boss = policy.resolve(record("BossEncounter", 3, 3, false))
assert(boss.UnitCountDelta == 0, "boss encounter pressure must remain untouched")

local function mustReject(candidate: any, message: string)
	local ok = pcall(function()
		policy.resolve(candidate)
	end)
	assert(not ok, message)
end

mustReject(record("BossEncounter", 3, 2, true), "boss intensity changes must fail closed")
mustReject(record("None", 0, 1, true), "non-encounter intensity changes must fail closed")
mustReject(record("StandardSquad", 1, 3, true), "multi-tier pressure jumps must fail closed")
mustReject(record("StandardSquad", 0, 1, true), "adjustable encounter base intensity must stay in range")
mustReject(record("StandardSquad", 2, 4, true), "adjustable encounter effective intensity must stay in range")
mustReject(record("StandardSquad", 2, 3, false), "modifier flag must match an applied pressure change")
mustReject(record("UnknownSlot", 1, 1, false), "unknown encounter slots must fail closed")

print("Run variation encounter consequence policy fixture passed")
