--!strict

--[[
	BA-014: the repeatable Main World Studio acceptance matrix.

	This file turns BA-010's Studio review checklist and BA-013's provisional
	budgets into named, measurable checks with explicit thresholds, capture
	modes, device profiles, and evidence artifacts.

	It records the *definition* of acceptance only. Every check ships as
	`NotRun`: nothing here asserts that the Main World has been captured,
	measured, or accepted, and nothing here activates geometry, streaming,
	lighting, audio, placement, or any Main World runtime.
]]

local MainWorldRepresentationConfig = require(script.Parent.MainWorldRepresentationConfig)

local RESULT_NOT_RUN = "NotRun"

-- Result vocabulary for a recorded run of this matrix. `Blocked` covers an
-- evidence-transport failure (the check never observed the build) and is
-- deliberately distinct from `Fail`, which is a real observed defect.
local ResultStatuses = table.freeze({
	NotRun = RESULT_NOT_RUN,
	Pass = "Pass",
	Fail = "Fail",
	Blocked = "Blocked",
	Invalid = "Invalid",
})

-- Identity fields every recorded run must carry before any result is read as
-- evidence. A capture missing one of these is `Invalid`, not `Pass`.
local RequiredRunIdentityFields = table.freeze({
	"captureDateAndTimezone",
	"operator",
	"repositoryCommit",
	"rojoVersion",
	"studioVersion",
	"placeFileName",
	"placeArtifactSha256",
	"mainWorldPlaceIdentity",
	"serverAndClientCount",
	"deviceProfileId",
	"graphicsQualityLevel",
	"featureFlagState",
	"rollbackCheckpointCommit",
})

local Categories = table.freeze({
	ArrivalAndFlow = "ArrivalAndFlow",
	NavigationAndComposition = "NavigationAndComposition",
	LandmarkAndReadability = "LandmarkAndReadability",
	VisualEnvironment = "VisualEnvironment",
	Audio = "Audio",
	StreamingAndLifecycle = "StreamingAndLifecycle",
	PerformanceAndMemory = "PerformanceAndMemory",
})

-- How a check is decided. `RecordOnly` checks produce required evidence but
-- have no pass/fail line yet; they may not be cited as acceptance.
local Classifications = table.freeze({
	Threshold = "Threshold",
	Binary = "Binary",
	RecordOnly = "RecordOnly",
})

-- Provenance keeps invented numbers visibly separate from inherited ones.
-- `Ba014AuthoringTarget` values are unmeasured starting lines that the first
-- recorded run is expected to revise.
local ThresholdProvenance = table.freeze({
	Ba010Checklist = "ba-010-checklist",
	Ba013Provisional = "ba-013-provisional",
	Ba014AuthoringTarget = "ba-014-authoring-target",
})

local Thresholds = table.freeze({
	OrientationRecognitionSeconds = table.freeze({
		value = 10,
		unit = "seconds",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba010Checklist,
	}),
	SimultaneousArrivalPlayers = table.freeze({
		value = 4,
		unit = "players",
		comparison = "at-least",
		provenance = ThresholdProvenance.Ba010Checklist,
	}),
	PreparationLoopSeconds = table.freeze({
		value = 60,
		unit = "seconds",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba014AuthoringTarget,
	}),
	DeadTravelSegmentSeconds = table.freeze({
		value = 8,
		unit = "seconds",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba014AuthoringTarget,
	}),
	DesktopFullMedianFrameMs = table.freeze({
		value = 16.7,
		unit = "milliseconds",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba013Provisional,
	}),
	DesktopFullP95FrameMs = table.freeze({
		value = 25.0,
		unit = "milliseconds",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba013Provisional,
	}),
	MobileMinimumReadableP95FrameMs = table.freeze({
		value = 33.3,
		unit = "milliseconds",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba013Provisional,
	}),
	PostWarmupStreamingHitchMs = table.freeze({
		value = 100,
		unit = "milliseconds",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba013Provisional,
	}),
	CleanupDriftPercent = table.freeze({
		value = 5,
		unit = "percent-of-post-load-baseline",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba013Provisional,
	}),
	TraversalCycleMinutes = table.freeze({
		value = 10,
		unit = "minutes",
		comparison = "at-least",
		provenance = ThresholdProvenance.Ba013Provisional,
	}),
	WarmupSeconds = table.freeze({
		value = 30,
		unit = "seconds",
		comparison = "at-least",
		provenance = ThresholdProvenance.Ba014AuthoringTarget,
	}),
	SteadyCaptureSeconds = table.freeze({
		value = 60,
		unit = "seconds",
		comparison = "at-least",
		provenance = ThresholdProvenance.Ba014AuthoringTarget,
	}),
	StaticReplicationChurnPerMinute = table.freeze({
		value = 0,
		unit = "replicated-property-writes-per-minute",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba013Provisional,
	}),
	CharacterReleaseBeforeRequiredContent = table.freeze({
		value = 0,
		unit = "occurrences",
		comparison = "at-most",
		provenance = ThresholdProvenance.Ba013Provisional,
	}),
	ReadableChannelsPerMajorDestination = table.freeze({
		value = 2,
		unit = "independent-channels",
		comparison = "at-least",
		provenance = ThresholdProvenance.Ba010Checklist,
	}),
})

