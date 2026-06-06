import SwiftUI

struct NotchHeaderView: View {
    @StateObject var vm: NotchViewModel
    @StateObject private var focusTimer = FocusTimer.shared
    @StateObject private var nowPlaying = NowPlayingMonitor.shared

    var body: some View {
        HStack(spacing: 6) {
            TabPill(label: "Capture", icon: "square.and.pencil", active: vm.contentType == .roamCapture) {
                vm.contentType = .roamCapture
            }
            TabPill(label: "Files", icon: "tray", active: vm.contentType == .normal) {
                vm.contentType = .normal
            }
            TabPill(label: "Stats", icon: "chart.bar.xaxis", active: vm.contentType == .systemMonitor) {
                vm.contentType = .systemMonitor
            }
            if focusTimer.isActive {
                TabPill(label: "Focus", icon: "timer", active: vm.contentType == .focusTimer) {
                    vm.contentType = .focusTimer
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            if nowPlaying.hasTrack {
                TabPill(label: "Media", icon: "music.note", active: vm.contentType == .mediaPlayer) {
                    vm.contentType = .mediaPlayer
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            Spacer()

            Button { vm.showSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Button { vm.contentType = .menu } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .animation(vm.animation, value: focusTimer.isActive)
        .animation(vm.animation, value: nowPlaying.hasTrack)
        .animation(vm.animation, value: vm.contentType)
    }
}

private struct TabPill: View {
    let label: String
    let icon: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(active ? .white : Color(white: 0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(active ? Color(white: 0.22) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NotchHeaderView(vm: .init())
        .padding()
        .frame(width: 600)
        .background(.black)
        .preferredColorScheme(.dark)
}
