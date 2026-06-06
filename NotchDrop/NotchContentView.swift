//
//  NotchContentView.swift
//  NotchDrop
//
//  Created by 秋星桥 on 2024/7/7.
//  Last Modified by 冷月 on 2025/5/5.
//

import ColorfulX
import SwiftUI
import UniformTypeIdentifiers

struct NotchContentView: View {
    @StateObject var vm: NotchViewModel

    // Explicit `if` branches are required — SwiftUI only fires insert/remove
    // transitions when it can see discrete view identity changes, not switch cases.
    var body: some View {
        ZStack {
            if vm.contentType == .normal {
                HStack(spacing: vm.spacing) {
                    ShareView(vm: vm, type: .airdrop)
                    TrayView(vm: vm)
                }
                .transition(contentTransition)
            }
            if vm.contentType == .menu {
                NotchMenuView(vm: vm)
                    .transition(contentTransition)
            }
            if vm.contentType == .settings {
                NotchSettingsView(vm: vm)
                    .transition(contentTransition)
            }
            if vm.contentType == .roamCapture {
                RoamCaptureView(vm: vm)
                    .transition(contentTransition)
            }
        }
        .animation(vm.animation, value: vm.contentType)
    }

    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.92)),
            removal:   .opacity.combined(with: .scale(scale: 0.96))
        )
    }
}

#Preview {
    NotchContentView(vm: .init())
        .padding()
        .frame(width: 600, height: 150, alignment: .center)
        .background(.black)
        .preferredColorScheme(.dark)
}
