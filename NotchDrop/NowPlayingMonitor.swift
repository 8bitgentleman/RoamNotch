import AppKit
import Combine
import MediaRemoteAdapter

/// System-wide Now Playing reader, backed by ejbills/mediaremote-adapter.
///
/// `MediaController` spawns `/usr/bin/perl` under the hood (perl carries the MediaRemote
/// entitlement that third-party apps lost in macOS 15.4), reads the private MediaRemote
/// framework, and streams full-state JSON back. That subprocess is why this app ships
/// without the App Sandbox — see CLAUDE.md "Media Player HUD".
///
/// The package already handles process lifecycle, full-state emission, artwork preservation
/// across same-track updates, and periodic self-restart, and delivers callbacks on the main
/// thread — so this type is a thin observable mirror plus a few derived conveniences.
final class NowPlayingMonitor: ObservableObject {
    static let shared = NowPlayingMonitor()

    /// Latest now-playing payload, or `nil` when no media player is active.
    @Published private(set) var track: TrackInfo.Payload?

    private let controller = MediaController()
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        controller.onTrackInfoReceived = { [weak self] info in
            self?.track = info?.payload
        }
        controller.onListenerTerminated = { [weak self] in
            // Real termination (not the package's periodic self-restart, which never fires
            // this). Clear state and try to recover after a short delay.
            self?.track = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.controller.startListening()
            }
        }
        controller.startListening()
    }

    // MARK: - Derived state

    var hasTrack: Bool { !(track?.title?.isEmpty ?? true) }
    var isPlaying: Bool { track?.isPlaying ?? false }

    /// Drives the compact HUD + auto-trigger: the notch surfaces media only while it's
    /// actively playing, so a long-paused background player doesn't widen the notch forever.
    var isActive: Bool { hasTrack && isPlaying }

    var durationSeconds: Double {
        guard let micros = track?.durationMicros, micros > 0 else { return 0 }
        return micros / 1_000_000
    }

    /// Live playback position, extrapolated from the last update's timestamp + playback rate.
    var elapsedSeconds: Double { track?.currentElapsedTime ?? 0 }

    var progress: Double {
        let d = durationSeconds
        guard d > 0 else { return 0 }
        return min(1, max(0, elapsedSeconds / d))
    }

    // MARK: - Controls

    func togglePlayPause() { controller.togglePlayPause() }
    func next() { controller.nextTrack() }
    func previous() { controller.previousTrack() }

    func seek(toFraction fraction: Double) {
        let d = durationSeconds
        guard d > 0 else { return }
        controller.setTime(seconds: d * min(1, max(0, fraction)))
    }
}