-- Ambient presentation ceilings visible to one client, carried forward from
-- BA-013. These bound optional atmosphere only; they never bound combat
-- telegraphs or canonical gameplay state.
local QualityTiers = table.freeze({
	table.freeze({
		id = "Full",
		intent = "approved-composition",
		ceilings = table.freeze({
			visibleEnabledLocalDynamicLights = 16,
			visibleShadowCastingLocalLights = 1,
			visibleAmbientParticleEmitters = 12,
			estimatedLiveAmbientParticles = 300,
			clientAnimatedDecorativeParts = 32,
			audibleLocalizedEnvironmentEmitters = 4,
			steadyStateAmbientBeds = 1,
			steadyStateMusicBeds = 1,
		}),
	}),
	table.freeze({
		id = "Reduced",
		intent = "at-most-60-percent-tier-c-density-and-earlier-lod",
		ceilings = table.freeze({
			visibleEnabledLocalDynamicLights = 8,
			visibleShadowCastingLocalLights = 0,
			visibleAmbientParticleEmitters = 6,
			estimatedLiveAmbientParticles = 120,
			clientAnimatedDecorativeParts = 16,
			audibleLocalizedEnvironmentEmitters = 2,
			steadyStateAmbientBeds = 1,
			steadyStateMusicBeds = 1,
		}),
	}),
	table.freeze({
		id = "MinimumReadable",
		intent = "silhouettes-route-edges-interaction-forms-collision-and-semantic-cues-retained",
		ceilings = table.freeze({
			visibleEnabledLocalDynamicLights = 4,
			visibleShadowCastingLocalLights = 0,
			visibleAmbientParticleEmitters = 0,
			estimatedLiveAmbientParticles = 0,
			clientAnimatedDecorativeParts = 0,
			audibleLocalizedEnvironmentEmitters = 1,
			steadyStateAmbientBeds = 1,
			steadyStateMusicBeds = 0,
		}),
	}),
})

local DeviceProfiles = table.freeze({
	table.freeze({
		id = "DesktopReference",
		qualityTierId = "Full",
		hardwareIdentityStatus = "recorded-per-run-never-assumed",
		graphicsLevelStatus = "recorded-per-run-never-assumed",
	}),
	table.freeze({
		id = "LowGraphicsDesktop",
		qualityTierId = "Reduced",
		hardwareIdentityStatus = "recorded-per-run-never-assumed",
		graphicsLevelStatus = "recorded-per-run-never-assumed",
	}),
	table.freeze({
		id = "MobileMinimum",
		qualityTierId = "MinimumReadable",
		hardwareIdentityStatus = "recorded-per-run-never-assumed",
		graphicsLevelStatus = "recorded-per-run-never-assumed",
	}),
})

-- The same fixed cameras are reused across every quality tier so tier
-- captures are comparable. Camera transforms are assigned when the composition
-- exists; they are not invented here.
local FixedCameras = table.freeze({
	table.freeze({ id = "camera.arrival_threshold", compositionBeat = "ArrivalThreshold" }),
	table.freeze({ id = "camera.orientation_center", compositionBeat = "OrientationCenter" }),
	table.freeze({ id = "camera.preparation_ring", compositionBeat = "PreparationRing" }),
	table.freeze({ id = "camera.interaction_edge", compositionBeat = "InteractionEdge" }),
	table.freeze({ id = "camera.adventure_gate", compositionBeat = "AdventureGate" }),
	table.freeze({ id = "camera.exploration_branch", compositionBeat = "ExplorationBranch" }),
	table.freeze({ id = "camera.return_seam", compositionBeat = "ReturnSeam" }),
})

local CaptureModes = table.freeze({
	table.freeze({ id = "capture.neutral_editor", qualityTierId = "Full", aspect = "editor" }),
	table.freeze({ id = "capture.gameplay_full", qualityTierId = "Full", aspect = "desktop-16x9" }),
	table.freeze({ id = "capture.gameplay_reduced", qualityTierId = "Reduced", aspect = "desktop-16x9" }),
	table.freeze({ id = "capture.gameplay_minimum", qualityTierId = "MinimumReadable", aspect = "desktop-16x9" }),
	table.freeze({
		id = "capture.mobile_minimum",
		qualityTierId = "MinimumReadable",
		aspect = "mobile-portrait-and-landscape",
	}),
})

local RecognitionDistancesStuds = table.freeze({ near = 32, mid = 128, far = 512 })

