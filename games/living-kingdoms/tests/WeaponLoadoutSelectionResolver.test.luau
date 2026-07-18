--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Systems/WeaponLoadoutSelectionResolver.luau"),
	{
		debugName = "WeaponLoadoutSelectionResolver",
		environment = {
			game = {
				GetService = function()
					return {
						Shared = {
							Config = { FirearmConfig = CONFIG_TOKEN },
							Weapons = { WeaponLoadoutContracts = CONTRACTS_TOKEN },
						},
					}
				end,
			},
			require = function(token: unknown)
				if token == CONFIG_TOKEN then
					return {
						get = function(id: unknown)
							return if id == "weapon.sniper-rifle" then { WeaponId = id } else nil
						end,
					}
				end
				assert(token == CONTRACTS_TOKEN, "unexpected resolver dependency")
				return {
					SelectionStateIds = { Open = "Open", Locked = "Locked" },
					RejectionReasonIds = {
						SelectionClosed = "SelectionClosed",
						InvalidIntent = "InvalidIntent",
						DuplicateRequest = "DuplicateRequest",
						RateLimited = "RateLimited",
						UnknownWeapon = "UnknownWeapon",
					},
					validateIntent = function(value: unknown)
						return type(value) == "table"
							and type((value :: any).requestId) == "string"
							and type((value :: any).weaponId) == "string"
					end,
				}
			end,
			script = { Parent = {} },
		},
		injectGlobals = true,
	}
)()

local assignment = {
	operativeEntityId = "operative.fixture",
	weaponId = "weapon.light-machine-gun",
	selectionStateId = "Open",
	revision = 1,
}
local accepted = resolver.resolve(assignment, { requestId = "r1", weaponId = "weapon.sniper-rifle" }, {
	selectionOpen = true,
	isDuplicateRequest = false,
	isRateLimited = false,
})
assert(accepted.didSelect and accepted.assignmentAfter.weaponId == "weapon.sniper-rifle", "known selection must apply")
assert(accepted.assignmentAfter.revision == 2, "selection must increment revision")

local unknown = resolver.resolve(assignment, { requestId = "r2", weaponId = "weapon.fake" }, {
	selectionOpen = true,
	isDuplicateRequest = false,
	isRateLimited = false,
})
assert(not unknown.didSelect and unknown.rejectionReasonId == "UnknownWeapon", "unknown weapon must reject")

local locked = resolver.resolve({
	operativeEntityId = "operative.fixture",
	weaponId = "weapon.light-machine-gun",
	selectionStateId = "Locked",
	revision = 2,
}, { requestId = "r3", weaponId = "weapon.sniper-rifle" }, {
	selectionOpen = false,
	isDuplicateRequest = false,
	isRateLimited = false,
})
assert(not locked.didSelect and locked.rejectionReasonId == "SelectionClosed", "locked selection must reject")

print("WeaponLoadoutSelectionResolver: known, unknown, and lock behavior passed")
