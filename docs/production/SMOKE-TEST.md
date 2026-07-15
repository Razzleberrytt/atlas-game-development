# Living Kingdoms Smoke Test

Use this checklist after changes that can affect project synchronization or startup.

## Reusable checklist

- [ ] Start the repository-pinned Rojo 7.7.0 server from `games\living-kingdoms` with `& "$env:USERPROFILE\.rokit\bin\rojo.exe" serve .\default.project.json`.
- [ ] Connect the Rojo 7.7.0 Studio plugin to `localhost:34872` and complete synchronization.
- [ ] Confirm `StarterPlayer > StarterPlayerScripts > Client`, `ServerScriptService > Server`, and `ReplicatedStorage > Shared` are present in Explorer.
- [ ] Open Output and clear existing messages so the run starts with an empty log.
- [ ] Start a Play session and wait for startup to settle.
- [ ] Confirm `[Living Kingdoms] Server bootstrap started` appears exactly once.
- [ ] Confirm `[Living Kingdoms] Client bootstrap started` appears exactly once.
- [ ] Confirm no errors or warnings originate from Living Kingdoms scripts.
- [ ] Classify project logs separately from Roblox platform, CoreScript, plugin, and editor logs.
- [ ] Stop the Play session when verification is complete.

## First successful launch

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: two clean Play runs after clearing Output

Observed on both runs:

- `[Living Kingdoms] Server bootstrap started` appeared exactly once.
- `[Living Kingdoms] Client bootstrap started` appeared exactly once.
- `StarterPlayer > StarterPlayerScripts > Client` remained present.
- `ServerScriptService > Server` remained present.
- `ReplicatedStorage > Shared` remained present.
- No Living Kingdoms-originated errors or warnings appeared.

Roblox Studio emitted `[PlatformLeaderboard] Fetcher request failed` and `checkRemoteAgainstAllowList` warnings naming `PlatformLeaderboardPush`, `PlatformLeaderboardTabOpened`, and `PlatformLeaderboardTabClosed`. These messages appeared on both clean Play runs and are classified as Roblox Studio-owned environment noise, not Living Kingdoms regressions.

Future smoke tests must distinguish project logs from platform and editor logs while still recording unexpected environment noise.

## LK-0010 CameraController launch validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: one clean Play run after clearing Output

Observed:

- `[Living Kingdoms] Server bootstrap started` appeared exactly once.
- `[Living Kingdoms] Client bootstrap started` appeared exactly once after `CameraController.init()` and `CameraController.start()` returned.
- The successful client confirmation verifies that `CameraController` initialized and started without interrupting bootstrap.
- No Living Kingdoms-originated errors or warnings appeared.
- Roblox Studio repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.
