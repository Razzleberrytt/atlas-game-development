from __future__ import annotations

from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return source.replace(old, new, 1)


path = Path("games/living-kingdoms/tests/OperativeLifeDamageRouting.test.luau")
source = path.read_text(encoding="utf-8")

source = replace_once(
    source,
    "local HEALTH_RESOLVER_TOKEN = {}",
    "local HEALTH_RESOLVER_TOKEN = {}\nlocal HEALING_RESOLVER_TOKEN = {}",
    "healing resolver token",
)
source = replace_once(
    source,
    '''\t\trequire = function(token)
\t\t\tif token == HEALTH_RESOLVER_TOKEN then
\t\t\t\treturn resolverProxy
\t\t\tend
\t\t\treturn baseRequire(token)
\t\tend,
\t\tscript = { Parent = { OperativeHealthResolver = HEALTH_RESOLVER_TOKEN } },''',
    '''\t\trequire = function(token)
\t\t\tif token == HEALTH_RESOLVER_TOKEN then
\t\t\t\treturn resolverProxy
\t\t\tend
\t\t\tif token == HEALING_RESOLVER_TOKEN then
\t\t\t\treturn {
\t\t\t\t\tresolve = function()
\t\t\t\t\t\terror("healing routing is covered by HROI-0106 fixtures")
\t\t\t\t\tend,
\t\t\t\t}
\t\t\tend
\t\t\treturn baseRequire(token)
\t\tend,
\t\tscript = {
\t\t\tParent = {
\t\t\t\tOperativeHealingResolver = HEALING_RESOLVER_TOKEN,
\t\t\t\tOperativeHealthResolver = HEALTH_RESOLVER_TOKEN,
\t\t\t},
\t\t},''',
    "healing resolver fixture dependency",
)

path.write_text(source, encoding="utf-8")
print("Patched legacy life damage routing fixture for healing dependency")
