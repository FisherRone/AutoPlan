# AutoPlan

Extract calendar events and reminders from text or images using LLM — right from the menu bar.

![项目演示](https://github.com/FisherRone/AutoPlan/blob/main/docs/docs/AutoPlan Demo Vedio - Email.gif?raw=true)

## Features

- **Clipboard Extraction** — Copy any text or screenshot, click "从剪贴板提取日程" in the menu bar, and get parsed calendar events / reminders saved automatically
- **Smart Recognition** — Supports both plain text and images (via OCR)
- **Weekly Report** — Auto-generate weekly summaries from your calendar data
- **Multi-Model** — Configurable LLM backends (OpenAI-compatible APIs)

## Requirements

- macOS 15.0+
- An LLM API key (OpenAI / DeepSeek / any OpenAI-compatible endpoint)

## Quick Start

1. Download the latest build or clone and build with Xcode
2. Launch the app — it lives in the menu bar
3. Open **Settings** → **Model Config** and configure your LLM
4. Copy text or a screenshot to clipboard, then click **从剪贴板提取日程** in the menu bar
5. Review the extracted events and click **保存** to save to Calendar / Reminders

You can also enable **直接保存** in Settings to skip the confirmation step.

## Build

Open `AutoPlan/AutoPlan.xcodeproj` in Xcode, select the **AutoPlan** scheme, and build.

> The app uses ad-hoc signing and runs without a sandbox.

## License

MIT
