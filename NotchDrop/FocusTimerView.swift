import SwiftUI

// MARK: - Expanded panel (opened state)

struct FocusTimerView: View {
    @StateObject var vm: NotchViewModel
    @StateObject var timer = FocusTimer.shared

    var body: some View {
        HStack(spacing: 20) {
            ring
            VStack(alignment: .leading, spacing: 0) {
                phaseAndSessions
                Spacer(minLength: 0)
                controls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.001, 1 - timer.progress))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timer.remainingSeconds)
            VStack(spacing: 1) {
                Text(timeString)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.2), value: timer.remainingSeconds)
            }
        }
        .frame(width: 76, height: 76)
    }

    private var phaseAndSessions: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(phaseLabel.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(ringColor)
            if timer.completedSessions > 0 {
                Text("· \(timer.completedSessions) done")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if timer.state == .idle {
            Button { timer.start() } label: {
                Label("Start Focus", systemImage: "play.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 22) {
                iconButton(
                    icon: timer.state == .running ? "pause.fill" : "play.fill",
                    color: .white
                ) {
                    if timer.state == .running { timer.pause() } else { timer.resume() }
                }
                iconButton(icon: "stop.fill", color: Color(red: 1, green: 0.32, blue: 0.32)) {
                    timer.stop()
                }
                iconButton(icon: "forward.end.fill", color: .white.opacity(0.35)) {
                    timer.skip()
                }
            }
        }
    }

    private func iconButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }

    private var timeString: String {
        let m = timer.remainingSeconds / 60
        let s = timer.remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var phaseLabel: String {
        switch timer.phase {
        case .work: return timer.state == .idle ? "Focus Timer" : "Focus"
        case .shortBreak: return "Short Break"
        }
    }

    private var ringColor: Color {
        timer.phase == .work ? .orange : Color(red: 0.2, green: 0.9, blue: 0.5)
    }
}

// MARK: - Compact HUD inside the widened notch (closed state)

struct FocusTimerCompact: View {
    @StateObject var timer = FocusTimer.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ringColor)

            Text(phaseLabel)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(ringColor)
                        .frame(width: geo.size.width * max(0.02, 1 - timer.progress))
                        .animation(.linear(duration: 1), value: timer.remainingSeconds)
                }
            }
            .frame(height: 3)

            Text(timeString)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.2), value: timer.remainingSeconds)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }

    private var timeString: String {
        let m = timer.remainingSeconds / 60
        let s = timer.remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var phaseLabel: String {
        timer.phase == .work ? "Focus" : "Break"
    }

    private var ringColor: Color {
        timer.phase == .work ? .orange : Color(red: 0.2, green: 0.9, blue: 0.5)
    }
}

#Preview("Expanded – idle") {
    FocusTimerView(vm: .init())
        .padding()
        .frame(width: 600, height: 120)
        .background(Color(white: 0.059))
        .preferredColorScheme(.dark)
}

#Preview("Compact") {
    FocusTimerCompact()
        .frame(width: 280, height: 28)
        .background(.black)
        .preferredColorScheme(.dark)
}
