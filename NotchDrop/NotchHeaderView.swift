//
//  NotchHeaderView.swift
//  NotchDrop
//
//  Created by 秋星桥 on 2024/7/7.
//

import ColorfulX
import SwiftUI

struct NotchHeaderView: View {
    @StateObject var vm: NotchViewModel

    private var headerTitle: String {
        switch vm.contentType {
        case .settings:
            let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
            return "Version: \(ver) (Build: \(build))"
        case .roamCapture:
            return "Capture to Roam"
        default:
            return "Notch Drop"
        }
    }

    var body: some View {
        HStack {
            Text(headerTitle)
            .contentTransition(.numericText())
            Spacer()
            Image(systemName: "ellipsis")
        }
        .animation(vm.animation, value: vm.contentType)
        .font(.system(.headline, design: .rounded))
    }
}

#Preview {
    NotchHeaderView(vm: .init())
}
