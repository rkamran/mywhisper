using System.Collections.Generic;

namespace MyWhisper.Models;

/// <summary>
/// One of the multilingual Whisper model variants the app can download from
/// Hugging Face. Larger = slower and bigger on disk, but markedly better for
/// lower-resource languages (Urdu, Hindi, Arabic, etc.).
/// </summary>
public readonly record struct WhisperModel(
    string Id,
    string DisplayName,
    string FileName,
    int SizeMB,
    int MinSizeMB)
{
    public string Url => $"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{FileName}";

    public override string ToString() => DisplayName;

    public static readonly IReadOnlyList<WhisperModel> Supported = new[]
    {
        new WhisperModel("base",           "Base · fast, small (148 MB)",                       "ggml-base.bin",            148, 100),
        new WhisperModel("small",          "Small · better non-English (488 MB)",               "ggml-small.bin",           488, 400),
        new WhisperModel("medium",         "Medium · solid quality (1.5 GB)",                   "ggml-medium.bin",         1530, 1200),
        new WhisperModel("large-v3-turbo", "Large v3 Turbo · best quality, fast (1.6 GB)",      "ggml-large-v3-turbo.bin", 1620, 1300),
        new WhisperModel("large-v3",       "Large v3 · top accuracy, slower (3 GB)",            "ggml-large-v3.bin",       3094, 2500),
    };

    public static WhisperModel ForId(string id)
    {
        foreach (var m in Supported)
            if (m.Id == id) return m;
        return Supported[0];
    }
}
