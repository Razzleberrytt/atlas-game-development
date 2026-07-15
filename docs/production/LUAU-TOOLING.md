# Luau Formatting and Static Analysis

Atlas uses two repository-pinned tools for Roblox Luau source:

- StyLua `2.5.2` formats Luau consistently.
- Selene `0.31.0` checks Luau using the Roblox standard library.

Both versions are pinned in the root `rokit.toml`. StyLua reads `stylua.toml`, which selects Luau syntax. Selene reads `selene.toml`, which selects Roblox globals and APIs.

## Install the pinned tools on Windows

Run these commands in PowerShell from the repository root. The explicit Rokit paths bypass any older Aftman shims earlier on PATH.

```powershell
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
Set-Location "$env:USERPROFILE\atlas-game-development"
& "$RokitBin\rokit.exe" install
& "$RokitBin\stylua.exe" --version
& "$RokitBin\selene.exe" --version
```

The version commands must report StyLua `2.5.2` and Selene `0.31.0`.

## Format all Luau source

This command rewrites all supported Luau source beneath the Living Kingdoms source directory:

```powershell
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
Set-Location "$env:USERPROFILE\atlas-game-development"
& "$RokitBin\stylua.exe" .\games\living-kingdoms\src
```

StyLua preserves leading Luau directives such as `--!strict`.

## Check formatting without modifying files

Use `--check` for a read-only formatting check:

```powershell
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
Set-Location "$env:USERPROFILE\atlas-game-development"
& "$RokitBin\stylua.exe" --check .\games\living-kingdoms\src
```

An exit code of `0` means every Luau source file is formatted.

## Lint all Luau source

Run Selene from the repository root so it discovers `selene.toml`:

```powershell
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
Set-Location "$env:USERPROFILE\atlas-game-development"
& "$RokitBin\selene.exe" .\games\living-kingdoms\src
```

An exit code of `0` with `Results: 0 errors, 0 warnings, 0 parse errors` means the current source passes static analysis.

## Scope

These tools cover files under `games/living-kingdoms/src`. No CI workflow, test framework, gameplay dependency, or additional development tool is configured by `LK-0005`.
