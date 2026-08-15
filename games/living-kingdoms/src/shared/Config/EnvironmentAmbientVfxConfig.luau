--!strict

-- Runtime-agnostic micro-atmosphere zones. Keep this pure data so Lune can
-- validate the presentation budget without Roblox globals.
local function rgb(r: number, g: number, b: number)
	return table.freeze({ r = r, g = g, b = b })
end

local function zone(
	id: string,
	kind: string,
	x: number,
	y: number,
	z: number,
	color: any,
	rate: number,
	lifetimeMin: number,
	lifetimeMax: number,
	speedMin: number,
	speedMax: number,
	sizeStart: number,
	sizeEnd: number,
	accelerationY: number,
	lightEmission: number,
	lightInfluence: number
)
	return table.freeze({
		id = id,
		kind = kind,
		x = x,
		y = y,
		z = z,
		color = color,
		rate = rate,
		lifetimeMin = lifetimeMin,
		lifetimeMax = lifetimeMax,
		speedMin = speedMin,
		speedMax = speedMax,
		sizeStart = sizeStart,
		sizeEnd = sizeEnd,
		accelerationY = accelerationY,
		lightEmission = lightEmission,
		lightInfluence = lightInfluence,
	})
end

local EnvironmentAmbientVfxConfig = {
	Version = "biome-vfx-v1",
	Texture = "rbxasset://textures/particles/smoke_main.dds",
	Zones = table.freeze({
		-- Creek vapor keeps the central crossing cool and damp without adding more fog globally.
		zone("creek.vapor.crossing", "CreekVapor", 26, 3.0, 14, rgb(184, 211, 211), 0.55, 5.5, 8.0, 0.12, 0.38, 1.8, 4.8, 0.09, 0.01, 0.86),
		zone("creek.vapor.north", "CreekVapor", 24, 3.0, 126, rgb(173, 202, 204), 0.45, 6.0, 8.0, 0.10, 0.32, 1.6, 4.4, 0.08, 0.01, 0.88),

		-- Logging-road dust gives the industrial route visible motion while staying sparse.
		zone("road.dust.loader", "RoadDust", 52, 2.2, -108, rgb(153, 128, 89), 0.65, 3.0, 4.5, 0.35, 0.75, 0.45, 1.5, 0.16, 0.0, 0.94),
		zone("road.dust.roadblock", "RoadDust", 150, 2.2, -158, rgb(145, 119, 83), 0.55, 3.0, 4.5, 0.30, 0.70, 0.4, 1.35, 0.14, 0.0, 0.95),

		-- Forest motes make the quieter western woods feel alive without bright firefly lights.
		zone("forest.motes.lookout", "ForestMotes", -158, 6.0, 122, rgb(210, 204, 146), 0.42, 5.0, 7.5, 0.15, 0.42, 0.22, 0.7, 0.05, 0.03, 0.80),
		zone("forest.motes.camp", "ForestMotes", -118, 4.0, 76, rgb(205, 198, 137), 0.48, 5.0, 7.5, 0.15, 0.45, 0.22, 0.72, 0.06, 0.03, 0.80),

		-- Corruption ash defines the eastern contaminated edge with color/motion, not light.
		zone("corruption.ash.extraction", "CorruptionAsh", 282, 4.0, 96, rgb(115, 96, 124), 0.72, 5.0, 7.5, 0.18, 0.48, 0.28, 0.9, 0.18, 0.02, 0.90),
		zone("corruption.ash.ridge", "CorruptionAsh", 296, 5.0, 154, rgb(105, 91, 116), 0.62, 5.0, 7.5, 0.16, 0.44, 0.26, 0.84, 0.20, 0.02, 0.90),
	}),
}

return table.freeze(EnvironmentAmbientVfxConfig)
