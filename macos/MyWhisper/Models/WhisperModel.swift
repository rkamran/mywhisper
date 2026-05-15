import Foundation

/// One of the multilingual Whisper model variants the app can download from
/// Hugging Face. Larger = slower and bigger on disk, but markedly better for
/// lower-resource languages (Urdu, Hindi, Arabic, etc.).
struct WhisperModel: Identifiable, Hashable {
    /// Stable storage key (also used for UserDefaults).
    let id: String
    /// Shown in the picker.
    let displayName: String
    /// On-disk filename inside ~/Library/Application Support/MyWhisper.
    let fileName: String
    /// Approximate download size in MB, for UI.
    let sizeMB: Int
    /// Sanity-check floor in MB — guards against truncated downloads.
    let minSizeMB: Int

    var url: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    static let supported: [WhisperModel] = [
        .init(id: "base",            displayName: "Base · fast, small (148 MB)",                      fileName: "ggml-base.bin",            sizeMB:  148, minSizeMB:  100),
        .init(id: "small",           displayName: "Small · better non-English (488 MB)",              fileName: "ggml-small.bin",           sizeMB:  488, minSizeMB:  400),
        .init(id: "medium",          displayName: "Medium · solid quality (1.5 GB)",                  fileName: "ggml-medium.bin",          sizeMB: 1530, minSizeMB: 1200),
        .init(id: "large-v3-turbo",  displayName: "Large v3 Turbo · best quality, fast (1.6 GB)",     fileName: "ggml-large-v3-turbo.bin",  sizeMB: 1620, minSizeMB: 1300),
        .init(id: "large-v3",        displayName: "Large v3 · top accuracy, slower (3 GB)",           fileName: "ggml-large-v3.bin",        sizeMB: 3094, minSizeMB: 2500),
    ]

    static func model(id: String) -> WhisperModel {
        supported.first(where: { $0.id == id }) ?? supported[0]
    }
}
