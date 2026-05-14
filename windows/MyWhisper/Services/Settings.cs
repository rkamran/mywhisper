using System;
using System.IO;
using System.Text.Json;

namespace MyWhisper.Services;

/// <summary>
/// User preferences persisted as JSON in %LOCALAPPDATA%\MyWhisper\settings.json.
/// The polish API key is NOT stored here — see <see cref="CredentialStore"/>.
/// </summary>
public sealed class Settings
{
    public string? SelectedInputDeviceId { get; set; }
    public bool PolishEnabled { get; set; }
    public string PolishEndpoint { get; set; } = "https://ollama.com/v1/chat/completions";
    public string PolishModel { get; set; } = "gpt-oss:20b";

    private static string FilePath => Path.Combine(AppPaths.DataDirectory, "settings.json");

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public static Settings Load()
    {
        try
        {
            if (File.Exists(FilePath))
            {
                string json = File.ReadAllText(FilePath);
                return JsonSerializer.Deserialize<Settings>(json) ?? new Settings();
            }
        }
        catch (Exception ex)
        {
            Log.Warn($"Settings load failed, using defaults: {ex.Message}");
        }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this, JsonOptions));
        }
        catch (Exception ex)
        {
            Log.Warn($"Settings save failed: {ex.Message}");
        }
    }
}
