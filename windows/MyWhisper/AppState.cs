using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using System.Windows.Threading;
using MyWhisper.Models;
using MyWhisper.Services;
using NAudio.CoreAudioApi;

namespace MyWhisper;

/// <summary>
/// Central observable state and orchestration: wires the hotkey monitor to the
/// record → transcribe → polish → type pipeline, and exposes everything the
/// setup window and tray icon bind to.
/// </summary>
public sealed class AppState : INotifyPropertyChanged, IDisposable
{
    private const int MinSampleCount = 16_000 / 4; // 0.25 s at 16 kHz
    private const double PolishTimeoutSeconds = 3.0;

    private readonly Dispatcher _dispatcher;
    private readonly Settings _settings;
    private readonly AudioRecorder _recorder = new();
    private readonly HotkeyMonitor _hotkey = new();
    private readonly ModelDownloader _downloader = new();
    private WhisperEngine? _whisper;

    public AppState(Dispatcher dispatcher)
    {
        _dispatcher = dispatcher;
        _settings = Settings.Load();
        _selectedInputDeviceId = _settings.SelectedInputDeviceId;
        _polishEnabled = _settings.PolishEnabled;
        _polishEndpoint = _settings.PolishEndpoint;
        _polishModel = _settings.PolishModel;
        _polishApiKeyPresent = CredentialStore.HasApiKey;

        _hotkey.Pressed += () => _dispatcher.InvokeAsync(BeginRecording);
        _hotkey.Released += () => _dispatcher.InvokeAsync(EndRecordingAndTranscribeAsync);
    }

    // ── Observable properties ───────────────────────────────────────────────

    private DictationState _dictation = DictationState.Idle;
    public DictationState Dictation { get => _dictation; private set => Set(ref _dictation, value); }

    private bool _modelDownloaded;
    public bool ModelDownloaded { get => _modelDownloaded; private set { if (Set(ref _modelDownloaded, value)) Raise(nameof(IsFullyConfigured)); } }

    private double _modelDownloadProgress;
    public double ModelDownloadProgress { get => _modelDownloadProgress; private set => Set(ref _modelDownloadProgress, value); }

    private bool _hotkeyRunning;
    public bool HotkeyRunning { get => _hotkeyRunning; private set { if (Set(ref _hotkeyRunning, value)) Raise(nameof(IsFullyConfigured)); } }

    public bool IsFullyConfigured => ModelDownloaded && HotkeyRunning;

    public ObservableCollection<AudioInputDevice> AvailableInputDevices { get; } = new();

    private string? _selectedInputDeviceId;
    public string? SelectedInputDeviceId
    {
        get => _selectedInputDeviceId;
        set { if (Set(ref _selectedInputDeviceId, value)) { _settings.SelectedInputDeviceId = value; _settings.Save(); } }
    }

    private bool _polishEnabled;
    public bool PolishEnabled
    {
        get => _polishEnabled;
        set { if (Set(ref _polishEnabled, value)) { _settings.PolishEnabled = value; _settings.Save(); } }
    }

    private string _polishEndpoint;
    public string PolishEndpoint
    {
        get => _polishEndpoint;
        set { if (Set(ref _polishEndpoint, value)) { _settings.PolishEndpoint = value; _settings.Save(); } }
    }

    private string _polishModel;
    public string PolishModel
    {
        get => _polishModel;
        set { if (Set(ref _polishModel, value)) { _settings.PolishModel = value; _settings.Save(); } }
    }

    private bool _polishApiKeyPresent;
    public bool PolishApiKeyPresent { get => _polishApiKeyPresent; private set => Set(ref _polishApiKeyPresent, value); }

    private string _lastRawTranscript = "";
    public string LastRawTranscript { get => _lastRawTranscript; private set => Set(ref _lastRawTranscript, value); }

    private string _lastTranscript = "";
    public string LastTranscript { get => _lastTranscript; private set => Set(ref _lastTranscript, value); }

    private int _totalTranscriptions;
    public int TotalTranscriptions { get => _totalTranscriptions; private set => Set(ref _totalTranscriptions, value); }

