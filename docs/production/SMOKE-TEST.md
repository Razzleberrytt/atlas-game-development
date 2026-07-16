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