local EvidenceArtifacts = table.freeze({
	FixedCameraCaptureSet = "fixed-camera-capture-set",
	TimedTraversalLog = "timed-traversal-log",
	ConsoleOutputCapture = "console-output-capture",
	InstanceCensus = "instance-census-by-root-and-class",
	MicroProfilerCapture = "microprofiler-capture",
	MemoryCategoryCapture = "memory-category-capture",
	NetworkReceiveCapture = "network-receive-capture",
	FrameTimeSeries = "frame-time-series",
	AudioSessionRecording = "audio-session-recording",
	AssetPermissionRecord = "asset-permission-record",
	StreamingTransitionLog = "streaming-transition-log",
	VideoWalkthrough = "video-walkthrough",
})

local ALL_STREAMING_GROUPS = table.freeze({
	"main_world.hub_core",
	"main_world.primary_route",
	"main_world.resources",
	"main_world.structures",
	"main_world.atmosphere",
})

type Check = {
	id: string,
	category: string,
	title: string,
	requirement: string,
	measurement: string,
	classification: string,
	thresholdKeys: { string },
	qualityCeilingKeys: { string },
	captureModeIds: { string },
	deviceProfileIds: { string },
	evidenceArtifactIds: { string },
	streamingGroupIds: { string },
	hubAnchorIds: { string },
	blocking: boolean,
	status: string,
}

