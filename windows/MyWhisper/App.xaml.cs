using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using Hardcodet.Wpf.TaskbarNotification;
using MyWhisper.Models;
using MyWhisper.Services;
using MyWhisper.Views;

namespace MyWhisper;

public partial class App : Application
{
    private const string SingleInstanceMutexName = "MyWhisper.SingleInstance.Mutex";

    private Mutex? _singleInstanceMutex;
    private AppState? _state;
    private TaskbarIcon? _tray;
    private SetupWindow? _setupWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Single-instance guard — a tray app should only ever run once.
        _singleInstanceMutex = new Mutex(initiallyOwned: true, SingleInstanceMutexName, out bool isNew);
        if (!isNew)
        {
            MessageBox.Show("MyWhisper is already running (look in the system tray).",
                "MyWhisper", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        DispatcherUnhandledException += (_, args) =>
        {
            Log.Error($"Unhandled exception: {args.Exception}");
            args.Handled = true;
        };

        _state = new AppState(Dispatcher);
        _state.PropertyChanged += OnStateChanged;

        BuildTrayIcon();

        // Bootstrap (load model, start hotkey) then show setup if needed.
        _ = BootstrapAsync();
    }

    private async Task BootstrapAsync()
    {
        try
        {
            await _state!.BootstrapAsync();
        }
        catch (Exception ex)
        {
            Log.Error($"Bootstrap failed: {ex.Message}");
        }

        if (!_state!.IsFullyConfigured)
            ShowSetupWindow();
    }

    private void BuildTrayIcon()
    {
        var menu = new ContextMenu();

        var openItem = new MenuItem { Header = "Open Setup…" };
        openItem.Click += (_, _) => ShowSetupWindow();
        menu.Items.Add(openItem);

        menu.Items.Add(new Separator());

        var quitItem = new MenuItem { Header = "Quit MyWhisper" };
        quitItem.Click += (_, _) => Shutdown();
        menu.Items.Add(quitItem);

        _tray = new TaskbarIcon
        {
            ToolTipText = "MyWhisper — hold Right Alt to dictate",
            ContextMenu = menu,
            IconSource = LoadTrayIcon()
        };
        _tray.TrayMouseDoubleClick += (_, _) => ShowSetupWindow();
    }

    private static BitmapImage? LoadTrayIcon()
    {
        try
        {
            // app.ico is copied next to the executable (see .csproj).
            string path = Path.Combine(AppContext.BaseDirectory, "Assets", "app.ico");
            if (File.Exists(path))
                return new BitmapImage(new Uri(path, UriKind.Absolute));
        }
        catch (Exception ex)
        {
            Log.Warn($"Tray icon load failed: {ex.Message}");
        }
        return null;
    }

    private void ShowSetupWindow()
    {
        if (_setupWindow is null)
        {
            _setupWindow = new SetupWindow { DataContext = _state };
            _setupWindow.Closing += (_, args) =>
            {
                // Hide instead of destroy so reopening is instant and cheap.
                args.Cancel = true;
                _setupWindow!.Hide();
            };
        }

        _setupWindow.Show();
        _setupWindow.WindowState = WindowState.Normal;
        _setupWindow.Activate();
        _setupWindow.Topmost = true;
        _setupWindow.Topmost = false;
    }

    private void OnStateChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(AppState.Dictation) && _tray is not null && _state is not null)
            _tray.ToolTipText = ToolTipFor(_state.Dictation);
    }

    private static string ToolTipFor(DictationState state) => state.Phase switch
    {
        DictationPhase.Idle => "MyWhisper — hold Right Alt to dictate",
        DictationPhase.Recording => "MyWhisper — recording…",
        DictationPhase.Transcribing => "MyWhisper — transcribing…",
        DictationPhase.Typing => "MyWhisper — typing…",
        DictationPhase.NoSpeech => "MyWhisper — no speech detected",
        DictationPhase.Error => $"MyWhisper — {state.Message}",
        _ => "MyWhisper"
    };

    protected override void OnExit(ExitEventArgs e)
    {
        _state?.Dispose();
        _tray?.Dispose();
        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }
}
