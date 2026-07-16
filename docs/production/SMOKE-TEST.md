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

## LK-0011 Fixed overhead camera validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: one clean Play run after clearing Output

Observed:

- `Workspace.Camera.CameraType` was `Scriptable` during Play.
- The viewport showed the baseplate from a visibly overhead angle aimed toward the configured world-space focus point.
- The view remained fixed after startup and did not return to the player-avatar camera.
- `[Living Kingdoms] Fixed overhead camera activated` appeared exactly once.
- `[Living Kingdoms] Server bootstrap started` appeared exactly once.
- `[Living Kingdoms] Client bootstrap started` appeared exactly once.
- No Living Kingdoms-originated errors or warnings appeared.
- Roblox Studio repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.

## LK-0012 Keyboard camera panning validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: one clean Play smoke run after clearing Output, followed by manual held-key validation

Observed:

- `W` and `S` continuously panned forward and backward.
- Up Arrow and Down Arrow continuously panned forward and backward.
- `A` and `D` continuously panned left and right.
- Left Arrow and Right Arrow continuously panned left and right.
- Holding `W+D` produced normalized diagonal movement without moving faster than cardinal input.
- Releasing all movement keys stopped the camera immediately.
- Camera translation remained horizontal while pitch, yaw, and height remained unchanged.
- Typing movement keys in the chat text box did not move the camera.
- `[Living Kingdoms] Fixed overhead camera activated` appeared exactly once.
- `[Living Kingdoms] Server bootstrap started` appeared exactly once.
- `[Living Kingdoms] Client bootstrap started` appeared exactly once.
- No Living Kingdoms-originated errors or warnings appeared.
- Roblox Studio repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.

## LK-0013 Mouse-wheel camera zoom validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: one interactive camera-validation run followed by one clean Play smoke run after clearing Output

Observed:

- Wheel forward decreased camera height by the configured `10`-stud sensitivity and zoomed in.
- Wheel backward increased camera height and zoomed out.
- Repeated wheel-forward input stopped exactly at the configured minimum height of `40` studs.
- Repeated wheel-backward input stopped exactly at the configured maximum height of `160` studs.
- The reconstructed ground-plane focus remained `(0, 0, 0)` while zooming from the initial `80`-stud height to both limits.
- The camera look vector remained `(-0.3535534, -0.8660254, -0.3535534)` at the initial height and both limits, confirming unchanged pitch and yaw.
- Keyboard panning remained functional when zoomed in, at the `80`-stud midpoint, and zoomed out.
- Typing movement keys and scrolling while an in-game text box was focused did not pan or zoom the camera.
- `[Living Kingdoms] Fixed overhead camera activated` appeared exactly once in the final clean run.
- `[Living Kingdoms] Server bootstrap started` appeared exactly once in the final clean run.
- `[Living Kingdoms] Client bootstrap started` appeared exactly once in the final clean run.
- No Living Kingdoms-originated errors or warnings appeared in the final clean run.
- Roblox Studio repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.

## LK-0014 Configurable camera bounds validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: one interactive camera-validation run followed by one clean Play smoke run after clearing Output

Observed:

- The focus point stopped exactly at minimum X `-128` and maximum X `128`.
- The focus point stopped exactly at minimum Z `-128` and maximum Z `128`.
- Diagonal movement into all four corners clamped both axes to their configured limits.
- Holding input against an edge caused no jitter or drift, and releasing and repressing input did not accumulate movement beyond the boundary.
- Moving away from an edge responded immediately.
- Mouse-wheel zoom remained functional at edges and did not alter the bounded focus point.
- Keyboard panning remained functional at the minimum `40`-stud height, initial `80`-stud height, and maximum `160`-stud height.
- Camera translation remained horizontal while pitch, yaw, and camera-height behavior remained otherwise unchanged.
- `[Living Kingdoms] Fixed overhead camera activated` appeared exactly once in the final clean run.
- `[Living Kingdoms] Server bootstrap started` appeared exactly once in the final clean run.
- `[Living Kingdoms] Client bootstrap started` appeared exactly once in the final clean run.
- No Living Kingdoms-originated errors or warnings appeared in the final clean run.
- Roblox Studio repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.

## LK-0101 Camera-relative survivor movement validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: one final clean Play run after focused movement, lifecycle, respawn, and camera regression checks

Observed:

- W/S and Up/Down moved the survivor forward and backward relative to the tactical camera; A/D and Left/Right moved left and right.
- Half-second cardinal samples traveled approximately `7.97` to `8.27` studs. A half-second W+D sample traveled `8.266` studs versus `8.267` studs for W, confirming normalized diagonal input.
- Releasing all movement keys stopped immediately; measured post-release displacement was approximately `0.0000038` studs.
- Settled ground movement stayed horizontal within approximately `0.00000024` studs of Y drift. An initial one-stud descent occurred when normal character collision carried the avatar from the raised SpawnLocation onto the Baseplate.
- The camera position did not change during survivor movement samples, confirming movement keys did not simultaneously pan the camera.
- Typing movement letters and arrow-key input in the in-game chat text box changed neither survivor nor camera position.
- Mouse-wheel zoom remained functional: the camera reached the configured `40`-stud minimum and returned to `90` studs while retaining `Scriptable` mode and the same look vector.
- Existing bounds and clamp logic were unchanged. Extreme keyboard-pan traversal was not repeated because keyboard panning is intentionally disabled while survivor control is active; the accepted LK-0014 boundary validation remains the regression record for that preserved behavior.
- Breaking the character joints produced a replacement character with a Humanoid and HumanoidRootPart without Living Kingdoms errors or warnings.
- Repeated `init()`, `start()`, `stop()`, and restart calls completed without errors.
- `[Living Kingdoms] Fixed overhead camera activated` appeared exactly once.
- `[Living Kingdoms] Server bootstrap started` appeared exactly once.
- `[Living Kingdoms] Client bootstrap started` appeared exactly once.
- No Living Kingdoms-originated errors or warnings appeared in the final clean run.
- Roblox Studio repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.

