import SwiftUI

// MARK: - Expanded panel

struct SystemMonitorView: View {
    @StateObject var vm: NotchViewModel
    @StateObject var monitor = SystemMonitor.shared

    var body: some View {
        HStack(spacing: 10) {
            MetricCard(
                label: "CPU",
                value: pct(monitor.cpuUsage),
                history: monitor.cpuHistory,
                color: cpuColor
            )
            MetricCard(
                label: "Memory",
                value: pct(monitor.ramUsage),
                history: monitor.ramHistory,
                color: ramColor
            )
            MetricCard(
                label: "Network ↓",
                value: bps(monitor.netDown),
                history: monitor.netDownHistory,
                color: .cyan
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { SystemMonitor.shared.start() }
    }

    private var cpuColor: Color {
        monitor.cpuUsage > 0.8 ? Color(red: 1, green: 0.3, blue: 0.3)
            : monitor.cpuUsage > 0.5 ? .orange : Color(red: 0.2, green: 0.9, blue: 0.5)
    }

    private var ramColor: Color {
        monitor.ramUsage > 0.85 ? Color(red: 1, green: 0.3, blue: 0.3)
            : monitor.ramUsage > 0.65 ? .orange : .blue
    }

    private func pct(_ v: Double) -> String { String(format: "%.0f%%", v * 100) }

    private func bps(_ v: Double) -> String {
        if v < 1_000 { return "—" }
        if v < 1_000_000 { return String(format: "%.0f KB/s", v / 1_000) }
        return String(format: "%.1f MB/s", v / 1_000_000)
    }
}

// MARK: - Metric card

private struct MetricCard: View {
    let label: String
    let value: String
    let history: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 1), value: value)
            }
            Sparkline(values: history, color: color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            guard values.count > 1 else { return AnyView(EmptyView()) }

            let step = w / CGFloat(values.count - 1)

            return AnyView(ZStack {
                // Fill
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        p.addLine(to: CGPoint(x: step * CGFloat(i), y: h * (1 - v)))
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(color.opacity(0.15))

                // Line
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * (1 - values[0])))
                    for i in 1 ..< values.count {
                        p.addLine(to: CGPoint(x: step * CGFloat(i), y: h * (1 - values[i])))
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            })
        }
    }
}

// MARK: - Compact HUD (inside widened notch when closed)

struct SystemMonitorCompact: View {
    @StateObject var monitor = SystemMonitor.shared

    var body: some View {
        HStack(spacing: 10) {
            compactItem(icon: "cpu", value: pct(monitor.cpuUsage), color: cpuColor)
            separator
            compactItem(icon: "memorychip", value: pct(monitor.ramUsage), color: ramColor)
            separator
            HStack(spacing: 3) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .semibold))
                Text(shortBps(monitor.netDown))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
            }
            .foregroundStyle(.cyan)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }

    private func compactItem(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.linear(duration: 1), value: value)
        }
        .foregroundStyle(color)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 1, height: 12)
    }

    private var cpuColor: Color {
        monitor.cpuUsage > 0.8 ? Color(red: 1, green: 0.3, blue: 0.3)
            : monitor.cpuUsage > 0.5 ? .orange : Color(red: 0.2, green: 0.9, blue: 0.5)
    }

    private var ramColor: Color {
        monitor.ramUsage > 0.85 ? Color(red: 1, green: 0.3, blue: 0.3)
            : monitor.ramUsage > 0.65 ? .orange : .blue
    }

    private func pct(_ v: Double) -> String { String(format: "%.0f%%", v * 100) }

    private func shortBps(_ v: Double) -> String {
        if v < 1_000 { return "—" }
        if v < 1_000_000 { return String(format: "%.0fK", v / 1_000) }
        return String(format: "%.1fM", v / 1_000_000)
    }
}

#Preview("Expanded") {
    SystemMonitorView(vm: .init())
        .padding()
        .frame(width: 600, height: 120)
        .background(Color(white: 0.059))
        .preferredColorScheme(.dark)
}

#Preview("Compact") {
    SystemMonitorCompact()
        .frame(width: 300, height: 28)
        .background(.black)
        .preferredColorScheme(.dark)
}
