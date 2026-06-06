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
- **`ContentType`**: what renders inside the opened panel. Currently: `normal` (file tray), `menu`, `settings`, `roamCapture`. Add new modes here.
- **`OpenReason`**: `click | drag | boot | unknown`. Drag always opens `.normal` (file tray); click/boot opens `.roamCapture`.

### View hierarchy

```
NotchWindowController (NSWindowController, full-screen overlay window)
└── NotchViewController (NSHostingController<NotchView>)
    └── NotchView
        ├── notch shape (black rectangle, always visible)
        └── when .opened:
            ├── NotchHeaderView   (title + ellipsis)
            └── NotchContentView  (switches on contentType)
                ├── .normal    → ShareView + TrayView
                ├── .menu      → NotchMenuView
                ├── .settings  → NotchSettingsView
                └── .roamCapture → RoamCaptureView
```

### Critical transition rule

`NotchContentView` uses explicit `if vm.contentType == .X` branches — **not a switch**. SwiftUI only fires insert/remove transitions when it can see discrete identity changes via `if`. Never revert to a `switch` here or transitions will break silently.

### Persistence

`@PublishedPersist` (wrapping `FileStorage`) writes JSON files to `~/Documents/NotchDrop/Config/`. Use it for any new persisted state — see `PublishedPersist.swift` for the pattern.

### Window sizing

The overlay window is hardcoded to `notchHeight = 200` px from the top of the screen. The opened panel is `notchOpenedSize = CGSize(width: 600, height: 160)`. Content beyond 160px height needs a `ScrollView` — the window does not resize dynamically.

## Roam Research integration

- **`RoamConfig`** — singleton, stores `graphName` + `apiToken` via `@PublishedPersist`. On first launch with empty credentials it reads `~/Documents/NotchDrop/.env` then `~/.env`. Copy `.env.example` to either path and fill in values.
- **`RoamAPI`** — HTTP client. Roam always returns a `308 → peer-N.api.roamresearch.com:3000` redirect. `NoRedirectDelegate` prevents URLSession from auto-following (which would strip the POST body); the `perform` loop handles it manually and validates the redirect host stays within `*.api.roamresearch.com`.
- **Daily note UID**: Roam daily notes use `MM-dd-yyyy` format as their block UID (e.g. `06-05-2026`).
- **Network entitlement**: `com.apple.security.network.client = true` is required in `NotchDrop.entitlements` — the hardened runtime with `platform-restrictions = 2` blocks DNS without it.

## Planned features (not yet built)

In priority order:

1. **Focus / Pomodoro timer** — timer state machine in VM, compact ring indicator in the notch, activates from menu
2. **System Monitor HUD** — CPU/RAM/network sparklines via polling, compact pill display, user-configurable metrics
3. **Media Player HUD** — `NowPlayingInfoCenter` integration, auto-triggers on playback, compact album art + EQ visualizer on left/right of notch, full media controller card on click
4. **Context-aware modes (phase 2)** — notch adapts based on foreground app

All three pending features require a "compact pill" concept — a thin indicator that extends below the physical notch while it's `closed`, separate from the full `opened` panel. This is not yet implemented.
