--!strict

local Config = {
	Version = "P6-0101-v1",
	BasicFirearm = table.freeze({
		InitialLoadedRounds = 12,
		InitialReserveRounds = 24,
		MaximumReserveRounds = 48,
		AuthoredCacheRounds = 12,
	}),
}

assert(Config.BasicFirearm.InitialLoadedRounds >= 0, "initial loaded ammunition must be nonnegative")
assert(Config.BasicFirearm.InitialReserveRounds >= 0, "initial reserve ammunition must be nonnegative")
assert(
	Config.BasicFirearm.InitialReserveRounds <= Config.BasicFirearm.MaximumReserveRounds,
	"initial reserve must fit the carry cap"
)
assert(Config.BasicFirearm.AuthoredCacheRounds > 0, "authored caches must grant a positive bounded amount")

return table.freeze(Config)
