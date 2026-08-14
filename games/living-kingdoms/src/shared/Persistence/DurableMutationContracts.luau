--!strict

--[[
	Patch 0.7 canonical durable-mutation transaction vocabulary.

	Every valuable mutation -- granting a reward, destroying an item -- is
	replay-protected by a transaction identity recorded in a durable ledger. Two
	things have to be true of such a ledger and neither is free:

	  1. a repeat of the same transaction must be recognisable as a repeat, so a
	     retry after a dropped response is safe;
	  2. a *different* transaction wearing the same id must be recognisable as a
	     conflict, not silently swallowed as a repeat.

	A ledger that records only "this id was used" can do (1) and cannot do (2),
	which makes an id collision look exactly like a successful retry while the
	second mutation is discarded. Recording the content identity alongside the id
	is what separates them.
]]

local DurableMutationContracts = {}

--[[
	Ledgers are durable and only ever grow, so they are bounded. A DataStore key
	has a hard size limit, and a record that exceeds it stops saving entirely --
	losing the inventory, not just the ledger. Failing closed at a bound well
	under that limit turns a silent cliff into a reportable condition.

	Pruning is deliberately not the answer: every entry removed from a replay
	ledger is a mutation that becomes replayable again.
]]
DurableMutationContracts.MaximumLedgerEntries = 4_096

--[[
	These match InventoryDismantleResolver's own identifier rule, which is the
	authority for dismantle transaction ids. A stricter bound here would reject,
	on load, transactions the resolver legitimately accepted at write time --
	stranding records rather than protecting them.
]]
DurableMutationContracts.MinimumTransactionIdLength = 1
DurableMutationContracts.MaximumTransactionIdLength = 128

function DurableMutationContracts.isValidTransactionId(value: any): boolean
	return type(value) == "string"
		and #value >= DurableMutationContracts.MinimumTransactionIdLength
		and #value <= DurableMutationContracts.MaximumTransactionIdLength
end

--[[
	A content identity is what distinguishes "the same mutation again" from "a
	different mutation reusing an id". It must be a stable projection of the
	payload, never of when or where the mutation happened.
]]
function DurableMutationContracts.isValidContentIdentity(value: any): boolean
	return type(value) == "string" and #value >= 3 and #value <= 256
end

function DurableMutationContracts.countEntries(ledger: any): number
	if type(ledger) ~= "table" then
		return 0
	end
	local total = 0
	for _ in ledger do
		total += 1
	end
	return total
end

function DurableMutationContracts.exceedsBound(ledger: any): boolean
	return DurableMutationContracts.countEntries(ledger) > DurableMutationContracts.MaximumLedgerEntries
end

return table.freeze(DurableMutationContracts)
