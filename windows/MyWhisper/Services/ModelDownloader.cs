using System;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace MyWhisper.Services;

/// <summary>
/// Downloads the multilingual ggml-base Whisper model into the per-user data
/// directory. Replaces the English-only ggml-base.en that earlier builds shipped.
/// </summary>
public sealed class ModelDownloader
{
    public const string ModelFileName = "ggml-base.bin";

    /// <summary>Pre-multilingual filename, cleaned up after a successful new download.</summary>
    public const string LegacyEnglishModelFileName = "ggml-base.en.bin";

    private const string RemoteUrl =
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin";

    // ggml-base.bin is ~148 MB; reject obvious truncations.
    private const long MinValidSize = 50_000_000;

    public static string LocalPath => Path.Combine(AppPaths.DataDirectory, ModelFileName);
    private static string LegacyLocalPath => Path.Combine(AppPaths.DataDirectory, LegacyEnglishModelFileName);

    public static bool IsDownloaded
    {
        get
        {
            var info = new FileInfo(LocalPath);
            return info.Exists && info.Length > MinValidSize;
        }
    }

    /// <summary>
    /// Downloads the model, reporting fractional progress (0..1). Writes to a
    /// temp file first and moves it into place only on success.
    /// </summary>
    public async Task DownloadAsync(IProgress<double> progress, CancellationToken ct = default)
    {
        using var http = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
        using var response = await http.GetAsync(
            RemoteUrl, HttpCompletionOption.ResponseHeadersRead, ct);
        response.EnsureSuccessStatusCode();

        long? total = response.Content.Headers.ContentLength;
        string tempPath = LocalPath + ".part";

        await using (var source = await response.Content.ReadAsStreamAsync(ct))
        await using (var dest = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None))
        {
            var buffer = new byte[81920];
            long written = 0;
            int read;
            while ((read = await source.ReadAsync(buffer, ct)) > 0)
            {
                await dest.WriteAsync(buffer.AsMemory(0, read), ct);
                written += read;
                if (total is > 0)
                    progress.Report((double)written / total.Value);
            }
        }

        if (File.Exists(LocalPath))
            File.Delete(LocalPath);
        File.Move(tempPath, LocalPath);

        // Best-effort cleanup of the old English-only model (~141 MB).
        try
        {
            if (File.Exists(LegacyLocalPath))
                File.Delete(LegacyLocalPath);
        }
        catch { /* harmless if it lingers */ }

        progress.Report(1.0);
    }
}
