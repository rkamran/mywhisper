# Third-party software notices

MyWhisper is distributed under the MIT License (see [LICENSE](LICENSE)). This
document lists the third-party components it depends on at runtime, their
licenses, and the required copyright notices.

Each component is the property of its respective owners.

---

## Components used by both apps

### whisper.cpp

- **What:** C/C++ implementation of OpenAI's Whisper speech-to-text model.
  Used directly via xcframework on macOS, and indirectly via the
  `Whisper.net.Runtime` NuGet package on Windows.
- **Project:** <https://github.com/ggml-org/whisper.cpp>
- **License:** MIT — see the *MIT License (template)* section below.
- **Copyright:** Copyright (c) 2023-2024 The ggml authors

### OpenAI Whisper model weights (`ggml-base.bin` and other ggml conversions)

- **What:** Model files downloaded at first run from
  [`huggingface.co/ggerganov/whisper.cpp`](https://huggingface.co/ggerganov/whisper.cpp).
  These are ggml-format conversions of the OpenAI Whisper model checkpoints.
- **Project:** <https://github.com/openai/whisper>
- **License:** MIT — see the *MIT License (template)* section below.
- **Copyright:** Copyright (c) 2022 OpenAI

---

## Components used by the macOS app only

The macOS app links only against Apple's frameworks (Cocoa, SwiftUI,
AVFoundation, Core Audio, Accessibility, OSLog, Security, Core Graphics).
These are part of the operating system and are governed by Apple's developer
agreements; no separate third-party attribution is required.

The `whisper.xcframework` bundled in `macos/Frameworks/` is pre-built from
the upstream **whisper.cpp** release (see above).

---

## Components used by the Windows app only

### Whisper.net

- **What:** .NET bindings around whisper.cpp.
- **Project:** <https://github.com/sandrohanea/whisper.net>
- **NuGet:** `Whisper.net` 1.9.1
- **License:** MIT — see the *MIT License (template)* section below.
- **Copyright:** Copyright (c) 2023 Sandro Hanea

### Whisper.net.Runtime

- **What:** Native whisper.cpp binaries packaged for redistribution alongside
  Whisper.net. Same upstream project as Whisper.net; ships the CPU build of
  whisper.cpp.
- **NuGet:** `Whisper.net.Runtime` 1.9.1
- **License:** MIT — see the *MIT License (template)* section below.
- **Copyright:** Copyright (c) 2023 Sandro Hanea
  (whisper.cpp portion: Copyright (c) 2023-2024 The ggml authors)

### NAudio

- **What:** Audio capture (WASAPI) and resampling for the recorder service.
- **Project:** <https://github.com/naudio/NAudio>
- **NuGet:** `NAudio` 2.2.1
- **License:** MIT — see the *MIT License (template)* section below.
- **Copyright:** Copyright (c) Mark Heath and contributors

### Hardcodet.NotifyIcon.Wpf

- **What:** System-tray icon support for the WPF host app.
- **Project:** <https://github.com/hardcodet/wpf-notifyicon>
- **NuGet:** `Hardcodet.NotifyIcon.Wpf` 1.1.0
- **License:** Code Project Open License 1.02 (CPOL) — see
  <https://www.codeproject.com/info/cpol10.aspx>
- **Copyright:** Copyright (c) Philipp Sumi

### .NET Runtime and supporting libraries

- **What:** The .NET 8 runtime, BCL, WPF, and selected support packages
  (`System.Drawing.Common` 8.0.0, `System.Security.Cryptography.ProtectedData`
  8.0.0). Shipped self-contained next to the app.
- **Project:** <https://github.com/dotnet/runtime>,
  <https://github.com/dotnet/wpf>
- **License:** MIT — see the *MIT License (template)* section below.
- **Copyright:** Copyright (c) .NET Foundation and Contributors

### Microsoft Visual C++ Redistributable runtime DLLs

- **What:** `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`, and `MSVCP140.dll`
  redistributed alongside `MyWhisper.exe` for app-local deployment so the
  native whisper.cpp DLL loads without a separately installed VC++
  Redistributable.
- **Project:** Microsoft Visual C++ Redistributable
- **License:** Microsoft Software License Terms — redistribution as part of
  an application is permitted under the standard VC++ Redistributable terms.
  See <https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files>
  for Microsoft's app-local deployment guidance.
- **Copyright:** Copyright (c) Microsoft Corporation. All rights reserved.

---

## Build-time tools (not redistributed in the app)

These run on the developer machine to produce builds, but no part of them
ships inside the macOS app bundle or the Windows installer.

| Tool | License | Project |
|---|---|---|
| **XcodeGen** | MIT — Copyright (c) Yonas Kolb | <https://github.com/yonaskolb/XcodeGen> |
| **Inno Setup** | Inno Setup License (modified BSD) — Copyright (c) Jordan Russell | <https://www.jrsoftware.org/isinfo.php> |
| **.NET SDK / Xcode** | Vendor-provided developer tools, used under their respective developer agreements. | |

---

## License texts

### MIT License (template)

The MIT License text below applies to every component above marked
**License: MIT**. The only thing that differs between those components is the
copyright holder, listed in each component's section above.

```
MIT License

Copyright (c) <year> <copyright holder, listed per-component above>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Code Project Open License 1.02 (CPOL) — for Hardcodet.NotifyIcon.Wpf

Full text: <https://www.codeproject.com/info/cpol10.aspx>

Summary of permissions and obligations (the canonical text at the URL above
governs):

- You may use, modify, and redistribute the Source Code and Executable Files,
  including for commercial purposes.
- No GPL-style copyleft: you are not required to release your own code under
  CPOL.
- You must retain the original copyright notice and may not misrepresent the
  origin of the Source Code.
- The Software is provided "as is," without warranties.

This summary is informational only; the linked CPOL 1.02 text is the binding
license.