local checks: { Check } = {
	-- Arrival and flow ----------------------------------------------------
	table.freeze({
		id = "mwam.arrival.destination_matrix",
		category = Categories.ArrivalAndFlow,
		title = "Every arrival cause lands at its intended anchor and facing",
		requirement = "Cold join, respawn, operation success, operation failure and replay decline each place the player at the intended arrival or return anchor with the intended facing.",
		measurement = "Run each of the five causes once per session and record landing anchor, position, facing and any ambiguity between safety and production spawns.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.VideoWalkthrough,
			EvidenceArtifacts.ConsoleOutputCapture,
		}),
		streamingGroupIds = table.freeze({ "main_world.hub_core" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.arrival.four_player_simultaneous",
		category = Categories.ArrivalAndFlow,
		title = "Four players arrive simultaneously without overlap or congestion",
		requirement = "Four players spawn at once with no overlap, fall-through, blocked camera or prompt contention.",
		measurement = "Start a four-client session, spawn simultaneously and record overlap, fall events, camera obstruction and competing prompts.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "SimultaneousArrivalPlayers" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.VideoWalkthrough,
			EvidenceArtifacts.FixedCameraCaptureSet,
		}),
		streamingGroupIds = table.freeze({ "main_world.hub_core" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.arrival.orientation_recognition",
		category = Categories.ArrivalAndFlow,
		title = "Orientation landmark and adventure direction are identified from the gameplay camera",
		requirement = "A player who has not seen the composition identifies the orientation landmark and the adventure direction from the gameplay camera without opening a menu.",
		measurement = "Time from character control to a spoken correct identification of both, recorded per tester and per quality tier.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "OrientationRecognitionSeconds" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({
			"capture.gameplay_full",
			"capture.gameplay_reduced",
			"capture.gameplay_minimum",
		}),
		deviceProfileIds = table.freeze({ "DesktopReference", "LowGraphicsDesktop", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.VideoWalkthrough,
			EvidenceArtifacts.TimedTraversalLog,
		}),
		streamingGroupIds = table.freeze({ "main_world.hub_core" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.arrival.preparation_reachability",
		category = Categories.ArrivalAndFlow,
		title = "Every enabled preparation anchor is reachable without a dead end",
		requirement = "Class, loadout and expedition preparation anchors are reachable from arrival without dead ends or unclear backtracking; held anchors are absent rather than broken.",
		measurement = "Walk to each enabled anchor from arrival and record path clarity, backtracking and any prompt that opens no surface.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.TimedTraversalLog,
			EvidenceArtifacts.VideoWalkthrough,
		}),
		streamingGroupIds = table.freeze({ "main_world.hub_core" }),
		hubAnchorIds = table.freeze({
			"hub.anchor.class_assignment",
			"hub.anchor.weapon_loadout",
			"hub.anchor.expedition_terminal",
		}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.arrival.return_debrief_context",
		category = Categories.ArrivalAndFlow,
		title = "Return exposes result, reward and replay context",
		requirement = "The return seam presents result, reward and replay context and does not read as a fresh unexplained spawn.",
		measurement = "Complete one success and one failure return and record what result/reward/replay information is visible without opening a menu.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.VideoWalkthrough,
			EvidenceArtifacts.FixedCameraCaptureSet,
		}),
		streamingGroupIds = table.freeze({ "main_world.hub_core" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.arrival.character_release_gating",
		category = Categories.ArrivalAndFlow,
		title = "Character release waits for required arrival content",
		requirement = "No character is released before the hub-core collision, orientation landmark and required interaction forms exist; no visible void or fall-through occurs at arrival.",
		measurement = "Count occurrences of character control granted before required content is present across repeated cold joins under a cold content cache.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "CharacterReleaseBeforeRequiredContent" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full", "capture.mobile_minimum" }),
		deviceProfileIds = table.freeze({ "DesktopReference", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.StreamingTransitionLog,
			EvidenceArtifacts.ConsoleOutputCapture,
		}),
		streamingGroupIds = table.freeze({ "main_world.hub_core" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),

	-- Navigation and composition -------------------------------------------
	table.freeze({
		id = "mwam.navigation.core_loop_traversal",
		category = Categories.NavigationAndComposition,
		title = "The core preparation loop stays compact",
		requirement = "Arrival to orientation center to each preparation surface to the adventure gate and back to the return seam is a compact repeatable loop.",
		measurement = "Walk the ordered route at default speed and record segment and total durations.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "PreparationLoopSeconds" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.TimedTraversalLog }),
		streamingGroupIds = table.freeze({ "main_world.hub_core", "main_world.primary_route" }),
		hubAnchorIds = table.freeze({}),
		blocking = false,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.navigation.dead_travel",
		category = Categories.NavigationAndComposition,
		title = "No long segment without a decision, landmark or interaction",
		requirement = "No traversal segment runs longer than the dead-travel target without a decision, landmark, discovery or interaction.",
		measurement = "Segment the walked route and record the duration of each stretch that offers none of those.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "DeadTravelSegmentSeconds" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.TimedTraversalLog }),
		streamingGroupIds = table.freeze({ "main_world.primary_route" }),
		hubAnchorIds = table.freeze({}),
		blocking = false,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.navigation.multiplayer_congestion",
		category = Categories.NavigationAndComposition,
		title = "Four-player congestion points are recorded",
		requirement = "Congestion points where four players cannot pass, inspect a station or read a prompt are enumerated with locations.",
		measurement = "Move a four-player group through every entrance, station and gate and record each congestion location and cause.",
		classification = Classifications.RecordOnly,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.VideoWalkthrough,
			EvidenceArtifacts.TimedTraversalLog,
		}),
		streamingGroupIds = table.freeze({ "main_world.hub_core" }),
		hubAnchorIds = table.freeze({}),
		blocking = false,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.navigation.boundary_and_metrics",
		category = Categories.NavigationAndComposition,
		title = "Boundaries, stairs and camera behave as authored geography",
		requirement = "Boundaries read as authored geography, stairs and ramps are traversable at default movement, and no false cover, invisible blocker or camera clip occurs on the core loop.",
		measurement = "Traverse boundaries, every stair and ramp, and every tight interior with the gameplay camera; record each defect location.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.VideoWalkthrough,
			EvidenceArtifacts.FixedCameraCaptureSet,
		}),
		streamingGroupIds = table.freeze({ "main_world.hub_core", "main_world.structures" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.navigation.optional_branch_payoff",
		category = Categories.NavigationAndComposition,
		title = "Optional branches pay off and loop back",
		requirement = "Each optional branch reaches a discovery, view, resource or future entrance and reconnects without long empty return travel.",
		measurement = "Walk every optional branch and record its payoff and its return path length.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.TimedTraversalLog }),
		streamingGroupIds = table.freeze({ "main_world.primary_route", "main_world.resources" }),
		hubAnchorIds = table.freeze({}),
		blocking = false,
		status = RESULT_NOT_RUN,
	}),

	-- Landmark and readability ---------------------------------------------
	table.freeze({
		id = "mwam.readability.landmark_recognition_distance",
		category = Categories.LandmarkAndReadability,
		title = "Landmarks are recognizable at near, mid and far distance in every tier",
		requirement = "Each major landmark is identifiable at the near, mid and far recognition distances at Full, Reduced and Minimum-readable quality.",
		measurement = "Capture each landmark from the three recognition distances in each tier and record correct identification.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({
			"capture.gameplay_full",
			"capture.gameplay_reduced",
			"capture.gameplay_minimum",
			"capture.mobile_minimum",
		}),
		deviceProfileIds = table.freeze({ "DesktopReference", "LowGraphicsDesktop", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.FixedCameraCaptureSet }),
		streamingGroupIds = table.freeze({ "main_world.structures", "main_world.hub_core" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.readability.independent_channels",
		category = Categories.LandmarkAndReadability,
		title = "Major destinations read through at least two independent channels",
		requirement = "Every major destination is recognizable through at least two of silhouette, path alignment, signage, light, audio and UI fallback, and no critical cue depends on color alone.",
		measurement = "For each destination record which channels are present, then re-verify recognition with a color-vision simulation applied.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "ReadableChannelsPerMajorDestination" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full", "capture.gameplay_minimum" }),
		deviceProfileIds = table.freeze({ "DesktopReference", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.FixedCameraCaptureSet }),
		streamingGroupIds = table.freeze({ "main_world.hub_core", "main_world.structures" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.readability.cues_under_atmosphere",
		category = Categories.LandmarkAndReadability,
		title = "Route, prompt and objective cues survive fog, bloom and particles",
		requirement = "Route edges, interaction prompts, hostile silhouettes and objective markers remain readable against the active fog, bloom, particle and landmark-lighting composition.",
		measurement = "Capture each fixed camera with the atmosphere profile active and record any cue lost to bloom, fog or particle overdraw.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({
			"capture.gameplay_full",
			"capture.gameplay_reduced",
			"capture.gameplay_minimum",
		}),
		deviceProfileIds = table.freeze({ "DesktopReference", "LowGraphicsDesktop", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.FixedCameraCaptureSet }),
		streamingGroupIds = table.freeze({ "main_world.atmosphere" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.readability.minimum_tier_preserves_meaning",
		category = Categories.LandmarkAndReadability,
		title = "Minimum-readable removes cost, never meaning",
		requirement = "Minimum-readable quality retains landmark silhouettes, route edges, interaction forms, collision truth and semantic cues, and changes no server-authored state.",
		measurement = "Compare the Minimum-readable capture set against Full for every fixed camera and confirm each retained element and unchanged collision or interaction eligibility.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full", "capture.gameplay_minimum" }),
		deviceProfileIds = table.freeze({ "DesktopReference", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.FixedCameraCaptureSet,
			EvidenceArtifacts.InstanceCensus,
		}),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),

	-- Visual environment ----------------------------------------------------
	table.freeze({
		id = "mwam.visual.fixed_camera_capture_set",
		category = Categories.VisualEnvironment,
		title = "The complete fixed-camera capture set exists for the run",
		requirement = "Every fixed camera is captured in every capture mode for the recorded build, so tier and run comparisons are possible at all.",
		measurement = "Produce one image per fixed camera per capture mode and attach them to the run's evidence packet.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({
			"capture.neutral_editor",
			"capture.gameplay_full",
			"capture.gameplay_reduced",
			"capture.gameplay_minimum",
			"capture.mobile_minimum",
		}),
		deviceProfileIds = table.freeze({ "DesktopReference", "LowGraphicsDesktop", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.FixedCameraCaptureSet }),
		streamingGroupIds = table.freeze({}),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.visual.geometry_defects",
		category = Categories.VisualEnvironment,
		title = "No terrain seam, floating prop or scale break survives review",
		requirement = "Terrain seams, floating or sunken props, silhouette collisions, scale inconsistency and adjacent signature-cluster repetition are absent from the reviewed composition.",
		measurement = "Review every fixed camera and the walked route for each defect class and record location and severity.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.neutral_editor", "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.FixedCameraCaptureSet }),
		streamingGroupIds = table.freeze({ "main_world.structures", "main_world.resources" }),
		hubAnchorIds = table.freeze({}),
		blocking = false,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.visual.environment_profile_ownership",
		category = Categories.VisualEnvironment,
		title = "One environment profile owns global lighting across transitions",
		requirement = "Day/night state, corruption tiers and expedition entry/exit leave global Lighting owned by exactly one profile, with remembered values restored and no competing writer.",
		measurement = "Enter and exit the expedition space repeatedly across day/night and corruption states, sampling the owned Lighting properties before, during and after each transition.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.ConsoleOutputCapture,
			EvidenceArtifacts.FixedCameraCaptureSet,
		}),
		streamingGroupIds = table.freeze({ "main_world.atmosphere" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.visual.ambient_ceilings",
		category = Categories.VisualEnvironment,
		title = "Visible ambient cost stays inside its tier ceiling",
		requirement = "Visible enabled dynamic lights, shadow-casting lights, ambient emitters, estimated live particles and client-animated decorative parts stay within the ceiling for the active quality tier.",
		measurement = "At each fixed camera, count each ambient class visible to one client with the full UI active and compare to the tier ceiling.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({
			"visibleEnabledLocalDynamicLights",
			"visibleShadowCastingLocalLights",
			"visibleAmbientParticleEmitters",
			"estimatedLiveAmbientParticles",
			"clientAnimatedDecorativeParts",
		}),
		captureModeIds = table.freeze({
			"capture.gameplay_full",
			"capture.gameplay_reduced",
			"capture.gameplay_minimum",
		}),
		deviceProfileIds = table.freeze({ "DesktopReference", "LowGraphicsDesktop", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.InstanceCensus }),
		streamingGroupIds = table.freeze({ "main_world.atmosphere" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),

	-- Audio -----------------------------------------------------------------
	table.freeze({
		id = "mwam.audio.asset_permission",
		category = Categories.Audio,
		title = "Every environment audio asset is permission-verified",
		requirement = "Every ambient bed, music region and localized emitter uses an asset whose ownership and usage permission is verified and recorded before its ID enters source.",
		measurement = "For each asset ID, record source, permission basis, loudness review and verified load in Studio.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.AssetPermissionRecord }),
		streamingGroupIds = table.freeze({ "main_world.atmosphere" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.audio.crossfade_and_reentry",
		category = Categories.Audio,
		title = "Zone crossfades survive rapid re-entry without stacking",
		requirement = "Rapid audio-zone boundary re-entry produces no pop, no stacked bed beyond a brief crossfade and no unintended silence; steady-state bed counts stay within the tier ceiling.",
		measurement = "Cross each zone boundary repeatedly at speed while recording audio and counting simultaneously playing beds and emitters.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({
			"audibleLocalizedEnvironmentEmitters",
			"steadyStateAmbientBeds",
			"steadyStateMusicBeds",
		}),
		captureModeIds = table.freeze({ "capture.gameplay_full", "capture.mobile_minimum" }),
		deviceProfileIds = table.freeze({ "DesktopReference", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.AudioSessionRecording,
			EvidenceArtifacts.InstanceCensus,
		}),
		streamingGroupIds = table.freeze({ "main_world.atmosphere" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.audio.mix_review",
		category = Categories.Audio,
		title = "Hub, interaction, transition and debrief mix is reviewed",
		requirement = "The hub social mix, interaction cues, portal/expedition transition and return/debrief mix are reviewed together rather than per asset.",
		measurement = "Record one continuous session covering all four moments and review levels and masking.",
		classification = Classifications.RecordOnly,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.AudioSessionRecording }),
		streamingGroupIds = table.freeze({ "main_world.atmosphere" }),
		hubAnchorIds = table.freeze({}),
		blocking = false,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.audio.accessibility",
		category = Categories.Audio,
		title = "No critical fact is audio-only",
		requirement = "Environment volume is separately controllable, every critical audio cue has a visual or text alternative, and speech and cues remain intelligible on a mobile speaker.",
		measurement = "Mute environment audio and confirm every critical fact remains available, then repeat the core loop on a mobile speaker at default volume.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full", "capture.mobile_minimum" }),
		deviceProfileIds = table.freeze({ "DesktopReference", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.AudioSessionRecording,
			EvidenceArtifacts.VideoWalkthrough,
		}),
		streamingGroupIds = table.freeze({ "main_world.atmosphere" }),
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),

	-- Streaming and lifecycle ------------------------------------------------
	table.freeze({
		id = "mwam.streaming.semantic_group_rebind",
		category = Categories.StreamingAndLifecycle,
		title = "Every semantic group streams out and rebinds by stable ID",
		requirement = "Each semantic streaming group can stream out and back in, and its presentation, effects and sounds release references on stream-out and rebind by stable ID on stream-in.",
		measurement = "Leave and re-enter each group's radius and record rebind success, orphaned instances, duplicated effects and retained connections.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.StreamingTransitionLog,
			EvidenceArtifacts.InstanceCensus,
		}),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.streaming.no_completion_on_stream_out",
		category = Categories.StreamingAndLifecycle,
		title = "Stream-out never completes or cancels semantic state",
		requirement = "Streaming a group out suspends the local surface only; it does not complete, cancel or mutate an interaction, discovery, route target or return destination, and HUD fallback still names an absent target.",
		measurement = "For each semantic target, stream it out mid-approach and verify the server-side state and HUD fallback are unchanged.",
		classification = Classifications.Binary,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.StreamingTransitionLog,
			EvidenceArtifacts.ConsoleOutputCapture,
		}),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.streaming.hitch_budget",
		category = Categories.StreamingAndLifecycle,
		title = "No post-warmup streaming hitch exceeds the budget",
		requirement = "After warmup, no streaming transition produces a frame longer than the hitch budget and no visible void appears during traversal.",
		measurement = "Traverse the route at default speed after the warmup period and record the longest frame at each transition.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "PostWarmupStreamingHitchMs", "WarmupSeconds" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full", "capture.mobile_minimum" }),
		deviceProfileIds = table.freeze({ "DesktopReference", "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.FrameTimeSeries,
			EvidenceArtifacts.StreamingTransitionLog,
		}),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.lifecycle.cleanup_drift",
		category = Categories.StreamingAndLifecycle,
		title = "A full traversal and return cycle returns to baseline",
		requirement = "After the traversal-and-return cycle, environment-owned instances, connections, sounds, emitters and memory return to within the drift allowance of the stable post-load baseline.",
		measurement = "Record the post-load baseline, run the cycle, force cleanup and re-record each counter.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "CleanupDriftPercent", "TraversalCycleMinutes" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.InstanceCensus,
			EvidenceArtifacts.MemoryCategoryCapture,
		}),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),

	-- Performance and memory --------------------------------------------------
	table.freeze({
		id = "mwam.performance.desktop_full_traversal",
		category = Categories.PerformanceAndMemory,
		title = "Desktop Full traversal meets its frame-time targets",
		requirement = "During steady traversal at Full quality with UI and audio active, desktop median and p95 client frame time meet their targets.",
		measurement = "Capture a steady traversal window after warmup and report median and p95 client frame time with the MicroProfiler labels used.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({
			"DesktopFullMedianFrameMs",
			"DesktopFullP95FrameMs",
			"WarmupSeconds",
			"SteadyCaptureSeconds",
		}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.FrameTimeSeries,
			EvidenceArtifacts.MicroProfilerCapture,
		}),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.performance.mobile_minimum_traversal",
		category = Categories.PerformanceAndMemory,
		title = "Lowest supported mobile meets its Minimum-readable target",
		requirement = "During steady traversal at Minimum-readable quality on the lowest supported mobile device, p95 client frame time meets its target.",
		measurement = "Repeat the steady traversal capture on the recorded mobile device and report p95 client frame time.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({
			"MobileMinimumReadableP95FrameMs",
			"WarmupSeconds",
			"SteadyCaptureSeconds",
		}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.mobile_minimum" }),
		deviceProfileIds = table.freeze({ "MobileMinimum" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.FrameTimeSeries,
			EvidenceArtifacts.MemoryCategoryCapture,
		}),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.performance.four_player_census",
		category = Categories.PerformanceAndMemory,
		title = "Four-player join and traversal cost is censused",
		requirement = "Server and client instance counts by root and class, client and server memory, render cost and network receive are recorded for a four-player join and traversal.",
		measurement = "Capture each counter at join, at steady traversal and at the four-player hub gathering.",
		classification = Classifications.RecordOnly,
		thresholdKeys = table.freeze({}),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({
			EvidenceArtifacts.InstanceCensus,
			EvidenceArtifacts.MemoryCategoryCapture,
			EvidenceArtifacts.NetworkReceiveCapture,
		}),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = false,
		status = RESULT_NOT_RUN,
	}),
	table.freeze({
		id = "mwam.performance.static_replication_churn",
		category = Categories.PerformanceAndMemory,
		title = "Loaded static content stops replicating",
		requirement = "Once a semantic group is loaded, its static content produces no continuing replicated property writes.",
		measurement = "Sample replicated property writes attributed to each loaded group over a steady window and report the per-minute rate.",
		classification = Classifications.Threshold,
		thresholdKeys = table.freeze({ "StaticReplicationChurnPerMinute", "SteadyCaptureSeconds" }),
		qualityCeilingKeys = table.freeze({}),
		captureModeIds = table.freeze({ "capture.gameplay_full" }),
		deviceProfileIds = table.freeze({ "DesktopReference" }),
		evidenceArtifactIds = table.freeze({ EvidenceArtifacts.NetworkReceiveCapture }),
		streamingGroupIds = ALL_STREAMING_GROUPS,
		hubAnchorIds = table.freeze({}),
		blocking = true,
		status = RESULT_NOT_RUN,
	}),
}

