import MediaRemoteAdapter
import SwiftUI

// MARK: - Expanded panel (opened state)

struct MediaPlayerView: View {
    @StateObject var vm: NotchViewModel
    @StateObject var monitor = NowPlayingMonitor.shared

    var body: some View {
        Group {
            if monitor.hasTrack {
                content
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        HStack(spacing: 18) {
            artwork
            VStack(alignment: .leading, spacing: 0) {
                Text(monitor.track?.title ?? "Unknown")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(secondaryLine)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                scrubber
                Spacer(minLength: 12)
                controls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var secondaryLine: String {
        [monitor.track?.artist, monitor.track?.album]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
    }

    private var artwork: some View {
        Group {
            if let art = monitor.track?.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(Color.white.opacity(0.07))
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .frame(width: 90, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scrubber: some View {
        // Re-read the extrapolated position twice a second so the bar creeps forward live.
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule().fill(Color.white.opacity(0.85))
                            .frame(width: max(0, geo.size.width * monitor.progress))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onEnded { value in
                            guard geo.size.width > 0 else { return }
                            monitor.seek(toFraction: Double(value.location.x / geo.size.width))
                        }
                    )
                }
                .frame(height: 4)

                HStack {
                    Text(timeString(monitor.elapsedSeconds))
                    Spacer()
                    Text(timeString(monitor.durationSeconds))
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 30) {
            iconButton("backward.end.fill", size: 18) { monitor.previous() }
            iconButton(monitor.isPlaying ? "pause.fill" : "play.fill", size: 24) { monitor.togglePlayPause() }
            iconButton("forward.end.fill", size: 18) { monitor.next() }
        }
        .frame(maxWidth: .infinity)
    }

    private func iconButton(_ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size + 10, height: size + 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
            Text("Nothing playing")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Compact HUD inside the widened notch (closed / popping state)
//
// The physical camera sits in the middle, so the artwork pins to the LEFT of the notch and
// the playback indicator to the RIGHT — the "left/right of notch" pattern. On hover the notch
// widens and the track title scrolls in the gap between the artwork and the camera.

struct MediaPlayerCompact: View {
    @StateObject var monitor = NowPlayingMonitor.shared
    /// Width of the physical notch cutout — the central gap the camera occupies.
    let notchWidth: CGFloat
    /// `true` while popping (hover): reveal the scrolling title.
    let expanded: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                thumbnail
                if expanded {
                    MarqueeText(text: marqueeText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)

            Color.clear.frame(width: notchWidth)

            rightIndicator
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 14)
        }
        .frame(maxHeight: .infinity)
    }

    private var marqueeText: String {
        [monitor.track?.title, monitor.track?.artist]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
    }

    private var thumbnail: some View {
        Group {
            if let art = monitor.track?.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(Color.white.opacity(0.12))
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    @ViewBuilder
    private var rightIndicator: some View {
        if monitor.isPlaying {
            EQWaveform()
        } else {
            Image(systemName: "pause.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Animated EQ bars

struct EQWaveform: View {
    var barCount: Int = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0 ..< barCount, id: \.self) { i in
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2.5, height: height(bar: i, time: t))
                }
            }
            .frame(height: 16)
        }
    }

    private func height(bar i: Int, time t: TimeInterval) -> CGFloat {
        let wave = sin(t * 6 + Double(i) * 1.3)
        return 5 + CGFloat((wave + 1) / 2) * 11 // 5...16pt
    }
}

// MARK: - Marquee

/// Scrolls its text horizontally, bouncing, only when it overflows the available width.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 11, weight: .medium, design: .rounded)

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { t in
                        Color.clear.preference(key: MarqueeWidthKey.self, value: t.size.width)
                    }
                )
                .offset(x: offset)
                .frame(width: geo.size.width, alignment: .leading)
                .clipped()
                .onAppear { containerWidth = geo.size.width }
                .onChange(of: geo.size.width) { containerWidth = $0; restart() }
                .onPreferenceChange(MarqueeWidthKey.self) { textWidth = $0; restart() }
                .onChange(of: text) { _ in restart() }
        }
        .frame(height: 15)
    }

    private func restart() {
        let overflow = textWidth - containerWidth
        guard overflow > 1 else {
            withAnimation(.none) { offset = 0 }
            return
        }
        offset = 0
        withAnimation(.linear(duration: Double(textWidth) / 30).delay(0.6).repeatForever(autoreverses: true)) {
            offset = -overflow
        }
    }
}

private struct MarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("Compact – closed") {
    MediaPlayerCompact(notchWidth: 200, expanded: false)
        .frame(width: 360, height: 32)
        .background(.black)
        .preferredColorScheme(.dark)
}
