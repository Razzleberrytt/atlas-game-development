--!strict

--[[
	Presentation-only role profiles for the six authoritative horde roles.
	Profiles reshape and recolor only the existing massless 18-component Walker
	shell and provide client pose offsets. They do not change the enemy root,
	collision, movement, health, targeting, damage, spawning, or rewards.
]]

local HordeExperienceConfig = require(script.Parent.HordeExperienceConfig)

export type Triple = { number }
export type RolePosture = {
	TorsoHeightStuds: number,
	TorsoPitchDegrees: number,
	TorsoRollDegrees: number,
	LeftArmPitchDegrees: number,
	LeftArmRollDegrees: number,
	RightArmPitchDegrees: number,
	RightArmRollDegrees: number,
	LeftLegPitchDegrees: number,
	RightLegPitchDegrees: number,
}
export type RolePresentationProfile = {
	RoleId: string,
	SignatureId: string,
	Scales: { [string]: Triple },
	Colors: { [string]: Triple },
	SensorBrightness: number,
	SensorRange: number,
	StridesPerSecond: number,
	Posture: RolePosture,
}

local ComponentGroups = table.freeze({
	TorsoCore = "Flesh",
	RibCage = "Armor",
	ChestPlate = "ArmorDark",
	Head = "Bone",
	Sensor = "Sensor",
	DorsalSpine = "Spine",
	ShoulderLeft = "Shoulder",
	ShoulderRight = "Shoulder",
	ForearmLeft = "Forearm",
	ForearmRight = "Forearm",
	ClawLeft = "Claw",
	ClawRight = "Claw",
	HipGuard = "Hip",
	LegLeft = "Leg",
	LegRight = "Leg",
	FootLeft = "Foot",
	FootRight = "Foot",
	BackCanister = "Canister",
})

local GroupIds = table.freeze({
	"Flesh",
	"Armor",
	"ArmorDark",
	"Bone",
	"Sensor",
	"Spine",
	"Shoulder",
	"Forearm",
	"Claw",
	"Hip",
	"Leg",
	"Foot",
	"Canister",
})

local function triple(x: number, y: number, z: number): Triple
	return table.freeze({ x, y, z })
end

local function posture(
	torsoHeightStuds: number,
	torsoPitchDegrees: number,
	torsoRollDegrees: number,
	leftArmPitchDegrees: number,
	leftArmRollDegrees: number,
	rightArmPitchDegrees: number,
	rightArmRollDegrees: number,
	leftLegPitchDegrees: number,
	rightLegPitchDegrees: number
): RolePosture
	return table.freeze({
		TorsoHeightStuds = torsoHeightStuds,
		TorsoPitchDegrees = torsoPitchDegrees,
		TorsoRollDegrees = torsoRollDegrees,
		LeftArmPitchDegrees = leftArmPitchDegrees,
		LeftArmRollDegrees = leftArmRollDegrees,
		RightArmPitchDegrees = rightArmPitchDegrees,
		RightArmRollDegrees = rightArmRollDegrees,
		LeftLegPitchDegrees = leftLegPitchDegrees,
		RightLegPitchDegrees = rightLegPitchDegrees,
	})
end

local function scales(values: { [string]: Triple }): { [string]: Triple }
	local result = {}
	for _, groupId in GroupIds do
		result[groupId] = values[groupId] or triple(1, 1, 1)
	end
	return table.freeze(result)
end

local function colors(values: { [string]: Triple }): { [string]: Triple }
	local result = {
		Flesh = values.Flesh,
		Armor = values.Armor,
		ArmorDark = values.ArmorDark,
		Bone = values.Bone,
		Sensor = values.Sensor,
		Spine = values.Spine or values.Claw,
		Shoulder = values.Shoulder or values.Armor,
		Forearm = values.Forearm or values.Bone,
		Claw = values.Claw,
		Hip = values.Hip or values.ArmorDark,
		Leg = values.Leg or values.Bone,
		Foot = values.Foot or values.Armor,
		Canister = values.Canister,
	}
	return table.freeze(result)
end

local function profile(
	roleId: string,
	signatureId: string,
	scaleValues: { [string]: Triple },
	colorValues: { [string]: Triple },
	sensorBrightness: number,
	sensorRange: number,
	stridesPerSecond: number,
	rolePosture: RolePosture
): RolePresentationProfile
	return table.freeze({
		RoleId = roleId,
		SignatureId = signatureId,
		Scales = scales(scaleValues),
		Colors = colors(colorValues),
		SensorBrightness = sensorBrightness,
		SensorRange = sensorRange,
		StridesPerSecond = stridesPerSecond,
		Posture = rolePosture,
	})
end

