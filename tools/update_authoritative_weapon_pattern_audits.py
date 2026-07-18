from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    source = file_path.read_text()
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one replacement, found {count}")
    file_path.write_text(source.replace(old, new, 1))


replace_once(
    "games/living-kingdoms/tests/AuthoritativeShotEffectsSourceAudit.test.luau",
    '''assertThat(
\tstring.find(runtime, "didApplyDamage = damageResolution.didApplyDamage", 1, true) ~= nil,
\t"server disclosure must use the committed damage resolution"
)
assertThat(
\tstring.find(
\t\truntime,
\t\t"impactWorldPosition = if damageResolution.didApplyDamage then fact.worldPosition else nil",
\t\t1,
\t\ttrue
\t) ~= nil,
\t"blocked or rejected damage must not fabricate an impact position"
)''',
    '''assertThat(
\tstring.find(runtime, "local didApplyPrimaryDamage = didCommitPrimary and damageResolution.didApplyDamage", 1, true)
\t\t~= nil,
\t"server disclosure must require both damage resolution and a successful revisioned health commit"
)
assertThat(
\tstring.find(runtime, "didApplyDamage = didApplyPrimaryDamage", 1, true) ~= nil,
\t"shot disclosure must use committed primary damage truth"
)
assertThat(
\tstring.find(runtime, "impactWorldPosition = if didApplyPrimaryDamage then fact.worldPosition else nil", 1, true)
\t\t~= nil,
\t"blocked, rejected, or stale commits must not fabricate an impact position"
)''',
)

runtime_test = "games/living-kingdoms/tests/OperativeCombatRuntimeService.test.luau"
replace_once(
    runtime_test,
    '''local RELOAD_TOKEN = {}
local SELECTOR_TOKEN = {}''',
    '''local RELOAD_TOKEN = {}
local SELECTOR_TOKEN = {}
local PATTERN_TOKEN = {}''',
)
replace_once(
    runtime_test,
    '''\t\t\t\tReloadResolver = RELOAD_TOKEN,
\t\t\t\tTargetCandidateSelector = SELECTOR_TOKEN,
\t\t\t},''',
    '''\t\t\t\tReloadResolver = RELOAD_TOKEN,
\t\t\t\tTargetCandidateSelector = SELECTOR_TOKEN,
\t\t\t\tWeaponPatternResolver = PATTERN_TOKEN,
\t\t\t},''',
)
replace_once(
    runtime_test,
    '''\t\t\telseif token == SELECTOR_TOKEN then
\t\t\t\treturn selector
\t\t\tend''',
    '''\t\t\telseif token == SELECTOR_TOKEN then
\t\t\t\treturn selector
\t\t\telseif token == PATTERN_TOKEN then
\t\t\t\treturn table.freeze({
\t\t\t\t\tresolve = function()
\t\t\t\t\t\treturn table.freeze({})
\t\t\t\t\tend,
\t\t\t\t})
\t\t\tend''',
)

print("Updated committed-hit audit and runtime dependency harness")
