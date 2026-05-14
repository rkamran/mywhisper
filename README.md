# MyWhisper

A minimal macOS dictation app inspired by Wispr Flow. Hold **Right Option**, speak, release — your words paste into whatever text field has focus. Everything runs locally via [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

## Requirements

- macOS 13.3+
- Xcode 15+ (only used to build/run; no extra tooling required to use the app)
- Apple Silicon recommended (Intel works, slower)

## Build & install (recommended)

Run the install script:

```bash
./scripts/install.sh
```

It builds in Release, ad-hoc signs locally, drops `MyWhisper.app` into `/Applications/`, and launches it. Use this for day-to-day rebuilds too — permissions you grant stick because the app lives at a stable path.

First launch walks through three steps:

1. **Microphone** — click *Grant*.
2. **Accessibility** — click *Request access*, enable MyWhisper in *System Settings → Privacy & Security → Accessibility*. The badge updates within ~2s; if it doesn't, click *Re-check now*.
3. **Download model** — `ggml-base.en` (~141 MB) → `~/Library/Application Support/MyWhisper/`.

Once all three are green, hold **Right Option** anywhere and speak.

### Running directly from Xcode (development only)

You can `open MyWhisper.xcodeproj` and hit ⌘R, but each rebuild gets a new ad-hoc signature, so macOS re-asks for permissions on every run and old grants point to stale binaries. Stick with `install.sh` unless you're actively debugging.

### Stale TCC entries

If you ran from Xcode first and System Settings now shows MyWhisper as "granted" but the app still reports orange, you have a stale TCC entry. Clear it:

```bash
tccutil reset Accessibility com.mywhisper.app
tccutil reset Microphone   com.mywhisper.app
```

Then run `./scripts/install.sh` and grant once more — that grant will persist.

## Using it

1. Focus any text field — Notes, a browser address bar, Slack, etc.
2. **Hold Right Option**, speak, release.
3. The icon cycles through `mic.fill → waveform → keyboard`, then the transcribed text is pasted at the cursor.

The previous clipboard contents are restored ~300 ms after the paste.

## Regenerating the Xcode project

If you edit `project.yml` (or want to add files), regenerate with:

```bash
/tmp/xcodegen-dist/xcodegen/bin/xcodegen generate
# or install xcodegen yourself: https://github.com/yonaskolb/XcodeGen
```

## Project layout

```
mywhisper/
├── project.yml                          # XcodeGen config
├── Frameworks/whisper.xcframework/      # Pre-built whisper.cpp v1.8.4 (macOS only)
└── MyWhisper/
    ├── Info.plist
    ├── MyWhisper.entitlements
    ├── MyWhisperApp.swift               # @main entry
    ├── AppDelegate.swift                # NSStatusItem-style menu bar setup window
    ├── AppState.swift                   # Observable app state
    ├── Services/
    │   ├── AudioRecorder.swift          # AVAudioEngine → 16 kHz mono Float32
    │   ├── WhisperEngine.swift          # whisper.cpp Swift wrapper
    │   ├── HotkeyMonitor.swift          # CGEventTap watching Right Option
    │   ├── TextInjector.swift           # Pasteboard + Cmd+V into focused app
    │   └── ModelDownloader.swift        # ggml-base.en.bin downloader
    └── Views/
        ├── SetupView.swift              # 3-step setup flow
        └── MenuBarContent.swift         # Menu bar status + quit
```

## Notes & limitations

- **English only.** `ggml-base.en` is English-specialized. Swap `ModelDownloader.modelName`/`remoteURL` to use a multilingual model.
- **No code signing.** The build script disables hardened runtime so you can run unsigned. To distribute, sign with your Developer ID and re-enable hardened runtime in `project.yml`.
- **App is not sandboxed.** Required because the app sends synthetic keystrokes via `CGEventPost` to other apps. Sandboxed apps can't post events outside themselves.
- The Right Option key is detected via its specific keycode (61) + the `NX_DEVICERALTKEYMASK` (0x40) flag, so left Option won't trigger dictation.

## Troubleshooting

- **"Hotkey monitor failed"** in the menu — Accessibility permission was revoked. Re-grant it; the app polls and recovers automatically.
- **Nothing pastes** — Make sure the destination app accepts paste (some fields disable it). Try TextEdit to confirm.
- **Model fails to download** — Hugging Face occasionally rate-limits. The file is fetched from `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin`; you can `curl` it manually into `~/Library/Application Support/MyWhisper/ggml-base.en.bin` and restart.
