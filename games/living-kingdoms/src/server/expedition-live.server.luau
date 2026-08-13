--!strict

-- Server-only mount for the first expedition vertical slice.
-- No client remote is created. Trusted server scripts and Studio command-bar
-- workflows may invoke ServerStorage.ExpeditionControl with an action string.

local ServerStorage = game:GetService("ServerStorage")

local ExpeditionLiveRuntimeService = require(script.Parent.Systems.ExpeditionLiveRuntimeService)

local existing = ServerStorage:FindFirstChild("ExpeditionControl")
if existing ~= nil then
	existing:Destroy()
end

local control = Instance.new("BindableFunction")
control.Name = "ExpeditionControl"
control.Parent = ServerStorage

ExpeditionLiveRuntimeService.start()

control.OnInvoke = function(action: string, payload: any?): any
	if action == "Start" then
		return ExpeditionLiveRuntimeService.startExpedition(payload)
	elseif action == "Stop" then
		local reasonId = if type(payload) == "string" then payload else nil
		return ExpeditionLiveRuntimeService.stopExpedition(reasonId)
	elseif action == "ReadSnapshot" then
		return ExpeditionLiveRuntimeService.readSnapshot()
	elseif action == "ReadRoomPlan" then
		return ExpeditionLiveRuntimeService.readRoomPlan()
	elseif action == "ReadRunVariationPlan" then
		return ExpeditionLiveRuntimeService.readRunVariationPlan()
	elseif action == "ReadRunVariationEncounterView" then
		return ExpeditionLiveRuntimeService.readRunVariationEncounterView()
	elseif action == "ReadRunVariationComposition" then
		return ExpeditionLiveRuntimeService.readRunVariationComposition()
	end
	return table.freeze({ Accepted = false, ReasonId = "UnknownAction", Snapshot = nil })
end

game:BindToClose(function()
	ExpeditionLiveRuntimeService.stop()
	if control.Parent ~= nil then
		control:Destroy()
	end
end)

print("[Living Kingdoms] Expedition live runtime mounted")
