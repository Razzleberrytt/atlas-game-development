--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local persistence = fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau")
local inventoryLive = fs.readFile("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")
local inventoryNetwork = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")
local combatAdapter = fs.readFile("games/living-kingdoms/src/server/Systems/EquipmentCombatAdapter.luau")
local weaponResolver = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedWeaponResolver.luau")
local rewardConfig = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau")
local combatRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local dismantleResolver = fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryDismantleResolver.luau")

assertThat(
	string.find(persistence, "function Service:unequip", 1, true) ~= nil,
	"durable inventory owner must expose authoritative unequip"
)
assertThat(string.find(persistence, "SlotAlreadyUnequipped", 1, true) ~= nil, "unequip retries must be idempotent")
assertThat(
	string.find(persistence, "guardedWrite(selfAny._store, keyFor(playerId), nextRecord)", 1, true) ~= nil,
	"unequip must remain behind the guarded durable write"
)
assertThat(
	string.find(persistence, "selfAny._records[playerId] = nextRecord", 1, true) ~= nil,
	"resident inventory may advance only through the persistence owner"
)
local unequipStart = string.find(persistence, "function Service:unequip", 1, true)
local dismantleStart = string.find(persistence, "function Service:dismantle", 1, true)
assertThat(
	unequipStart ~= nil and dismantleStart ~= nil and unequipStart < dismantleStart,
	"unequip owner block missing"
)
local unequipSource = string.sub(persistence, unequipStart :: number, (dismantleStart :: number) - 1)
local guardedWritePosition =
	string.find(unequipSource, "guardedWrite(selfAny._store, keyFor(playerId), nextRecord)", 1, true)
local residentAdvancePosition = string.find(unequipSource, "selfAny._records[playerId] = nextRecord", 1, true)
assertThat(
	guardedWritePosition ~= nil and residentAdvancePosition ~= nil and guardedWritePosition < residentAdvancePosition,
	"unequip must commit durably before advancing resident inventory"
)
assertThat(
	string.find(unequipSource, "nextRecord.EquippedBySlot[slotId] = nil", 1, true) ~= nil,
	"unequip must clear only the requested durable slot"
)

assertThat(
	string.find(inventoryLive, "function Service.unequipOwnedSlot", 1, true) ~= nil,
	"live inventory service must expose owner-only slot unequip"
)
assertThat(
	string.find(inventoryLive, "requesterId ~= ownerId", 1, true) ~= nil,
	"inventory mutations must reject cross-player access"
)
assertThat(
	string.find(inventoryLive, "SessionLeaseRequired", 1, true) ~= nil,
	"valuable equipment mutations must require the live session lease"
)
assertThat(
	string.find(inventoryLive, "return persistence:unequip(ownerId, slotId, nowUnix)", 1, true) ~= nil,
	"live service must delegate unequip to the durable owner"
)
assertThat(
	string.find(inventoryLive, "persistenceState._records", 1, true) == nil
		and string.find(inventoryLive, "local persistenceState = persistence :: any", 1, true) == nil,
	"live inventory service must never mutate persistence's private resident cache"
)

assertThat(
	string.find(inventoryNetwork, 'unequipOwnedSlot.Name = "UnequipOwnedSlot"', 1, true) ~= nil,
	"bounded slot-intent unequip remote missing"
)
assertThat(
	string.find(
		inventoryNetwork,
		"InventoryLiveService.equipOwnedItem(player.UserId, player.UserId, instanceId",
		1,
		true
	) ~= nil,
	"equip owner identity must come from invoking player"
)
assertThat(
	string.find(inventoryNetwork, "InventoryLiveService.unequipOwnedSlot(player.UserId, player.UserId, slotId", 1, true)
		~= nil,
	"unequip owner identity must come from invoking player"
)
for _, forbidden in { "payload.Damage", "payload.Rarity", "payload.Affixes", "payload.Power", "payload.WeaponId" } do
	assertThat(not string.find(inventoryNetwork, forbidden, 1, true), "inventory network must not trust " .. forbidden)
end

assertThat(
	string.find(inventoryNetwork, "COMBAT_ACTIVATION_RETRY_INTERVAL_SECONDS = 0.25", 1, true) ~= nil,
	"combat activation retry interval must remain explicit and bounded"
)
assertThat(
	string.find(inventoryNetwork, "COMBAT_ACTIVATION_MAX_ATTEMPTS = 80", 1, true) ~= nil,
	"combat activation must have a hard attempt ceiling"
)
assertThat(
	string.find(inventoryNetwork, "attempt < COMBAT_ACTIVATION_MAX_ATTEMPTS", 1, true) ~= nil,
	"combat activation retry must stop at the hard attempt ceiling"
)
assertThat(
	string.find(inventoryNetwork, "task.delay(COMBAT_ACTIVATION_RETRY_INTERVAL_SECONDS", 1, true) ~= nil,
	"bounded combat activation retry must use delayed finite attempts"
)
assertThat(
	string.find(inventoryNetwork, "weaponActivationGenerationByPlayerId", 1, true) ~= nil,
	"stale delayed combat activations must be cancellable by generation"
)
assertThat(
	string.find(inventoryNetwork, "pendingWeaponActivationByPlayerId", 1, true) == nil,
	"inventory network must not regress to the stale forever-heartbeat activation queue"
)

assertThat(
	string.find(combatAdapter, "InventoryLiveService.getRecord(player.UserId)", 1, true) ~= nil,
	"combat adapter must resolve the resident server-owned inventory record"
)
assertThat(
	string.find(combatAdapter, "EquippedWeaponResolver.resolveInstance", 1, true) ~= nil,
	"specific activation must prove the owned instance is currently equipped"
)
assertThat(
	string.find(combatAdapter, "EquippedWeaponResolver.resolvePreferred", 1, true) ~= nil,
	"default reconciliation must derive the preferred durable weapon server-side"
)
assertThat(
	string.find(combatAdapter, "OperativeCombatRuntimeService.equipFoundWeapon", 1, true) ~= nil,
	"equipment must use the existing authoritative combat equip seam"
)
assertThat(
	string.find(combatAdapter, "FirearmConfig.DefaultSelectableWeaponId", 1, true) ~= nil,
	"clearing weapon equipment must fall back through canonical combat config"
)

assertThat(string.find(weaponResolver, "ItemNotOwned", 1, true) ~= nil, "forged instances must fail closed")
assertThat(string.find(weaponResolver, "ItemNotEquipped", 1, true) ~= nil, "unequipped instances must not drive combat")
assertThat(
	string.find(weaponResolver, "definition.WeaponId", 1, true) ~= nil,
	"combat weapon identity must come from authored equipment definition"
)
assertThat(
	string.find(rewardConfig, "FirearmConfig.isKnownWeaponId(definition.WeaponId)", 1, true) ~= nil,
	"authored durable weapon ids must remain validated against combat config"
)
assertThat(
	string.find(combatRuntime, "function OperativeCombatRuntimeService.equipFoundWeapon", 1, true) ~= nil,
	"authoritative combat equip seam must remain present"
)
assertThat(
	string.find(dismantleResolver, 'return reject("ItemEquipped")', 1, true) ~= nil,
	"equipped items must remain protected from dismantle so combat cannot outlive durable ownership"
)

print(
	"InventoryEquipmentCombatAuthoritySourceAudit: durable equipment activation preserves ownership and bounded failure"
)
