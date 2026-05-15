# MyWhisper for Windows

Windows port of MyWhisper — push-to-talk dictation that transcribes your speech
locally with Whisper and types it into whatever text field has focus.

Hold **Right Alt**, speak, release.

## Status

Code-complete, **not yet build-verified.** It was authored on macOS, so it
needs one compile pass on a Windows machine with the .NET 8 SDK. See
[Building](#building).

## Requirements

- Windows 10 (1809+) or Windows 11
- [.NET 8 SDK](https://dotnet.microsoft.com/download) — to build
- A microphone with desktop-app access enabled in
  *Settings → Privacy & security → Microphone*

## Building

```powershell
cd windows
dotnet build MyWhisper.sln -c Debug
dotnet run --project MyWhisper\MyWhisper.csproj
```

First launch:
1. The setup window opens. Click **Download model** (~141 MB → `%LOCALAPPDATA%\MyWhisper`).
2. Optionally pick a specific microphone, and configure transcript polishing
   (an OpenAI-compatible endpoint such as Ollama Cloud).
3. Hold **Right Alt** anywhere and speak.

## Packaging

```powershell
pwsh windows\scripts\package.ps1            # win-x64
pwsh windows\scripts\package.ps1 -Runtime win-arm64
```

Produces in `windows/dist/`:

- **`MyWhisper-<version>-<rid>.zip`** — portable build. Extract anywhere and
  run `MyWhisper.exe`. Self-contained; no .NET runtime needed on the target.
- **`MyWhisper-<version>-Setup.exe`** — Inno Setup installer (only if
  `iscc.exe` is on PATH). Wizard install with Start Menu shortcut, optional
  desktop icon, optional run-at-login, and a proper uninstaller in
  Settings → Apps. To enable, install Inno Setup once:
  ```powershell
  winget install JRSoftware.InnoSetup
  ```

Both ship with the VC++ runtime DLLs bundled, so recipients don't need to
preinstall the Visual C++ Redistributable. SmartScreen still warns once on
first launch (unsigned) → More info → Run anyway.

## Architecture

A WPF tray app. No admin rights or permission prompts needed at runtime —
Windows lets desktop apps capture audio and synthesize input directly.

| Concern | Implementation |
|---|---|
| Speech-to-text | `Whisper.net` (whisper.cpp), `ggml-base.en` model |
| Audio capture | `NAudio` WASAPI → resampled to 16 kHz mono float |
| Global push-to-talk | `SetWindowsHookEx` low-level keyboard hook, **Right Alt** (listen-only, AltGr-safe) |
| Text injection | `SendInput` with Unicode keystrokes — leaves the clipboard untouched |
| Tray icon | `Hardcodet.NotifyIcon.Wpf` |
| Polish (optional) | `HttpClient` → OpenAI-compatible chat endpoint; see [`../shared/polish-prompt.md`](../shared/polish-prompt.md) |
| API-key storage | DPAPI (per-user encryption) in `%LOCALAPPDATA%\MyWhisper` |

### Layout

```
windows/
├── MyWhisper.sln
├── MyWhisper/
│   ├── MyWhisper.csproj
│   ├── app.manifest                 PerMonitorV2 DPI, Win10/11 compat
│   ├── App.xaml(.cs)                tray app entry, single-instance guard
│   ├── AppState.cs                  observable state + dictation pipeline
│   ├── Models/DictationState.cs
│   ├── Services/
│   │   ├── WhisperEngine.cs         Whisper.net wrapper
│   │   ├── AudioRecorder.cs         WASAPI capture + resample
│   │   ├── AudioDeviceProbe.cs      enumerate input devices
│   │   ├── HotkeyMonitor.cs         low-level keyboard hook (Right Alt)
│   │   ├── TextInjector.cs          SendInput Unicode typing
│   │   ├── ModelDownloader.cs       ggml-base.en download
│   │   ├── Polisher.cs              OpenAI-compatible polish call
│   │   ├── CredentialStore.cs       DPAPI key storage
│   │   ├── Settings.cs              JSON preferences
│   │   ├── AppPaths.cs / Log.cs
│   └── Views/
│       ├── SetupWindow.xaml(.cs)
│       └── Converters.cs
└── scripts/
    ├── make-icon.swift              regenerates Assets/app.ico (run on macOS)
    └── package.ps1                  self-contained zip build
```

## Known caveats (to verify on first Windows build)

- **Not compile-verified.** Expect a few fixes — most likely package versions
  (`Whisper.net`, `NAudio`, `Hardcodet.NotifyIcon.Wpf`) and minor XAML/binding
  tweaks. The Win32 P/Invoke signatures follow standard patterns but warrant a
  runtime check.
- **`Whisper.net.Runtime`** ships the CPU build. For NVIDIA GPUs swap in
  `Whisper.net.Runtime.Cublas`.
- **AltGr keyboards:** Right Alt is AltGr on many non-US layouts. The hook is
  listen-only so it never blocks AltGr, but holding it still triggers dictation —
  a future setting should let users rebind the trigger.
- **Mic privacy:** if capture returns silence, desktop-app microphone access is
  likely off in Windows privacy settings — the setup window has a shortcut to it.
