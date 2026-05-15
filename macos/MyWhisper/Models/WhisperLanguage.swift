import Foundation

/// Languages exposed in the Setup picker. `auto` lets whisper.cpp detect the
/// language per utterance — works well for clips longer than a couple seconds.
struct WhisperLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let supported: [WhisperLanguage] = [
        .init(code: "auto", name: "Auto-detect"),
        .init(code: "en", name: "English"),
        .init(code: "es", name: "Spanish"),
        .init(code: "fr", name: "French"),
        .init(code: "de", name: "German"),
        .init(code: "it", name: "Italian"),
        .init(code: "pt", name: "Portuguese"),
        .init(code: "nl", name: "Dutch"),
        .init(code: "pl", name: "Polish"),
        .init(code: "ru", name: "Russian"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "zh", name: "Chinese"),
        .init(code: "ar", name: "Arabic"),
        .init(code: "hi", name: "Hindi"),
        .init(code: "tr", name: "Turkish"),
    ]

    static func displayName(for code: String) -> String {
        supported.first(where: { $0.code == code })?.name ?? code
    }
}