## LK-0102 Prototype movement authority validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: one focused movement/correction/respawn run followed by one clean Play smoke run after clearing Output

Observed:

- Normal W/A/S/D, arrow-key, and normalized diagonal control remained responsive through the existing `SurvivorController`; ordinary movement resumed after a correction.
- Mouse-wheel zoom remained responsive, and the tactical camera remained active during survivor movement.
- Ordinary jumping, falling/settling, movement on a transient 10-degree test slope, and small physics variation produced no movement-correction warning.
- A deliberate client-side 100-stud horizontal displacement was detected on the server and corrected. The forced position began at approximately `(0.17, 4.22, 1.63)` and settled after correction near the last accepted sample at approximately `(5.60, 4.22, 1.63)`.
- `[Living Kingdoms] Corrected impossible movement for razzleberryt` appeared once for the deliberate correction and did not repeat on following frames, resumed movement, jumping, slope traversal, or respawn.
- Breaking the character joints produced a replacement character with a new `HumanoidRootPart`; validation state reset safely and normal control remained available.
- The final clean run showed `[Living Kingdoms] Server bootstrap started`, `[Living Kingdoms] Fixed overhead camera activated`, and `[Living Kingdoms] Client bootstrap started` exactly once each.
- No Living Kingdoms-originated error or unexpected warning appeared in the final clean run.
- The final clean run repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.

## LK-0103 Survivor-facing and movement-state replication validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: focused two-client movement/state, respawn, and disconnect checks followed by one clean Play smoke run after clearing Output

Observed:

- Repeated survivor movement input changed the local root look vector from initial negative Z to approximately `(0.666, 0, -0.746)`, and releasing input preserved the facing.
- In a deterministic two-client probe, Player1 observed Player2 transition to `Moving` during a valid-speed horizontal sample and back to `Idle` afterward.
- During movement, Player1 observed `SurvivorFacingDirection` `(1, 0, 0)` matching Player2's replicated root look vector `(1, 0, 0)`. On returning to `Idle`, that facing remained stable.
- Respawning Player2 produced a replacement character with state `Idle`, a valid facing attribute, and no stale-character failure.
- Closing Player2 left Player1 connected as the only player without a Living Kingdoms error or warning.
- Existing survivor controls and camera zoom remained functional during the focused checks.
- The final clean run showed `[Living Kingdoms] Server bootstrap started`, `[Living Kingdoms] Fixed overhead camera activated`, and `[Living Kingdoms] Client bootstrap started` exactly once each.
- No Living Kingdoms-originated error or unexpected warning appeared in the final clean run.
- The final clean run repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.

## LK-0104 Survivor-follow camera validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Runs: one focused two-client camera-validation run followed by one clean two-client smoke run

Observed:

- Horizontal root traversal in all cardinal and diagonal world directions moved the camera in the same direction. The survivor remained framed without visible per-frame snapping or jitter during the focused traversal.
- The configured look vector remained approximately `(-0.3535534, -0.8660254, -0.3535534)` throughout focused movement, bounds, jump, zoom, respawn, and lifecycle probes, confirming unchanged pitch and yaw.
- Mouse-wheel input reached exactly the configured `40`-stud minimum and `160`-stud maximum camera heights while the camera stayed `Scriptable` and retained the same look vector.
- With the root held at `(140, approximately 3.22, -140)`, the reconstructed ground-plane camera focus was exactly `(128, 0, -128)`, confirming that the existing bounds constrain the followed focus point.
- A jump raised the root from approximately `3.22` to `10.54` studs while camera Y remained exactly `80` throughout the sample. No distracting vertical camera bob was visible.
- After the survivor target stopped, one `0.4`-second sample captured convergence and the following `0.4`-second sample measured zero camera displacement, confirming prompt settling without prolonged drift.
- Temporarily removing the `HumanoidRootPart` produced zero camera displacement during the missing-root interval. Restoring it reacquired the root without a Living Kingdoms error or warning.
- Breaking the character joints produced a replacement character. After one second, the reconstructed camera focus matched the new root X/Z, `Scriptable` mode remained active, and pitch/yaw were unchanged.
- Repeated controller `init()`, `start()`, `stop()`, and `destroy()` calls completed safely. A stop/start cycle restored survivor-follow framing; terminal destroy calls were safe no-ops when repeated.
- Existing LK-0101 and LK-0103 Studio records remain the direct held-key regression evidence for cardinal/diagonal movement, chat suppression, and movement-key ownership. LK-0104 did not change movement input handling; it only disables camera panning and enables follow alongside the existing survivor lifecycle.
- The final clean run showed `[Living Kingdoms] Server bootstrap started`, `[Living Kingdoms] Fixed overhead camera activated`, and `[Living Kingdoms] Client bootstrap started` exactly once each per applicable server/client Output.
- No Living Kingdoms-originated error or unexpected warning appeared in the final clean run.
- The final clean run repeated the previously documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. These remain classified as Roblox Studio-owned environment noise.
