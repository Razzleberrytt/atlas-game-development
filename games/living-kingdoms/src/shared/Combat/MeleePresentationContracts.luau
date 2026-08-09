--!strict

-- Safe server-to-client presentation vocabulary for confirmed melee outcomes.
-- These messages disclose only already-committed combat facts and grant no
-- target, damage, cadence, inventory, or combat-mode authority to the client.
local MeleePresentationContracts = {}

export type MessageKindId = "HitConfirmed"
export type HitConfirmedMessage = {
	kindId: MessageKindId,
	strikeId: string,
	targetEntityId: string,
	damageAmount: number,
	becameDead: boolean,
	serverTimestamp: number,
}

MeleePresentationContracts.MessageKindIds = table.freeze({
	HitConfirmed = "HitConfirmed",
})

function MeleePresentationContracts.validateHitConfirmedMessage(message: unknown): boolean
	if type(message) ~= "table" then
		return false
	end
	local candidate = message :: any
	return candidate.kindId == MeleePresentationContracts.MessageKindIds.HitConfirmed
		and type(candidate.strikeId) == "string"
		and candidate.strikeId ~= ""
		and type(candidate.targetEntityId) == "string"
		and candidate.targetEntityId ~= ""
		and type(candidate.damageAmount) == "number"
		and candidate.damageAmount == candidate.damageAmount
		and candidate.damageAmount > 0
		and type(candidate.becameDead) == "boolean"
		and type(candidate.serverTimestamp) == "number"
		and candidate.serverTimestamp == candidate.serverTimestamp
		and candidate.serverTimestamp >= 0
end

return table.freeze(MeleePresentationContracts)
