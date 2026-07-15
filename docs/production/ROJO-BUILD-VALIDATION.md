# Rojo Build Validation

LK-0006 was validated on Windows with the repository-pinned Rojo 7.7.0 executable.

## Automated validation

Run these commands from `games\living-kingdoms` in PowerShell:

```powershell
$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
$ArtifactDirectory = Join-Path $env:TEMP "atlas-game-development\LK-0006"
$ArtifactPath = Join-Path $ArtifactDirectory "living-kingdoms.rbxlx"

& "$RokitBin\rojo.exe" --version
& "$RokitBin\rojo.exe" sourcemap .\default.project.json
New-Item -ItemType Directory -Force -Path $ArtifactDirectory
& "$RokitBin\rojo.exe" build .\default.project.json --output $ArtifactPath
Get-Item -LiteralPath $ArtifactPath | Select-Object FullName, Length
```

All Rojo commands exited with code `0`. The build produced `C:\Users\Will\AppData\Local\Temp\atlas-game-development\LK-0006\living-kingdoms.rbxlx`, a non-empty 1,318-byte place file. The artifact is outside the repository and is not committed, so no repository ignore rule is required.

The sourcemap parsed successfully and identified the source-backed `Client` and `Server` script nodes. The empty shared source directory has no source span in the sourcemap, so its mapping was validated in `default.project.json` and in the generated place XML. The generated place contained:

- `StarterPlayer > StarterPlayerScripts > Client` as a `LocalScript`
- `ServerScriptService > Server` as a `Script`
- `ReplicatedStorage > Shared` as a `Folder`

StyLua check and Selene also exited with code `0` against all current Luau source.

## Roblox Studio synchronization

Roblox Studio and the Rojo 7.7.0 plugin were available. Studio was connected to the pinned Rojo 7.7.0 server for `LivingKingdoms` at `localhost:34872`, and Explorer visibly contained all three mappings listed above.

LK-0006 did not start a play session or record bootstrap output; that smoke-test work belongs to LK-0007.
