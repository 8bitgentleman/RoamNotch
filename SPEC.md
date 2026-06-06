# RoamNotch Spec

This is the living product and technical spec. It describes what's built, what's planned, and the architectural direction. Update it as decisions are made.

---

## What this app is

A macOS menubar app that lives in the camera notch. The physical notch is `#000000`, so the app is invisible when collapsed — it extends downward on hover/click. The notch is treated as a persistent ambient surface, not a traditional menu-bar app.

The unique angle vs. other notch apps (boringNotch, DynamicNotch, etc.) is **Roam Research integration** — the notch is a zero-friction capture point for your PKM graph.

---

## Current state (built)

| Feature | Status | Notes |
|---|---|---|
| Notch expand/collapse | ✅ | closed → popping → opened state machine |
| File tray (drag & drop) | ✅ | Accepts files, shows previews, AirDrop support |
| Roam quick capture | ✅ | Outline editor → daily note via Roam API |
| Focus/Pomodoro timer | ✅ | Compact HUD in notch while running |
| Media player HUD | ✅ | Compact + expanded views, artwork, scrubber |
| System monitor HUD | ✅ | CPU/RAM compact pill on hover |
| Settings + menu | ✅ | |
| Multi-monitor | ✅ | One notch window per screen with notch |

---

## Architecture: current

### State machine
`NotchViewModel` is the single source of truth.

- **`Status`**: `closed → popping → opened`
- **`ContentType`**: what renders inside the opened panel. Currently a flat enum; one content type active at a time.
- **`OpenReason`**: `click | drag | boot | unknown`

### Compact HUD priority (hardcoded, in `notchSize`)
Timer > Media > SysMonitor

This works for three features. It won't scale cleanly past ~4–5.

---

## Architecture: target

The priority arbitration should move to a proper engine, inspired by DynamicNotch's `NotchEngine`. Key concept: separate **live activities** (persistent, one at a time) from **temporary notifications** (auto-dismiss, preempt live content then restore it).

### Content types

**Live activities** — persistent while their condition is true, compete by priority:
- Media player (while playing)
- Focus timer (while running)
- System monitor (while hovered)
- Screen recording indicator (while recording)
- Calendar upcoming event (when event is imminent)
- Hotspot active

**Temporary notifications** — show for a fixed duration, then restore previous live activity:
- Battery: charger connected/disconnected
- Battery: low power warning
- Battery: fully charged
- Bluetooth: device connected (with battery level)
- Network: WiFi joined
- Network: VPN connected
- Network: no internet connection
- Download complete / in-progress

**Always-wins (override everything)**:
- Drag & drop in progress
- Lock screen (separate window)
- Onboarding

### Priority arbitration rules
1. Each live activity declares a numeric priority.
2. The engine always surfaces the highest-priority active one.
3. Temporary notifications preempt live activities for their duration, then restore.
4. Priority order is user-configurable in settings (drag to reorder).
5. Events queue; transitions wait for the current animation to finish before starting the next.

---

## Features: planned

### Infrastructure improvements (do first, unblocks everything else)

**1. NotchEngine priority queue**
Replace the flat `ContentType` enum with a protocol + priority-sorted engine. Each feature emits a content object; the engine decides what's visible. This is a refactor of `NotchViewModel` + `NotchContentView`, not a rewrite of features.

**2. Media: AppleScript bridge**
When the user hits play/pause/seek, fire the command via `NSAppleScript` directly to Apple Music or Spotify in addition to the MediaRemote command. Apply optimistic state immediately (instant UI feedback), then confirm via AppleScript after ~200ms. Also add `DistributedNotificationCenter` observers for `com.apple.Music.playerInfo` and `com.spotify.client.PlaybackStateChanged` to catch events MediaRemote misses.

**3. Media: debounce perl subprocess**
Pass `--no-diff --debounce=150` when launching the MediaRemote adapter perl process. Reduces jitter from rapid state updates. One-line change in `NowPlayingMonitor`.

**4. Animation presets**
Extract all animation curves into a named preset struct (snappy / balanced / relaxed). User picks in settings. Prevents magic numbers scattered across views.

---

### System HUD replacement

Replace the macOS center-screen volume and brightness overlays with in-notch versions. Intercept media key events via `CGEventTap` or `IOKit`, read the new level, show a temporary notification in the notch with an icon + level bar, then auto-dismiss.

- Volume HUD: speaker icon + bar, color changes green → orange → red at high levels, slash icon when muted
- Brightness HUD: sun icon + bar
- Keyboard backlight: keyboard icon + bar (if available)
- Transitions between HUD types morph without collapsing (e.g., brightness → volume if keys are pressed quickly)

Reference: DynamicNotch `SystemAudioVolumeService`, `SystemDisplayBrightnessService`, `SystemMediaKeyTap`, `HardwareHUDMonitor`.

---

### Battery events

Show temporary notifications in the notch for battery state changes:
- **Charger connected**: plug icon + current charge %
- **Charger disconnected**: unplug icon + current charge %
- **Low battery** (configurable threshold, default 20%): battery icon, pulsing red
- **Fully charged**: battery-full icon + "Charged"

Use `IOKit` (`IOPSCopyPowerSourcesInfo`) for power source monitoring.

---

### Bluetooth device events

When a Bluetooth device connects or disconnects, show a temporary notification:
- Device name + icon (headphones, keyboard, mouse, etc.)
- Battery level for supported devices (AirPods, Magic Keyboard, etc.) shown as a circular fill ring
- Auto-dismiss after ~4 seconds

Use `IOBluetooth` framework. For AirPods battery: read `IOBluetooth` device properties.

---

### Network events

