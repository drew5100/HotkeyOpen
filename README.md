# HotkeyOpen

A macOS menu bar app for managing keyboard shortcuts to open apps and run commands.

## Requirements

- macOS 14.0 or later
- Xcode 15+ (for building from source)

## Building from Source

### Option 1: Using Swift Package Manager

```bash
git clone https://github.com/drew5100/HotkeyOpen.git
cd HotkeyOpen
swift build -c release
```

The built binary will be at `.build/release/HotkeyOpen`

### Option 2: Using XcodeGen

```bash
git clone https://github.com/drew5100/HotkeyOpen.git
cd HotkeyOpen
xcodegen generate
xcodebuild -project HotkeyOpen.xcodeproj -scheme HotkeyOpen -configuration Release build
```

The built app will be at `build/Release/HotkeyOpen.app`

### Running the App

After building, you can run the app with:
```bash
open .build/release/HotkeyOpen
```

Or copy to Applications:
```bash
cp -r .build/release/HotkeyOpen /Applications/
```

## Installation

Download the latest release from the [Releases](https://github.com/drew5100/HotkeyOpen/releases) page.

After downloading:
1. Unzip the file
2. Move `HotkeyOpen.app` to `/Applications`
3. Right-click the app and select "Open" to bypass Gatekeeper (first time only)

## Development

Dependencies:
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - For keyboard shortcut recording
