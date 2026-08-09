from pathlib import Path

path = Path("games/living-kingdoms/tests/OperativeCombatRuntimeService.test.luau")
source = path.read_text()


def replace_once(old: str, new: str) -> None:
    global source
    if new in source:
        return
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"expected one fixture patch anchor, found {count}: {old[:80]!r}")
    source = source.replace(old, new, 1)


replace_once(
    'local combatContracts = loadSimple("games/living-kingdoms/src/shared/Combat/CombatContracts.luau", "CombatContracts")\n',
    'local combatContracts = loadSimple("games/living-kingdoms/src/shared/Combat/CombatContracts.luau", "CombatContracts")\n'
    'local primaryCombatModeContracts = loadSimple(\n'
    '\t"games/living-kingdoms/src/shared/Combat/PrimaryCombatModeContracts.luau",\n'
    '\t"PrimaryCombatModeContracts"\n'
    ')\n',
)
replace_once(
    'local COMBAT_CONTRACTS_TOKEN = {}\nlocal SCARCITY_CONTRACTS_TOKEN = {}\n',
    'local COMBAT_CONTRACTS_TOKEN = {}\n'
    'local PRIMARY_COMBAT_MODE_CONTRACTS_TOKEN = {}\n'
    'local SCARCITY_CONTRACTS_TOKEN = {}\n',
)
replace_once(
    '\t\tCombat = {\n'
    '\t\t\tCombatContracts = COMBAT_CONTRACTS_TOKEN,\n'
    '\t\t\tAmmunitionScarcityContracts = SCARCITY_CONTRACTS_TOKEN,\n',
    '\t\tCombat = {\n'
    '\t\t\tCombatContracts = COMBAT_CONTRACTS_TOKEN,\n'
    '\t\t\tPrimaryCombatModeContracts = PRIMARY_COMBAT_MODE_CONTRACTS_TOKEN,\n'
    '\t\t\tAmmunitionScarcityContracts = SCARCITY_CONTRACTS_TOKEN,\n',
)
replace_once(
    'local LIFE_TOKEN = {}\nlocal MATCH_RESULT_TOKEN = {}\n',
    'local LIFE_TOKEN = {}\n'
    'local PRIMARY_COMBAT_MODE_SERVICE_TOKEN = {}\n'
    'local MATCH_RESULT_TOKEN = {}\n',
)
replace_once(
    'local configuredEngineerInspector = nil\nlocal configuredEngineerCommitter = nil\n',
    'local configuredEngineerInspector = nil\n'
    'local configuredEngineerCommitter = nil\n'
    'local primaryCombatModeByPlayer = {}\n'
    'local primaryCombatModeService = table.freeze({\n'
    '\treadMode = function(player)\n'
    '\t\treturn primaryCombatModeByPlayer[player] or primaryCombatModeContracts.ModeIds.Firearm\n'
    '\tend,\n'
    '\tsetMode = function(player, modeId)\n'
    '\t\tprimaryCombatModeByPlayer[player] = modeId\n'
    '\t\treturn true\n'
    '\tend,\n'
    '})\n',
)
replace_once(
    '\t\t\t\tOperativeLifeService = LIFE_TOKEN,\n'
    '\t\t\t\tMatchResultService = MATCH_RESULT_TOKEN,\n',
    '\t\t\t\tOperativeLifeService = LIFE_TOKEN,\n'
    '\t\t\t\tPrimaryCombatModeService = PRIMARY_COMBAT_MODE_SERVICE_TOKEN,\n'
    '\t\t\t\tMatchResultService = MATCH_RESULT_TOKEN,\n',
)
replace_once(
    '\t\t\tif token == COMBAT_CONTRACTS_TOKEN then\n'
    '\t\t\t\treturn combatContracts\n'
    '\t\t\telseif token == SCARCITY_CONTRACTS_TOKEN then\n',
    '\t\t\tif token == COMBAT_CONTRACTS_TOKEN then\n'
    '\t\t\t\treturn combatContracts\n'
    '\t\t\telseif token == PRIMARY_COMBAT_MODE_CONTRACTS_TOKEN then\n'
    '\t\t\t\treturn primaryCombatModeContracts\n'
    '\t\t\telseif token == SCARCITY_CONTRACTS_TOKEN then\n',
)
replace_once(
    '\t\t\telseif token == LIFE_TOKEN then\n'
    '\t\t\t\treturn lifeService\n'
    '\t\t\telseif token == MATCH_RESULT_TOKEN then\n',
    '\t\t\telseif token == LIFE_TOKEN then\n'
    '\t\t\t\treturn lifeService\n'
    '\t\t\telseif token == PRIMARY_COMBAT_MODE_SERVICE_TOKEN then\n'
    '\t\t\t\treturn primaryCombatModeService\n'
    '\t\t\telseif token == MATCH_RESULT_TOKEN then\n',
)
replace_once(
    '\ttable.clear(combatAllowedByPlayer)\n',
    '\ttable.clear(combatAllowedByPlayer)\n\ttable.clear(primaryCombatModeByPlayer)\n',
)

path.write_text(source)
print("patched OperativeCombatRuntimeService fixture for primary combat mode dependencies")
