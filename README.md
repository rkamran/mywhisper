# MyWhisper

Push-to-talk dictation that transcribes your speech locally with Whisper and
types it into whatever text field has focus. Hold a key, speak, release.

This is a multi-platform monorepo. The two apps share a design and a polish
prompt, but no code — each is native to its platform.

## Layout

| Path | What |
|---|---|
| [`macos/`](macos/) | macOS app — Swift / SwiftUI, ships today. See [`macos/README.md`](macos/README.md). |
| [`windows/`](windows/) | Windows port — C# / WPF, planned. See [`windows/README.md`](windows/README.md). |
| [`shared/`](shared/) | Cross-platform reference: the [polish prompt](shared/polish-prompt.md), icon master, design notes. No build artifacts. |

## Status

- **macOS** — released. Download the latest signed-and-notarized `.dmg` from
  [Releases](https://github.com/rkamran/mywhisper/releases).
- **Windows** — released. Build the installer with `windows\scripts\package.ps1`
  on a Windows box and attach the `.exe` + `.zip` to the same release; see
  [`windows/README.md`](windows/README.md).

## Working in this repo

Each platform folder is self-contained — `cd` into it and use its own scripts.
The `shared/` folder is documentation/reference only; each app embeds its own
copy of anything it needs (e.g. the polish prompt) and those copies must be
kept in sync by hand.

## License

MyWhisper is released under the [MIT License](LICENSE).

It depends on several third-party open-source libraries (whisper.cpp,
Whisper.net, NAudio, .NET, and more) — see
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) for the full list and
their respective copyright notices. A copy of that file is also bundled with
each binary release; the in-app **Setup → Open source licenses** link opens it.
