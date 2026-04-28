# Mathy

<p align="center">
  <img src="Mathy/Mathy/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Mathy logo">
</p>

[![CI](https://github.com/FaroutYLq/mathy/actions/workflows/ci.yml/badge.svg)](https://github.com/FaroutYLq/mathy/actions/workflows/ci.yml)
[![Documentation](https://readthedocs.org/projects/mathy/badge/?version=latest)](https://mathy.readthedocs.io/en/latest/)

A macOS menu bar app that captures math equations from your screen and converts them to LaTeX using [pix2tex/LaTeX-OCR](https://github.com/lukas-blecher/LaTeX-OCR).

## How It Works

1. Press **Cmd+Shift+M** (configurable)
2. Draw a rectangle around a math equation on screen
3. LaTeX is copied to your clipboard instantly

Mathy runs a local Python server that keeps the OCR model loaded in memory, so after the initial ~15s startup, each conversion takes only ~100-300ms.

## Install

1. Download **Mathy.dmg** from [Releases](https://github.com/FaroutYLq/mathy/releases)
2. Open the DMG and drag **Mathy** to **Applications**
3. First launch: right-click Mathy.app > **Open** (required once for unsigned apps)

On first launch, Mathy automatically installs the Python OCR engine and downloads the model (~200MB). A setup window shows progress — no terminal needed.

### Requirements

- **macOS 13+** (Ventura or later)
- **Python 3.8+** (pre-installed on most Macs, or `brew install python3`)

## Usage

Once running, Mathy appears as a calligraphic **M** icon in the menu bar.

- **Cmd+Shift+M** — Capture a screen region and convert to LaTeX
- Click the menu bar icon to see server status, recent history, and settings
- Converted LaTeX is automatically copied to your clipboard
- A preview popup shows the captured image alongside rendered LaTeX

## Documentation

Full technical documentation is available at [mathy.readthedocs.io](https://mathy.readthedocs.io/en/latest/), covering architecture, build instructions, project structure, and implementation details.

## License

See [LICENSE](LICENSE).
