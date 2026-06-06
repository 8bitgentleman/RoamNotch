import Combine
import Foundation

class FocusTimer: ObservableObject {
    static let shared = FocusTimer()

    enum Phase { case work, shortBreak }
    enum State { case idle, running, paused }

    @Published private(set) var phase: Phase = .work
    @Published private(set) var state: State = .idle
    @Published private(set) var remainingSeconds: Int = 25 * 60
    @Published private(set) var completedSessions: Int = 0

    let workMinutes = 25
    let breakMinutes = 5

    var totalSeconds: Int { (phase == .work ? workMinutes : breakMinutes) * 60 }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var isActive: Bool { state != .idle }

    private var ticker: AnyCancellable?

    private init() {}

    func start() {
        guard state == .idle else { return }
        phase = .work
        remainingSeconds = workMinutes * 60
        completedSessions = 0
        state = .running
        scheduleTick()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        ticker?.cancel()
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        scheduleTick()
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        state = .idle
        phase = .work
        remainingSeconds = workMinutes * 60
    }

    func skip() {
        ticker?.cancel()
        ticker = nil
        advancePhase()
    }

    private func scheduleTick() {
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            advancePhase()
        }
    }

    private func advancePhase() {
        if phase == .work {
            completedSessions += 1
            phase = .shortBreak
            remainingSeconds = breakMinutes * 60
            state = .running
            scheduleTick()
        } else {
            phase = .work
            remainingSeconds = workMinutes * 60
            state = .idle
        }
    }
}
