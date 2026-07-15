# Windows Local Setup

This guide prepares a Windows machine to clone Atlas, run the pinned Rojo server for Living Kingdoms, connect Roblox Studio, and verify the repository foundation.

## Required setup

The required tools are:

- Git
- Roblox Studio and a Roblox account
- Rokit, used to install the repository-pinned Rojo CLI
- The matching Rojo Studio plugin

Use PowerShell for every command below.

### 1. Install Git and clone the repository

Check whether Git is available:

```powershell
git --version
```

If PowerShell cannot find Git, install it with Windows Package Manager, close PowerShell, and open a new PowerShell window:

```powershell
winget install --id Git.Git -e --source winget
```

Clone the repository into your Windows user profile and enter its root:

```powershell
Set-Location $env:USERPROFILE
git clone https://github.com/Razzleberrytt/atlas-game-development.git
Set-Location "$env:USERPROFILE\atlas-game-development"
git status --short --branch
```

If the repository is already cloned, skip `git clone` and use the final `Set-Location` command.

### 2. Install Roblox Studio

Open the official [Roblox Studio setup page](https://create.roblox.com/docs/studio/setup):

```powershell
Start-Process "https://create.roblox.com/docs/studio/setup"
```

Select **Download Studio**, run the downloaded `RobloxStudio.exe`, launch Studio, and sign in with a Roblox account. Launch Studio at least once before installing the Rojo plugin, then close Studio.

### 3. Install pinned Rojo with Rokit

This repository uses [Rokit](https://github.com/rojo-rbx/rokit) and the root `rokit.toml` to pin Rojo `7.7.0`. Do not install an unpinned global Rojo version for this workflow.

Install Rokit using its official Windows PowerShell installer:

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

The installer normally adds `%USERPROFILE%\.rokit\bin` to PATH, but an existing terminal does not always see that change. Define the full Rokit path explicitly, install the pinned project tools, and verify the version:

```powershell
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
Set-Location "$env:USERPROFILE\atlas-game-development"
& "$RokitBin\rokit.exe" install
& "$RokitBin\rojo.exe" --version
```

The final command must report Rojo `7.7.0`.

#### Existing Aftman shim problem

Some Windows machines have an older Aftman shim at `%USERPROFILE%\.aftman\bin\rojo.exe`. In this repository it fails with `no aftman.toml files list this tool`, because Atlas deliberately uses `rokit.toml` for Rojo.

Inspect every `rojo` command visible on PATH:

```powershell
Get-Command rojo -All | Select-Object Source
```

If the Aftman path appears first, do not use plain `rojo` in the current terminal. The remaining commands in this guide call `%USERPROFILE%\.rokit\bin\rojo.exe` explicitly, which bypasses the stale Aftman shim without deleting or reconfiguring unrelated user tools.

### 4. Install the Rojo Studio plugin

Keep Roblox Studio closed and use the pinned Rojo CLI to install its matching Studio plugin:

```powershell
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
& "$RokitBin\rojo.exe" plugin install
```

Launch Roblox Studio again. Confirm that **Rojo** appears in Studio's **Plugins** toolbar. Rojo's official [installation guide](https://rojo.space/docs/v7/getting-started/installation/) also documents the CLI-installed plugin.

### 5. Start the Living Kingdoms Rojo server

In PowerShell, enter the game directory and start Rojo using its `default.project.json`:

```powershell
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
Set-Location "$env:USERPROFILE\atlas-game-development\games\living-kingdoms"
Test-Path .\default.project.json
& "$RokitBin\rojo.exe" serve .\default.project.json
```

`Test-Path` must print `True`. Leave this PowerShell window running. Rojo should report a server on `localhost` port `34872` unless the local configuration says otherwise.

### 6. Connect Roblox Studio

1. Open Roblox Studio and create or open a local Baseplate place.
2. Open the **Plugins** tab and select **Rojo**.
3. In the Rojo panel, connect to `localhost:34872`.
4. Accept the initial synchronization after reviewing the displayed changes.
5. Keep the Rojo PowerShell process running while editing or testing.

## Verification checklist

Complete these checks manually in Roblox Studio after synchronization:

- [ ] Explorer contains `StarterPlayer > StarterPlayerScripts > Client`. Because `src/client` contains `init.client.luau`, `Client` is the client script entry point.
- [ ] Explorer contains `ServerScriptService > Server`. Because `src/server` contains `init.server.luau`, `Server` is the server script entry point.
- [ ] Explorer contains `ReplicatedStorage > Shared`, mapped from `src/shared`.
- [ ] Start a Play session and open **View > Output**.
- [ ] Output shows `[Living Kingdoms] Client bootstrap started` once.
- [ ] Output shows `[Living Kingdoms] Server bootstrap started` once.
- [ ] No new errors or warnings appear during startup.
- [ ] Stop the Play session and disconnect Rojo when finished.

## Steps that require manual execution

Repository validation can confirm the documented files, paths, commands, mappings, and expected messages, but it cannot complete machine-specific installation or Studio interaction. A developer must still:

- Install Git if it is not already present and clone the repository.
- Install and sign in to Roblox Studio.
- Run the Rokit installer and `rokit install` on the Windows machine.
- Run the pinned CLI's `rojo plugin install` command and confirm the plugin appears in Studio.
- Start the Rojo server, connect Studio, review the initial sync, and complete every verification checkbox above.

## Optional tools

The following tools are optional and are not required to complete the setup above:

- Visual Studio Code or another source editor
- The Rojo Visual Studio Code extension
- GitHub CLI

Formatting and static-analysis tools are intentionally not selected or configured here. That work belongs to `LK-0005`.
