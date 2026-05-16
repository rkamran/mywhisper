using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using MyWhisper.Services;

namespace MyWhisper.Views;

public partial class SetupWindow : Window
{
    public SetupWindow()
    {
        InitializeComponent();
    }

    private AppState? State => DataContext as AppState;

    private async void OnDownloadModel(object sender, RoutedEventArgs e)
    {
        if (State is null)
            return;
        DownloadButton.IsEnabled = false;
        try
        {
            await State.DownloadModelAsync();
        }
        finally
        {
            DownloadButton.IsEnabled = true;
        }
    }

    private void OnRefreshDevices(object sender, RoutedEventArgs e)
        => State?.RefreshInputDevices();

    private void OnUseSystemDefault(object sender, RoutedEventArgs e)
    {
        if (State is not null)
            State.SelectedInputDeviceId = null;
    }

    private void OnSaveApiKey(object sender, RoutedEventArgs e)
    {
        if (State is null)
            return;
        string key = ApiKeyBox.Password;
        if (string.IsNullOrWhiteSpace(key))
            return;
        State.SetPolishApiKey(key);
        ApiKeyBox.Clear();
    }

    private void OnRemoveApiKey(object sender, RoutedEventArgs e)
    {
        State?.SetPolishApiKey(null);
        ApiKeyBox.Clear();
    }

    private void OnOpenMicSettings(object sender, RoutedEventArgs e)
    {
        try
        {
            // Opens Settings → Privacy → Microphone so the user can confirm
            // desktop apps are allowed to use the mic.
            Process.Start(new ProcessStartInfo("ms-settings:privacy-microphone")
            {
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Log.Warn($"Could not open microphone settings: {ex.Message}");
        }
    }

    private void OnOpenLicenses(object sender, RoutedEventArgs e)
    {
        // THIRD_PARTY_LICENSES.md is copied next to MyWhisper.exe by
        // package.ps1; Inno Setup ships it inside the install directory too.
        // Fall back to the canonical GitHub copy if it's not on disk.
        string localPath = Path.Combine(AppContext.BaseDirectory, "THIRD_PARTY_LICENSES.md");
        string target = File.Exists(localPath)
            ? localPath
            : "https://github.com/rkamran/mywhisper/blob/main/THIRD_PARTY_LICENSES.md";
        try
        {
            Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            Log.Warn($"Could not open licenses ({target}): {ex.Message}");
        }
    }
}
