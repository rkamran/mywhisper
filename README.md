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

- **macOS** — released. Download the latest `.dmg` from
  [Releases](https://github.com/rkamran/mywhisper/releases).
- **Windows** — not started; stack and architecture mapped out in
  [`windows/README.md`](windows/README.md).

## Working in this repo

Each platform folder is self-contained — `cd` into it and use its own scripts.
The `shared/` folder is documentation/reference only; each app embeds its own
copy of anything it needs (e.g. the polish prompt) and those copies must be
kept in sync by hand.
