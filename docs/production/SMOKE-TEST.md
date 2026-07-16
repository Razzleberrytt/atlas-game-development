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

## LK-0105 Multiplayer movement and regression validation

- Date: 2026-07-15
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI 7.7.0 and Studio plugin 7.7.0
- Project: `LivingKingdoms` synchronized from `games\living-kingdoms\default.project.json` at `localhost:34872`
- Studio mode: local **Server & Clients** session with one server and two clients on one machine
- Runs: one focused two-client regression session followed by one clean two-client startup/log run

Observed:

- Each client moved only its own survivor. Movement and facing changes on one survivor left the other survivor's position and rotation unchanged, and each camera followed only its local survivor.
- Both clients observed the remote survivor's replicated `Idle`/`Moving` transitions and facing updates. Returning to `Idle` preserved the last replicated facing.
- A valid-speed sample moved Player1 approximately `8.06` studs without an LK-0102 correction. Player2 observed the remote movement while its local survivor and camera remained stationary.
- A forced 100-stud Player1 displacement was corrected by the server in approximately `0.35` seconds. Player2 remained undisturbed, and both survivors could resume normal movement afterward. The expected corrected client showed one visible snap/rubber-band; no repeated correction followed.
- Respawning Player1 did not disturb Player2, and respawning Player2 did not disturb Player1. Each replacement character established fresh `Idle` state, facing, movement-validation sampling, and local camera follow.
- Closing Player2 removed it from the session while Player1 remained healthy. Server movement-validation and movement-state tracking cleaned up without a Living Kingdoms error or warning.
- Replacing Client 1's `Workspace.CurrentCamera` reacquired the local survivor immediately, restored `Scriptable` mode, preserved follow framing, and retained mouse-wheel zoom.
- A focused local text box suppressed movement keys and wheel zoom only on Client 1. Client 2 retained independent input and zoom. Wheel input changed only the receiving client's camera, and movement keys did not pan either camera.
- Repeated controller `init()`, `start()`, and `stop()` calls completed safely on both clients. Idempotent no-op calls created no duplicate connections or logs; a deliberate stop/start cycle emitted one expected activation for that new lifecycle. Existing LK-0101 and LK-0104 records remain the direct held-key evidence for cardinal/diagonal control and movement-key ownership.
- In the final clean run, each client emitted `[Living Kingdoms] Fixed overhead camera activated` and `[Living Kingdoms] Client bootstrap started` exactly once; the server emitted `[Living Kingdoms] Server bootstrap started` exactly once. No unintended Living Kingdoms error or warning appeared.

Network observations:

- The local loopback sample observed the remote `Moving` state approximately `0.016` seconds after the measured movement probe began. This is an approximate Studio observation, not a production latency guarantee.
- No obvious remote-character jitter was visible during the valid-speed sample. The deterministic probe used small stepped displacements, so it does not represent adverse network conditions.
- The forced invalid displacement produced the expected local correction snap after approximately `0.35` seconds. The other client did not visibly receive the full invalid displacement before correction.
- Roblox character network ownership behaved as expected for this prototype: local character movement replicated to the server and peer, while the server could reject the impossible displacement and propagate the correction. Client ownership was not treated as gameplay authority.

Known limitations and changes:

- This was a two-client, single-machine Studio loopback test. It does not measure internet latency, packet loss, low frame rate, mobile input, console input, or production server load.
- The validator remains a tolerant, discrete prototype sanity boundary. This record does not claim production-grade networking or exploit prevention.
- Roblox Studio repeated the documented `PlatformLeaderboard` fetch and protected-container allow-list warnings. They are classified as Studio-owned environment noise.
- No reproducible LK-0105 source defect was found. No runtime source file or architecture was changed; LK-0105 changes are documentation-only.

## LK-0207 Two-client automatic-combat security and feel validation

- Date: 2026-07-16
- Environment: Microsoft Windows 11 Home 10.0.26200; Roblox Studio 0.730.0.7300790
- Rojo: repository-pinned CLI and Studio plugin 7.7.0
- Studio mode: local **Server & Clients** session with one server and two clients on one machine
- Runs: focused security/timing/lifecycle sessions followed by one clean two-client startup and combat-presentation run
- Exact roadmap acceptance: “clients cannot select illegal targets, fire for another operative, exceed cadence, create ammunition, set damage, or hit through invalid obstruction; target priority matches the documented rules; camera and movement regressions pass; manual priority override remains unimplemented unless separately approved.”

