--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local presentationSource =
	fs.readFile("games/living-kingdoms/src/client/Presentation/OperativeProgressionMapPresentation.luau")
local menuSource = fs.readFile("games/living-kingdoms/src/client/Controllers/RPGMenuController.luau")

assertThat(
	presentationSource:find("OperativeProgressionConfig", 1, true) ~= nil,
	"durable progression map must consume the canonical authored rank config"
)
assertThat(
	presentationSource:find('WaitForChild("OperativeProgressionNetwork"', 1, true) ~= nil,
	"durable progression map must consume the server-owned progression surface"
)
assertThat(
	presentationSource:find("progressionReadState:InvokeServer()", 1, true) ~= nil,
	"durable progression map must read server-derived account progression"
)
assertThat(
	presentationSource:find(":FireServer", 1, true) == nil,
	"durable progression map must expose no client-authored mutation path"
)
assertThat(
	presentationSource:find("OperativeProgressionConfig.Ranks", 1, true) ~= nil,
	"durable progression map must render authored milestones rather than duplicating rank data"
)
assertThat(
	presentationSource:find("OperativeProgressionConfig.Unlocks", 1, true) ~= nil,
	"durable progression map must render authored unlocks rather than duplicating reward copy"
)
assertThat(
	presentationSource:find("unlock.RequiredRank == rankOrdinal", 1, true) ~= nil,
	"durable unlocks must attach to their authored rank milestone"
)
assertThat(
	presentationSource:find("unlock.DisplayName", 1, true) ~= nil
		and presentationSource:find("unlock.Description", 1, true) ~= nil,
	"unlock milestone presentation must stay config-driven"
)
assertThat(
	presentationSource:find("Rally Ping", 1, true) == nil
		and presentationSource:find("squad-rally-ping", 1, true) == nil,
	"the presenter must not hard-code the first Rally unlock"
)
assertThat(
	presentationSource:find("RANK UNLOCKS", 1, true) ~= nil,
	"rank cards with authored consequences need an explicit unlock section"
)
assertThat(
	presentationSource:find("OPERATIVE PROGRESSION  //  DURABLE", 1, true) ~= nil,
	"durable map must distinguish account progression from temporary run progression"
)
for _, statusId in { "EARNED", "CURRENT", "NEXT", "LOCKED" } do
	assertThat(
		presentationSource:find(statusId, 1, true) ~= nil,
		"durable progression map must expose milestone state " .. statusId
	)
end
assertThat(
	presentationSource:find("Temporary Field XP and run upgrades reset each run", 1, true) ~= nil,
	"durable map must explain the temporary-versus-durable boundary"
)

-- Per-unlock held state is server truth. The presenter renders the disclosed
-- `IsEarned` answer and must never recompute the rank requirement itself,
-- otherwise the map and the server entitlement check can disagree.
assertThat(
	presentationSource:find("unlock.IsEarned == true", 1, true) ~= nil,
	"unlock held state must come from the server-disclosed snapshot"
)
assertThat(
	presentationSource:find("snapshot.Unlocks", 1, true) ~= nil,
	"the presenter must prefer the disclosed unlock list over the authored list"
)
assertThat(
	presentationSource:find("currentRank >= unlock.RequiredRank", 1, true) == nil
		and presentationSource:find("snapshot.Rank >= unlock", 1, true) == nil,
	"the presenter must not re-derive the durable entitlement rule on the client"
)
for _, unlockStatus in { "[EARNED]", "[LOCKED]" } do
	assertThat(
		presentationSource:find(unlockStatus, 1, true) ~= nil,
		"each unlock must read as held or not held on its own, not only through its rank card: " .. unlockStatus
	)
end
assertThat(
	presentationSource:find("snapshot.EarnedUnlockCount", 1, true) ~= nil
		and presentationSource:find("snapshot.TotalUnlockCount", 1, true) ~= nil,
	"the map must summarise how many authored unlocks the operative actually holds"
)
assertThat(
	presentationSource:find("NEXT: %s AT RANK %d", 1, true) ~= nil,
	"the map must name the next unearned unlock and the rank that grants it"
)
assertThat(
	presentationSource:find("Focused Beam", 1, true) == nil
		and presentationSource:find("Self-Treatment", 1, true) == nil
		and presentationSource:find("personal-focused-beam", 1, true) == nil
		and presentationSource:find("medic-self-treatment", 1, true) == nil,
	"the presenter must stay config-driven as unlocks are added"
)

assertThat(
	menuSource:find('topButton(window, "PROGRESSION"', 1, true) ~= nil,
	"existing RPG menu must expose the durable progression surface"
)
assertThat(
	menuSource:find("skillsTab = progressionTab", 1, true) ~= nil,
	"existing hidden Skills surface should be reused rather than creating a parallel menu"
)
assertThat(
	menuSource:find("OperativeProgressionMapPresentation.rebuild(panel)", 1, true) ~= nil,
	"RPG menu should delegate durable map rendering to the dedicated presenter"
)
assertThat(
	menuSource:find("RunProgressionConfig.SkillTrees", 1, true) == nil,
	"RPG menu must not relabel temporary run-upgrade topology as durable progression"
)
assertThat(
	menuSource:find("progressionChooseUpgrade", 1, true) == nil,
	"RPG menu durable progression surface must not retain the old run-upgrade mutation remote"
)
assertThat(
	menuSource:find("FIELD SKILLS", 1, true) == nil,
	"old run-only skill-tree copy must be removed from RPG menu"
)
