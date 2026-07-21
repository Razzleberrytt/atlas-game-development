--!strict

--[[
	RPG-0108 (part 2) server-side per-operative relic modifier adapter.

	The authoritative combat, reload, and life owners need one operative's bounded
	relic modifiers many times per evaluation. This thin adapter reads the equipped
	relics from the existing RunBuildService owner, derives the bundle through the
	pure RelicModifierResolver, and caches it against the server-owned build
	revision so a stable build costs one table lookup per read.

	It owns no relic state, creates no connections, and adds no network surface.
	Callers release their entry through forget(); stop paths call clear().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicModifierResolver = require(ReplicatedStorage.Shared.RPG.RelicModifierResolver)
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

function RelicModifierService.forget(player: Player)
	cache[player] = nil
end

function RelicModifierService.clear()
	table.clear(cache)
end

return table.freeze(RelicModifierService)
