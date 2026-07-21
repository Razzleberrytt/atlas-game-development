--!strict

--[[
	RPG-0108 (part 2) server-side per-operative relic modifier adapter.

	The authoritative combat, reload, and life owners need one operative's bounded
	relic modifiers many times per evaluation. This thin adapter reads the equipped
	relics from the existing RunBuildService owner, derives the bundle through the
	pure RelicModifierResolver, and caches it against the server-owned build
	revision so a stable build costs one table lookup per read. It also forwards
	counted-relic advances to the same owner, which holds the canonical slot
	counter.

	It owns no relic state, creates no connections, and adds no network surface.
	Callers release their entry through forget(); stop paths call clear().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicModifierResolver = require(ReplicatedStorage.Shared.RPG.RelicModifierResolver)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local RunBuildService = require(script.Parent.RunBuildService)

export type RelicModifiers = RelicModifierResolver.RelicModifiers

type CacheEntry = {
	revision: number,
	modifiers: RelicModifiers,
}

local RelicModifierService = {}

local NEUTRAL_MODIFIERS: RelicModifiers = RelicModifierResolver.deriveModifiers({})
local cache: { [Player]: CacheEntry } = {}

--[[
	Returns the operative's current bounded relic modifiers, or the frozen neutral
	bundle when the operation is stopped, the operative is untracked, or no relic
	is equipped.
]]
function RelicModifierService.read(player: Player): RelicModifiers
	local read = RunBuildService.readEquippedRelicIds(player)
	if read == nil then
		cache[player] = nil
		return NEUTRAL_MODIFIERS
	end
	local cached = cache[player]
	if cached ~= nil and cached.revision == read.revision then
		return cached.modifiers
	end
	local modifiers = RelicModifierResolver.deriveModifiers(read.relicIds)
	cache[player] = { revision = read.revision, modifiers = modifiers }
	return modifiers
end

--[[
	Advances Blood Battery's confirmed-kill counter in its equipped slot and
	returns how many times it triggered. Returns zero when the relic is not
	equipped, when the operation is stopped, or when the kill count is not a whole
	positive number; the caller commits the healing through the authoritative life
	boundary.
]]
function RelicModifierService.advanceBloodBatteryKills(player: Player, kills: number, killThreshold: number): number
	if
		type(kills) ~= "number"
		or kills ~= kills
		or kills <= 0
		or kills % 1 ~= 0
		or type(killThreshold) ~= "number"
		or killThreshold <= 0
	then
		return 0
	end
	local advance =
		RunBuildService.advanceRelicCounter(player, RunRpgContracts.RelicIds.BloodBattery, kills, killThreshold)
	return if advance == nil then 0 else advance.triggerCount
end

function RelicModifierService.forget(player: Player)
	cache[player] = nil
end

function RelicModifierService.clear()
	table.clear(cache)
end

return table.freeze(RelicModifierService)
