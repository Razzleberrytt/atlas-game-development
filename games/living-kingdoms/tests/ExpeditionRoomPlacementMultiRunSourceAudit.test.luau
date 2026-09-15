--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomPlacementService.luau")

local function contains(token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

assert(contains('local CONTAINER_NAME = "ExpeditionInstances"'))
assert(contains("local registry = ExpeditionInstanceRegistry.new()"))
assert(contains("local rootsByRunId"))
assert(contains("function Service.placeForRun(runId: string, roomPlan: any): any"))
assert(contains("registry:create(runId, layout.Seed, planIdentity, reproductionKey)"))
assert(contains('root:SetAttribute("RunId", runId)'))
assert(contains('root:SetAttribute("InstanceSlot", instance.SlotIndex)'))
assert(contains('root:SetAttribute("ReproductionKey", reproductionKey)'))
assert(contains("shiftPlacement(placement, instance.OriginX, instance.OriginZ)"))
assert(contains("function Service.destroyRun(runId: string): any"))
assert(contains("function Service.getRootForRun(runId: string): Folder?"))
assert(contains("function Service.getActiveInstances(): { any }"))
assert(contains("function Service.destroyAll()"))
assert(contains("ModularDungeonRoomPresentation.apply(model, placement)"))
assert(not contains("local activeRoot: Folder?"), "placement service must not retain singleton root authority")

print("ExpeditionRoomPlacementMultiRunSourceAudit: run-scoped roots and ownership are preserved")