local Basic = profile(
	HordeExperienceConfig.Roles.Basic.Id,
	"standard-hollow",
	{},
	{
		Flesh = triple(71, 20, 24),
		Armor = triple(27, 24, 25),
		ArmorDark = triple(13, 11, 12),
		Bone = triple(176, 166, 138),
		Claw = triple(126, 96, 72),
		Sensor = triple(255, 28, 22),
		Canister = triple(62, 76, 40),
	},
	2.6,
	8.5,
	3,
	posture(0, 0, 0, 0, 0, 0, 0, 0, 0)
)

local Runner = profile(
	HordeExperienceConfig.Roles.Runner.Id,
	"razor-sprinter",
	{
		Flesh = triple(0.82, 1.04, 0.82),
		Armor = triple(0.78, 0.88, 0.82),
		ArmorDark = triple(0.82, 0.85, 0.82),
		Bone = triple(0.82, 0.9, 0.82),
		Sensor = triple(0.86, 0.82, 0.86),
		Spine = triple(0.72, 1.24, 0.72),
		Shoulder = triple(0.72, 0.82, 0.72),
		Forearm = triple(0.78, 1.22, 0.78),
		Claw = triple(0.68, 1.34, 0.68),
		Hip = triple(0.78, 0.82, 0.78),
		Leg = triple(0.76, 1.18, 0.76),
		Foot = triple(0.72, 0.9, 1.2),
		Canister = triple(0.62, 0.74, 0.62),
	},
	{
		Flesh = triple(91, 27, 18),
		Armor = triple(39, 24, 18),
		ArmorDark = triple(19, 12, 10),
		Bone = triple(190, 151, 112),
		Claw = triple(178, 92, 44),
		Sensor = triple(255, 118, 28),
		Canister = triple(86, 50, 22),
	},
	3.1,
	9,
	5,
	posture(-0.05, 14, 0, -18, -5, -18, 5, -8, -8)
)

local Crawler = profile(
	HordeExperienceConfig.Roles.Crawler.Id,
	"grave-low-crawl",
	{
		Flesh = triple(1.02, 0.72, 1.08),
		Armor = triple(1, 0.72, 1.08),
		ArmorDark = triple(1, 0.72, 1.08),
		Bone = triple(0.86, 0.84, 0.9),
		Sensor = triple(0.92, 0.82, 0.92),
		Spine = triple(1.12, 1.32, 1.12),
		Shoulder = triple(0.88, 0.82, 0.95),
		Forearm = triple(1.08, 1.18, 1.08),
		Claw = triple(0.82, 1.38, 0.82),
		Hip = triple(0.92, 0.7, 0.95),
		Leg = triple(0.76, 0.58, 0.82),
		Foot = triple(0.8, 0.7, 0.88),
		Canister = triple(0.72, 0.74, 0.72),
	},
	{
		Flesh = triple(62, 22, 70),
		Armor = triple(31, 22, 37),
		ArmorDark = triple(15, 10, 19),
		Bone = triple(155, 136, 165),
		Claw = triple(121, 76, 139),
		Sensor = triple(184, 72, 255),
		Canister = triple(58, 42, 76),
	},
	2.8,
	8,
	4.2,
	posture(-0.82, 58, 0, -44, -8, -44, 8, 28, 28)
)

local Screamer = profile(
	HordeExperienceConfig.Roles.Screamer.Id,
	"choir-beacon",
	{
		Flesh = triple(0.84, 1.16, 0.82),
		Armor = triple(0.76, 0.92, 0.8),
		ArmorDark = triple(0.78, 0.9, 0.8),
		Bone = triple(0.82, 1.28, 0.82),
		Sensor = triple(1.24, 1.42, 1.18),
		Spine = triple(0.82, 1.52, 0.82),
		Shoulder = triple(0.72, 0.78, 0.72),
		Forearm = triple(0.72, 1.08, 0.72),
		Claw = triple(0.64, 0.98, 0.64),
		Hip = triple(0.78, 0.86, 0.78),
		Leg = triple(0.8, 1.08, 0.8),
		Foot = triple(0.78, 0.88, 0.94),
		Canister = triple(1.08, 1.46, 1.08),
	},
	{
		Flesh = triple(83, 68, 16),
		Armor = triple(48, 43, 18),
		ArmorDark = triple(21, 19, 8),
		Bone = triple(205, 193, 115),
		Claw = triple(157, 134, 54),
		Sensor = triple(255, 231, 72),
		Canister = triple(132, 112, 22),
	},
	4.5,
	12,
	2.4,
	posture(0.08, -12, 0, -8, -38, -8, 38, 4, 4)
)