local MainWorldAcceptanceMatrixConfig = {
	Version = "BA-014-v1",
	RuntimeEnabled = false,
	MatrixExecuted = false,
	EvidenceLevel = "E1",
	ResultStatuses = ResultStatuses,
	Categories = Categories,
	Classifications = Classifications,
	ThresholdProvenance = ThresholdProvenance,
	RequiredRunIdentityFields = RequiredRunIdentityFields,
	Thresholds = Thresholds,
	QualityTiers = QualityTiers,
	DeviceProfiles = DeviceProfiles,
	FixedCameras = FixedCameras,
	CaptureModes = CaptureModes,
	RecognitionDistancesStuds = RecognitionDistancesStuds,
	EvidenceArtifacts = EvidenceArtifacts,
	Checks = table.freeze(checks),
}

local checksById: { [string]: Check } = {}
for _, check in checks do
	assert(checksById[check.id] == nil, `duplicate acceptance check id: {check.id}`)
	checksById[check.id] = check
end
MainWorldAcceptanceMatrixConfig.ChecksById = table.freeze(checksById)

function MainWorldAcceptanceMatrixConfig.checksForCategory(categoryId: string): { Check }
	local matches: { Check } = {}
	for _, check in checks do
		if check.category == categoryId then
			table.insert(matches, check)
		end
	end
	return matches