### Fixture and harness boundary

`AutomaticCombatDevelopmentHarness` replaced the reload-only development harness. It is guarded by `RunService:IsStudio()` before it creates state or connects the reload remote. It creates exactly two anchored, clearly labeled fixtures, `hostile.lk0207.alpha` and `hostile.lk0207.bravo`; these are stationary test targets, not enemy AI, pathfinding, spawning, waves, or production combat completion.

The harness starts each test weapon with zero loaded rounds and the existing temporary 24-round reserve so a tester must exercise `R` before acquisition and fire. Each fixture starts at 1000 harness-only health. Per-player weapon, cadence, reload, selected-target, and threat state is server-owned. Fixture eligibility, obstruction outcome, health, and processed ShotIds are server-owned. The harness composes the existing P2 selector and resolvers instead of copying their rules.

The only direct harness controls are `start()` and `stop()` from the Studio server command bar. `stop()` disconnects the reload listener, Heartbeat, player lifecycle connections, and character connections; clears per-player state and selected-target presentation; and destroys `Workspace.LK0207CombatFixtures`. Character replacement creates fresh per-player combat/reload state and invalidates delayed reload callbacks with a generation token. Player leave removes its state. Repeated `stop()`/`start()` calls produced exactly two fixtures, with no duplicate connections or error.

Test-only client command-bar listeners observed already-disclosed presentation messages and their receipt timestamps. A client command sent malformed `CombatPresentation:FireServer(...)` and wrong/extra `ReloadIntent:FireServer(...)` payloads solely to verify that no authoritative path accepted them. These hooks exist only in the temporary Studio session, add no source or admin command, and disappear when the session closes.

### Client authority and remote audit

Pass. `default.project.json` contains exactly two combat RemoteEvents. `ReloadIntent` is the only `OnServerEvent` combat listener and accepts exactly one configured `WeaponId`; Roblox supplies the sending `Player`. `CombatPresentation` has only server-to-client listeners in project code. There is no target, fire, ammunition, cadence, timestamp, damage, hit, health, target-state, obstruction, or ShotId client request path.

- Client A could not submit a target or choose Client B’s target/operative through any remote.
- Cross-operative selected-target state was rejected as `SelectedTargetInvalid` in the integration fixture.
- Client A and B consumed their own ammunition and retained independent cadence/reload state.
- Wrong weapon IDs and extra reload arguments produced no `ReloadStarted` event. A subsequent valid local `R` immediately produced `ReloadStarted`, proving the rejection did not corrupt state.
- A client-fired malformed `CombatPresentation` message produced no target, shot, ammo, health, or damage transition because the server has no listener.
- Resolver fixtures confirmed that client-like extra damage amount/type/timestamp fields cannot replace configured 20 `Ballistic` damage or server time.
- `WeaponController` now rejects incomplete target, clear, shot, and reload tables; nonempty IDs, configured weapon IDs, and finite required timestamps are validated before presentation.

### Target priority and legality

Pass through the LK-0202/LK-0203 fixtures and the new two-operative integration fixture.

- Each operative preferred the valid hostile threatening its exact operative. A threat to the other operative was not promoted.
- Closest threatening wins; without a threat, closest valid wins; equal distance uses lexical `CombatEntityId` ordering.
- Candidate ordering did not change selection.
- Hidden, obstructed, friendly/neutral, dead, untargetable, empty-ammo, non-ready, and out-of-range candidates were excluded.
- Exactly 80 horizontal studs remained legal; 80.001 was rejected.
- Loss returned `nil`, cleared presentation, and later authoritative facts allowed reacquisition.
- In Studio, Client 1 received only `hostile.lk0207.bravo` as its selected target and Client 2 received only `hostile.lk0207.alpha` in the observed threat-assigned cycle.
- Manual priority override remains unimplemented.

### Fire, cadence, and ammunition

Pass. Pure fixtures confirmed exact-boundary legality, just-before rejection, at most one shot per evaluation, no catch-up burst, last-round legality, zero-loaded rejection, one-round consumption, and unchanged reserve while firing.

