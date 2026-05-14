namespace MyWhisper.Services;

/// <summary>Downloads the ggml-base.en Whisper model into the per-user data directory.</summary>
public sealed class ModelDownloader
{
    public const string ModelFileName = "ggml-base.en.bin";

    private const string RemoteUrl =
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";

    // ggml-base.en.bin is ~141 MB; reject obvious truncations.
    private const long MinValidSize = 50_000_000;

    public static string LocalPath => Path.Combine(AppPaths.DataDirectory, ModelFileName);

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
        progress.Report(1.0);
    }
}
