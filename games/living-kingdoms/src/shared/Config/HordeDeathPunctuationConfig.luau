--!strict

--[[
	Presentation-only punctuation for server-authored horde deaths. The client
	selects one definition from already-replicated role and entity identity facts.
	These values can change only billboard copy/color, the existing blood pool,
	and the existing bounded camera-shake channel. They grant no rewards or power.
]]

export type Definition = {
	Title: string,
	Color: { number },
	BloodDiameterStuds: number,
	BloodColor: { number },
	ShakeMagnitude: number,
	ShakeDurationSeconds: number,
	BillboardLifetimeSeconds: number,
}

local KindIds = table.freeze({
	Screamer = "Screamer",
	ScreamerInterrupted = "ScreamerInterrupted",
	Bloater = "Bloater",
	BrutePhaseOne = "BrutePhaseOne",
	BruteFinal = "BruteFinal",
})

local DefinitionsByKindId: { [string]: Definition } = {
	[KindIds.Screamer] = table.freeze({
		Title = "CHOIR SILENCED",
		Color = table.freeze({ 255, 224, 64 }),
		BloodDiameterStuds = 6,
		BloodColor = table.freeze({ 84, 7, 9 }),
		ShakeMagnitude = 0.18,
		ShakeDurationSeconds = 0.2,
		BillboardLifetimeSeconds = 1.45,
	}),
	[KindIds.ScreamerInterrupted] = table.freeze({
		Title = "SUMMON INTERRUPTED",
		Color = table.freeze({ 255, 244, 120 }),
		BloodDiameterStuds = 6.5,
		BloodColor = table.freeze({ 92, 8, 10 }),
		ShakeMagnitude = 0.26,
		ShakeDurationSeconds = 0.23,
		BillboardLifetimeSeconds = 1.65,
	}),
	[KindIds.Bloater] = table.freeze({
		Title = "ROT BURST ARMED",
		Color = table.freeze({ 121, 225, 78 }),
		BloodDiameterStuds = 8,
		BloodColor = table.freeze({ 45, 92, 32 }),
		ShakeMagnitude = 0.3,
		ShakeDurationSeconds = 0.24,
		BillboardLifetimeSeconds = 1.65,
	}),
	[KindIds.BrutePhaseOne] = table.freeze({
		Title = "BRUTE PHASE BROKEN",
		Color = table.freeze({ 255, 90, 64 }),
		BloodDiameterStuds = 7.5,
		BloodColor = table.freeze({ 86, 4, 7 }),
		ShakeMagnitude = 0.32,
		ShakeDurationSeconds = 0.25,
		BillboardLifetimeSeconds = 1.65,
	}),
	[KindIds.BruteFinal] = table.freeze({
		Title = "BRUTE ERADICATED",
		Color = table.freeze({ 255, 42, 42 }),
		BloodDiameterStuds = 9,
		BloodColor = table.freeze({ 105, 2, 5 }),
		ShakeMagnitude = 0.42,
		ShakeDurationSeconds = 0.3,
		BillboardLifetimeSeconds = 1.85,
	}),
}

local Config = {
	KindIds = KindIds,
	BruteFinalEntityMarker = "brute-phase2",
	GenericBloodDiameterStuds = 5,
	GenericBloodColor = table.freeze({ 76, 4, 7 }),
	GenericShakeMagnitude = 0.1,
	GenericShakeDurationSeconds = 0.18,
	GenericBillboardLifetimeSeconds = 1.2,
	MaximumTitleCharacters = 24,
	MaximumShakeMagnitude = 0.5,
}

function Config.get(kindId: unknown): Definition?
	return if type(kindId) == "string" then DefinitionsByKindId[kindId] else nil
end

for kindId, definition in DefinitionsByKindId do
	assert(
		#definition.Title > 0 and #definition.Title <= Config.MaximumTitleCharacters,
		kindId .. " title is not bounded"
	)
	assert(#definition.Color == 3 and #definition.BloodColor == 3, kindId .. " colors must be RGB tuples")
	assert(
		definition.BloodDiameterStuds >= 5 and definition.BloodDiameterStuds <= 10,
		kindId .. " blood pool is unbounded"
	)
	assert(
		definition.ShakeMagnitude > Config.GenericShakeMagnitude
			and definition.ShakeMagnitude <= Config.MaximumShakeMagnitude,
		kindId .. " shake magnitude is unbounded"
	)
	assert(
		definition.ShakeDurationSeconds >= Config.GenericShakeDurationSeconds
			and definition.ShakeDurationSeconds <= 0.35,
		kindId .. " shake duration is unbounded"
	)
	assert(
		definition.BillboardLifetimeSeconds >= Config.GenericBillboardLifetimeSeconds
			and definition.BillboardLifetimeSeconds <= 2,
		kindId .. " billboard lifetime is unbounded"
	)
end

return table.freeze(Config)
