//
//  NotchView.swift
//  NotchDrop
//
//  Created by 秋星桥 on 2024/7/7.
//

import SwiftUI

struct NotchView: View {
    @StateObject var vm: NotchViewModel
    @StateObject private var focusTimer = FocusTimer.shared
    @StateObject private var sysMonitor = SystemMonitor.shared
    @StateObject private var nowPlaying = NowPlayingMonitor.shared

    @State var dropTargeting: Bool = false

    private let compactTimerWidth: CGFloat = 280
    private let compactSysmonWidth: CGFloat = 300

    /// A compact HUD (timer or media) extends the notch past the physical cutout onto the
    /// desktop, so it must stay fully opaque — the idle-dim only applies to the bare notch
    /// sitting invisibly inside the black cutout. Without this, a light-mode wallpaper shows
    /// through the 0.3-opacity capsule as grey instead of jet black.
    private var compactActive: Bool { focusTimer.isActive || nowPlaying.isActive }
    // Media flanks the camera: art left + indicator right (closed), + scrolling title (hover).
    private var compactMediaWidth: CGFloat { vm.deviceNotchRect.width + 96 }
    private var compactMediaPoppingWidth: CGFloat { vm.deviceNotchRect.width + 300 }

    var notchSize: CGSize {
        switch vm.status {
        case .closed:
            // Timer always shows its compact HUD; media auto-shows while playing; sysmon
            // only peeks on hover. Priority: timer > media > sysmon.
            let width: CGFloat = focusTimer.isActive ? compactTimerWidth
                : nowPlaying.isActive ? compactMediaWidth
                : max(0, vm.deviceNotchRect.width - 4)
            // Match the physical notch height exactly so a compact capsule lines up flush with
            // the cutout's bottom edge instead of stopping a few px short.
            return CGSize(width: width, height: vm.deviceNotchRect.height)
        case .opened:
            return vm.notchOpenedSize
        case .popping:
            // On hover: timer keeps its width, media widens to scroll the title, else sysmon.
            let width: CGFloat = focusTimer.isActive ? compactTimerWidth
                : nowPlaying.isActive ? compactMediaPoppingWidth
                : compactSysmonWidth
            return CGSize(width: width, height: vm.deviceNotchRect.height + 4)
        }
    }

    // Derived from the physical notch height so radii scale correctly on any Mac.
    private var notchBaseRadius: CGFloat { vm.deviceNotchRect.height / 3 }

    var notchTopRadius: CGFloat {
        switch vm.status {
        case .closed, .popping: notchBaseRadius - 4
        case .opened: 0
        }
    }

    var notchBottomRadius: CGFloat {
        switch vm.status {
        case .closed, .popping: notchBaseRadius
        case .opened: 44
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            notch
                .zIndex(0)
                .disabled(true)
                .opacity((vm.notchVisible || compactActive) ? 1 : 0.3)
            if vm.status != .opened {
                if focusTimer.isActive {
                    FocusTimerCompact()
                        .frame(width: compactTimerWidth, height: notchSize.height)
                        .zIndex(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                } else if nowPlaying.isActive {
                    // Album art left of the camera, playback indicator right; title scrolls on hover.
                    MediaPlayerCompact(notchWidth: vm.deviceNotchRect.width, expanded: vm.status == .popping)
                        .frame(width: notchSize.width, height: notchSize.height)
                        .zIndex(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                } else if vm.status == .popping {
                    // Sysmon peeks on hover only — slides in with the notch expansion
                    SystemMonitorCompact()
                        .frame(width: compactSysmonWidth, height: notchSize.height)
                        .zIndex(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                }
            }
            Group {
                if vm.status == .opened {
                    VStack(spacing: vm.spacing) {
                        NotchHeaderView(vm: vm)
                        NotchContentView(vm: vm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.top, vm.menuBarHeight + vm.spacing)
                    .padding([.horizontal, .bottom], vm.spacing)
                    .frame(maxWidth: vm.notchOpenedSize.width, maxHeight: vm.notchOpenedSize.height)
                    .background {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0, bottomLeadingRadius: notchBottomRadius,
                            bottomTrailingRadius: notchBottomRadius, topTrailingRadius: 0
                        )
                        .fill(.black)
                    }
                    .zIndex(1)
                }
            }
            .transition(
                .scale.combined(
                    with: .opacity
                ).combined(
                    with: .offset(y: -vm.notchOpenedSize.height / 2)
                ).animation(vm.animation)
            )
        }
        .background(dragDetector)
        .animation(vm.animation, value: vm.status)
        .animation(vm.animation, value: nowPlaying.isActive)
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var notch: some View {
        NotchShape(topCornerRadius: notchTopRadius, bottomCornerRadius: notchBottomRadius)
            .fill(.black)
            .frame(width: notchSize.width, height: notchSize.height)
            .shadow(
                color: .black.opacity(([.opened, .popping].contains(vm.status)) ? 1 : 0),
                radius: 16
            )
    }

    @ViewBuilder
    var dragDetector: some View {
        RoundedRectangle(cornerRadius: notchBottomRadius)
            .foregroundStyle(Color.black.opacity(0.001)) // fuck you apple and 0.001 is the smallest we can have
            .contentShape(Rectangle())
            .frame(width: notchSize.width + vm.dropDetectorRange, height: notchSize.height + vm.dropDetectorRange)
            .onDrop(of: [.data], isTargeted: $dropTargeting) { _ in true }
            .onChange(of: dropTargeting) { isTargeted in
                if isTargeted, vm.status == .closed {
                    // Open the notch when a file is dragged over it
                    vm.notchOpen(.drag)
                    vm.hapticSender.send()
                } else if !isTargeted {
                    // Close the notch when the dragged item leaves the area
                    let mouseLocation: NSPoint = NSEvent.mouseLocation
                    if !vm.notchOpenedRect.insetBy(dx: vm.inset, dy: vm.inset).contains(mouseLocation) {
                        vm.notchClose()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
