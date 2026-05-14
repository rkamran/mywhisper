# MyWhisper for Windows

Windows port of MyWhisper — push-to-talk dictation that types into any focused
field. Not yet implemented; this directory is the planned home for the C#
codebase.

## Planned stack

| Concern | Choice |
|---|---|
| Language / runtime | C# / .NET 8, shipped self-contained (no runtime install) |
| UI | WPF — a setup window + system tray icon |
| Speech-to-text | [`whisper.net`](https://github.com/sandrohanea/whisper.net) wrapping whisper.cpp |
| Audio capture | [`NAudio`](https://github.com/naudio/NAudio) (WASAPI) |
| Polish call | `HttpClient` → OpenAI-compatible endpoint (Ollama Cloud) |
| Global push-to-talk | `SetWindowsHookEx` low-level keyboard hook, watching **Right Alt** |
| Text injection | `SendInput` (Win32 P/Invoke) |
| Tray icon | `Shell_NotifyIcon` (Win32 P/Invoke) |

## Mapping from the macOS app

| macOS | Windows |
|---|---|
| `HotkeyMonitor` (CGEventTap, Right Option) | low-level keyboard hook, Right Alt |
| `TextInjector` (CGEventPost / paste) | `SendInput` |
| `AudioRecorder` (AVAudioEngine) | `NAudio` WASAPI capture → 16 kHz mono float |
| `WhisperEngine` (whisper.cpp xcframework) | `whisper.net` |
| `MenuBarExtra` / `AppDelegate` | WPF + `Shell_NotifyIcon` tray |
| `ModelDownloader` | `HttpClient` download to `%LOCALAPPDATA%\MyWhisper` |
| `Polisher` | direct port — see `shared/polish-prompt.md` |
| `KeychainStore` | Windows Credential Manager (DPAPI) |

## Planned layout

```
windows/
├── MyWhisper.sln
├── MyWhisper/
│   ├── App.xaml / App.xaml.cs
│   ├── Views/            (SetupWindow, tray menu)
│   ├── Services/         (AudioRecorder, WhisperEngine, HotkeyMonitor,
│   │                      TextInjector, ModelDownloader, Polisher, CredentialStore)
│   └── MyWhisper.csproj
└── scripts/
    └── package.ps1       (build + zip/MSIX)
```

Status: **not started.**
