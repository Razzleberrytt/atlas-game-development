--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "world material language source audit failed", 2)
	end
end

local source = fs.readFile("games/living-kingdoms/src/shared/Config/WorldMaterialLanguageConfig.luau")

check(string.find(source, 'Version = "VIS-0105-world-material-v1"', 1, true) ~= nil)
for _, roleName in
	{
		"InfrastructureMetal",
		"InfrastructureSignal",
		"SecurityMetal",
		"SecuritySignal",
		"CampFabric",
		"CampEmber",
		"CrossingWood",
		"CrossingWarning",
		"OverlookMetal",
		"OverlookStone",
	}
do
	check(string.find(source, roleName .. " = role(", 1, true) ~= nil, "missing semantic material role")
end
for _, ruleName in
	{
		"NoGameplayAuthority",
		"NoDestinationEncoding",
		"NoHiddenMissionState",
		"GeometryPlusMaterialRequired",
		"ProductionApprovalRequiredForReplacement",
	}
do
	check(string.find(source, ruleName .. " = true", 1, true) ~= nil, "missing world material rule")
end
check(string.find(source, "table.freeze", 1, true) ~= nil, "material language must be immutable")
check(string.find(source, "rbxassetid://", 1, true) == nil, "material planning must not introduce asset IDs")
check(string.find(source, "RemoteEvent", 1, true) == nil)
check(string.find(source, "FireServer", 1, true) == nil)

print("world material language source audit passed")
