# AutoPlan

Extract calendar events and reminders from text or images using LLM — right from macOS Shortcuts.

## Features

- **Event Extraction** — Paste text or screenshot, let LLM parse it into calendar events / reminders
- **Weekly Report** — Auto-generate weekly summaries from your calendar data
- **Shortcuts Integration** — Trigger everything via macOS Shortcuts (Services menu or automation)
- **Multi-Model** — Configurable LLM backends (OpenAI-compatible APIs)

## Requirements

- macOS 15.0+
- An LLM API key (OpenAI / DeepSeek / any OpenAI-compatible endpoint)

## Quick Start

1. Download the latest build or clone and build with Xcode
2. Launch the app, go to the **General** tab and configure your LLM
3. Install the bundled shortcut via **About** tab → "安装提取日程"
4. Copy text / screenshot to clipboard → **Services** → **提取日程** in the menu bar

## Project Structure

```
AutoPlan/
├── AutoPlan/              # macOS SwiftUI App
│   └── AutoPlanApp/
│       ├── Intents/       # App Intents (Shortcuts integration)
│       └── Views/         # SwiftUI views
├── AutoPlanCore/          # Core logic (SPM package)
│   └── Sources/AutoPlanCore/
│       ├── Service/       # LLM, EventKit, OCR services
│       ├── Model/         # Data models & config
│       └── Statistics/    # Weekly report & charts
└── AI 聊天记录/            # Design & planning notes (Chinese)
```

## Build

Open `AutoPlan/AutoPlan.xcodeproj` in Xcode, select the **AutoPlan** scheme, and build.

> The app uses ad-hoc signing and runs without a sandbox.

## License

MIT
