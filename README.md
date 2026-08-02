# ZW's Homebrew Tap

[![Homebrew](https://img.shields.io/badge/Homebrew-third--party%20tap-FBB040?logo=homebrew&logoColor=000)](https://brew.sh/)
[![macOS](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Last commit](https://img.shields.io/github/last-commit/zwu7/homebrew-tap)](https://github.com/zwu7/homebrew-tap/commits/main)
[![GitHub stars](https://img.shields.io/github/stars/zwu7/homebrew-tap?style=flat)](https://github.com/zwu7/homebrew-tap/stargazers)

**Curated macOS casks for teaching, research, media production, browser automation, and legacy compatibility.**

This third-party Homebrew tap packages a practical collection of macOS applications that are missing from the official taps, require architecture-specific installers, or are intentionally pinned to preserve a known working environment.

这是一个面向 macOS 教学、科研、内容制作、浏览器自动化和旧版兼容场景维护的 Homebrew Tap。它特别适合需要一键部署 ClassIn、离线转写工具、浏览器测试组件，以及 EndNote X9 + Office 2016 等兼容环境的用户。

> [!IMPORTANT]
> This is an independent community tap. It is not affiliated with Homebrew or any software vendor represented here.

## Why use this tap?

- **One-command installation** for software that would otherwise require manual downloads and drag-and-drop setup.
- **Reproducible environments** through intentionally pinned builds where version stability matters more than automatic upgrades.
- **Legacy academic compatibility**, including EndNote X9 and Office 2016 15.41 components.
- **Architecture-aware packages** for Apple Silicon and Intel Macs where upstream installers support both.
- **Practical uninstall support**, with cleanup rules included in many casks.
- **Official upstream downloads whenever possible**; this repository provides Homebrew definitions, not repackaged application binaries.

## Quick start

Install any cask directly with its fully qualified name:

```bash
brew install --cask zwu7/tap/classin
```

You may also add the tap first:

```bash
brew tap zwu7/tap
brew install --cask zwu7/tap/buzz-captions
```

Using fully qualified names keeps the source explicit and avoids ambiguity when a cask has the same token as one in an official Homebrew repository.

## Cask catalog

### Teaching and research

| Cask | What it installs | Why it is here |
|---|---|---|
| `classin` | ClassIn | Apple Silicon classroom and hybrid-learning client from the official upstream installer. |
| `endnote-x9` | EndNote X9 | Pinned for legacy-license workflows and older Cite While You Write compatibility. |
| `microsoft-word-2016-1541` | Microsoft Word 2016 15.41 | Pinned legacy Word build, especially useful with older EndNote CWYW workflows. |
| `microsoft-excel-2016-1541` | Microsoft Excel 2016 15.41 | Pinned spreadsheet build for reproducible legacy Office environments. |
| `microsoft-powerpoint-2016-1541` | Microsoft PowerPoint 2016 15.41 | Pinned presentation build for reproducible legacy Office environments. |
| `microsoft-onedrive-2025-25056` | Microsoft OneDrive 25.056 | Pinned Apple Silicon build for environments that must remain on a known OneDrive release. |

### Audio, video, and transcription

| Cask | What it installs | Why it is here |
|---|---|---|
| `audacity` | Audacity | Pinned to the final macOS release before the OpenVINO AI plugin transition; supports Apple Silicon and Intel. |
| `buzz-captions` | Buzz | Offline audio transcription and translation powered by Whisper; supports Apple Silicon and Intel. |
| `capcut` | CapCut | Direct standalone macOS installer for video editing and visual content production. |
| `obs` | OBS Studio | Pinned stable screen-recording and streaming build, with an `obs` command wrapper. |

### Browsers and automation

| Cask | What it installs | Why it is here |
|---|---|---|
| `chromedriver` | ChromeDriver | Architecture-aware browser automation driver from Chrome for Testing. |
| `mercury-browser` | Mercury | Apple Silicon build of the performance-oriented Firefox fork. |
| `srware-iron` | SRWare Iron | Privacy-focused Chromium browser with automatic Apple Silicon/Intel selection. |

### Productivity and communication

| Cask | What it installs | Why it is here |
|---|---|---|
| `pdf-expert` | PDF Expert 2 | Legacy PDF Expert release for users who need the older desktop application. |
| `wechat` | WeChat for Mac / 微信 Mac 版 | Homebrew-managed installation of the official macOS client. |
| `wetype` | WeType / 微信输入法 | Pinned to the last selected non-AI release after cross-device sync was introduced. |

Check the exact version, architecture requirements, dependencies, and caveats before installation:

```bash
brew info --cask zwu7/tap/<cask-name>
```

## Suggested setups

### Academic legacy stack

```bash
brew install --cask \
  zwu7/tap/endnote-x9 \
  zwu7/tap/microsoft-word-2016-1541 \
  zwu7/tap/microsoft-excel-2016-1541 \
  zwu7/tap/microsoft-powerpoint-2016-1541
```

### Teaching and content-production stack

```bash
brew install --cask \
  zwu7/tap/classin \
  zwu7/tap/buzz-captions \
  zwu7/tap/audacity \
  zwu7/tap/obs
```

### Browser automation stack

```bash
brew install --cask \
  zwu7/tap/chromedriver \
  zwu7/tap/mercury-browser \
  zwu7/tap/srware-iron
```

## Updating

Refresh Homebrew metadata and upgrade a cask when a newer definition is published in this tap:

```bash
brew update
brew upgrade --cask zwu7/tap/<cask-name>
```

Some casks are deliberately pinned and will not track the newest upstream release. In addition, applications with their own built-in updater may still update themselves independently of Homebrew.

## Uninstalling

Standard uninstall:

```bash
brew uninstall --cask zwu7/tap/<cask-name>
```

Remove the application and the user-level support files declared by its cask, when available:

```bash
brew uninstall --cask --zap zwu7/tap/<cask-name>
```

Remove the tap itself after uninstalling its casks:

```bash
brew untap zwu7/tap
```

## Support policy

This tap is maintained on a best-effort basis for practical, reproducible macOS setups.

Before opening an issue, please include:

```bash
brew config
brew doctor
brew info --cask zwu7/tap/<cask-name>
```

Also include your Mac model or CPU architecture, macOS version, the exact command you ran, and the complete error output.

[Open an issue](https://github.com/zwu7/homebrew-tap/issues) for broken downloads, checksum mismatches, installation failures, architecture problems, or version-update requests.

## Security and licensing

- Review a cask before installing it if you are using a pinned or legacy build.
- Older software may no longer receive upstream security fixes.
- Commercial applications may require a valid license, subscription, or account.
- Application binaries, trademarks, and licenses belong to their respective upstream owners.
- Installing a cask means downloading software from the URL declared in its Ruby definition; this tap does not grant additional rights to that software.

## Contributing

Focused pull requests are welcome. Please keep changes small and verifiable:

1. Use an official or clearly attributable upstream download URL.
2. Provide architecture-specific SHA-256 checksums when the upstream URL is versioned and stable.
3. Explain any intentional version pin in the cask's `livecheck` block or comments.
4. Test installation, upgrade behavior, uninstall behavior, and `--zap` cleanup where applicable.
5. Run Homebrew's style and audit checks before submitting.

```bash
brew style --cask zwu7/tap/<cask-name>
brew audit --cask --strict --online zwu7/tap/<cask-name>
```

---

If this tap saves you time, please consider giving the repository a star. It helps other macOS users discover it.
