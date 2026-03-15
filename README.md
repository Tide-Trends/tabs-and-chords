# Tabs & Chords

Minimal macOS menu bar app that reads the currently playing song from Spotify or Apple Music and opens tab searches for it.

## What it does

- Uses a custom monochrome guitar-pick style menu bar icon.
- Single click the menu bar item to open Ultimate Guitar search for the currently playing song.
- Double click the menu bar item to read the currently open Ultimate Guitar tab URL and play that song in Apple Music.
- Ultimate Guitar title search format: `<song> <artist>`
- Right click the menu bar item to open a small menu with playback, search, refresh, launch-at-login, and quit actions.
- Supports Spotify and Apple Music when they are actively playing.
- Launch at login is handled through macOS login items and may require approval in System Settings.
- Supports Safari, Google Chrome, Arc, Brave Browser, and Microsoft Edge for reading the current Ultimate Guitar tab URL.
- Global shortcuts:
  - `Option-Command-P` plays the current Ultimate Guitar tab in Apple Music
  - `Option-Command-T` searches tabs for the current song
- For Apple Music playback from a tab, the app first tries direct library playback, then resolves the song via Apple search and opens the exact `music://music.apple.com/...` track URL automatically.

## Build

```bash
swift build
```

## Install

```bash
./scripts/install.sh
```