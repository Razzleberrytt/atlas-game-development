from pathlib import Path
import re

ROOTS = [
    Path("games/living-kingdoms/src/server"),
    Path("games/living-kingdoms/src/shared"),
    Path("games/living-kingdoms/src/main-world"),
]

ROOT_WAIT = re.compile(
    r'^(\s*)local\s+(\w+)\s*=\s*ReplicatedStorage:WaitForChild\("([^"]*[Nn]etwork)"\)(.*)$'
)
CHILD_WAIT = re.compile(
    r'^(\s*)local\s+(\w+)\s*=\s*([\w_]*[Nn]etwork):WaitForChild\("([^"]+)"\)(.*)$'
)

changed_files = []

for root in ROOTS:
    if not root.is_dir():
        continue
    for path in root.rglob("*.luau"):
        lines = path.read_text().splitlines()
        if not any(ROOT_WAIT.match(line) or CHILD_WAIT.match(line) for line in lines):
            continue

        if not any(re.match(r"\s*local\s+NETWORK_WAIT_SECONDS\s*=", line) for line in lines):
            service_indexes = [
                index
                for index, line in enumerate(lines)
                if "game:GetService(" in line and re.match(r"\s*local\s+", line)
            ]
            if not service_indexes:
                raise SystemExit(f"no GetService anchor for {path}")
            lines.insert(max(service_indexes) + 1, "local NETWORK_WAIT_SECONDS = 20")

        output = []
        changed = False
        for line in lines:
            root_match = ROOT_WAIT.match(line)
            if root_match:
                indent, variable, network_name, tail = root_match.groups()
                output.append(
                    f'{indent}local {variable} = ReplicatedStorage:WaitForChild("{network_name}", NETWORK_WAIT_SECONDS){tail}'
                )
                output.append(
                    f'{indent}assert({variable} ~= nil, "{network_name} did not become available before the server bootstrap timeout")'
                )
                changed = True
                continue

            child_match = CHILD_WAIT.match(line)
            if child_match:
                indent, variable, receiver, child_name, tail = child_match.groups()
                tail = re.sub(r"::\s*(RemoteEvent|RemoteFunction)\b(?!\?)", r":: \1?", tail)
                output.append(
                    f'{indent}local {variable} = {receiver}:WaitForChild("{child_name}", NETWORK_WAIT_SECONDS){tail}'
                )
                output.append(
                    f'{indent}assert({variable} ~= nil, "{receiver}.{child_name} did not become available before the server bootstrap timeout")'
                )
                changed = True
                continue

            output.append(line)

        if changed:
            path.write_text("\n".join(output) + "\n")
            changed_files.append(path)

# Independent copy of the durable audit's forbidden shapes.
findings = []
for root in ROOTS:
    if not root.is_dir():
        continue
    for path in root.rglob("*.luau"):
        for line_number, line in enumerate(path.read_text().splitlines(), 1):
            network_child = re.search(r'([\w_]*[Nn]etwork):WaitForChild\("([^"]+)"\)', line)
            replicated_network = re.search(
                r'ReplicatedStorage:WaitForChild\("([^"]*[Nn]etwork)"\)', line
            )
            if network_child or replicated_network:
                findings.append(f"{path}:{line_number}: {line.strip()}")

if findings:
    raise SystemExit("unbounded server/shared waits remain:\n" + "\n".join(findings))

print(f"bounded server/shared network waits in {len(changed_files)} files")
for path in changed_files:
    print(path)
