# Tabs & Chords

![Tabs & Chords demo](https://raw.githubusercontent.com/Tide-Trends/tabs-and-chords/main/Screen%20Recording%202026-03-15%20at%205.gif)

DMG installer (build locally):

```bash
zsh scripts/build_dmg.sh
```

This creates [dist/Tabs-and-Chords.dmg](dist/Tabs-and-Chords.dmg). Open the DMG and drag `Tabs & Chords.app` into `Applications`.

Minimal macOS menu bar app that reads the currently playing song from Spotify or Apple Music and integrates with Ultimate Guitar + Apple Music.

## What it does

Allows you to quickly open or play a song from Ultimate Guitar tabs.
- Single click the menu bar item to open Ultimate Guitar search for the currently playing song.
- Double click the menu bar item to read the currently open Ultimate Guitar tab URL and play that song in Apple Music.
- Right click the menu bar item to open a small menu with playback, search, refresh, launch-at-login, and quit actions.
- Supports Spotify and Apple Music when they are actively playing.
- Supports Safari, Google Chrome, Arc, Brave Browser, and Microsoft Edge for reading the current Ultimate Guitar tab URL.
- Global shortcuts:
  - `Option-Command-P` plays the current Ultimate Guitar tab in Apple Music
  - `Option-Command-T` searches tabs for the current song

## Install

You can install either of these ways:

1. Download the repository and open the folder in Xcode, then run the app.
2. Download the DMG from Releases and install from there:
  https://github.com/Tide-Trends/tabs-and-chords/releases/

If you are building from source in Terminal, you can also run:

```bash
./scripts/install.sh
```

## Build DMG

```bash
zsh scripts/build_dmg.sh
```
