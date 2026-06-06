# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

RoamNotch (formerly NotchDrop) is a macOS menubar app that lives in the camera notch. It intercepts the notch area and renders interactive widgets there. The physical notch is `#000000` so the app's UI is invisible when collapsed — it extends downward on hover/click.

## Build & run

Open `NotchDrop.xcodeproj` in Xcode and run the `NotchDrop` scheme. There are no tests and no CLI build scripts. The app requires a Mac with a notch (or falls back to a simulated 150×28 notch on non-notch screens).

## Architecture

### State machine

`NotchViewModel` owns all state and is the single source of truth:

- **`Status`**: `closed → popping → opened`. `popping` is the hover-preview state (notch bumps down 4px). Mouse events in `NotchViewModel+Events.swift` drive transitions.
- **`ContentType`**: what renders inside the opened panel: `normal` (file tray), `menu`, `settings`, `roamCapture`, `focusTimer`, `systemMonitor`, `mediaPlayer`. Add new modes here. Tabs remembered across open/close are gated by `isTabContent()` — `mediaPlayer` is intentionally excluded (it's a transient auto-trigger, not a sticky tab).
- **`OpenReason`**: `click | drag | boot | unknown`. Drag always opens `.normal` (file tray). A click while music is playing jumps straight to `.mediaPlayer` (the compact HUD you clicked); otherwise click/boot restores `lastTabContent`.

### View hierarchy

```
NotchWindowController (NSWindowController, full-screen overlay window)
└── NotchViewController (NSHostingController<NotchView>)
    └── NotchView
        ├── notch shape (black rectangle, always visible)
        └── when .opened:
            ├── NotchHeaderView   (title + ellipsis)
            └── NotchContentView  (switches on contentType)
                ├── .normal        → ShareView + TrayView
                ├── .menu          → NotchMenuView
                ├── .settings      → NotchSettingsView
                ├── .roamCapture   → RoamCaptureView
                ├── .focusTimer    → FocusTimerView
                ├── .systemMonitor → SystemMonitorView
                └── .mediaPlayer   → MediaPlayerView
```

### Compact HUDs (closed / popping state)

Several features render a "compact pill" — a thin indicator inside a *widened notch capsule* (not floating below it) while the notch is `closed`/`popping`. `NotchView.notchSize` picks the width by priority **timer > media > sysmon**:
- `FocusTimerCompact` — always on while a timer runs.
- `MediaPlayerCompact` — auto-shows while audio plays. Art pins LEFT of the camera, EQ/pause indicator RIGHT (the "left/right of notch" pattern); the title marquee-scrolls in the gap on hover.
- `SystemMonitorCompact` — peeks only on hover (`popping`), slides back on exit.

### Critical transition rule

`NotchContentView` uses explicit `if vm.contentType == .X` branches — **not a switch**. SwiftUI only fires insert/remove transitions when it can see discrete identity changes via `if`. Never revert to a `switch` here or transitions will break silently.

### Persistence

`@PublishedPersist` (wrapping `FileStorage`) writes JSON files to `~/Documents/NotchDrop/Config/`. Use it for any new persisted state — see `PublishedPersist.swift` for the pattern.

### Window sizing

The overlay window is hardcoded to `notchHeight = 200` px from the top of the screen. The opened panel is `notchOpenedSize = CGSize(width: 600, height: 210)`. Content beyond that height needs a `ScrollView` — the window does not resize dynamically.

## Roam Research integration

- **`RoamConfig`** — singleton, stores `graphName` + `apiToken` via `@PublishedPersist`. On first launch with empty credentials it reads `~/Documents/NotchDrop/.env` then `~/.env`. Copy `.env.example` to either path and fill in values.
- **`RoamAPI`** — HTTP client. Roam always returns a `308 → peer-N.api.roamresearch.com:3000` redirect. `NoRedirectDelegate` prevents URLSession from auto-following (which would strip the POST body); the `perform` loop handles it manually and validates the redirect host stays within `*.api.roamresearch.com`.
- **Daily note UID**: Roam daily notes use `MM-dd-yyyy` format as their block UID (e.g. `06-05-2026`).
- **Network entitlement**: `com.apple.security.network.client = true` is kept in `NotchDrop.entitlements` for outbound HTTP. (The App Sandbox itself is now disabled — see "Media Player integration" — but the key is harmless and documents intent.)

## Media Player integration

- **`NowPlayingMonitor`** — singleton `ObservableObject` wrapping the adapter's `MediaController`. Started once in `NotchViewModel.init`. Exposes the current `TrackInfo.Payload?` plus convenience flags: `hasTrack`, `isPlaying`, `isActive` (drives the compact HUD + auto-trigger + media tab), `progress`/`elapsedSeconds`/`durationSeconds`, and controls (`togglePlayPause`, `next`, `previous`, `seek(toFraction:)`).
- **Why a perl subprocess?** `MPNowPlayingInfoCenter` only exposes *your own* app's playback. System-wide now-playing + artwork lives in the **private MediaRemote framework**. We use the `ejbills/mediaremote-adapter` SPM package, which bridges to the C API by spawning `/usr/bin/perl` running a bundled `run.pl` that `dlopen`s the adapter dylib. Updates arrive on the main queue.
- **Sandbox is OFF.** Spawning the perl helper is incompatible with the App Sandbox and a locked-down hardened runtime, so `ENABLE_APP_SANDBOX = NO` and the `com.apple.security.hardened-process.*` keys were removed from `NotchDrop.entitlements`. Accepted tradeoff for a direct-distribution (non-App-Store), notch-intercepting app. Risk: this relies on an undocumented framework + an unlicensed wrapper, so an OS update can break it.
- **Embedding gotcha.** The adapter is a `.library(type: .dynamic)` built *from source* — Xcode links it but does **not** auto-embed it (unlike `LookInsideServer`, a `.binaryTarget` xcframework). An explicit *Embed Frameworks* copy-files phase (`PBXCopyFilesBuildPhase`, `dstSubfolderSpec = 10`, CodeSignOnCopy) is required in the pbxproj, or a shipped `.app` crashes on launch when dyld can't find the dylib. `run.pl` rides along in the SPM resource bundle (`Contents/Resources/MediaRemoteAdapter_MediaRemoteAdapter.bundle`).

## Planned features (not yet built)

1. **Context-aware modes (phase 2)** — notch behavior adapts to the foreground app. Most complex; not started.

The Focus/Pomodoro timer, System Monitor HUD, and Media Player HUD are **built** (see the compact-HUD note in Architecture). The "compact pill" concept — a thin indicator inside a widened notch capsule while `closed` — is now implemented and shared by all three.
