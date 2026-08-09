--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-024 vendor contract assertion failed", 2)
	end
end

local sourcePath = "games/living-kingdoms/src/shared/Vendor/VendorContracts.luau"
local source = fs.readFile(sourcePath)
local Contracts = luau.load(source, {
	debugName = "VendorContracts",
	injectGlobals = true,
})()

local vendor = table.freeze({
	VendorId = "vendor.fixture.field-merchant",
	Version = "1",
	CatalogRefIds = table.freeze({ "catalog.fixture.field-supplies" }),
	RuntimeEnabled = false,
})

local catalog = table.freeze({
	CatalogId = "catalog.fixture.field-supplies",
	Version = "1",
	Entries = table.freeze({
		table.freeze({
			EntryId = "entry.fixture.field-kit",
			ItemRefId = "item.fixture.field-kit",
			Price = table.freeze({
				CurrencyRefId = "currency.fixture.tokens",
				UnitAmount = 25,
			}),
			MaxQuantityPerRequest = 3,
			Available = true,
		}),
		table.freeze({
			EntryId = "entry.fixture.unavailable",
			ItemRefId = "item.fixture.unavailable",
			Price = table.freeze({
				CurrencyRefId = "currency.fixture.tokens",
				UnitAmount = 10,
			}),
			MaxQuantityPerRequest = nil,
			Available = false,
		}),
	}),
	RuntimeEnabled = false,
})

assert(Contracts.RuntimeConsumptionActive == false)
assert(Contracts.MutationIntentAllowed == false)
assert(Contracts.validateVendorDefinition(vendor) == true)
assert(Contracts.validateCatalogDefinition(catalog) == true)
assert(Contracts.validateVendorSet({ vendor }) == true)
assert(Contracts.validateCatalogSet({ catalog }) == true)

local disabledVendor = Contracts.evaluateQuote(vendor, catalog, "entry.fixture.field-kit", 1, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 100 },
})
assert(disabledVendor.Eligible == false)
assert(disabledVendor.ReasonId == Contracts.DenialReasonIds.VendorDisabled)

local enabledVendor = table.clone(vendor)
enabledVendor.RuntimeEnabled = true

local unrelatedCatalog = table.clone(catalog)
unrelatedCatalog.CatalogId = "catalog.fixture.other"
unrelatedCatalog.RuntimeEnabled = true
local unavailableCatalog = Contracts.evaluateQuote(enabledVendor, unrelatedCatalog, "entry.fixture.field-kit", 1, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 100 },
})
assert(unavailableCatalog.Eligible == false)
assert(unavailableCatalog.ReasonId == Contracts.DenialReasonIds.CatalogUnavailable)

local disabledCatalog = Contracts.evaluateQuote(enabledVendor, catalog, "entry.fixture.field-kit", 1, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 100 },
})
assert(disabledCatalog.Eligible == false)
assert(disabledCatalog.ReasonId == Contracts.DenialReasonIds.CatalogDisabled)

local enabledCatalog = table.clone(catalog)
enabledCatalog.RuntimeEnabled = true

local missingEntry = Contracts.evaluateQuote(enabledVendor, enabledCatalog, "entry.fixture.missing", 1, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 100 },
})
assert(missingEntry.Eligible == false)
assert(missingEntry.ReasonId == Contracts.DenialReasonIds.EntryUnavailable)

local unavailableEntry = Contracts.evaluateQuote(enabledVendor, enabledCatalog, "entry.fixture.unavailable", 1, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 100 },
})
assert(unavailableEntry.Eligible == false)
assert(unavailableEntry.ReasonId == Contracts.DenialReasonIds.EntryUnavailable)

local invalidQuantity = Contracts.evaluateQuote(enabledVendor, enabledCatalog, "entry.fixture.field-kit", 0, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 100 },
})
assert(invalidQuantity.Eligible == false)
assert(invalidQuantity.ReasonId == Contracts.DenialReasonIds.QuantityInvalid)