Temporary notifications for:
- **WiFi connected**: network name + signal strength icon
- **VPN connected/disconnected**: shield icon + connection name
- **Personal hotspot active**: hotspot icon (persists as live activity while hotspot is on)
- **No internet**: warning icon, persists until connection restored

Use `Network.framework` (`NWPathMonitor`) + `CoreWLAN` for WiFi SSID.

---

### Download monitoring

Watch `~/Downloads` (and optionally other configured folders) for new or completing files:
- **Download in progress**: file icon + progress bar + filename, lives as a live activity
- **Download complete**: file thumbnail + "Done" badge, temporary notification that auto-dismisses

Use `DispatchSource.makeFileSystemObjectSource` or `NSMetadataQuery` to watch the folder. Track partial (`.crdownload`, `.part`, `.download`) files and replace with final file on completion.

Reference: DynamicNotch `FolderFileDownloadMonitor`.

---

### Screen recording indicator

While a screen recording is active, show a persistent compact indicator (red dot + "REC") as a live activity. Detects system screen recording via `CGWindowListCopyWindowInfo` or `SCStream` availability checks.

Reference: DynamicNotch `SystemScreenRecordingMonitor`.

---

### Synchronized lyrics

When music is playing and the media panel is open (or in a dedicated lyrics mode), fetch and display synchronized lyrics:
- Query [LRCLIB](https://lrclib.net) first, fall back to [OVH API](https://api.lyrics.ovh)
- Display current line prominently, previous/next lines dimmed
- Auto-scroll in sync with playback position

Reference: DynamicNotch `LRCLIBLyricsProvider`, `OvhLyricsProvider`, `NowPlayingLyricsState`.

---

### Calendar / upcoming events

When a calendar event is starting soon (configurable lead time, default 5 min), surface it:
- **Compact**: event title truncated + countdown ("6m")
- **Hover/expanded**: full event title, duration, calendar color accent

Use `EventKit` (`EKEventStore`). Requires calendar permission. Show as a live activity while the event is imminent or in-progress.

Reference: DynamicNotch `CalendarViewModel`, `CalendarNotchView`.

---

### Lock screen presence

Show a dedicated floating panel on the lock screen displaying:
- Clock (large)
- Now playing info (album art, title, artist)
- Lyrics if available

Requires placing a window in a SkyLight compositor space above the lock screen. Use `dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/...")` → `SLSSpaceCreate` / `SLSSpaceSetAbsoluteLevel` / `SLSShowSpaces` / `SLSSpaceAddWindowsAndRemoveFromSpaces`.

This is a private API with OS-update risk. Implement with graceful fallback (no-op if SkyLight symbols are unavailable).

Reference: DynamicNotch `SkyLightOperator`, `LockScreenPanelManager`, `LockScreenLiveActivityWindowManager`.

---

### Onboarding flow

First-launch walkthrough rendered inside the notch itself (not a separate settings window):
- Step 1: Welcome / what the notch does
- Step 2: Roam API credentials
- Step 3: Permission requests (calendar, accessibility for HUD intercept)
- Step 4: Done

Onboarding content gets the highest priority override until completed.

---

## Media player: additional controls (enabled by AppleScript bridge)

Once the AppleScript bridge is in place, expose in the expanded media view:
- Shuffle toggle
- Repeat mode (off / one / all)
- Volume slider
- Favorite / love track button (Apple Music only)

---

## Features we are intentionally NOT adopting from DynamicNotch

- **File converter** — out of scope, drag-and-drop format conversion is not a Roam/PKM use case
- **AirDrop as a drop target** — we already handle drag-and-drop; AirDrop sends are a different UX that adds complexity for little notch-specific value
- **YouTube Music HTTP bridge** — niche; add only if there's demand
- **Dynamic Island support** — we target notch Macs only for now

---

## Roam-specific features (our differentiator, not in DynamicNotch)

These are ours alone and should stay high-quality:

### Quick capture (built)
Zero-friction outline editor → Roam daily note. Keep this fast: notch opens, cursor is already in the input.

### Capture improvements (planned)
- Block references: `((` autocomplete against graph
- Page links: `[[` autocomplete against graph
- Tag support: `#` autocomplete
- Voice capture: click mic → transcribe → insert as bullet

### Roam context (future)
- Show today's daily note preview in the notch home page
- Surface blocks with `[[Today]]` or date tags

---

## Settings surface

Settings will need to grow as features are added. Planned sections:

| Section | Contents |
|---|---|
| General | Launch at login, animation speed preset, expand interaction (hover vs click) |
| Roam | API token, graph name, capture defaults |
| Now Playing | Source filter (all apps / specific), show lyrics, compact HUD behavior |
| Priorities | Drag-to-reorder live activity priority |
| HUD | Enable/disable notch HUD replacement, indicator style (bar vs ring), color thresholds |
| Battery | Enable events, low-battery threshold |
| Bluetooth | Enable connection events, show battery |
| Network | Enable WiFi/VPN/hotspot events |
| Downloads | Watched folders, enable progress indicator |
| Calendar | Enable upcoming events, lead time |
| Permissions | Accessibility, calendar, screen recording |

---

## Implementation order (suggested)

1. **NotchEngine priority queue** — foundation for everything else
2. **Media AppleScript bridge + debounce** — immediate quality improvement
3. **System HUD replacement** — high visibility, self-contained
4. **Battery events** — simple, high value
5. **Bluetooth events** — simple, high value
6. **Network events** — moderate complexity
7. **Download monitoring** — moderate complexity
8. **Animation presets** — polish, pairs well with settings work
9. **Screen recording indicator** — simple once engine is in place
10. **Calendar** — requires EventKit permission flow
11. **Synchronized lyrics** — network dependency, lower priority
12. **Lock screen presence** — private API risk, do last
13. **Onboarding** — needed before any public release
14. **Roam capture enhancements** — ongoing, our core differentiator