    // ── Lifecycle ───────────────────────────────────────────────────────────

    /// <summary>Loads persisted state, the model, and starts the hotkey monitor.</summary>
    public async Task BootstrapAsync()
    {
        RefreshInputDevices();
        ModelDownloaded = ModelDownloader.IsDownloaded;

        if (ModelDownloaded)
            await LoadWhisperAsync();

        StartHotkey();
    }

    public void RefreshInputDevices()
    {
        var devices = AudioDeviceProbe.ListInputDevices();
        AvailableInputDevices.Clear();
        foreach (var d in devices)
            AvailableInputDevices.Add(d);

        // Drop a stale selection if that device is gone.
        if (_selectedInputDeviceId is not null &&
            !devices.Any(d => d.Id == _selectedInputDeviceId))
        {
            SelectedInputDeviceId = null;
        }
    }

    public async Task DownloadModelAsync()
    {
        try
        {
            var progress = new Progress<double>(p => ModelDownloadProgress = p);
            await _downloader.DownloadAsync(progress);
            ModelDownloaded = true;
            ModelDownloadProgress = 1.0;
            await LoadWhisperAsync();
        }
        catch (Exception ex)
        {
            Log.Error($"Model download failed: {ex.Message}");
            Dictation = DictationState.Error($"Model download failed: {ex.Message}");
        }
    }

    public void SetPolishApiKey(string? key)
    {
        CredentialStore.SetApiKey(key);
        PolishApiKeyPresent = CredentialStore.HasApiKey;
    }

    private async Task LoadWhisperAsync()
    {
        try
        {
            string path = ModelDownloader.LocalPath;
            _whisper = await Task.Run(() => new WhisperEngine(path));
            Log.Info("Whisper model loaded");
        }
        catch (Exception ex)
        {
            Log.Error($"Failed to load Whisper model: {ex.Message}");
            Dictation = DictationState.Error($"Failed to load model: {ex.Message}");
        }
    }

    private void StartHotkey()
    {
        try
        {
            _hotkey.Start();
            HotkeyRunning = true;
            Log.Info("Hotkey monitor started (Right Alt)");
        }
        catch (Exception ex)
        {
            Log.Error($"Hotkey monitor failed: {ex.Message}");
            Dictation = DictationState.Error($"Hotkey monitor failed: {ex.Message}");
        }
    }

    // ── Dictation pipeline ──────────────────────────────────────────────────

    private void BeginRecording()
    {
        if (!ModelDownloaded || _whisper is null)
        {
            Log.Warn("BeginRecording skipped: model not ready");
            return;
        }
        if (Dictation.Phase is not (DictationPhase.Idle or DictationPhase.NoSpeech))
        {
            Log.Info($"BeginRecording skipped: phase={Dictation.Phase}");
            return;
        }

        try
        {
            MMDevice? device = _selectedInputDeviceId is not null
                ? AudioDeviceProbe.DeviceById(_selectedInputDeviceId)
                : null;
            device ??= AudioDeviceProbe.DefaultInputDevice();
            if (device is null)
            {
                Dictation = DictationState.Error("No microphone available");
                return;
            }

            _recorder.Start(device);
            Dictation = DictationState.Recording;
            Log.Info($"Recording started on '{device.FriendlyName}'");
        }
        catch (Exception ex)
        {
            Log.Error($"Recording failed to start: {ex.Message}");
            Dictation = DictationState.Error($"Recording failed: {ex.Message}");
        }
    }

