import SwiftUI

private struct CommandReturnHandler: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onKeyPress(.return, phases: .down) { event in
                guard event.modifiers.contains(.command) else { return .ignored }
                action()
                return .handled
            }
        } else {
            content
        }
    }
}

struct RoamCaptureView: View {
    @StateObject var vm: NotchViewModel
    @StateObject var config = RoamConfig.shared

    @State private var text: String = ""
    @State private var isSending = false
    @State private var sendError: String? = nil
    @State private var didSucceed = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        Group {
            if config.isConfigured {
                captureUI
            } else {
                unconfiguredPrompt
            }
        }
        .onAppear { editorFocused = true }
    }

    // MARK: - Main capture UI

    private var captureUI: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Capture a thought… (Tab to indent)")
                        .foregroundStyle(.tertiary)
                        .font(.system(.body, design: .rounded))
                        .padding(.top, 1)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .font(.system(.body, design: .rounded))
                    .focused($editorFocused)
                    .modifier(CommandReturnHandler(action: send))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                if let error = sendError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if didSucceed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
                sendButton
            }
            .animation(vm.animation, value: didSucceed)
            .animation(vm.animation, value: sendError)
        }
    }

    private var sendButton: some View {
        Button(action: send) {
            HStack(spacing: 4) {
                if isSending {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text(isSending ? "Sending…" : "⌘↩  Send to Roam")
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(sendEnabled ? 0.12 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(sendEnabled ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!sendEnabled)
    }

    private var sendEnabled: Bool {
        !isSending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Not configured

    private var unconfiguredPrompt: some View {
        VStack(spacing: 4) {
            Text("Roam not configured")
                .font(.system(.body, design: .rounded, weight: .medium))
            Text("Add your graph name and API token in Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Send

    private func send() {
        let blocks = parseBlocks(text)
        guard !blocks.isEmpty, let api = config.api else { return }

        isSending = true
        sendError = nil

        Task {
            do {
                try await api.sendCapture(blocks)
                await MainActor.run {
                    isSending = false
                    didSucceed = true
                    text = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        didSucceed = false
                        vm.notchClose()
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    sendError = error.localizedDescription
                }
            }
        }
    }

    // Parses text into blocks, using leading tab count as indent level.
    private func parseBlocks(_ raw: String) -> [RoamAPI.CaptureBlock] {
        raw.components(separatedBy: .newlines)
            .compactMap { line -> RoamAPI.CaptureBlock? in
                let indent = line.prefix(while: { $0 == "\t" }).count
                let stripped = String(line.drop(while: { $0 == "\t" }))
                guard !stripped.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                return RoamAPI.CaptureBlock(text: stripped, indent: indent)
            }
    }
}

#Preview {
    RoamCaptureView(vm: .init())
        .padding()
        .frame(width: 600, height: 120)
        .background(.black)
        .preferredColorScheme(.dark)
}
