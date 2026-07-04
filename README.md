# Lumo — Native macOS Client for Proton Lumo AI

A native-feeling macOS wrapper for [Proton's Lumo AI chat](https://lumo.proton.me/), built with Swift, WebKit, and AppKit. Not affiliated with Proton AG.

![Lumo](Lumo/Assets.xcassets/AppIcon.appiconset/icon-256.png)

## ✨ Features

### Native macOS Experience
- **Transparent title bar** with unified toolbar — blends seamlessly with the web UI
- **Native menu bar** with full keyboard shortcuts (File, Edit, View, Navigate, Window, Help)
- **Toolbar buttons** for New Chat, Back, Forward, Reload, and Toggle Sidebar
- **macOS Settings window** via SwiftUI (⌘,)
- **Dark mode** that follows system appearance with vibrant background
- **Full Screen support** (⌃⌘F)
- **Native file open panels** for file uploads
- **System Services menu** integration
- **Custom app icon** (Proton-style purple chat bubble)

### Session Persistence
- Login is **persisted across app launches** using `WKWebsiteDataStore.default()`
- Cookies, localStorage, and session data all survive restarts
- "Clear Session & Reload" (⇧⌘R) to sign out and reset

### Performance Optimizations
- **Hardware-accelerated compositing** via layer-backed views
- **Streaming content rendering** — `suppressesIncrementalRendering = false` so content appears as it loads
- **Tracker blocking** — blocks common analytics/tracking domains for faster, more private browsing
- **Transparent background** — eliminates redundant background painting, lets system vibrancy handle it
- **Optimized user agent** — minimal overhead, site-specific compatibility
- **No media user action requirement** — media plays immediately without click gating
- **Debug-only developer extras** — keeps production lightweight

### Smart Navigation
- **External links open in default browser** — never navigates away from the chat
- **Same-origin only** — blocks navigation to non-proton.me domains within the app
- **Offline error page** — shows a native-looking "You appear to be offline" page
- **`window.open()` handling** — loads popups in the main view instead of new windows

### Native JavaScript Bridge
- **Focus message input** (⌘L) — programmatically focuses the chat textarea
- **Toggle sidebar** (⌃⌘S) — clicks the sidebar button via DOM
- **New chat** (⌘T) — starts a new conversation or falls back to root URL
- **Injected CSS** — native-style scrollbars, focus rings, font smoothing, anti-text-selection on chrome elements

## 📁 Project Structure

```
Lumo/
├── LumoApp.swift              — SwiftUI app entry point + Settings scene
├── AppDelegate.swift          — App lifecycle, window management, menu actions
├── AppSettings.swift          — Observable settings (persisted via UserDefaults)
├── ChatWindowController.swift — Window chrome + toolbar configuration
├── WebViewController.swift    — WKWebView setup, JS/CSS injection, navigation, find bar
├── MenuBuilder.swift           — Complete native menu bar construction
├── SettingsView.swift         — SwiftUI settings panel
├── Info.plist                 — App metadata
├── Lumo.entitlements          — Network client entitlement
└── Assets.xcassets/           — App icon + accent color
```

## 🏗️ Building

### Using the build script:
```bash
./build.sh --open
```

The script builds with the locally selected Xcode, writes DerivedData under
`build/DerivedData`, and installs the latest app at `/Applications/Lumo.app`.
Use `--debug` for a Debug build or `--install-dir <path>` to install elsewhere.

### Using Xcode:
1. Open `Lumo.xcodeproj` in Xcode
2. Select the Lumo scheme
3. Build and run (⌘R)

### Requirements:
- macOS 12.0+ (Monterey)
- Xcode 15+ (or Xcode beta for macOS 14+ features)
- Swift 5.0+

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New Window |
| ⌘T | New Chat |
| ⌘W | Close Window |
| ⌘R | Reload Page |
| ⇧⌘R | Clear Session & Reload |
| ⌘[ | Navigate Back |
| ⌘] | Navigate Forward |
| ⌘F | Find on Page |
| ⌘L | Focus Message Input |
| ⌃⌘S | Toggle Sidebar |
| ⌘+ | Zoom In |
| ⌘- | Zoom Out |
| ⌘0 | Reset Zoom |
| ⌃⌘F | Enter Full Screen |
| ⌘, | Settings |

## 🔒 Privacy

- No telemetry, no analytics, no tracking
- Tracker blocking enabled by default (toggleable in Settings)
- All data stays local (cookies, cache, preferences)
- App runs with hardened runtime enabled
- ATS (App Transport Security) enforces HTTPS only

## ⚠️ Disclaimer

This is an unofficial wrapper. It is **not affiliated with, endorsed by, or sponsored by Proton AG**. All trademarks belong to their respective owners. The app simply wraps the publicly accessible web interface at `lumo.proton.me` in a native macOS shell.

## 📝 License

Open source. Do whatever you want with it.
