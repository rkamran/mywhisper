using System;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using MyWhisper.Models;

namespace MyWhisper.Services;

/// <summary>
/// Downloads a chosen multilingual Whisper model into the per-user data directory.
/// </summary>
public sealed class ModelDownloader
{
    /// <summary>Pre-multilingual filename, cleaned up once any new model lands.</summary>
    public const string LegacyEnglishModelFileName = "ggml-base.en.bin";

    public static string LocalPath(WhisperModel model)
        => Path.Combine(AppPaths.DataDirectory, model.FileName);

    public static bool IsDownloaded(WhisperModel model)
    {
        var info = new FileInfo(LocalPath(model));
        return info.Exists && info.Length >= (long)model.MinSizeMB * 1024 * 1024;
    }

    /// <summary>
    /// Downloads <paramref name="model"/>, reporting fractional progress (0..1).
    /// Writes to a temp file first and moves it into place only on success.
    /// </summary>
    public async Task DownloadAsync(WhisperModel model, IProgress<double> progress, CancellationToken ct = default)
    {
        using var http = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
        using var response = await http.GetAsync(
            model.Url, HttpCompletionOption.ResponseHeadersRead, ct);
        response.EnsureSuccessStatusCode();

        long? total = response.Content.Headers.ContentLength;
        string finalPath = LocalPath(model);
        string tempPath = finalPath + ".part";

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

        if (File.Exists(finalPath))
            File.Delete(finalPath);
        File.Move(tempPath, finalPath);

        // Best-effort cleanup of the old English-only model (~141 MB).
        try
        {
            string legacy = Path.Combine(AppPaths.DataDirectory, LegacyEnglishModelFileName);
            if (File.Exists(legacy))
                File.Delete(legacy);
        }
        catch { /* harmless if it lingers */ }

        progress.Report(1.0);
    }
}
