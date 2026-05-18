import Foundation
import SwiftUI
import AVFoundation
import OSLog

private let log = Logger(subsystem: "com.mywhisper.app", category: "AppState")

enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case typing
    case noSpeech
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    private static let selectedDeviceUIDKey = "selectedInputDeviceUID"
    private static let selectedLanguageKey  = "selectedLanguage"
    private static let selectedModelIDKey   = "selectedModelID"
    private static let polishEnabledKey      = "polishEnabled"
    private static let polishEndpointKey     = "polishEndpoint"
    private static let polishModelKey        = "polishModel"

    @Published var dictation: DictationState = .idle
    @Published var micPermission: PermissionState = .unknown
    @Published var accessibilityGranted: Bool = false
    @Published var modelDownloaded: Bool = false
    @Published var modelDownloadProgress: Double = 0
    @Published var lastTranscript: String = ""
    @Published var lastRawTranscript: String = ""
    @Published var totalTranscriptions: Int = 0
    @Published var availableInputDevices: [AudioInputDevice] = []
    @Published var selectedInputDeviceUID: String? {
        didSet { UserDefaults.standard.set(selectedInputDeviceUID, forKey: Self.selectedDeviceUIDKey) }
    }
    @Published var selectedLanguage: String = "auto" {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: Self.selectedLanguageKey) }
    }
    @Published var selectedModelID: String = "base" {
        didSet {
            UserDefaults.standard.set(selectedModelID, forKey: Self.selectedModelIDKey)
            Task { @MainActor in await self.onSelectedModelChanged() }
        }
    }

    var selectedModel: WhisperModel { WhisperModel.model(id: selectedModelID) }

    /// Name of the system default input device, or nil if unavailable.
    var defaultInputDeviceName: String? {
        AudioDeviceProbe.defaultInputDeviceName()
    }

    /// Human-readable name of the active input device.
    var activeInputDeviceName: String {
        if let uid = selectedInputDeviceUID,
           let device = availableInputDevices.first(where: { $0.uid == uid }) {
            return device.name
        }
        return defaultInputDeviceName ?? "Unknown"
    }

    @Published var polishEnabled: Bool = false {
        didSet { UserDefaults.standard.set(polishEnabled, forKey: Self.polishEnabledKey) }
    }
    @Published var polishEndpoint: String = "https://ollama.com/v1/chat/completions" {
        didSet { UserDefaults.standard.set(polishEndpoint, forKey: Self.polishEndpointKey) }
    }
    @Published var polishModel: String = "gpt-oss:20b" {
        didSet { UserDefaults.standard.set(polishModel, forKey: Self.polishModelKey) }
    }
    @Published var polishAPIKeyPresent: Bool = false

    private let recorder = AudioRecorder()
    private var whisper: WhisperEngine?
    private let hotkey = HotkeyMonitor()
    private let downloader = ModelDownloader()
    private var permissionPollTimer: Timer?

    private init() {
        let defaults = UserDefaults.standard
        self.selectedInputDeviceUID = defaults.string(forKey: Self.selectedDeviceUIDKey)
        if let lang = defaults.string(forKey: Self.selectedLanguageKey), !lang.isEmpty {
            self.selectedLanguage = lang
        }
        if let mid = defaults.string(forKey: Self.selectedModelIDKey), !mid.isEmpty {
            self.selectedModelID = mid
        }
        self.polishEnabled  = defaults.bool(forKey: Self.polishEnabledKey)
        if let ep = defaults.string(forKey: Self.polishEndpointKey), !ep.isEmpty {
            self.polishEndpoint = ep
        }
        if let m = defaults.string(forKey: Self.polishModelKey), !m.isEmpty {
            self.polishModel = m
        }
        self.polishAPIKeyPresent = KeychainStore.apiKey() != nil
    }

    func setPolishAPIKey(_ key: String?) {
        KeychainStore.setAPIKey(key)
        polishAPIKeyPresent = KeychainStore.apiKey() != nil
    }

    private func polishIfEnabled(_ raw: String) async -> String {
        guard polishEnabled, polishAPIKeyPresent,
              let url = URL(string: polishEndpoint),
              let key = KeychainStore.apiKey() else { return raw }

        let config = PolisherConfig(endpoint: url, model: polishModel, apiKey: key, timeout: 3.0)
        do {
            let polished = try await Polisher.polish(raw, config: config)
            return polished.isEmpty ? raw : polished
        } catch {
            log.error("polish failed, falling back to raw: \(error.localizedDescription, privacy: .public)")
            return raw
        }
    }

    var isFullyConfigured: Bool {
        micPermission == .granted && accessibilityGranted && modelDownloaded
    }

    var menuBarSymbol: String {
        switch dictation {
        case .idle: return isFullyConfigured ? "mic" : "mic.slash"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .typing: return "keyboard"
        case .noSpeech: return "mic.badge.xmark"
        case .error: return "exclamationmark.triangle"
        }
    }

    func bootstrap() async {
        refreshMicPermission()
        refreshAccessibility()
        refreshModelStatus()
        refreshInputDevices()
        startPermissionPolling()
        if modelDownloaded {
            await loadWhisper()
        }
        if isFullyConfigured {
            startHotkey()
        }
    }

    func refreshInputDevices() {
        availableInputDevices = AudioDeviceProbe.listInputDevices()
        // Drop the selection if the device went away.
        if let uid = selectedInputDeviceUID, !availableInputDevices.contains(where: { $0.uid == uid }) {
            selectedInputDeviceUID = nil
        }
    }

    func refreshMicPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: micPermission = .granted
        case .denied, .restricted: micPermission = .denied
        case .notDetermined: micPermission = .unknown
        @unknown default: micPermission = .unknown
        }
    }

    func requestMicPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        micPermission = granted ? .granted : .denied
        if granted {
            refreshInputDevices()
        }
        await reconcile()
        // The system permission dialog steals focus; bring the setup window back.
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: AppDelegate.openSetupNotification, object: nil)
    }

    func refreshAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func promptAccessibility() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    func refreshModelStatus() {
        modelDownloaded = ModelDownloader.isDownloaded(selectedModel)
    }

    func downloadModel() async {
        let target = selectedModel
        modelDownloadProgress = 0
        do {
            try await downloader.download(model: target) { [weak self] progress in
                Task { @MainActor in self?.modelDownloadProgress = progress }
            }
            // Only flip downloaded=true if the user is still on the same model.
            if selectedModelID == target.id {
                modelDownloaded = true
                modelDownloadProgress = 1.0
                await loadWhisper()
                await reconcile()
            }
        } catch {
            dictation = .error("Model download failed: \(error.localizedDescription)")
        }
    }

    private func loadWhisper() async {
        let path = ModelDownloader.localPath(for: selectedModel).path
        do {
            whisper = try WhisperEngine(modelPath: path)
            log.info("loaded whisper model: \(self.selectedModelID, privacy: .public)")
        } catch {
            dictation = .error("Failed to load model: \(error.localizedDescription)")
        }
    }

    /// Called whenever the user picks a different model in the picker.
    /// If the new model is already downloaded, swap the whisper engine; otherwise
    /// surface the Download button by clearing the downloaded flag.
    private func onSelectedModelChanged() async {
        whisper = nil
        modelDownloadProgress = 0
        refreshModelStatus()
        if modelDownloaded {
            await loadWhisper()
        }
        await reconcile()
    }

    private func reconcile() async {
        if isFullyConfigured {
            startHotkey()
        }
    }

    private func startHotkey() {
        hotkey.onPress = { [weak self] in
            Task { @MainActor in await self?.beginRecording() }
        }
        hotkey.onRelease = { [weak self] in
            Task { @MainActor in await self?.endRecordingAndTranscribe() }
        }
        do {
            try hotkey.start()
        } catch {
            dictation = .error("Hotkey monitor failed: \(error.localizedDescription)")
        }
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let wasGranted = self.accessibilityGranted
                self.refreshAccessibility()
                if !wasGranted && self.accessibilityGranted {
                    await self.reconcile()
                }
            }
        }
    }

    private func beginRecording() async {
        guard isFullyConfigured else {
            log.warning("beginRecording: not fully configured (mic=\(String(describing: self.micPermission), privacy: .public), a11y=\(self.accessibilityGranted, privacy: .public), model=\(self.modelDownloaded, privacy: .public))")
            return
        }
        guard whisper != nil else {
            log.error("beginRecording: whisper engine not loaded")
            dictation = .error("Whisper model not loaded")
            return
        }
        guard dictation == .idle || dictation == .noSpeech else {
            log.debug("beginRecording: skipped, state=\(String(describing: self.dictation), privacy: .public)")
            return
        }
        do {
            let deviceID = selectedInputDeviceUID.flatMap(AudioDeviceProbe.deviceID(forUID:))
            try recorder.start(deviceID: deviceID)
            dictation = .recording
            log.info("recording started")
        } catch {
            log.error("recording failed to start: \(error.localizedDescription, privacy: .public)")
            dictation = .error("Recording failed: \(error.localizedDescription)")
        }
    }

    private func endRecordingAndTranscribe() async {
        guard dictation == .recording else {
            log.debug("endRecording: not recording (state=\(String(describing: self.dictation), privacy: .public))")
            return
        }
        let samples = recorder.stop()
        let duration = Double(samples.count) / 16_000.0
        let (rms, peak) = Self.amplitude(samples)
        log.info("recording stopped: \(samples.count, privacy: .public) samples (\(String(format: "%.2f", duration), privacy: .public)s) rms=\(String(format: "%.4f", rms), privacy: .public) peak=\(String(format: "%.4f", peak), privacy: .public)")

        guard samples.count > 16_000 / 4 else {
            log.notice("samples too short, ignoring")
            dictation = .noSpeech
            try? await Task.sleep(nanoseconds: 800_000_000)
            dictation = .idle
            return
        }
        if peak < 0.005 {
            log.notice("audio is near silent (peak=\(String(format: "%.4f", peak), privacy: .public)). Mic not capturing.")
        }
        dictation = .transcribing
        let engine = whisper
        let language = selectedLanguage
        let raw: String = await Task.detached(priority: .userInitiated) { [samples, language] in
            guard let engine else { return "" }
            do {
                return try engine.transcribe(samples: samples, language: language)
            } catch {
                log.error("whisper transcribe threw: \(error.localizedDescription, privacy: .public)")
                return ""
            }
        }.value
        log.info("whisper raw (\(language, privacy: .public)): \"\(raw, privacy: .public)\"")

        let cleaned = Self.clean(raw)
        guard !cleaned.isEmpty else {
            log.notice("transcript empty after cleaning, no paste")
            dictation = .noSpeech
            try? await Task.sleep(nanoseconds: 800_000_000)
            dictation = .idle
            return
        }
        lastRawTranscript = cleaned

        dictation = .transcribing
        let polished = await polishIfEnabled(cleaned)

        dictation = .typing
        lastTranscript = polished
        totalTranscriptions += 1
        log.info("pasting: \"\(polished, privacy: .public)\"")
        TextInjector.paste(polished)
        try? await Task.sleep(nanoseconds: 250_000_000)
        dictation = .idle
    }

    private static func amplitude(_ samples: [Float]) -> (rms: Float, peak: Float) {
        guard !samples.isEmpty else { return (0, 0) }
        var sumSq: Float = 0
        var peak: Float = 0
        for s in samples {
            sumSq += s * s
            let a = abs(s)
            if a > peak { peak = a }
        }
        return (sqrt(sumSq / Float(samples.count)), peak)
    }

    private static func clean(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Whisper sometimes emits "[BLANK_AUDIO]" or "(silence)" for empty input.
        let junk = ["[BLANK_AUDIO]", "[silence]", "(silence)", "[ Silence ]", "[no audio]"]
        for j in junk where text.localizedCaseInsensitiveContains(j) {
            text = text.replacingOccurrences(of: j, with: "", options: .caseInsensitive)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum PermissionState {
    case unknown
    case granted
    case denied
}