In Studio, one 12-round magazine changed its target from 1000 to 760 health: exactly 12 accepted shots at 20 damage. A final clean run showed the first accepted shot change 1000 to 980. Client 2 remained at zero loaded rounds until its own reload and then began its own independent cycle. Observed authoritative shot intervals were 0.201–0.250 seconds in the 0.05-second Studio harness evaluation loop. No faster shot, doubled evaluation, or catch-up burst appeared.

### Hit, damage, and obstruction

Pass through LK-0205 and integration fixtures.

- A legal unobstructed shot applied exactly configured 20 `Ballistic` damage.
- `Blocked` and explicit `Miss` outcomes applied no damage.
- Dead, untargetable, hidden, neutral/friendly, mismatched, and newly out-of-range targets failed revalidation safely.
- Exactly-at-range remained legal.
- A committed ShotId could not apply damage twice, including after a miss/rejection became terminal.
- Health clamped to zero; lethal and nonlethal flags were correct.
- Client-like damage amount, type, timestamp, target health, and hit fields were ignored or rejected.

The live harness default used only the server-owned `TargetHit` fact. Obstruction and post-selection invalidation variants were deterministic automated checks, not claims of a production raycast or enemy runtime.

### Reload

Pass through LK-0206 fixtures, integration checks, and live two-client observation.

- Local `R` sent one configured weapon ID; processed input, text focus, rapid input, and controller lifecycle guards remained covered by `WeaponController.test.luau`.
- Full magazine, zero reserve, wrong weapon, extra payloads, and already-reloading requests were rejected.
- Just-before deadline was rejected; exactly the two-second deadline was legal.
- Existing rounds remained loaded; transfer used `min(missing capacity, reserve)` and conserved totals.
- Incapacitation, death, weapon disablement, and weapon change interrupted without transfer. Movement and damage-only fixture fields did not interrupt.
- Client 1’s reload event was absent from Client 2. Client 2 later reloaded and fired independently.

Measured loopback presentation: Client 1 received reload start and completion 1.999 seconds apart. Client 2’s observed pair was 2.017 seconds apart, reflecting Studio scheduling around the server-owned two-second deadline. No early completion occurred.

### Presentation and disclosure

Pass.

- Target indicators were created only from valid server `TargetSelected` messages naming an existing disclosed fixture.
- Unknown IDs, unknown message kinds, and malformed known-target disclosures failed closed.
- Client 1 and Client 2 received different operative-specific target IDs; neither local selection changed until that client independently reloaded and acquired.
- Each disclosed ShotId was presented once; repeated ShotIds were ignored by the controller fixture and none repeated in live logs.
- Reload start/completion stayed local to the applicable player.
- Presentation changed status/highlight only; it did not mutate ammo, health, legality, hits, damage, or server state.
- Target clear arrived after the empty magazine made selection invalid and removed the indicator.

Measured loopback delivery from message server timestamp to client receipt was 18.5–23.4 ms for target, shot, and clear messages. Target acquisition followed reload completion within approximately 0–16 ms of client-observed event ordering. The final clear followed the last shot’s authoritative timestamp by approximately 50 ms (one harness evaluation) plus approximately 23 ms delivery.

### P1 multiplayer regressions

Pass with the accepted LK-0105 record plus focused live checks; no movement, facing, camera, chat, or zoom source changed in LK-0207.

- Two distinct characters and local cameras remained present during combat.
- Client 1 camera remained `Scriptable`; local wheel input changed its camera height from 80 to 40 while Client 2 remained `Scriptable` at 80, confirming camera isolation and zoom.
- Respawning Player1 replaced its character and freshened combat state while Player2’s root remained unchanged at `(-4.0821, 4.2229, -1.3529)`.
- Closing Player2 produced a server disconnect and reduced the player count from two to one without a Living Kingdoms error. Repeated fresh two-client sessions established zero-loaded, 24-reserve server state and 1000-health fixtures again.
- The accepted LK-0105 held-movement, facing replication, chat suppression, and camera-follow evidence remains the direct input regression record. Desktop automation could not sustain a held movement key in this run, so those measurements were not restated as new observations.
- Repeated harness lifecycle calls remained safe. `WeaponController` repeated init/start/stop/destroy behavior remained covered by its fixture.
- In the final clean run, the server bootstrap appeared exactly once; each client’s camera activation and client bootstrap appeared exactly once. No unintended Living Kingdoms warning or error appeared.