    private async Task EndRecordingAndTranscribeAsync()
    {
        if (Dictation.Phase != DictationPhase.Recording)
        {
            Log.Info($"EndRecording skipped: phase={Dictation.Phase}");
            return;
        }

        float[] samples;
        try
        {
            samples = await _recorder.StopAsync();
        }
        catch (Exception ex)
        {
            Log.Error($"StopAsync failed: {ex.Message}");
            Dictation = DictationState.Error($"Recording failed: {ex.Message}");
            return;
        }

        var (rms, peak) = Amplitude(samples);
        Log.Info($"Recording stopped: {samples.Length} samples " +
                 $"({samples.Length / 16000.0:F2}s) rms={rms:F4} peak={peak:F4} " +
                 $"device='{_recorder.LastDeviceName}'");

        if (samples.Length < MinSampleCount)
        {
            Log.Info("Samples too short, ignoring");
            await FlashNoSpeechAsync();
            return;
        }
        if (peak < 0.005f)
            Log.Warn($"Audio near-silent (peak={peak:F4}); mic may be muted or wrong device selected");

        Dictation = DictationState.Transcribing;

        string raw;
        try
        {
            var whisper = _whisper!;
            raw = await Task.Run(() => whisper.TranscribeAsync(samples));
        }
        catch (Exception ex)
        {
            Log.Error($"Transcription failed: {ex.Message}");
            Dictation = DictationState.Error($"Transcription failed: {ex.Message}");
            return;
        }
        Log.Info($"Whisper raw: \"{raw}\"");

        string cleaned = Clean(raw);
        if (cleaned.Length == 0)
        {
            Log.Info("Transcript empty after cleaning, no paste");
            await FlashNoSpeechAsync();
            return;
        }

        LastRawTranscript = cleaned;
        string polished = await PolishIfEnabledAsync(cleaned);

        Dictation = DictationState.Typing;
        LastTranscript = polished;
        TotalTranscriptions++;
        Log.Info($"Typing: \"{polished}\"");

        try
        {
            TextInjector.Type(polished);
        }
        catch (Exception ex)
        {
            Log.Error($"Text injection failed: {ex.Message}");
        }

        await Task.Delay(250);
        Dictation = DictationState.Idle;
    }

    private async Task<string> PolishIfEnabledAsync(string raw)
    {
        if (!PolishEnabled || !PolishApiKeyPresent)
            return raw;

        string? key = CredentialStore.GetApiKey();
        if (string.IsNullOrEmpty(key) || !Uri.TryCreate(PolishEndpoint, UriKind.Absolute, out _))
            return raw;

        try
        {
            var config = new PolisherConfig(
                PolishEndpoint, PolishModel, key, TimeSpan.FromSeconds(PolishTimeoutSeconds));
            string polished = await Polisher.PolishAsync(raw, config);
            return string.IsNullOrWhiteSpace(polished) ? raw : polished;
        }
        catch (Exception ex)
        {
            Log.Error($"Polish failed, falling back to raw: {ex.Message}");
            return raw;
        }
    }

    private async Task FlashNoSpeechAsync()
    {
        Dictation = DictationState.NoSpeech;
        await Task.Delay(800);
        Dictation = DictationState.Idle;
    }

    private static string Clean(string raw)
    {
        string text = raw.Trim();
        string[] junk = { "[BLANK_AUDIO]", "[silence]", "(silence)", "[ Silence ]", "[no audio]" };
        foreach (string j in junk)
            text = text.Replace(j, "", StringComparison.OrdinalIgnoreCase);
        return text.Trim();
    }

    private static (float Rms, float Peak) Amplitude(float[] samples)
    {
        if (samples.Length == 0)
            return (0f, 0f);
        float sumSq = 0f, peak = 0f;
        foreach (float s in samples)
        {
            sumSq += s * s;
            float a = MathF.Abs(s);
            if (a > peak) peak = a;
        }
        return (MathF.Sqrt(sumSq / samples.Length), peak);
    }

    // ── INotifyPropertyChanged ──────────────────────────────────────────────

    public event PropertyChangedEventHandler? PropertyChanged;

    private bool Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return false;
        field = value;
        Raise(name);
        return true;
    }

    private void Raise(string? name)
    {
        if (_dispatcher.CheckAccess())
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        else
            _dispatcher.InvokeAsync(() => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name)));
    }

    public void Dispose()
    {
        _hotkey.Dispose();
        _recorder.Dispose();
        _whisper?.Dispose();
    }
}
