#!/usr/bin/env python3
"""Validate the commit-addressed Living Kingdoms Main World CI artifact contract."""

from __future__ import annotations

from pathlib import Path

from _console import use_utf8_output

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "luau-validation.yml"
VALIDATOR = ROOT / "scripts" / "validate.py"


def require(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise RuntimeError(f"missing {context}: {needle!r}")


def main() -> int:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    validator = VALIDATOR.read_text(encoding="utf-8")

    require(
        validator,
        '"LivingKingdomsMainWorld.rbxlx"',
        "dedicated Main World deterministic build output",
    )
    require(
        validator,
        '"games/living-kingdoms/main-world.project.json"',
        "dedicated Main World project build",
    )

    require(
        workflow,
        "living-kingdoms-main-world-rbxlx-${{ github.sha }}",
        "commit-addressed Main World artifact name",
    )
    require(
        workflow,
        "/tmp/LivingKingdomsMainWorld.rbxlx",
        "Main World build upload path",
    )
    require(
        workflow,
        "/tmp/LivingKingdomsMainWorld.rbxlx.sha256",
        "Main World SHA-256 sidecar",
    )
    require(
        workflow,
        "/tmp/LivingKingdomsMainWorld.identity.txt",
        "Main World identity manifest",
    )
    require(
        workflow,
        "sha256sum /tmp/LivingKingdomsMainWorld.rbxlx",
        "Main World SHA-256 generation",
    )
    require(workflow, 'commit=${GITHUB_SHA}', "commit identity record")
    require(
        workflow,
        "project=games/living-kingdoms/main-world.project.json",
        "project identity record",
    )

    print("[main-world-ci-artifact] contract OK")
    return 0


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
