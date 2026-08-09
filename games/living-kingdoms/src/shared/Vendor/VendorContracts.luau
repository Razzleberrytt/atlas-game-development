--!strict

--[[
	BA-024 canonical vendor/catalog/pricing contracts and deterministic quote resolver.

	This module is pure, dormant architecture. Vendor, catalog, item, and currency
	references remain opaque IDs until BA-025 cross-domain validation. It does not
	debit currency, grant items, persist state, bind networking, or activate vendor UI.
]]

local Contracts = {}

Contracts.RuntimeConsumptionActive = false
Contracts.MutationIntentAllowed = false

Contracts.DenialReasonIds = table.freeze({
	VendorDisabled = "VendorDisabled",
	CatalogUnavailable = "CatalogUnavailable",
	CatalogDisabled = "CatalogDisabled",
	EntryUnavailable = "EntryUnavailable",
	QuantityInvalid = "QuantityInvalid",
	QuantityLimitExceeded = "QuantityLimitExceeded",
	InsufficientCurrency = "InsufficientCurrency",
})

export type VendorPriceDefinition = {
	CurrencyRefId: string,
	UnitAmount: number,
}

export type VendorCatalogEntryDefinition = {
	EntryId: string,
	ItemRefId: string,
	Price: VendorPriceDefinition,
	MaxQuantityPerRequest: number?,
	Available: boolean,
}

export type VendorCatalogDefinition = {
	CatalogId: string,
	Version: string,
	Entries: { VendorCatalogEntryDefinition },
	RuntimeEnabled: boolean,
}

export type VendorDefinition = {
	VendorId: string,
	Version: string,
	CatalogRefIds: { string },
	RuntimeEnabled: boolean,
}

export type VendorQuoteContext = {
	CurrencyBalancesByRefId: { [string]: number },
}

export type VendorQuoteResult = {
	Eligible: boolean,
	ReasonId: string?,
	VendorId: string,
	CatalogId: string,
	EntryId: string?,
	ItemRefId: string?,
	CurrencyRefId: string?,
	Quantity: number?,
	UnitAmount: number?,
	TotalAmount: number?,
	AvailableBalance: number?,
}

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 1 and (value :: number) % 1 == 0
end

local function isNonNegativeInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0 and (value :: number) % 1 == 0
end

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