### Feel observations

- Target selection felt prompt after reload, with acquisition appearing in the same visible transition as readiness returned.
- Server acceptance to shot presentation was approximately 19–23 ms on local loopback and did not feel delayed.
- Cadence appeared steady. The 0.05-second evaluation produced small 0.201–0.250-second spacing variation without bursts.
- Target clear occurred promptly at empty magazine, within one evaluation plus local delivery.
- Reload feedback matched the two-second vulnerability window and was understandable: `Reloading`, then `Reload complete`, acquisition, and shots.
- No visible combat-induced rubber-banding or camera jitter was observed. The only documented correction snap remains the deliberate LK-0105 invalid-movement probe.
- Automatic targeting was understandable with the two labeled stationary fixtures because the threatened target received the indicator and health changed in 20-point steps.
- The temporary `Shot fired` status is readable but repetitive and does not explain why a particular threat won priority without looking at the target indicator. This is a known presentation limitation, not a balance-tuning change.

### Defect and exact fix

One reproducible LK-0207 defect was found: `WeaponController` accepted under-specified server presentation tables when only a kind and one local field were present. The narrow fix validates complete required identity, configured weapon, and finite timestamp fields before presenting. A regression fixture now proves that a malformed disclosure naming a real fixture does not create a highlight.

The Studio harness was also adjusted from 200 to 1000 fixture health and from an initially loaded magazine to an empty one. This is test setup only: it keeps fixtures observable after slow local client startup and makes reload timing explicit. It does not change `FirearmConfig` or production balance.

### Known limitations

- This was a two-client, single-machine Studio loopback test; it does not measure internet latency, packet loss, adverse frame rate, mobile/console input, or production load.
- Stationary fixtures are not enemy AI, hostile discovery, pathfinding, production spawning, waves, or a permanent enemy architecture.
- Harness visibility, line of sight, threat, and obstruction are controlled server-owned facts. No production visibility provider or raycast filter is claimed.
- Harness health and processed ShotIds are server-owned only for the Studio session. P3 production health ownership and long-lived deduplication remain unimplemented.
- Same-server client rejoin could not be driven after the closed Studio client window; cleanup was directly observed and repeated clean sessions proved fresh join state. The harness’s `PlayerAdded` and `PlayerRemoving` paths remain deterministic source/fixture boundaries.
- Existing Roblox Studio platform messages remain environment noise; no new Living Kingdoms-originated warning/error appeared.

At the time of this LK-0207 record, P2 was complete and P3 had not started.

## LK-0305 operative life runtime validation

- Environment: Windows 11, Roblox Studio two-client local Server & Clients session, Rojo 7.7.0 at `localhost:34872`.
- Final clean server started once with no Living Kingdoms error. Both players read `Alive`, health `100`, revision `0` from the server-VM Studio-only bindable controls.
- Alive control remained available: a client movement probe displaced Player1, and one explicit reload produced exactly 12 accepted shots (`1000` to `760` fixture health).
- A server-only pure-resolver transition committed Player1 to `Incapacitated`, health `0`, revision `1`, and `WalkSpeed 0`; the same 60-frame movement-intent probe produced `0` displacement. Player2 remained `Alive 100`, revision `0`, with `WalkSpeed 16`. Reload/fire while down did not change fixture health.
- A server-only accepted revive committed Player1 to `Alive`, health `30`, revision `2`, with `WalkSpeed 16`. A one-stud client displacement remained accepted. No ammunition appeared automatically; after an explicit reload, the preserved second 12-round reserve magazine fired normally (`760` to `520`).
- A server-only death transition followed by `Player:LoadCharacter()` left Player1 `Dead`, health `0`, revision `4`; the character instance changed, its authoritative restriction remained `WalkSpeed 0`, Humanoid health remained a non-authoritative positive shell, and `Players.CharacterAutoLoads` remained `false`.
- A client command attempted to set Humanoid health and WalkSpeed. The server still read `Dead`, health `0`, revision `4`, and `WalkSpeed 0`. No life-state RemoteEvent or client transition surface existed.

