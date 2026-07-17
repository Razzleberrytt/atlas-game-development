--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau")
local hud = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local presenter = fs.readFile("games/living-kingdoms/src/client/Presentation/RemoteWeaponMotionPresenter.luau")

for _, typeName in
	{
		"ReloadStartedPresentationMessage",
		"ReloadCompletedPresentationMessage",
		"ReloadInterruptedPresentationMessage",
	}
do
	local startIndex = string.find(contracts, "export type " .. typeName, 1, true)
	assertThat(startIndex ~= nil, "missing reload presentation type " .. typeName)
	local endIndex = string.find(contracts, "}\n", startIndex :: number, true)
	assertThat(endIndex ~= nil, "reload presentation type is not closed " .. typeName)
	local typeBlock = string.sub(contracts, startIndex :: number, endIndex :: number)
	assertThat(
		string.find(typeBlock, "operativeEntityId: CombatEntityId", 1, true) ~= nil,
		"reload presentation must identify the authoritative operative: " .. typeName
	)
end

assertThat(
	string.find(runtime, "broadcastReloadPresentation", 1, true) ~= nil,
	"reload lifecycle must use one bounded squad presentation helper"
)
local _, broadcastCount = string.gsub(runtime, "presentationRemote:FireAllClients", "")
assertThat(broadcastCount == 2, "only accepted shots and reload lifecycle may broadcast")
assertThat(
	string.find(runtime, "OperativeCombatRuntimeService.publishAmmunitionState(player)", 1, true) ~= nil,
	"ammunition state must remain private"
)

for _, required in
	{
		"RemoteWeaponMotionPresenter.presentShot",
		"RemoteWeaponMotionPresenter.presentReloadStarted",
		"RemoteWeaponMotionPresenter.presentReloadCompleted",
		"RemoteWeaponMotionPresenter.presentReloadInterrupted",
		"RemoteWeaponMotionPresenter.cleanupPlayer",
		"RemoteWeaponMotionPresenter.stop",
	}
do
	assertThat(string.find(controller, required, 1, true) ~= nil, "missing squad motion routing " .. required)
end

local _, localReloadFilterCount = string.gsub(hud, "isLocalOperativeEntityId(payload.operativeEntityId)", "")
assertThat(localReloadFilterCount >= 4, "local HUD must filter shot and all broadcast reload lifecycle messages")

for _, required in
	{
		"Workspace:GetServerTimeNow()",
		"motionState.shotGeneration",
		"motionState.reloadGeneration",
		"motionState.isReloading",
		"tween:Cancel()",
		"states[player] = nil",
	}
do
	assertThat(string.find(presenter, required, 1, true) ~= nil, "remote motion presenter missing " .. required)
end

for _, forbidden in
	{
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"DamageResolver",
		"FirearmHitResolver",
		"loadedRounds",
		"reserveRounds",
		"DamagePerHit",
		"CadenceSeconds",
		"ReloadDurationSeconds",
		"Humanoid:TakeDamage",
	}
do
	assertThat(not string.find(presenter, forbidden, 1, true), "remote motion presenter must not contain " .. forbidden)
end