end

function MainWorldAcceptanceMatrixConfig.blockingChecks(): { Check }
	local matches: { Check } = {}
	for _, check in checks do
		if check.blocking then
			table.insert(matches, check)
		end
	end
	return matches
end

-- A run is acceptable only when every blocking check recorded `Pass`. Anything
-- else — including `NotRun` and `Blocked` — leaves activation gated.
function MainWorldAcceptanceMatrixConfig.isActivationAcceptable(): boolean
	if not MainWorldAcceptanceMatrixConfig.MatrixExecuted then
		return false
	end
	for _, check in checks do
		if check.blocking and check.status ~= ResultStatuses.Pass then
			return false
		end
	end
	return true
end

-- Module-load invariants: this matrix may never ship carrying a result, and
-- every reference it makes must resolve inside the same contract.
assert(MainWorldAcceptanceMatrixConfig.RuntimeEnabled == false, "BA-014 defines acceptance; it activates nothing")
assert(MainWorldAcceptanceMatrixConfig.MatrixExecuted == false, "BA-014 ships with no recorded run")
assert(
	MainWorldRepresentationConfig.RuntimeEnabled == false,
	"BA-014 cannot be defined against an already-activated Main World"
)
assert(MainWorldAcceptanceMatrixConfig.isActivationAcceptable() == false, "an unrun matrix can never accept activation")