local function hasOnlyKeys(value: { [any]: any }, permittedKeys: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or permittedKeys[key] ~= true then
			return false
		end
	end
	return true
end

local function isDenseArray(value: { [any]: any }): boolean
	local count = 0
	for key in value do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		count += 1
	end
	return #value == count
end

local function validateUniqueStringList(value: unknown, maximumLength: number): boolean
	if type(value) ~= "table" or not isDenseArray(value :: { [any]: any }) or #value < 1 then
		return false
	end
	local seen = {}
	for _, entry in value :: { any } do
		if not isNonEmptyBoundedString(entry, maximumLength) or seen[entry] then
			return false
		end
		seen[entry] = true
	end
	return true
end

local function validatePrice(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local price = value :: { [any]: any }
	return hasOnlyKeys(price, {
		CurrencyRefId = true,
		UnitAmount = true,
	}) and isNonEmptyBoundedString(price.CurrencyRefId, 128) and isNonNegativeInteger(price.UnitAmount)
end

local function validateCatalogEntry(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local entry = value :: { [any]: any }
	if
		not hasOnlyKeys(entry, {
			EntryId = true,
			ItemRefId = true,
			Price = true,
			MaxQuantityPerRequest = true,
			Available = true,
		})
	then
		return false
	end
	if not isNonEmptyBoundedString(entry.EntryId, 96) or not isNonEmptyBoundedString(entry.ItemRefId, 128) then
		return false
	end
	if not validatePrice(entry.Price) then
		return false
	end
	if entry.MaxQuantityPerRequest ~= nil and not isPositiveInteger(entry.MaxQuantityPerRequest) then
		return false
	end
	return type(entry.Available) == "boolean"
end

function Contracts.validateCatalogDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [any]: any }
	if
		not hasOnlyKeys(definition, {
			CatalogId = true,
			Version = true,
			Entries = true,
			RuntimeEnabled = true,
		})
	then
		return false
	end
	if not isNonEmptyBoundedString(definition.CatalogId, 96) or not isNonEmptyBoundedString(definition.Version, 24) then
		return false
	end
	if type(definition.Entries) ~= "table" or not isDenseArray(definition.Entries) or #definition.Entries < 1 then
		return false
	end
	local seenEntryIds = {}
	for _, entry in definition.Entries do
		if not validateCatalogEntry(entry) or seenEntryIds[entry.EntryId] then
			return false
		end
		seenEntryIds[entry.EntryId] = true
	end
	return type(definition.RuntimeEnabled) == "boolean"
end

function Contracts.validateVendorDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [any]: any }
	if
		not hasOnlyKeys(definition, {
			VendorId = true,
			Version = true,
			CatalogRefIds = true,
			RuntimeEnabled = true,
		})
	then
		return false
	end
	if not isNonEmptyBoundedString(definition.VendorId, 96) or not isNonEmptyBoundedString(definition.Version, 24) then
		return false
	end
	if not validateUniqueStringList(definition.CatalogRefIds, 96) then
		return false
	end
	return type(definition.RuntimeEnabled) == "boolean"
end

function Contracts.validateVendorSet(definitions: unknown): boolean
	if type(definitions) ~= "table" or not isDenseArray(definitions :: { [any]: any }) then
		return false
	end
	local seenVendorIds = {}
	for _, definition in definitions :: { any } do
		if not Contracts.validateVendorDefinition(definition) or seenVendorIds[definition.VendorId] then
			return false
		end
		seenVendorIds[definition.VendorId] = true
	end
	return true
end

function Contracts.validateCatalogSet(definitions: unknown): boolean
	if type(definitions) ~= "table" or not isDenseArray(definitions :: { [any]: any }) then
		return false
	end
	local seenCatalogIds = {}
	for _, definition in definitions :: { any } do
		if not Contracts.validateCatalogDefinition(definition) or seenCatalogIds[definition.CatalogId] then
			return false
		end
		seenCatalogIds[definition.CatalogId] = true
	end
	return true
end

local function vendorReferencesCatalog(vendor: VendorDefinition, catalogId: string): boolean
	for _, catalogRefId in vendor.CatalogRefIds do
		if catalogRefId == catalogId then
			return true
		end
	end
	return false
end

local function findCatalogEntry(catalog: VendorCatalogDefinition, entryId: string): VendorCatalogEntryDefinition?
	for _, entry in catalog.Entries do
		if entry.EntryId == entryId then
			return entry
		end
	end
	return nil
end

local function normalizedBalance(value: unknown): number
	if isNonNegativeInteger(value) then
		return value :: number
	end
	return 0
end

local function denied(vendorId: string, catalogId: string, reasonId: string): VendorQuoteResult
	return table.freeze({
		Eligible = false,
		ReasonId = reasonId,
		VendorId = vendorId,
		CatalogId = catalogId,
		EntryId = nil,
		ItemRefId = nil,
		CurrencyRefId = nil,
		Quantity = nil,
		UnitAmount = nil,
		TotalAmount = nil,
		AvailableBalance = nil,
	})
end

function Contracts.evaluateQuote(
	vendor: VendorDefinition,
	catalog: VendorCatalogDefinition,
	entryId: string,
	quantity: number,
	context: VendorQuoteContext
): VendorQuoteResult
	if not vendor.RuntimeEnabled then
		return denied(vendor.VendorId, catalog.CatalogId, Contracts.DenialReasonIds.VendorDisabled)
	end
	if not vendorReferencesCatalog(vendor, catalog.CatalogId) then
		return denied(vendor.VendorId, catalog.CatalogId, Contracts.DenialReasonIds.CatalogUnavailable)
	end
	if not catalog.RuntimeEnabled then
		return denied(vendor.VendorId, catalog.CatalogId, Contracts.DenialReasonIds.CatalogDisabled)
	end
	local entry = findCatalogEntry(catalog, entryId)
	if entry == nil or not entry.Available then
		return denied(vendor.VendorId, catalog.CatalogId, Contracts.DenialReasonIds.EntryUnavailable)
	end
	if not isPositiveInteger(quantity) then
		return denied(vendor.VendorId, catalog.CatalogId, Contracts.DenialReasonIds.QuantityInvalid)
	end
	if entry.MaxQuantityPerRequest ~= nil and quantity > entry.MaxQuantityPerRequest then
		return denied(vendor.VendorId, catalog.CatalogId, Contracts.DenialReasonIds.QuantityLimitExceeded)
	end

	local totalAmount = entry.Price.UnitAmount * quantity
	local availableBalance = normalizedBalance(context.CurrencyBalancesByRefId[entry.Price.CurrencyRefId])
	if availableBalance < totalAmount then
		return table.freeze({
			Eligible = false,
			ReasonId = Contracts.DenialReasonIds.InsufficientCurrency,
			VendorId = vendor.VendorId,
			CatalogId = catalog.CatalogId,
			EntryId = entry.EntryId,
			ItemRefId = entry.ItemRefId,
			CurrencyRefId = entry.Price.CurrencyRefId,
			Quantity = quantity,
			UnitAmount = entry.Price.UnitAmount,
			TotalAmount = totalAmount,
			AvailableBalance = availableBalance,
		})
	end

	return table.freeze({
		Eligible = true,
		ReasonId = nil,
		VendorId = vendor.VendorId,
		CatalogId = catalog.CatalogId,
		EntryId = entry.EntryId,
		ItemRefId = entry.ItemRefId,
		CurrencyRefId = entry.Price.CurrencyRefId,
		Quantity = quantity,
		UnitAmount = entry.Price.UnitAmount,
		TotalAmount = totalAmount,
		AvailableBalance = availableBalance,
	})
end

assert(Contracts.RuntimeConsumptionActive == false, "BA-024 must remain dormant")
assert(Contracts.MutationIntentAllowed == false, "BA-024 cannot authorize purchase mutation")

return table.freeze(Contracts)
