#!/usr/bin/env python3
"""Unified Atlas repository validation entry point.

Profiles:
  docs  Documentation/roadmap authority + efficiency-construct checks only.
  fast  R1 iteration: docs + layout + formatting/lint + all Lune fixtures + Rojo builds.
  full  R2/R3/CI: fast plus import/migration/evidence decoder and reconciliation checks.

  persistence-hardening
        Patch 0.7 durable-state suite only. A focused subset of the same
        fixtures `fast`/`full` run, for iterating on persistence without paying
        for the whole sweep. It is a filter, never a substitute: `full` remains
        the merge gate, and this profile deliberately cannot pass anything
        `full` would fail.

Humans, coding agents, and CI should call this script instead of duplicating the
validation command list elsewhere.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from _console import use_utf8_output

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games" / "living-kingdoms"


def run(label: str, command: list[str]) -> None:
    print(f"\n[validate] {label}\n$ {' '.join(command)}", flush=True)
    executable = command[0]
    if executable != sys.executable and shutil.which(executable) is None:
        raise RuntimeError(
            f"required executable {executable!r} was not found; install pinned tools from rokit.toml"
        )
    result = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    output = result.stdout or ""
    if output:
        print(output, end="" if output.endswith("\n") else "\n", flush=True)
    if result.returncode != 0:
        tail = output[-3000:].strip()
        if tail:
            escaped_tail = tail.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print(f"::error title=Atlas command output::{escaped_tail}", file=sys.stderr)
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")


def python_script(label: str, script: str, *args: str) -> None:
    run(label, [sys.executable, script, *args])


def validate_docs() -> None:
    python_script("roadmap/authority integrity", "scripts/validate_roadmap_authority.py")
    python_script("engineering efficiency construct", "scripts/validate_efficiency_construct.py")
    python_script("Patch 0.7 acceptance matrix", "scripts/validate_patch_07_acceptance.py")
    python_script("modular asset systems", "scripts/validate_modular_asset_systems.py")
    python_script("Main World CI artifact contract", "scripts/validate_main_world_ci_artifact.py")
    python_script(
        "Main World artifact bundle verifier",
        "scripts/verify_main_world_artifact_bundle.py",
        "--self-test",
    )


def validate_full_preflight() -> None:
    """Run cheap full-profile checks first so expensive fixtures fail fast."""
    python_script("Studio import package", "scripts/verify_studio_import_package.py")
    python_script("migration manifests", "scripts/validate_migration_manifests.py")
    python_script("current migration evidence", "scripts/validate_migration_current_evidence.py")
    python_script(
        "RBXL property decoder self-test",
        "scripts/roblox/extract_rbxl_world_properties.py",
        "--self-test",
    )
    python_script(
        "RBXL subtree evidence selector self-test",
        "scripts/roblox/select_rbxl_subtree_evidence.py",
        "--self-test",
    )
    python_script(
        "RBXL direct review-unit extractor self-test",
        "scripts/roblox/extract_rbxl_review_unit.py",
        "--self-test",
    )
    python_script(
        "RBXL presentation decoder self-test",
        "scripts/roblox/extract_rbxl_presentation_properties.py",
        "--self-test",
    )
    python_script(
        "RBXL BillboardGui decoder self-test",
        "scripts/roblox/extract_rbxl_billboard_properties.py",
        "--self-test",
    )
    python_script(
        "re-extracted property evidence",
        "scripts/validate_reextracted_property_evidence.py",
    )
    python_script(
        "re-extracted presentation evidence",
        "scripts/validate_reextracted_presentation_evidence.py",
    )


PERSISTENCE_HARDENING_FIXTURES = (
    "PlayerInventoryPersistenceService",
    "InventorySessionLeaseService",
    "InventoryMultiServerHandoff",
    "InventoryReadOutageRecovery",
    "InventoryLifecycleFaultMatrix",
    "InventoryMigrationMatrix",
    "InventoryRecordCapacity",
    "InventoryInvariantChecker",
    "InventoryStorageContractSourceAudit",
    "InventoryLiveLifecycleSourceAudit",
    "StudioInventoryPersistenceIsolation",
    "RobloxInventoryDataStoreAdapterLoadGuard",
    "PersistenceReasonClassificationAudit",
    "OperativeProgressionLedgerShape",
    "DurableMutationAuthoritySourceAudit",
    "EquipmentAffixDurableLifecycle",
)


def validate_persistence_hardening() -> None:
    """Patch 0.7 durable-state suite: a filter over the same fixtures, never a substitute."""
    fixtures = []
    for name in PERSISTENCE_HARDENING_FIXTURES:
        path = GAME / "tests" / f"{name}.test.luau"
        if not path.exists():
            raise RuntimeError(f"persistence-hardening fixture is missing: {path}")
        fixtures.append(path)
    for fixture in fixtures:
        run(
            f"Persistence fixture: {fixture.relative_to(ROOT)}",
            ["lune", "run", str(fixture.relative_to(ROOT))],
        )
    print("")
    print(f"[validate] executed {len(fixtures)} persistence-hardening fixtures", flush=True)


def rojo_build(label: str, project: str, output_name: str) -> None:
    output = Path(tempfile.gettempdir()) / output_name
    run(
        label,
        [
            "rojo",
            "build",
            project,
            "--output",
            str(output),
        ],
    )
    print(f"[validate] build artifact: {output}", flush=True)


def validate_toolchain_and_game() -> None:
    python_script("repository layout", "scripts/validate_living_kingdoms_layout.py")
    run(
        "Luau formatting",
        [
            "stylua",
            "--check",
            "games/living-kingdoms/src",
            "games/living-kingdoms/tests",
            "games/living-kingdoms/tools",
        ],
    )
    run("Selene", ["selene", "games/living-kingdoms/src"])

    fixtures = sorted((GAME / "tests").rglob("*.test.luau"))
    if not fixtures:
        raise RuntimeError("no Living Kingdoms Lune fixtures were discovered")
    for fixture in fixtures:
        run(
            f"Lune fixture: {fixture.relative_to(ROOT)}",
            ["lune", "run", str(fixture.relative_to(ROOT))],
        )
    print(f"\n[validate] executed {len(fixtures)} Lune fixtures", flush=True)

    rojo_build(
        "Rojo build: operation place",
        "games/living-kingdoms/default.project.json",
        "LivingKingdoms.rbxlx",
    )
    rojo_build(
        "Rojo build: dedicated Main World",
        "games/living-kingdoms/main-world.project.json",
        "LivingKingdomsMainWorld.rbxlx",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=("docs", "fast", "full", "persistence-hardening"))
    args = parser.parse_args()

    try:
        python_script(
            "Main World Studio snapshot materialization",
            "scripts/roblox/materialize_main_world_studio_snapshot.py",
        )
        if args.profile == "persistence-hardening":
            validate_persistence_hardening()
            print("")
            print(f"[validate] OK — profile={args.profile}")
            return 0
        validate_docs()
        if args.profile == "full":
            validate_full_preflight()
        if args.profile in {"fast", "full"}:
            validate_toolchain_and_game()
    except RuntimeError as exc:
        print(f"::error title=Atlas validation::{exc}", file=sys.stderr)
        print(f"\n[validate] FAILED: {exc}", file=sys.stderr)
        return 1

    print(f"\n[validate] OK — profile={args.profile}")
    return 0


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
