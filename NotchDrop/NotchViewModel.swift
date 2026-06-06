import Cocoa
import Combine
import Foundation
import LaunchAtLogin
import SwiftUI

class NotchViewModel: NSObject, ObservableObject {
    var cancellables: Set<AnyCancellable> = []
    let inset: CGFloat

    init(inset: CGFloat = -4) {
        self.inset = inset
        super.init()
        setupCancellables()
    }

    deinit {
        destroy()
    }

    // stiffness=350, damping=28, mass=0.8 → response≈0.3, dampingFraction≈0.836
    let animation: Animation = .spring(response: 0.3, dampingFraction: 0.836)
    let notchOpenedSize: CGSize = .init(width: 600, height: 160)
    let dropDetectorRange: CGFloat = 32

    enum Status: String, Codable, Hashable, Equatable {
        case closed
        case opened
        case popping
    }

    enum OpenReason: String, Codable, Hashable, Equatable {
        case click
        case drag
        case boot
        case unknown
    }

    enum ContentType: Int, Codable, Hashable, Equatable {
        case normal
        case menu
        case settings
        case roamCapture
        case focusTimer
    }

    var notchOpenedRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchOpenedSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - notchOpenedSize.height,
            width: notchOpenedSize.width,
            height: notchOpenedSize.height
        )
    }

    var headlineOpenedRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchOpenedSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - deviceNotchRect.height,
            width: notchOpenedSize.width,
            height: deviceNotchRect.height
        )
    }

    @Published private(set) var status: Status = .closed
    @Published var openReason: OpenReason = .unknown
    @Published var contentType: ContentType = .roamCapture

    @Published var spacing: CGFloat = 16
    @Published var cornerRadius: CGFloat = 16
    @Published var deviceNotchRect: CGRect = .zero
    @Published var screenRect: CGRect = .zero
    @Published var optionKeyPressed: Bool = false
    @Published var notchVisible: Bool = true

    @PublishedPersist(key: "selectedLanguage", defaultValue: .system)
    var selectedLanguage: Language

    @PublishedPersist(key: "hapticFeedback", defaultValue: true)
    var hapticFeedback: Bool

    let hapticSender = PassthroughSubject<Void, Never>()

    func notchOpen(_ reason: OpenReason) {
        openReason = reason
        status = .opened
        contentType = reason == .drag ? .normal : .roamCapture
        NSApp.activate(ignoringOtherApps: true)
    }

    func notchClose() {
        openReason = .unknown
        status = .closed
        // Don't reset contentType here — mutating it during the close animation
        // causes a visible flash. notchOpen() sets it fresh on the next open.
    }

    func showSettings() {
        contentType = .settings
    }

    func showRoamCapture() {
        contentType = .roamCapture
    }

    func showFocusTimer() {
        contentType = .focusTimer
    }

    func notchPop() {
        openReason = .unknown
        status = .popping
    }
}
