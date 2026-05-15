using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Whisper.net;

namespace MyWhisper.Services;

/// <summary>
/// Wraps Whisper.net (whisper.cpp) for local multilingual transcription.
/// One instance owns the loaded model; reuse it across dictation sessions.
/// </summary>
public sealed class WhisperEngine : IDisposable
{
    private readonly WhisperFactory _factory;
    private readonly object _gate = new();

    public WhisperEngine(string modelPath)
    {
        if (!File.Exists(modelPath))
            throw new FileNotFoundException("Whisper model not found", modelPath);

        // FromPath loads the ggml model and selects the native runtime shipped
        // by the Whisper.net.Runtime package.
        _factory = WhisperFactory.FromPath(modelPath);
    }

    /// <summary>
    /// Transcribes 16 kHz mono float samples in the given <paramref name="language"/>.
    /// Pass <c>"auto"</c> to let whisper.cpp detect the language per utterance.
    /// </summary>
    public async Task<string> TranscribeAsync(float[] samples, string language, CancellationToken ct = default)
    {
        if (samples.Length == 0)
            return string.Empty;

        string lang = string.IsNullOrWhiteSpace(language) ? "auto" : language;

        // A processor is cheap; build a fresh one per call so state never leaks
        // between sessions.
        WhisperProcessor processor;
        lock (_gate)
        {
            processor = _factory.CreateBuilder()
                .WithLanguage(lang)
                .WithNoContext()
                .Build();
        }

        var sb = new StringBuilder();
        await using (processor)
        {
            await foreach (var segment in processor.ProcessAsync(samples, ct))
                sb.Append(segment.Text);
        }

        return sb.ToString().Trim();
    }

    public void Dispose() => _factory.Dispose();
}
