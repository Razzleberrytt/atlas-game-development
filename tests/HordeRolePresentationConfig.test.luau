--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local HORDE_TOKEN = {}
local hordeConfig = {
	Roles = {
		Basic = { Id = "horde.role.infected" },
		Runner = { Id = "horde.role.runner" },
		Crawler = { Id = "horde.role.crawler" },
		Screamer = { Id = "horde.role.screamer" },
		Bloater = { Id = "horde.role.bloater" },
		Brute = { Id = "horde.role.brute" },
	},
}

local source = fs.readFile("games/living-kingdoms/src/shared/Config/HordeRolePresentationConfig.luau")
local config = luau.load(source, {
	debugName = "HordeRolePresentationConfig",
	environment = {
		script = { Parent = { HordeExperienceConfig = HORDE_TOKEN } },
		require = function(token: unknown)
			assert(token == HORDE_TOKEN, "unexpected role-presentation dependency")
			return hordeConfig
		end,
	},
	injectGlobals = true,
})()

local expectedRoleIds = {
	"horde.role.infected",
	"horde.role.runner",
	"horde.role.crawler",
	"horde.role.screamer",
	"horde.role.bloater",
	"horde.role.brute",
}

local signatures = {}
for _, roleId in expectedRoleIds do
	local profile = config.get(roleId)
	assert(profile ~= nil, "missing role presentation profile: " .. roleId)
	assert(signatures[profile.SignatureId] == nil, "role signatures must be distinct")
	signatures[profile.SignatureId] = true
	assert(profile.StridesPerSecond >= 1.5 and profile.StridesPerSecond <= 5.5, "stride bound")
	assert(math.abs(profile.Posture.TorsoHeightStuds) <= 1, "posture height bound")
	for _, groupId in config.GroupIds do
		local scale = profile.Scales[groupId]
		assert(scale ~= nil and #scale == 3, "missing scale group " .. groupId)
		for _, value in scale do
			assert(value >= 0.55 and value <= 1.6, "scale bound")
		end
	end
end

assert(config.get("unknown") == nil, "unknown roles must not resolve")
assert(config.Crawler.Posture.TorsoPitchDegrees >= 50, "crawler must own a low forward posture")
assert(config.Runner.StridesPerSecond > config.Basic.StridesPerSecond, "runner stride must read faster")
assert(config.Brute.Scales.Shoulder[1] > config.Basic.Scales.Shoulder[1], "brute must read broad")
assert(config.Bloater.Scales.Canister[1] > config.Basic.Scales.Canister[1], "bloater sac must read enlarged")
assert(config.Screamer.SensorBrightness > config.Basic.SensorBrightness, "screamer beacon must read brighter")

print("HordeRolePresentationConfig: six distinct bounded role profiles passed")
