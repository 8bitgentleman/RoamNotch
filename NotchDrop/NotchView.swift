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

    @State var dropTargeting: Bool = false

    private let compactTimerWidth: CGFloat = 280
    private let compactSysmonWidth: CGFloat = 300

    private var compactActive: Bool { focusTimer.isActive || true } // sysmon always shows
    private var compactWidth: CGFloat { focusTimer.isActive ? compactTimerWidth : compactSysmonWidth }

    var notchSize: CGSize {
        switch vm.status {
        case .closed:
            let width = compactActive ? compactWidth : max(0, vm.deviceNotchRect.width - 4)
            let height = max(0, vm.deviceNotchRect.height - 4)
            return CGSize(width: width, height: height)
        case .opened:
            return vm.notchOpenedSize
        case .popping:
            let width = compactActive ? compactWidth : vm.deviceNotchRect.width
            return .init(width: width, height: vm.deviceNotchRect.height + 4)
        }
    }

    var notchCornerRadius: CGFloat {
        switch vm.status {
        case .closed: 14
        case .opened: 32
        case .popping: 14
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            notch
                .zIndex(0)
                .disabled(true)
                .opacity(vm.notchVisible ? 1 : 0.3)
            if vm.status != .opened {
                if focusTimer.isActive {
                    FocusTimerCompact()
                        .frame(width: compactTimerWidth, height: notchSize.height)
                        .zIndex(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                } else {
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
                    .padding(vm.spacing)
                    .frame(maxWidth: vm.notchOpenedSize.width, maxHeight: vm.notchOpenedSize.height)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 32)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color(white: 0.059, opacity: 0.92))
                        }
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
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var notch: some View {
        Rectangle()
            .foregroundStyle(.black)
            .mask(notchBackgroundMaskGroup)
            .frame(
                width: notchSize.width + notchCornerRadius * 2,
                height: notchSize.height
            )
            .shadow(
                color: .black.opacity(([.opened, .popping].contains(vm.status)) ? 1 : 0),
                radius: 16
            )
    }

    var notchBackgroundMaskGroup: some View {
        Rectangle()
            .foregroundStyle(.black)
            .frame(
                width: notchSize.width,
                height: notchSize.height
            )
            .clipShape(.rect(
                bottomLeadingRadius: notchCornerRadius,
                bottomTrailingRadius: notchCornerRadius
            ))
            .overlay {
                ZStack(alignment: .topTrailing) {
                    Rectangle()
                        .frame(width: notchCornerRadius, height: notchCornerRadius)
                        .foregroundStyle(.black)
                    Rectangle()
                        .clipShape(.rect(topTrailingRadius: notchCornerRadius))
                        .foregroundStyle(.white)
                        .frame(
                            width: notchCornerRadius + vm.spacing,
                            height: notchCornerRadius + vm.spacing
                        )
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -notchCornerRadius - vm.spacing + 0.5, y: -0.5)
            }
            .overlay {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .frame(width: notchCornerRadius, height: notchCornerRadius)
                        .foregroundStyle(.black)
                    Rectangle()
                        .clipShape(.rect(topLeadingRadius: notchCornerRadius))
                        .foregroundStyle(.white)
                        .frame(
                            width: notchCornerRadius + vm.spacing,
                            height: notchCornerRadius + vm.spacing
                        )
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: notchCornerRadius + vm.spacing - 0.5, y: -0.5)
            }
    }

    @ViewBuilder
    var dragDetector: some View {
        RoundedRectangle(cornerRadius: notchCornerRadius)
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
