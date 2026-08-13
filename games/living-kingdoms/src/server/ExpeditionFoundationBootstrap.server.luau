--!strict

--[[
	The inventory session lifecycle used to live here as well as in
	`inventory-network.server.luau`. Both scripts are mounted, so every join ran
	two loads (two DataStore reads and two lease acquisitions) and every renewal
	tick ran two UpdateAsync writes per player, under two different failure
	policies -- this script kicked, the network script only warned.

	`inventory-network.server.luau` is the single owner. Its header has declared
	that ownership since blueprint v2.0, `InventoryLiveLifecycleSourceAudit` pins
	it, and it holds the state the lifecycle needs anyway: loaded-player tracking,
	snapshot pushes, and equipment reconciliation. The kick policy this script
	enforced moved there with the rest.

	Nothing replaced it here, so this file intentionally mounts no behavior. It is
	kept as the record of that decision rather than deleted, so a future reader
	does not re-add a second lifecycle owner.
]]

return nil
