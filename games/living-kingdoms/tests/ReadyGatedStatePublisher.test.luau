--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Publisher = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Networking/ReadyGatedStatePublisher.luau"),
	{ injectGlobals = true }
)()

local sends = {}
local publisher = Publisher.new(function(owner, remoteId, payload)
	table.insert(sends, {
		owner = owner,
		remoteId = remoteId,
		payload = payload,
	})
end)

local playerA = "player-A"
local playerB = "player-B"
local remote = "HordeNetwork.State"

assert(publisher:isReady(playerA) == false)
assert(publisher:publish(playerA, remote, "route.target", 1, { value = "old-route" }) == "buffered")
assert(publisher:publish(playerA, remote, "route.target", 2, { value = "new-route" }) == "buffered")
assert(publisher:publish(playerA, remote, "objective.current", 7, { value = "objective" }) == "buffered")
assert(#sends == 0, "pre-ready publishes must not be sent")
assert(publisher:readPendingCount(playerA) == 2, "latest retention must be keyed by semantic fact, not attempt count")

-- A second owner must remain isolated even when it uses the same remote/key.
assert(publisher:publish(playerB, remote, "route.target", 9, { value = "player-b-route" }) == "buffered")
assert(publisher:readPendingCount(playerB) == 1)
assert(publisher:readPendingCount(playerA) == 2)

local flushedA = publisher:markReady(playerA)
assert(flushedA == 2, "ready transition must flush one current payload per retained semantic key")
assert(publisher:isReady(playerA) == true)
assert(publisher:readPendingCount(playerA) == 0)
assert(#sends == 2)
-- Flush order is deterministic by remote + semantic key: objective before route.
assert(sends[1].payload.value == "objective")
assert(sends[2].payload.value == "new-route", "historical route payload must be replaced before ready")

assert(publisher:publish(playerA, remote, "route.target", 3, { value = "live-route" }) == "sent")
assert(#sends == 3)
assert(sends[3].payload.value == "live-route")

local semanticCounters = publisher:readSemanticCounters()
assert(semanticCounters["route.target"].Attempts == 4)
assert(semanticCounters["route.target"].Accepted == 4)
assert(semanticCounters["route.target"].SuppressedUnchanged == 0, "R2 must not silently implement R3 suppression")
assert(semanticCounters["objective.current"].Attempts == 1)

local deliveryCounters = publisher:readDeliveryCounters()
assert(deliveryCounters[remote].Sent == 3)
assert(deliveryCounters[remote].BufferedLatest == 4)
assert(deliveryCounters[remote].SuppressedBeforeReady == 4)

-- Marking ready twice must not replay already-flushed state.
assert(publisher:markReady(playerA) == 0)
assert(#sends == 3)

-- Disconnect/removal must discard owner-specific pending state without affecting others.
publisher:remove(playerB)
assert(publisher:readPendingCount(playerB) == 0)
assert(publisher:markReady(playerB) == 0)
assert(#sends == 3)

-- A new readiness cycle may buffer again and flush only its newest current fact.
publisher:markNotReady(playerA)
assert(publisher:isReady(playerA) == false)
assert(
	publisher:publish(playerA, "MissionNetwork.State", "round.phase", "Holdout", { phase = "Holdout" }) == "buffered"
)
assert(
	publisher:publish(playerA, "MissionNetwork.State", "round.phase", "Resolved", { phase = "Resolved" }) == "buffered"
)
assert(publisher:readPendingCount(playerA) == 1)
assert(publisher:markReady(playerA) == 1)
assert(#sends == 4)
assert(sends[4].remoteId == "MissionNetwork.State")
assert(sends[4].payload.phase == "Resolved")

print(
	"ReadyGatedStatePublisher: keyed latest retention, readiness flush, isolation, counters, and R2/R3 boundary passed"
)
