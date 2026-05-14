import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        statusLabel
        Divider()
        Button("Open Setup…") {
            NotificationCenter.default.post(name: AppDelegate.openSetupNotification, object: nil)
        }
        if state.isFullyConfigured {
            Text("Hold Right Option to dictate")
                .font(.caption)
        }
        Divider()
        Button("Quit MyWhisper") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state.dictation {
        case .idle:
            Label(state.isFullyConfigured ? "Idle — ready" : "Setup required",
                  systemImage: state.isFullyConfigured ? "circle" : "exclamationmark.circle")
        case .recording:
            Label("Recording…", systemImage: "mic.fill")
        case .transcribing:
            Label("Transcribing…", systemImage: "waveform")
        case .typing:
            Label("Typing…", systemImage: "keyboard")
        case .noSpeech:
            Label("No speech detected", systemImage: "mic.badge.xmark")
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
        }
    }
}