local tooMany = Contracts.evaluateQuote(enabledVendor, enabledCatalog, "entry.fixture.field-kit", 4, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 100 },
})
assert(tooMany.Eligible == false)
assert(tooMany.ReasonId == Contracts.DenialReasonIds.QuantityLimitExceeded)

local insufficient = Contracts.evaluateQuote(enabledVendor, enabledCatalog, "entry.fixture.field-kit", 2, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 49 },
})
assert(insufficient.Eligible == false)
assert(insufficient.ReasonId == Contracts.DenialReasonIds.InsufficientCurrency)
assert(insufficient.CurrencyRefId == "currency.fixture.tokens")
assert(insufficient.UnitAmount == 25)
assert(insufficient.Quantity == 2)
assert(insufficient.TotalAmount == 50)
assert(insufficient.AvailableBalance == 49)

local malformedBalance = Contracts.evaluateQuote(enabledVendor, enabledCatalog, "entry.fixture.field-kit", 1, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = -10 },
})
assert(malformedBalance.Eligible == false)
assert(malformedBalance.AvailableBalance == 0)

local eligible = Contracts.evaluateQuote(enabledVendor, enabledCatalog, "entry.fixture.field-kit", 3, {
	CurrencyBalancesByRefId = { ["currency.fixture.tokens"] = 75 },
})
assert(eligible.Eligible == true)
assert(eligible.ReasonId == nil)
assert(eligible.ItemRefId == "item.fixture.field-kit")
assert(eligible.TotalAmount == 75)
assert(eligible.AvailableBalance == 75)

local duplicateCatalogRef = table.clone(vendor)
duplicateCatalogRef.CatalogRefIds = {
	"catalog.fixture.field-supplies",
	"catalog.fixture.field-supplies",
}
assert(Contracts.validateVendorDefinition(duplicateCatalogRef) == false)

local duplicateVendorId = table.clone(vendor)
assert(Contracts.validateVendorSet({ vendor, duplicateVendorId }) == false)

local duplicateEntry = table.clone(catalog)
duplicateEntry.Entries = {
	catalog.Entries[1],
	catalog.Entries[1],
}
assert(Contracts.validateCatalogDefinition(duplicateEntry) == false)

local duplicateCatalogId = table.clone(catalog)
assert(Contracts.validateCatalogSet({ catalog, duplicateCatalogId }) == false)

local negativePrice = table.clone(catalog)
local negativeEntry = table.clone(catalog.Entries[1])
negativeEntry.Price = {
	CurrencyRefId = "currency.fixture.tokens",
	UnitAmount = -1,
}
negativePrice.Entries = { negativeEntry }
assert(Contracts.validateCatalogDefinition(negativePrice) == false)

local invalidLimit = table.clone(catalog)
local invalidLimitEntry = table.clone(catalog.Entries[1])
invalidLimitEntry.MaxQuantityPerRequest = 0
invalidLimit.Entries = { invalidLimitEntry }
assert(Contracts.validateCatalogDefinition(invalidLimit) == false)

local unknownVendorField = table.clone(vendor)
unknownVendorField.ClientMayPurchase = true
assert(Contracts.validateVendorDefinition(unknownVendorField) == false)

local unknownCatalogField = table.clone(catalog)
unknownCatalogField.LiveStock = 100
assert(Contracts.validateCatalogDefinition(unknownCatalogField) == false)

-- BA-024 must stay pure quote/eligibility architecture with no transaction path.
assert(string.find(source, "Instance.new", 1, true) == nil)
assert(string.find(source, "GetService", 1, true) == nil)
assert(string.find(source, "FireServer", 1, true) == nil)
assert(string.find(source, "InvokeServer", 1, true) == nil)
assert(string.find(source, "DataStore", 1, true) == nil)
assert(string.find(source, "RemoteEvent", 1, true) == nil)
assert(string.find(source, "RemoteFunction", 1, true) == nil)

print("BA-024 VendorContracts fixture passed")
