using System.Text;
using Whisper.net;

namespace MyWhisper.Services;

/// <summary>
/// Wraps Whisper.net (whisper.cpp) for local English transcription.
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
    /// Transcribes 16 kHz mono float samples. Returns the concatenated segment
    /// text, trimmed. Safe to call from a background thread.
    /// </summary>
    public async Task<string> TranscribeAsync(float[] samples, CancellationToken ct = default)
    {
        if (samples.Length == 0)
            return string.Empty;

        // A processor is cheap; build a fresh one per call so state never leaks
        // between sessions.
        WhisperProcessor processor;
        lock (_gate)
        {
            processor = _factory.CreateBuilder()
                .WithLanguage("en")
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
