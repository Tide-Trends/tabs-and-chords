# Tabs & Chords

> Minimal macOS menu bar app that bridges your music player with guitar tabs, chords, and sheet music.

<img src="https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square" alt="macOS 13+"/> <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift 5.9"/> <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT"/>

![Demo](assets/demo.gif)

---

## What It Does

Tabs & Chords lives in your menu bar and connects your music to guitar resources. Play a song, click the pick icon, and you're looking at tabs.

### Core Actions

| Action | Trigger | Description |
|--------|---------|-------------|
| **Search tabs** | Single click / `⌥⌘T` | Opens your chosen tab site with the current song |
| **Play from tab** | Double click / `⌥⌘P` | Reads the open Ultimate Guitar tab URL and plays that song in Apple Music |
| **Copy track** | `⌥⌘⇧C` | Copies "Song – Artist" to clipboard |
| **Alt search** | `⌥⌘S` | Searches with your secondary provider |
| **Menu** | Right click | Full menu with all actions and preferences |

### Supported Players

- **Spotify** — detects currently playing track
- **Apple Music** — detects currently playing track and can play songs from tabs

### Supported Browsers (for reading Ultimate Guitar tabs)

Safari, Google Chrome, Arc, Brave Browser, Microsoft Edge

---

## Customization

All preferences are accessible from the right-click menu under **Preferences**.

### Search Providers

Choose your primary and secondary tab search provider:

| Provider | What it searches |
|----------|-----------------|
| **Ultimate Guitar** | Tabs, chords, bass tabs |
| **Songsterr** | Interactive tabs with playback |
| **Chordify** | Chord diagrams from audio |
| **Musescore** | Sheet music and notation |

Set a secondary provider to quickly search two sites for the same song.

### Feedback Style

Control how the app communicates actions:

- **Status Bar Flash** — briefly shows a message in the menu bar (default)
- **Banner Notifications** — system notification banners
- **None** — silent operation

### Display Options

- **Show song in status bar** — displays the current track name next to the pick icon
- **Show shortcut hints** — includes keyboard shortcut reminders in the menu

### Other Settings

- **Launch at login** — start automatically when you log in
- **Check for updates on launch** — quietly checks GitHub for new releases

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥⌘T` | Search tabs for the current song |
| `⌥⌘P` | Play the open Ultimate Guitar tab in Apple Music |
| `⌥⌘⇧C` | Copy current track info to clipboard |
| `⌥⌘S` | Search with secondary provider |

---

## Install

### Option 1: Download from Releases

Download the latest DMG from [Releases](https://github.com/Tide-Trends/tabs-and-chords/releases/).

#### First launch (Gatekeeper)

Since the app isn't notarized, run this once:

```bash
xattr -dr com.apple.quarantine "/Applications/Tabs & Chords.app"
```

### Option 2: Build from Source

```bash
git clone https://github.com/Tide-Trends/tabs-and-chords.git
cd tabs-and-chords
swift build -c release
```

The binary is at `.build/release/TabsAndChords`.

Or open in Xcode:

```bash
open Package.swift
```

### Build DMG

```bash
zsh scripts/build_dmg.sh
```

---

## Requirements

- **macOS 13 Ventura** or later
- Apple Silicon or Intel Mac
- Accessibility permissions for AppleScript (prompted on first use)

---

## How It Works

1. **Song detection** — Queries Spotify and Apple Music via AppleScript for the currently playing track
2. **Tab search** — Constructs a search URL for the chosen provider and opens it in your default browser
3. **Tab → playback** — Reads the active browser tab URL, parses the Ultimate Guitar path to extract artist/title, searches Apple Music (library first, then catalog via iTunes Search API), and plays the match
4. **Browser priority** — Checks the frontmost browser first, then falls back through your configured priority order

---

## Companion App

For a notch-integrated experience, see [Boring Notch + Guitar Tabs](https://github.com/Tide-Trends/boring.notch) — a fork of TheBoringNotch with built-in Ultimate Guitar search in the macOS notch.

---

## License

MIT
