--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/AmmunitionScarcityContracts.luau"), {
	debugName = "AmmunitionScarcityContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Domain/AmmunitionSupplyResolver.luau"), {
	debugName = "AmmunitionSupplyResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "unexpected service request")
				return { Shared = { Combat = { AmmunitionScarcityContracts = CONTRACTS_TOKEN } } }
			end,
		},
		require = function(token: unknown)
			assertThat(token == CONTRACTS_TOKEN, "unexpected resolver dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local function state(reserveRounds: number, processed: { [string]: boolean }?)
	return {
		weaponId = "weapon.basic_firearm",
		loadedRounds = 12,
		reserveRounds = reserveRounds,
		magazineCapacity = 12,
		maximumReserveRounds = 48,
		processedSupplyIds = processed or {},
	}
end

local function supply(id: string, rounds: number, sourceId: string?)
	return {
		supplyId = id,
		sourceId = sourceId or contracts.SupplySourceIds.AuthoredCache,
		weaponId = "weapon.basic_firearm",
		availableRounds = rounds,
	}
end

local initial = state(24)
local accepted = resolver.collect(initial, supply("cache.lookout", 12))
assertThat(accepted.didCollect, "valid cache must collect")
assertThat(accepted.grantedRounds == 12, "cache must grant its bounded rounds")
assertThat(accepted.stateAfter.reserveRounds == 36, "reserve must increase")
assertThat(accepted.stateAfter.processedSupplyIds["cache.lookout"] == true, "supply identity must be processed")
assertThat(initial.reserveRounds == 24, "input state must remain immutable")
assertThat(initial.processedSupplyIds["cache.lookout"] == nil, "input processed set must remain immutable")

local loot = resolver.collect(state(24), supply("enemy-loot:7:99", 8, contracts.SupplySourceIds.EnemyLoot))
assertThat(loot.didCollect and loot.grantedRounds == 8, "server-owned enemy loot must use the same bounded supply path")
assertThat(loot.stateAfter.reserveRounds == 32, "enemy loot must increase reserve ammunition only")

local clamped = resolver.collect(state(44), supply("cache.roadblock", 12))
assertThat(clamped.didCollect and clamped.grantedRounds == 4, "collection must clamp to reserve capacity")
assertThat(clamped.stateAfter.reserveRounds == 48, "reserve must not overflow")

local full = resolver.collect(state(48), supply("cache.full", 12))
assertThat(not full.didCollect, "full reserve must reject")
assertThat(
	full.rejectionReasonId == contracts.CollectionRejectionReasonIds.NoCapacity,
	"full reserve reason must be stable"
)

local duplicate = resolver.collect(state(24, { ["cache.used"] = true }), supply("cache.used", 12))
assertThat(not duplicate.didCollect, "duplicate cache must reject")
assertThat(
	duplicate.rejectionReasonId == contracts.CollectionRejectionReasonIds.DuplicateCollection,
	"duplicate reason must be stable"
)

local wrongWeapon = supply("cache.wrong", 12)
wrongWeapon.weaponId = "weapon.other"
local invalidSupply = resolver.collect(state(24), wrongWeapon)
assertThat(not invalidSupply.didCollect, "wrong-weapon supply must reject")
assertThat(
	invalidSupply.rejectionReasonId == contracts.CollectionRejectionReasonIds.InvalidSupply,
	"invalid supply reason"
)

local invalidSource = resolver.collect(state(24), supply("loot.fake", 8, "ClientClaim"))
assertThat(not invalidSource.didCollect, "unknown ammunition sources must fail closed")
assertThat(invalidSource.rejectionReasonId == contracts.CollectionRejectionReasonIds.InvalidSupply, "source rejection")

local malformed = resolver.collect({} :: any, supply("cache.bad-state", 12))
assertThat(not malformed.didCollect, "malformed state must reject without throwing")
assertThat(malformed.rejectionReasonId == contracts.CollectionRejectionReasonIds.InvalidState, "invalid state reason")
assertThat(malformed.stateAfter.reserveRounds == 0, "malformed rejection must return a safe empty snapshot")
