local fs = require("@lune/fs")
local luau = require("@lune/luau")

local profilePath = "games/living-kingdoms/src/server/Systems/EnvironmentProfileService.luau"
local previewPath = "games/living-kingdoms/src/server/EnvironmentVisualPreview.server.luau"
local nightConfigPath = "games/living-kingdoms/src/shared/Config/NightCorruptionConfig.luau"

local profileSource = fs.readFile(profilePath)
local previewSource = fs.readFile(previewPath)
local nightConfigSource = fs.readFile(nightConfigPath)

for _, path in { profilePath, previewPath } do
	local loaded = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})
	assert(type(loaded) == "function", "Studio environment preview source must compile: " .. path)
end

assert(string.find(previewSource, "RunService:IsStudio()", 1, true), "preview must fail closed outside Studio")
assert(
	string.find(profileSource, "RunService:IsStudio()", 1, true),
	"profile preview API must independently fail closed outside Studio"
)
assert(string.find(profileSource, "studioPreviewActive", 1, true), "preview ownership guard is missing")
assert(string.find(profileSource, "setStudioPreview", 1, true), "Studio preview apply API is missing")
assert(string.find(profileSource, "clearStudioPreview", 1, true), "Studio preview clear API is missing")
assert(
	string.find(profileSource, "if studioPreviewActive then", 1, true),
	"live environment writes must yield while Studio preview owns the profile"
)

assert(
	string.find(previewSource, "LK_EnvironmentPreviewEnabled", 1, true),
	"preview enable attribute is missing"
)
assert(
	string.find(previewSource, "LK_EnvironmentPreviewIntensity", 1, true),
	"preview intensity attribute is missing"
)
assert(
	string.find(previewSource, "LK_EnvironmentPreviewClockTime", 1, true),
	"derived preview clock readback is missing"
)
assert(string.find(previewSource, "math.clamp", 1, true), "preview intensity must be bounded")
assert(
	string.find(previewSource, "NightConfig.MinimumFogEnd", 1, true),
	"preview must exercise the real night fog boundary"
)
assert(
	string.find(previewSource, "NightConfig.NightStartClockTime", 1, true)
		and string.find(previewSource, "NightConfig.DeepNightClockTime", 1, true),
	"preview must exercise the real night clock endpoints"
)

assert(not string.find(previewSource, "RemoteEvent", 1, true), "Studio preview must not add a client authority surface")
assert(not string.find(previewSource, "RemoteFunction", 1, true), "Studio preview must not add a client authority surface")
assert(not string.find(previewSource, "DataStore", 1, true), "Studio preview must not persist acceptance state")
assert(
	string.find(nightConfigSource, "RuntimeEnabled = false", 1, true),
	"Studio preview must not bypass the runtime night-cycle acceptance gate"
)
assert(
	string.find(nightConfigSource, "daytime biome visual and combat-readability Studio acceptance", 1, true),
	"Studio acceptance gate ownership changed unexpectedly"
)

print("EnvironmentStudioPreviewSourceAudit: Studio-only override preserves the production runtime gate")
