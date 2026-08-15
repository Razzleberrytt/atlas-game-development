--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/CharacterStatConfig.luau"), {
	debugName = "CharacterStatConfig",
	injectGlobals = true,
})()
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/CharacterStatResolver.luau"), {
	debugName = "CharacterStatResolver",
	injectGlobals = true,
})()

assertThat(resolver.resolveStat(config.StatIds.MaxHealth, {}, config) == 100, "base health must resolve without modifiers")
assertThat(resolver.resolveStat("UnknownStat", {}, config) == nil, "unknown stats must fail closed")

local modifiers = {
	{
		SourceId = "equipment:test",
		SourceCategory = config.SourceCategories.Equipment,
		StatId = config.StatIds.MaxHealth,
		Operation = config.OperationIds.Multiply,
		Value = 1.5,
		Priority = 30,
	},
	{
		SourceId = "progression:test",
		SourceCategory = config.SourceCategories.Progression,
		StatId = config.StatIds.MaxHealth,
		Operation = config.OperationIds.Add,
		Value = 20,
		Priority = 10,
	},
}
assertThat(resolver.resolveStat(config.StatIds.MaxHealth, modifiers, config) == 180, "additive modifiers must apply before multiplicative modifiers")

local reversed = { modifiers[2], modifiers[1] }
assertThat(resolver.resolveStat(config.StatIds.MaxHealth, reversed, config) == 180, "modifier input order must not change resolution")

local clamped = {
	{
		SourceId = "temporary:overspeed",
		SourceCategory = config.SourceCategories.Temporary,
		StatId = config.StatIds.MovementSpeed,
		Operation = config.OperationIds.Add,
		Value = 1000,
	},
}
assertThat(resolver.resolveStat(config.StatIds.MovementSpeed, clamped, config) == 32, "resolved stats must respect configured clamps")

local malformed = {
	{
		SourceId = "temporary:broken",
		SourceCategory = config.SourceCategories.Temporary,
		StatId = config.StatIds.MaxHealth,
		Operation = "Divide",
		Value = 2,
	},
}
assertThat(resolver.resolveStat(config.StatIds.MaxHealth, malformed, config) == nil, "malformed modifiers must fail closed")
local valid, reasonId = resolver.validateModifier(malformed[1], config)
assertThat(valid == false and reasonId == "InvalidOperation", "modifier validation must expose stable failure reasons")

local all = resolver.resolveAll(modifiers, config)
assertThat(all ~= nil and all[config.StatIds.MaxHealth] == 180, "resolveAll must share the canonical stat math")
assertThat(all ~= nil and all[config.StatIds.DamageMultiplier] == 1, "unmodified stats must retain base values")

print("CharacterStatResolver: aggregation order, determinism, clamps, invalid input, and complete resolution passed")
