<div align="center">
    <img src="docs/AppIcon-iOS-Default-1024x1024@1x.png" width="180" height="auto">
    <h1>AutoPlan</h1>
    <p>Extract calendar events and reminders from text or images using LLM — right from the menu bar.</p>
</div>

<div align="center">
    <table>
        <th><a href="https://github.com/FisherRone/AutoPlan/releases">Releases ↗</a></th>
        <td><a href="#features">Features</a></td>
        <td><a href="#customization">Customization</a></td>
        <td><a href="#quick-start">Quick Start</a></td>
    </table>
</div>

<br>

<a name="features"></a>
## Features

Copy any text or screenshot to your clipboard, click **Extract from Clipboard** in the menu bar, and AutoPlan parses it into structured calendar events or reminders using your preferred LLM.

![Demo](docs/Demos/AutoPlanDemoVedio-Email.gif)

- **Clipboard Extraction** — Works with plain text, emails, chat messages, or screenshots
- **Smart Recognition** — LLM-powered parsing understands dates, times, locations, and context; images are processed via OCR automatically
- **Calendar & Reminders** — Saves directly to Apple Calendar and Reminders with one click
- **Menu-Bar Native** — Lives in your status bar; no dock icon, no window clutter

<a name="customization"></a>
## Customization

AutoPlan is built to fit your workflow. Choose any OpenAI-compatible provider, fine-tune how events are categorized, and even write your own extraction prompt.

### General Settings & Providers

<div align="center">
    <img src="docs/Demos/ScreenshotGeneralSetting.png" width="420" height="auto">
    &nbsp;&nbsp;
    <img src="docs/Demos/ScreenshotAddLLMProvider.png" width="420" height="auto">
</div>

- **Model Config** — Add your own API keys for OpenAI, DeepSeek, or any OpenAI-compatible endpoint; test connectivity with one click
- **Extraction Model** — Pick which model handles the parsing
- **Confirmation Toggle** — Choose whether to review events before saving, or save instantly
- **Launch at Login** — Start AutoPlan automatically when you log in

### Advanced Settings & Prompt Variables

<div align="center">
    <img src="docs/Demos/ScreenshotAdvancedSettingsPage.png" width="420" height="auto">
    &nbsp;&nbsp;
    <img src="docs/Demos/ScreenshotAdvancedSettingsPromptVariables.png" width="420" height="auto">
</div>

- **Custom Prompts** — Override the default extraction prompt with your own; edit in any text editor
- **User Rules** — Layer extra instructions on top of the default prompt without replacing it
- **List Management** — Choose which Calendar and Reminders lists to use; add per-list descriptions to improve categorization accuracy
- **Prompt Variables** — Use placeholders like `{{date}}`, `{{time}}`, and `{{content}}` to build dynamic prompts

<a name="quick-start"></a>
## Quick Start

1. Download the latest build from [Releases](https://github.com/FisherRone/AutoPlan/releases) or clone and build with Xcode
2. Launch the app — it appears in your menu bar
3. Open **Settings** → **Model Config** and add your LLM API key
4. Copy text or a screenshot to your clipboard, then click **Extract from Clipboard** in the menu bar
5. Review the extracted events and click **Save** to add them to Calendar / Reminders

Enable **Skip Confirmation** in Settings to save events instantly without reviewing.

## Requirements

- macOS 15.0+
- An API key for an OpenAI-compatible LLM service (OpenAI, DeepSeek, etc.)

## Build

Open `AutoPlan/AutoPlan.xcodeproj` in Xcode, select the **AutoPlan** scheme, and build.

> The app uses ad-hoc signing and runs without a sandbox.

## License

MIT
