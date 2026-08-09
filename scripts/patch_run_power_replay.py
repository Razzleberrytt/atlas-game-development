from pathlib import Path

PROGRESSION = Path("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
LIFECYCLE_TEST = Path("games/living-kingdoms/tests/OperationLifecycleReplay.test.luau")


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one anchor, found {count}")
    return source.replace(old, new, 1)


progression = PROGRESSION.read_text()
reset_block = '''function RunProgressionService.resetOperation(): boolean
\tif not started then
\t\treturn false
\tend

\t-- Gameplay progression is operation-scoped, but revision/gain/selection
\t-- sequences are transport counters observed by a long-lived HUD. Keep those
\t-- counters monotonic so the client accepts the fresh-run snapshot and the
\t-- first gain/selection of the next run is still visible.
\tlevel = 1
\txp = 0
\ttotalXp = 0
\tsquadKills = 0
\teliteKillsSinceReward = 0
\tlastGainAmount = 0
\tlevelsGainedLastAward = 0
\taccumulatedSeconds = 0
\tinitialScanComplete = false
\tunclaimedUpgradeChoices = 0
\tofferSequence = 0
\tlastSelectedUpgradeId = ""
\tlastSelectedUpgradeName = ""
\tlastSelectedUpgradeStack = 0
\ttable.clear(trackedLifeStates)
\ttable.clear(pendingChoiceIds)
\ttable.clear(lastUpgradeRequestTimestamps)
\ttable.clear(processedFieldIntelRewardIds)
\ttable.clear(fieldIntelRewardOrder)
\tsyncCombatModifierAttributes()
\tpublishAll()
\treturn true
end

'''
progression = replace_once(
    progression,
    "function RunProgressionService.start()\n",
    reset_block + "function RunProgressionService.start()\n",
    "RunProgressionService reset insertion",
)
PROGRESSION.write_text(progression)

fixture = LIFECYCLE_TEST.read_text()
fixture = replace_once(
    fixture,
    "local survivalLootResetCount = 0\n",
    "local survivalLootResetCount = 0\nlocal runBuildResetCount = 0\nlocal runProgressionResetCount = 0\n",
    "replay counters",
)
fixture = replace_once(
    fixture,
    "\tPrimaryCombatModeService = {},\n\tOperativeReviveSessionService = {},\n",
    "\tPrimaryCombatModeService = {},\n\tRunBuildService = {},\n\tRunProgressionService = {},\n\tOperativeReviveSessionService = {},\n",
    "replay tokens",
)
fixture = replace_once(
    fixture,
    "\t[TOKENS.PrimaryCombatModeService] = {\n\t\tresetAllToMelee = function()\n\t\t\tprimaryCombatModeResetCount += 1\n\t\tend,\n\t},\n\t[TOKENS.OperativeReviveSessionService] = owner(\"ReviveSessions\"),\n",
    "\t[TOKENS.PrimaryCombatModeService] = {\n\t\tresetAllToMelee = function()\n\t\t\tprimaryCombatModeResetCount += 1\n\t\tend,\n\t},\n\t[TOKENS.RunBuildService] = {\n\t\tresetOperation = function()\n\t\t\trunBuildResetCount += 1\n\t\tend,\n\t},\n\t[TOKENS.RunProgressionService] = {\n\t\tresetOperation = function()\n\t\t\trunProgressionResetCount += 1\n\t\tend,\n\t},\n\t[TOKENS.OperativeReviveSessionService] = owner(\"ReviveSessions\"),\n",
    "replay module mocks",
)
fixture = replace_once(
    fixture,
    "assertThat(survivalLootResetCount == 0, \"the initial launch must not reset survival loot\")\n",
    "assertThat(survivalLootResetCount == 0, \"the initial launch must not reset survival loot\")\nassertThat(runBuildResetCount == 0, \"the initial launch must not reset temporary run build power\")\nassertThat(runProgressionResetCount == 0, \"the initial launch must not reset Field XP progression\")\n",
    "initial replay assertions",
)
fixture = replace_once(
    fixture,
    "assertThat(survivalLootResetCount == 1, \"fresh replay must rebuild survival loot exactly once\")\n",
    "assertThat(survivalLootResetCount == 1, \"fresh replay must rebuild survival loot exactly once\")\nassertThat(runBuildResetCount == 1, \"fresh replay must clear temporary run build power exactly once\")\nassertThat(runProgressionResetCount == 1, \"fresh replay must clear Field XP progression exactly once\")\n",
    "fresh replay assertions",
)
fixture = replace_once(
    fixture,
    "assertThat(survivalLootResetCount == 1, \"idempotent launch preparation must not rebuild survival loot twice\")\n",
    "assertThat(survivalLootResetCount == 1, \"idempotent launch preparation must not rebuild survival loot twice\")\nassertThat(runBuildResetCount == 1, \"idempotent launch preparation must not reset run build twice\")\nassertThat(runProgressionResetCount == 1, \"idempotent launch preparation must not reset run progression twice\")\n",
    "idempotent replay assertions",
)
fixture = replace_once(
    fixture,
    "\tcontains(lifecycle, \"PrimaryCombatModeService.resetAllToMelee()\")\n\t\tand contains(lifecycle, \"OperativeCombatRuntimeService.resetForReplay()\")\n\t\tand contains(lifecycle, \"SurvivalLootService.resetForReplay()\"),\n\t\"fresh-run replay must reset melee mode, firearm state, and survival loot\"\n",
    "\tcontains(lifecycle, \"PrimaryCombatModeService.resetAllToMelee()\")\n\t\tand contains(lifecycle, \"OperativeCombatRuntimeService.resetForReplay()\")\n\t\tand contains(lifecycle, \"SurvivalLootService.resetForReplay()\")\n\t\tand contains(lifecycle, \"RunBuildService.resetOperation()\")\n\t\tand contains(lifecycle, \"RunProgressionService.resetOperation()\"),\n\t\"fresh-run replay must reset opening state and all temporary run power\"\n",
    "replay source assertion",
)
LIFECYCLE_TEST.write_text(fixture)

print("Applied temporary run-power replay reset patch")
