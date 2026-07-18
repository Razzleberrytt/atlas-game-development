from pathlib import Path

path = Path("games/living-kingdoms/tests/AuthoritativeShotEffectsSourceAudit.test.luau")
source = path.read_text()
old = '''assertThat(
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
)'''
new = '''assertThat(
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
)'''
if source.count(old) != 1:
    raise RuntimeError("AuthoritativeShotEffectsSourceAudit: expected legacy assertion block once")
path.write_text(source.replace(old, new, 1))
print("Updated authoritative shot-effects audit for revision-commit truth")
