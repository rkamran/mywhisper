namespace MyWhisper.Services;

/// <summary>Resolves the per-user data directory for MyWhisper.</summary>
public static class AppPaths
{
    /// <summary>%LOCALAPPDATA%\MyWhisper, created on first access.</summary>
    public static string DataDirectory
    {
        get
        {
            string dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "MyWhisper");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }
}