local Bloater = profile(
	HordeExperienceConfig.Roles.Bloater.Id,
	"rot-pressure-sac",
	{
		Flesh = triple(1.34, 1.15, 1.38),
		Armor = triple(1.22, 1.02, 1.3),
		ArmorDark = triple(1.24, 1.02, 1.3),
		Bone = triple(0.94, 0.92, 0.98),
		Sensor = triple(0.92, 0.9, 0.92),
		Spine = triple(1.12, 1.1, 1.18),
		Shoulder = triple(1.16, 1.1, 1.22),
		Forearm = triple(1.06, 1.02, 1.1),
		Claw = triple(0.9, 0.92, 0.9),
		Hip = triple(1.3, 1.08, 1.36),
		Leg = triple(1.06, 0.94, 1.12),
		Foot = triple(1.08, 1, 1.18),
		Canister = triple(1.56, 1.52, 1.56),
	},
	{
		Flesh = triple(45, 83, 31),
		Armor = triple(28, 44, 24),
		ArmorDark = triple(13, 22, 11),
		Bone = triple(161, 178, 119),
		Claw = triple(93, 126, 66),
		Sensor = triple(120, 255, 78),
		Canister = triple(94, 171, 48),
	},
	3.8,
	10.5,
	2,
	posture(-0.08, 8, 0, 4, -18, 4, 18, 3, 3)
)

local Brute = profile(
	HordeExperienceConfig.Roles.Brute.Id,
	"grief-heavy-frame",
	{
		Flesh = triple(1.42, 1.26, 1.38),
		Armor = triple(1.38, 1.22, 1.42),
		ArmorDark = triple(1.38, 1.18, 1.42),
		Bone = triple(1.12, 1.08, 1.14),
		Sensor = triple(1.08, 1.05, 1.08),
		Spine = triple(1.24, 1.3, 1.28),
		Shoulder = triple(1.48, 1.42, 1.5),
		Forearm = triple(1.36, 1.24, 1.38),
		Claw = triple(1.26, 1.24, 1.26),
		Hip = triple(1.3, 1.2, 1.34),
		Leg = triple(1.2, 1.18, 1.22),
		Foot = triple(1.3, 1.18, 1.34),
		Canister = triple(1.14, 1.16, 1.18),
	},
	{
		Flesh = triple(84, 14, 17),
		Armor = triple(35, 15, 17),
		ArmorDark = triple(14, 7, 8),
		Bone = triple(184, 139, 124),
		Claw = triple(173, 54, 47),
		Sensor = triple(255, 42, 42),
		Canister = triple(94, 25, 28),
	},
	4.2,
	11,
	1.8,
	posture(-0.12, 18, 0, 3, -14, 3, 14, -4, -4)
)

local DefinitionsByRoleId = table.freeze({
	[Basic.RoleId] = Basic,
	[Runner.RoleId] = Runner,
	[Crawler.RoleId] = Crawler,
	[Screamer.RoleId] = Screamer,
	[Bloater.RoleId] = Bloater,
	[Brute.RoleId] = Brute,
})

local function get(roleId: unknown): RolePresentationProfile?
	return if type(roleId) == "string" then DefinitionsByRoleId[roleId] else nil
end

local signatureIds = {}
for roleId, definition in DefinitionsByRoleId do
	assert(definition.RoleId == roleId, "role presentation identity must match its key")
	assert(signatureIds[definition.SignatureId] == nil, "every role requires a distinct visual signature")
	signatureIds[definition.SignatureId] = true
	assert(definition.StridesPerSecond >= 1.5 and definition.StridesPerSecond <= 5.5, "role stride must stay bounded")
	assert(definition.SensorBrightness >= 0 and definition.SensorBrightness <= 5, "role eye brightness must stay bounded")
	assert(definition.SensorRange >= 4 and definition.SensorRange <= 14, "role eye range must stay bounded")
	assert(math.abs(definition.Posture.TorsoHeightStuds) <= 1, "role posture cannot detach from its root")
	assert(math.abs(definition.Posture.TorsoPitchDegrees) <= 65, "role torso pitch must stay readable")
	for _, groupId in GroupIds do
		local scale = definition.Scales[groupId]
		local color = definition.Colors[groupId]
		assert(scale ~= nil and #scale == 3, "every role requires every component-group scale")
		assert(color ~= nil and #color == 3, "every role requires every component-group color")
		for _, value in scale do
			assert(value >= 0.55 and value <= 1.6, "presentation scale must remain bounded")
		end
		for _, value in color do
			assert(value >= 0 and value <= 255, "presentation colors must remain valid RGB")
		end
	end
end

local Config = {
	Version = "HROI-0127-v1-six-role-readability",
	ComponentGroups = ComponentGroups,
	GroupIds = GroupIds,
	Basic = Basic,
	Runner = Runner,
	Crawler = Crawler,
	Screamer = Screamer,
	Bloater = Bloater,
	Brute = Brute,
	DefinitionsByRoleId = DefinitionsByRoleId,
	Default = Basic,
	get = get,
}

return table.freeze(Config)
