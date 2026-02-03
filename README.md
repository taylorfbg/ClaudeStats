# ClaudeStats

A lightweight native macOS menu bar app that displays your [Claude.ai](https://claude.ai) usage stats at a glance.

<img src="ClaudeStats/Assets.xcassets/ClaudeIcon.imageset/claude-icon@2x.png" width="50">

## Features

- **Current session usage** — see your session percentage and time until reset
- **Weekly limits** — track your weekly "All models" usage percentage and reset day
- **Menu bar percentage** — optionally display your current session % right in the menu bar
- **Auto-refresh** — stats update every 60 seconds in the background
- **Persistent login** — log in once via the built-in browser, session is remembered between launches
- **No dock icon** — runs entirely in the menu bar

## Requirements

- macOS 13.0+
- Xcode 15+ (to build from source)

## Installation

### Build from source

1. Clone the repo:
   ```
   git clone https://github.com/taylorfbg/ClaudeStats.git
   ```
2. Open `ClaudeStats.xcodeproj` in Xcode
3. Build and run (Cmd+R)
4. The app appears in your menu bar — no dock icon

### Or build from command line

```
xcodebuild -scheme ClaudeStats -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/ClaudeStats.app /Applications/
open /Applications/ClaudeStats.app
```

## Setup

1. Click the robot icon in your menu bar
2. Click **Log in to Claude** or **Settings**
3. Log in to your Claude.ai account in the browser window that opens
4. Once logged in, the app automatically fetches your usage data
5. Close the settings window — the app continues refreshing in the background

## How It Works

ClaudeStats uses an embedded WebView (WKWebView) to load your Claude.ai usage page and extract the usage percentages via JavaScript. This approach:

- Handles Cloudflare authentication seamlessly
- Keeps your login session persistent between app launches
- Requires no API keys or manual cookie copying

## Project Structure

```
ClaudeStats/
├── ClaudeStatsApp.swift       # App entry with MenuBarExtra
├── StatsViewModel.swift       # WebView loading, data extraction, refresh timer
├── ClaudeIcon.swift           # Menu bar icon helper
├── Models/
│   ├── StatsCache.swift       # Local stats cache models
│   └── UsageData.swift        # Usage API response models
├── Views/
│   ├── MenuContentView.swift  # Main dropdown UI
│   ├── UsageRowView.swift     # Progress bar component
│   └── SettingsView.swift     # Login WebView + status
├── Assets.xcassets/           # App icon
└── Info.plist                 # LSUIElement=true (no dock icon)
```

## License

MIT
