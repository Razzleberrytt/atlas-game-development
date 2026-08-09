--!strict

-- Safe server-to-client presentation vocabulary for confirmed melee outcomes.
-- These messages disclose only already-committed combat facts and grant no
-- target, damage, cadence, inventory, or combat-mode authority to the client.
local MeleePresentationContracts = {}

export type MessageKindId = "SwingCommitted" | "HitConfirmed"
export type SwingCommittedMessage = {
	kindId: MessageKindId,
	attackerUserId: number,
	strikeId: string,
	serverTimestamp: number,
}
export type HitConfirmedMessage = {
	kindId: MessageKindId,
	strikeId: string,
	targetEntityId: string,
	damageAmount: number,
	becameDead: boolean,
	serverTimestamp: number,
}

MeleePresentationContracts.MessageKindIds = table.freeze({
	SwingCommitted = "SwingCommitted",
	HitConfirmed = "HitConfirmed",
})

function MeleePresentationContracts.validateSwingCommittedMessage(message: unknown): boolean
	if type(message) ~= "table" then
		return false
	end
	local candidate = message :: any
	return candidate.kindId == MeleePresentationContracts.MessageKindIds.SwingCommitted
		and type(candidate.attackerUserId) == "number"
		and candidate.attackerUserId % 1 == 0
		and candidate.attackerUserId > 0
		and type(candidate.strikeId) == "string"
		and candidate.strikeId ~= ""
		and type(candidate.serverTimestamp) == "number"
		and candidate.serverTimestamp == candidate.serverTimestamp
		and candidate.serverTimestamp >= 0
end

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
