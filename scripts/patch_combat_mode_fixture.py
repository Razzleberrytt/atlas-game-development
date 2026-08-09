from pathlib import Path

PATH = Path("games/living-kingdoms/tests/OperativeCombatRuntimeService.test.luau")
source = PATH.read_text()


def replace_once(old: str, new: str) -> None:
    global source
    if new in source:
        return
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"expected one anchor, found {count}: {old[:100]!r}")
    source = source.replace(old, new, 1)


replace_once(
    "local VALIDATOR_TOKEN = {}\nlocal CLASS_SERVICE_TOKEN = {}\n",
    "local VALIDATOR_TOKEN = {}\nlocal CLASS_SERVICE_TOKEN = {}\nlocal PRIMARY_COMBAT_MODE_CONTRACTS_TOKEN = {}\n",
)

replace_once(
    "local hordeConfig =\n\tloadSimple(\"games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau\", \"HordeExperienceConfig\")\n",
    "local hordeConfig =\n\tloadSimple(\"games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau\", \"HordeExperienceConfig\")\nlocal primaryCombatModeContracts = table.freeze({\n\tModeIds = table.freeze({ Firearm = \"Firearm\", Melee = \"Melee\" }),\n})\n",
)

replace_once(
    "\t\t\tEnemyContracts = ENEMY_CONTRACTS_TOKEN,\n\t\t},\n",
    "\t\t\tEnemyContracts = ENEMY_CONTRACTS_TOKEN,\n\t\t\tPrimaryCombatModeContracts = PRIMARY_COMBAT_MODE_CONTRACTS_TOKEN,\n\t\t},\n",
)

replace_once(
    "local LIFE_TOKEN = {}\nlocal MATCH_RESULT_TOKEN = {}\n",
    "local LIFE_TOKEN = {}\nlocal PRIMARY_COMBAT_MODE_SERVICE_TOKEN = {}\nlocal MATCH_RESULT_TOKEN = {}\n",
)

replace_once(
    "local configuredEngineerInspector = nil\nlocal configuredEngineerCommitter = nil\n\nlocal scheduled = {}\n",
    "local configuredEngineerInspector = nil\nlocal configuredEngineerCommitter = nil\nlocal primaryCombatModeService = table.freeze({\n\treadMode = function()\n\t\treturn primaryCombatModeContracts.ModeIds.Firearm\n\tend,\n\tsetMode = function()\n\t\treturn true\n\tend,\n})\n\nlocal scheduled = {}\n",
)

replace_once(
    "\t\t\t\tOperativeLifeService = LIFE_TOKEN,\n\t\t\t\tMatchResultService = MATCH_RESULT_TOKEN,\n",
    "\t\t\t\tOperativeLifeService = LIFE_TOKEN,\n\t\t\t\tPrimaryCombatModeService = PRIMARY_COMBAT_MODE_SERVICE_TOKEN,\n\t\t\t\tMatchResultService = MATCH_RESULT_TOKEN,\n",
)

replace_once(
    "\t\t\telseif token == HORDE_CONFIG_TOKEN then\n\t\t\t\treturn hordeConfig\n",
    "\t\t\telseif token == HORDE_CONFIG_TOKEN then\n\t\t\t\treturn hordeConfig\n\t\t\telseif token == PRIMARY_COMBAT_MODE_CONTRACTS_TOKEN then\n\t\t\t\treturn primaryCombatModeContracts\n",
)

replace_once(
    "\t\t\telseif token == LIFE_TOKEN then\n\t\t\t\treturn lifeService\n\t\t\telseif token == MATCH_RESULT_TOKEN then\n",
    "\t\t\telseif token == LIFE_TOKEN then\n\t\t\t\treturn lifeService\n\t\t\telseif token == PRIMARY_COMBAT_MODE_SERVICE_TOKEN then\n\t\t\t\treturn primaryCombatModeService\n\t\t\telseif token == MATCH_RESULT_TOKEN then\n",
)

PATH.write_text(source)
print("Patched OperativeCombatRuntimeService fixture for server-owned primary combat mode")
