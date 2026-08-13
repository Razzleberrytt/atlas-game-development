--!strict

local Core = require(script.Parent.PlayerInventoryPersistenceCore)

export type Store = {
	read: (self: any, key: string) -> any,
	saveResult: (self: any, key: string, value: any) -> any,
}
export type Service = any

local MARKER = "__ATLAS_READ_ERROR__"
local Service = {}

local function keyFor(playerId: number): string
	return string.format("player:%d:inventory", playerId)
end

function Service.new(store: Store): Service
	assert(type(store) == "table" and type(store.read) == "function" and type(store.saveResult) == "function", "invalid store")

	local readErrors = {}
	local proxy = {}

	function proxy:load(key: string): any
		local outcome = store:read(key)
		if outcome.Status == "Failed" then
			readErrors[key] = true
			return MARKER
		end
		readErrors[key] = nil
		if outcome.Status == "Found" then
			return outcome.Value
		end
		return nil
	end

	function proxy:save(key: string, value: any): boolean
		return store:saveResult(key, value).Status == "Saved"
	end

	local inner = Core.new(proxy)
	local coreLoadPlayer = inner.loadPlayer
	inner.loadPlayer = function(_self: any, playerId: number, nowUnix: number): any
		local outcome = coreLoadPlayer(inner, playerId, nowUnix)
		if outcome.Accepted ~= true and readErrors[keyFor(playerId)] == true then
			return table.freeze({
				Accepted = false,
				ReasonId = "LoadFailed",
				Record = nil,
				Migrated = false,
			})
		end
		return outcome
	end

	return inner
end

return table.freeze(Service)
