--!strict

--[[
	Studio-only environment acceptance harness.

	The live corruption cycle is intentionally disabled until visual/combat
	readability is accepted in Studio. This script lets a tester preview the exact
	production night profile without changing that gameplay gate.

	While Play Solo/Start Server is running in Studio, edit these Workspace
	attributes from the Attributes panel or Command Bar:
	- LK_EnvironmentPreviewEnabled: true/false
	- LK_EnvironmentPreviewIntensity: 0..1

	0.0 previews the first night transition frame; 1.0 previews deep night.
	The derived clock is published as LK_EnvironmentPreviewClockTime.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local EnvironmentProfileService = require(script.Parent.Systems.EnvironmentProfileService)
local NightConfig = require(ReplicatedStorage.Shared.Config.NightCorruptionConfig)

local ENABLED_ATTRIBUTE = "LK_EnvironmentPreviewEnabled"
local INTENSITY_ATTRIBUTE = "LK_EnvironmentPreviewIntensity"
local CLOCK_ATTRIBUTE = "LK_EnvironmentPreviewClockTime"
local STATUS_ATTRIBUTE = "LK_EnvironmentPreviewStatus"

local applying = false

local function clockTimeForIntensity(intensity: number): number
	local clockTime = NightConfig.NightStartClockTime
		+ (NightConfig.DeepNightClockTime + 24 - NightConfig.NightStartClockTime) * intensity
	if clockTime >= 24 then
		clockTime -= 24
	end
	return clockTime
end

local function readIntensity(): number
	local value = Workspace:GetAttribute(INTENSITY_ATTRIBUTE)
	if type(value) ~= "number" then
		return 1
	end
	return math.clamp(value, 0, 1)
end

local function applyPreview()
	if applying then
		return
	end
	applying = true

	local enabled = Workspace:GetAttribute(ENABLED_ATTRIBUTE) == true
	if not enabled then
		EnvironmentProfileService.clearStudioPreview()
		Workspace:SetAttribute(CLOCK_ATTRIBUTE, nil)
		Workspace:SetAttribute(STATUS_ATTRIBUTE, "DAY BASELINE — preview disabled")
		applying = false
		return
	end

	local intensity = readIntensity()
	local clockTime = clockTimeForIntensity(intensity)
	EnvironmentProfileService.setStudioPreview(clockTime, intensity, NightConfig.MinimumFogEnd)
	Workspace:SetAttribute(CLOCK_ATTRIBUTE, clockTime)
	Workspace:SetAttribute(
		STATUS_ATTRIBUTE,
		string.format("NIGHT PREVIEW — intensity %.2f / clock %.2f", intensity, clockTime)
	)
	applying = false
end

if Workspace:GetAttribute(ENABLED_ATTRIBUTE) == nil then
	Workspace:SetAttribute(ENABLED_ATTRIBUTE, false)
end
if Workspace:GetAttribute(INTENSITY_ATTRIBUTE) == nil then
	Workspace:SetAttribute(INTENSITY_ATTRIBUTE, 1)
end

Workspace:GetAttributeChangedSignal(ENABLED_ATTRIBUTE):Connect(applyPreview)
Workspace:GetAttributeChangedSignal(INTENSITY_ATTRIBUTE):Connect(applyPreview)

applyPreview()

print(
	"[Living Kingdoms] Studio environment preview ready — toggle Workspace."
		.. ENABLED_ATTRIBUTE
		.. " and set "
		.. INTENSITY_ATTRIBUTE
		.. " from 0 to 1"
)