The live pass found and fixed two integration defects before the final run: Studio command-bar requires use a separate module cache, so the development controls now use Studio-only `BindableFunction` instances in `ServerStorage`; and zero-loaded readiness now returns to the existing P2 `Ready` convention after revival so reload is eligible without refilling ammunition. LK-0306 remains unstarted.

## LK-0307 squad-failure validation

A two-client Server & Clients session used the Studio-only `ServerStorage.LK0305OperativeLifeDevelopment` controls. The server began the explicit operation with two registered participants and reported `Viable` with multiplayer history. Incapacitating Player1 kept `Viable`; incapacitating Player2 changed the squad to `Pending`, and the stored deadline delta printed exactly `3`. A callback requested for `2.999` seconds woke just after the deadline under Studio scheduling, so the server committed `Failed`; its attempted Alive restoration did not undo committed failure. This live boundary exposed and prompted a fix to pure transition precedence so an evaluation exactly at the deadline commits before considering restored viability. Focused fixtures prove cancellation at `2.999`, cleared timing, fresh full grace, and exact-deadline failure deterministically.

The existing live character-authority probes confirm that replacement-character or Humanoid/client-attribute changes are not squad facts. Focused runtime fixtures verify that late registrations are not admitted after explicit operation start, disconnect removes the copied operative snapshot, and zero-connected abandonment enters failure grace. The source audit confirms that `default.project.json` contains no client-accessible squad-failure mutation remote. The isolated controls are Studio-only `BindableFunction` instances under `ServerStorage` and are absent in production.

## LK-0308 P3 integration, security, and regression validation

A clean two-client Server & Clients session explicitly began with two admitted players. Both started `Alive 100`, revision `0`, with independent combat state and a `Viable` squad. Ordinary nonlethal damage left Player1 Alive; lethal ordinary damage produced `Incapacitated 0`, disabled movement/combat, and left Player2 and squad viability unaffected. The reviver entered the server-derived eight-stud boundary through existing movement authority. Begin produced server-derived progress, release removed the session, and retry restarted from zero. Movement, accepted reviver damage, and a server-observed line-of-sight obstruction each cancelled and reset the hold. Focused fixtures cover out-of-range, disconnect, life-state changes, single-target ownership, duplicate request non-acceleration, and teardown deterministically.

One uninterrupted actual-client hold completed after four seconds. Player1 returned to `Alive 30`; movement and combat returned; loaded/reserve ammunition, cadence, and processed ShotIds remained preserved; reload and selected target were clear; and no invulnerability was granted. A later incapacitation naturally crossed its stored 30-second deadline and became Dead. Character replacement remained `Dead 0` and restricted. In a clean finishing case, server-created finishing damage immediately transitioned an Incapacitated operative to Dead; repeating the event left the revision unchanged. Ordinary damage continued to stop at Incapacitated. With both operatives nonviable, the squad entered Pending and committed terminal Failed; deterministic fixtures cover pre-deadline cancellation, a fresh full grace, exact-deadline commitment, and late-registration/replacement resistance.

Actual client spoof probes returned `MalformedPayload` for extra fields, `SelfTarget`, `HiddenOrUnregisteredTarget`, and `StalePhase`. Client writes to disclosed attributes and Humanoid health did not change either authoritative snapshot. Source and fixture audits additionally cover missing/wrong fields, non-finite and cross-operative identities, sender-derived identity, rate limiting, copied disclosure, no timer acceleration, and the absence of any client damage, death, recovery, or failure declaration surface. Camera stayed attached to each local operative with no free spectating or teammate cycling; repeated bootstrap, replacement, client isolation, and teardown checks produced no Living Kingdoms runtime error.

A separate clean one-client operation created one pending solo recovery on first incapacitation and kept the squad Viable. Before eight seconds it remained Incapacitated. The Studio-only deadline-forward control then evaluated the exact stored production deadline through the normal resolver/commit path, returning the operative to `Alive 30` without refilling ammunition and consuming the allowance. A second incapacitation created no recovery deadline, entered Pending, and committed Failed after the three-second grace.

The Studio run was local loopback. Tool interaction overhead prevented a new live visual observation strictly before the multiplayer three-second failure deadline, and a two-client topology cannot stage two simultaneous revivers; deterministic automated fixtures provide those boundary and ownership results. Internet latency, packet loss, mobile/console input, and production load remain unmeasured. P3 is complete; P4 remains unstarted.