local captureModeIds: { [string]: boolean } = {}
for _, mode in CaptureModes do
	local tierFound = false
	for _, tier in QualityTiers do
		if tier.id == mode.qualityTierId then
			tierFound = true
			break
		end
	end
	assert(tierFound, `capture mode {mode.id} references an unknown quality tier`)
	captureModeIds[mode.id] = true
end

local deviceProfileIds: { [string]: boolean } = {}
for _, profile in DeviceProfiles do
	deviceProfileIds[profile.id] = true
end

local streamingGroupIds: { [string]: boolean } = {}
for _, group in MainWorldRepresentationConfig.StreamingGroups do
	streamingGroupIds[group.id] = true
end
for _, groupId in ALL_STREAMING_GROUPS do
	assert(streamingGroupIds[groupId], `unknown BA-011 streaming group: {groupId}`)
end

local evidenceArtifactIds: { [string]: boolean } = {}
for _, artifactId in EvidenceArtifacts do
	evidenceArtifactIds[artifactId] = true
end

local categoryCounts: { [string]: number } = {}
for _, categoryId in Categories do
	categoryCounts[categoryId] = 0
end

for _, check in checks do
	assert(categoryCounts[check.category] ~= nil, `check {check.id} uses an unknown category`)
	categoryCounts[check.category] += 1
	assert(check.status == RESULT_NOT_RUN, `check {check.id} must ship unrun`)
	assert(#check.requirement > 0 and #check.measurement > 0, `check {check.id} needs a requirement and a measurement`)
	assert(#check.captureModeIds > 0, `check {check.id} needs at least one capture mode`)
	assert(#check.deviceProfileIds > 0, `check {check.id} needs at least one device profile`)
	assert(#check.evidenceArtifactIds > 0, `check {check.id} needs at least one evidence artifact`)

	if check.classification == Classifications.RecordOnly then
		assert(not check.blocking, `record-only check {check.id} cannot block activation`)
		assert(#check.thresholdKeys == 0, `record-only check {check.id} cannot carry a threshold`)
		assert(#check.qualityCeilingKeys == 0, `record-only check {check.id} cannot carry a tier ceiling`)
	elseif check.classification == Classifications.Threshold then
		assert(
			#check.thresholdKeys > 0 or #check.qualityCeilingKeys > 0,
			`threshold check {check.id} needs a threshold or a tier ceiling to compare against`
		)
	else
		assert(check.classification == Classifications.Binary, `check {check.id} uses an unknown classification`)
	end

	for _, thresholdKey in check.thresholdKeys do
		assert(Thresholds[thresholdKey] ~= nil, `check {check.id} references unknown threshold {thresholdKey}`)
	end
	for _, ceilingKey in check.qualityCeilingKeys do
		for _, tier in QualityTiers do
			assert(
				tier.ceilings[ceilingKey] ~= nil,
				`check {check.id} references ceiling {ceilingKey} missing from tier {tier.id}`
			)
		end
	end
	for _, modeId in check.captureModeIds do
		assert(captureModeIds[modeId], `check {check.id} references unknown capture mode {modeId}`)
	end
	for _, profileId in check.deviceProfileIds do
		assert(deviceProfileIds[profileId], `check {check.id} references unknown device profile {profileId}`)
	end
	for _, artifactId in check.evidenceArtifactIds do
		assert(evidenceArtifactIds[artifactId], `check {check.id} references unknown evidence artifact {artifactId}`)
	end
	for _, groupId in check.streamingGroupIds do
		assert(streamingGroupIds[groupId], `check {check.id} references unknown streaming group {groupId}`)
	end
end

for categoryId, count in categoryCounts do
	assert(count > 0, `acceptance category {categoryId} has no checks`)
end

for thresholdKey, threshold in Thresholds do
	assert(
		threshold.provenance == ThresholdProvenance.Ba010Checklist
			or threshold.provenance == ThresholdProvenance.Ba013Provisional
			or threshold.provenance == ThresholdProvenance.Ba014AuthoringTarget,
		`threshold {thresholdKey} needs recorded provenance`
	)
end

return table.freeze(MainWorldAcceptanceMatrixConfig)
