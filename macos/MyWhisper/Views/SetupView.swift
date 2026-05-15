import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    micRow
                    accessibilityRow
                    modelRow
                    polishRow
                    if state.isFullyConfigured {
                        readyCard
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 520, minHeight: 480)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("MyWhisper").font(.title2).bold()
                Text("Hold Right Option to dictate anywhere.").foregroundStyle(.secondary).font(.caption)
            }
            Spacer()
        }
        .padding(20)
    }

    private var micRow: some View {
        SetupStep(
            number: 1,
            title: "Microphone access",
            description: "Required to capture your speech for transcription.",
            status: state.micPermission.statusBadge
        ) {
            switch state.micPermission {
            case .granted:
                deviceSelector
            case .denied:
                Button("Open System Settings") { openMicPrivacySettings() }
            case .unknown:
                Button("Grant microphone access") {
                    Task { await state.requestMicPermission() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var deviceSelector: some View {
        let selection = Binding<String?>(
            get: { state.selectedInputDeviceUID },
            set: { state.selectedInputDeviceUID = $0 }
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Input device")
                Picker("", selection: selection) {
                    Text("System default").tag(String?.none)
                    if !state.availableInputDevices.isEmpty {
                        Divider()
                        ForEach(state.availableInputDevices) { device in
                            Text(device.name).tag(String?(device.uid))
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 220, alignment: .leading)
                Button {
                    state.refreshInputDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh device list")
            }
            if state.availableInputDevices.isEmpty {
                Text("No input devices detected yet. Plug in a mic or click refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Pick the mic Wispr-style apps don't capture from. \"System default\" follows whatever is selected in Sound preferences.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accessibilityRow: some View {
        SetupStep(
            number: 2,
            title: "Accessibility access",
            description: "Lets MyWhisper read the Right Option key and paste transcribed text into the focused field.",
            status: state.accessibilityGranted ? StatusBadge(text: "Granted", color: .green) : StatusBadge(text: "Required", color: .orange)
        ) {
            if !state.accessibilityGranted {
                HStack(spacing: 8) {
                    Button("Request access") { state.promptAccessibility() }
                        .buttonStyle(.borderedProminent)
                    Button("Open System Settings") { openAccessibilitySettings() }
                    Button("Re-check now") { state.refreshAccessibility() }
                }
                Text("If you've already enabled MyWhisper in System Settings but this still shows orange, the entry is for an old build path. See README — run `scripts/install.sh` to install to /Applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Running from: \(Bundle.main.bundlePath)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }

    private var modelRow: some View {
        SetupStep(
            number: 3,
            title: "Whisper model",
            description: "Bigger models transcribe lower-resource languages (Urdu, Hindi, Arabic, …) much more accurately. Each model downloads once to ~/Library/Application Support/MyWhisper and runs locally.",
            status: state.modelDownloaded ? StatusBadge(text: "Ready", color: .green) : StatusBadge(text: "Not downloaded", color: .orange)
        ) {
            modelPicker

            if !state.modelDownloaded {
                if state.modelDownloadProgress > 0 && state.modelDownloadProgress < 1 {
                    ProgressView(value: state.modelDownloadProgress)
                        .progressViewStyle(.linear)
                    Text("\(Int(state.modelDownloadProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Button("Download \(state.selectedModel.displayName.prefix(while: { $0 != " " }))") {
                        Task { await state.downloadModel() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                HStack(spacing: 8) {
                    Button("Re-download") {
                        try? FileManager.default.removeItem(at: ModelDownloader.localPath(for: state.selectedModel))
                        state.refreshModelStatus()
                    }
                    .controlSize(.small)
                    Text("Using \(state.selectedModel.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                languagePicker
            }
        }
    }

    private var modelPicker: some View {
        let binding = Binding(
            get: { state.selectedModelID },
            set: { state.selectedModelID = $0 }
        )
        return HStack(spacing: 8) {
            Text("Size")
            Picker("", selection: binding) {
                ForEach(WhisperModel.supported) { model in
                    Text(model.displayName).tag(model.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(minWidth: 320, alignment: .leading)
        }
    }

    private var languagePicker: some View {
        let binding = Binding(
            get: { state.selectedLanguage },
            set: { state.selectedLanguage = $0 }
        )
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Language")
                Picker("", selection: binding) {
                    ForEach(WhisperLanguage.supported) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 200, alignment: .leading)
            }
            Text("Auto-detect works for clips longer than a couple seconds. Pin a specific language for more reliable short utterances.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var polishRow: some View {
        let toggleBinding = Binding(
            get: { state.polishEnabled },
            set: { state.polishEnabled = $0 }
        )
        let endpointBinding = Binding(
            get: { state.polishEndpoint },
            set: { state.polishEndpoint = $0 }
        )
        let modelBinding = Binding(
            get: { state.polishModel },
            set: { state.polishModel = $0 }
        )

        return SetupStep(
            number: 4,
            title: "Polish transcripts (optional)",
            description: "Send the raw Whisper transcript to an OpenAI-compatible chat endpoint (Ollama Cloud by default) to fix punctuation, capitalization, and infer list/heading formatting.",
            status: state.polishEnabled
                ? (state.polishAPIKeyPresent ? StatusBadge(text: "On", color: .green) : StatusBadge(text: "Needs key", color: .orange))
                : StatusBadge(text: "Off", color: .secondary)
        ) {
            Toggle("Polish transcripts before pasting", isOn: toggleBinding)

            if state.polishEnabled {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        Text("Endpoint").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                        TextField("https://…/v1/chat/completions", text: endpointBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Model").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                        TextField("gpt-oss:20b", text: modelBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("API key").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                        apiKeyField
                    }
                }
                Text("Keys are stored in macOS Keychain. If the polish call fails or times out (>3s), the raw transcript is pasted instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !state.lastRawTranscript.isEmpty && state.lastRawTranscript != state.lastTranscript {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last raw:").font(.caption.weight(.semibold))
                        Text(state.lastRawTranscript).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text("Last polished:").font(.caption.weight(.semibold))
                        Text(state.lastTranscript).font(.caption.monospaced())
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    @State private var apiKeyDraft: String = ""

    private var apiKeyField: some View {
        HStack(spacing: 6) {
            SecureField(state.polishAPIKeyPresent ? "•••••••• (stored)" : "Paste API key", text: $apiKeyDraft)
                .textFieldStyle(.roundedBorder)
            Button("Save") {
                state.setPolishAPIKey(apiKeyDraft)
                apiKeyDraft = ""
            }
            .disabled(apiKeyDraft.isEmpty)
            if state.polishAPIKeyPresent {
                Button(role: .destructive) {
                    state.setPolishAPIKey(nil)
                } label: {
                    Image(systemName: "trash")
                }
                .help("Remove stored API key")
            }
        }
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ready to dictate", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("Place your cursor in any text field, hold the **Right Option** key, speak, and release. Your words will paste in.")
                .foregroundStyle(.secondary)
            if state.totalTranscriptions > 0 {
                Text("Last transcription: \(state.lastTranscript)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Color.green.opacity(0.3))
        )
    }

    private func openMicPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct SetupStep<Content: View>: View {
    let number: Int
    let title: String
    let description: String
    let status: StatusBadge
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.15)).frame(width: 28, height: 28)
                Text("\(number)").font(.callout.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    status
                }
                Text(description).foregroundStyle(.secondary).font(.subheadline)
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15)))
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

private extension PermissionState {
    var statusBadge: StatusBadge {
        switch self {
        case .granted: return StatusBadge(text: "Granted", color: .green)
        case .denied: return StatusBadge(text: "Denied", color: .red)
        case .unknown: return StatusBadge(text: "Required", color: .orange)
        }
    }
}
