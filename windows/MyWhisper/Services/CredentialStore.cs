using System.Security.Cryptography;
using System.Text;

namespace MyWhisper.Services;

/// <summary>
/// At-rest storage for the polish API key. The key is encrypted with DPAPI
/// (per-user scope) and written to %LOCALAPPDATA%\MyWhisper — equivalent in
/// intent to the macOS Keychain-backed store.
/// </summary>
public static class CredentialStore
{
    private static string KeyFilePath => Path.Combine(AppPaths.DataDirectory, "polish-key.dat");

    // Extra entropy mixed into DPAPI so the blob is only meaningful to this app.
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("com.mywhisper.ollama");

    public static bool HasApiKey => File.Exists(KeyFilePath);

    public static void SetApiKey(string? key)
    {
        if (string.IsNullOrWhiteSpace(key))
        {
            if (File.Exists(KeyFilePath))
                File.Delete(KeyFilePath);
            return;
        }

        byte[] plaintext = Encoding.UTF8.GetBytes(key);
        byte[] encrypted = ProtectedData.Protect(plaintext, Entropy, DataProtectionScope.CurrentUser);
        File.WriteAllBytes(KeyFilePath, encrypted);
    }

    public static string? GetApiKey()
    {
        if (!File.Exists(KeyFilePath))
            return null;
        try
        {
            byte[] encrypted = File.ReadAllBytes(KeyFilePath);
            byte[] plaintext = ProtectedData.Unprotect(encrypted, Entropy, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(plaintext);
        }
        catch
        {
            // Corrupt or unreadable (e.g. copied from another user profile).
            return null;
        }
    }
}
