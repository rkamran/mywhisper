using System.Collections.Generic;

namespace MyWhisper.Models;

/// <summary>
/// Languages exposed in the Setup picker. <c>"auto"</c> lets whisper.cpp detect
/// the language per utterance — works well for clips longer than a couple
/// seconds; pin a specific code for reliable short utterances.
/// </summary>
public readonly record struct WhisperLanguage(string Code, string Name)
{
    public override string ToString() => Name;

    public static readonly IReadOnlyList<WhisperLanguage> Supported = new[]
    {
        new WhisperLanguage("auto", "Auto-detect"),
        new WhisperLanguage("en", "English"),
        new WhisperLanguage("es", "Spanish"),
        new WhisperLanguage("fr", "French"),
        new WhisperLanguage("de", "German"),
        new WhisperLanguage("it", "Italian"),
        new WhisperLanguage("pt", "Portuguese"),
        new WhisperLanguage("nl", "Dutch"),
        new WhisperLanguage("pl", "Polish"),
        new WhisperLanguage("ru", "Russian"),
        new WhisperLanguage("ja", "Japanese"),
        new WhisperLanguage("ko", "Korean"),
        new WhisperLanguage("zh", "Chinese"),
        new WhisperLanguage("ar", "Arabic"),
        new WhisperLanguage("hi", "Hindi"),
        new WhisperLanguage("tr", "Turkish"),
    };
}
