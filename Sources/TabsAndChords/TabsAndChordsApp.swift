import AppKit
import Carbon
import Foundation
import ServiceManagement

struct TrackInfo {
    let title: String
    let artist: String

    var searchQuery: String {
        [title, artist]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var displayName: String {
        [title, artist]
            .filter { !$0.isEmpty }
            .joined(separator: " – ")
    }
}

struct ScriptExecutionError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

enum AppleScriptRunner {
    static func run(script: String, arguments: [String] = []) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")

        var osascriptArguments = ["-e", script]
        if !arguments.isEmpty {
            osascriptArguments.append("--")
            osascriptArguments.append(contentsOf: arguments)
        }

        process.arguments = osascriptArguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw ScriptExecutionError(message: errorOutput.isEmpty ? "AppleScript command failed." : errorOutput)
        }

        return output
    }
}

// MARK: - Player Detection

enum PlayerSource: CaseIterable {
    case spotify
    case music

    var applicationName: String {
        switch self {
        case .spotify:
            return "Spotify"
        case .music:
            return "Music"
        }
    }

    var script: String {
        switch self {
        case .spotify:
            return #"""
tell application "Spotify"
    if it is running and player state is playing then
        return name of current track & "|||" & artist of current track
    end if
end tell
"""#
        case .music:
            return #"""
tell application "Music"
    if it is running and player state is playing then
        return name of current track & "|||" & artist of current track
    end if
end tell
"""#
        }
    }
}

enum SongLookupError: LocalizedError {
    case notPlaying

    var errorDescription: String? {
        switch self {
        case .notPlaying:
            return "No currently playing song found in Spotify or Music."
        }
    }
}

final class SongLookupService {
    func currentTrack() throws -> TrackInfo {
        for source in PlayerSource.allCases {
            if let track = readTrack(from: source) {
                return track
            }
        }

        throw SongLookupError.notPlaying
    }

    private func readTrack(from source: PlayerSource) -> TrackInfo? {
        do {
            let rawOutput = try AppleScriptRunner.run(script: source.script)

            guard !rawOutput.isEmpty else {
                return nil
            }

            let components = rawOutput.components(separatedBy: "|||")
            guard let title = components.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty
            else {
                return nil
            }

            let artist = components.dropFirst().joined(separator: "|||")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return TrackInfo(title: title, artist: artist)
        } catch {
            return nil
        }
    }
}

// MARK: - Browser Tab Reading

enum BrowserSource: CaseIterable {
    case safari
    case chrome
    case arc
    case brave
    case edge

    var applicationName: String {
        switch self {
        case .safari:
            return "Safari"
        case .chrome:
            return "Google Chrome"
        case .arc:
            return "Arc"
        case .brave:
            return "Brave Browser"
        case .edge:
            return "Microsoft Edge"
        }
    }

    var script: String {
        switch self {
        case .safari:
            return """
tell application "Safari"
    if it is running and (count of windows) > 0 then
        return URL of current tab of front window
    end if
end tell
"""
        case .chrome, .arc, .brave, .edge:
            return """
tell application "\(applicationName)"
    if it is running and (count of windows) > 0 then
        return URL of active tab of front window
    end if
end tell
"""
        }
    }

    static func fromName(_ name: String) -> BrowserSource? {
        allCases.first { $0.applicationName == name }
    }
}

// MARK: - Ultimate Guitar Service

enum UltimateGuitarError: LocalizedError {
    case noOpenUltimateGuitarTab

    var errorDescription: String? {
        switch self {
        case .noOpenUltimateGuitarTab:
            return "No supported browser has an open Ultimate Guitar tab page in the active tab."
        }
    }
}

final class UltimateGuitarService {
    private let trailingNoiseTokens: Set<String> = [
        "official", "acoustic", "live", "studio", "version", "ver", "tab", "tabs",
        "chord", "chords", "intro", "solo", "lesson", "tutorial", "ukulele",
        "fingerstyle", "bass", "pro", "edit"
    ]

    func currentTrackFromOpenTab() throws -> TrackInfo {
        let prefs = Preferences.shared
        let priorityOrder = prefs.browserPriority.order

        let frontmostApplicationName = NSWorkspace.shared.frontmostApplication?.localizedName
        let prioritizedSources: [BrowserSource] = priorityOrder.compactMap { name in
            BrowserSource.fromName(name)
        }.sorted { lhs, rhs in
            let lhsIsFrontmost = lhs.applicationName == frontmostApplicationName
            let rhsIsFrontmost = rhs.applicationName == frontmostApplicationName
            return lhsIsFrontmost && !rhsIsFrontmost
        }

        let remainingSources = BrowserSource.allCases.filter { source in
            !prioritizedSources.contains(where: { $0.applicationName == source.applicationName })
        }

        for source in prioritizedSources + remainingSources {
            guard let url = currentURL(from: source) else {
                continue
            }

            if let track = parseUltimateGuitarTrack(from: url) {
                return track
            }
        }

        throw UltimateGuitarError.noOpenUltimateGuitarTab
    }

    private func currentURL(from source: BrowserSource) -> URL? {
        do {
            let rawOutput = try AppleScriptRunner.run(script: source.script)
            guard !rawOutput.isEmpty else {
                return nil
            }

            return URL(string: rawOutput)
        } catch {
            return nil
        }
    }

    private func parseUltimateGuitarTrack(from url: URL) -> TrackInfo? {
        guard let host = url.host?.lowercased(), host.contains("ultimate-guitar.com") else {
            return nil
        }

        let pathComponents = url.path.split(separator: "/").map(String.init)
        guard pathComponents.count >= 3, pathComponents[0] == "tab" else {
            return nil
        }

        let artist = humanizeSlug(pathComponents[1])
        let title = normalizeTitleSlug(pathComponents[2])

        guard !artist.isEmpty, !title.isEmpty else {
            return nil
        }

        return TrackInfo(title: title, artist: artist)
    }

    private func humanizeSlug(_ slug: String) -> String {
        slug
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }

    private func normalizeTitleSlug(_ slug: String) -> String {
        var tokens = slug.split(separator: "-").map { String($0).lowercased() }

        while let last = tokens.last, last.allSatisfy(\.isNumber) {
            tokens.removeLast()
        }

        while tokens.count > 1 {
            guard let last = tokens.last else {
                break
            }

            if trailingNoiseTokens.contains(last) || isVersionToken(last) {
                tokens.removeLast()
                continue
            }

            break
        }

        return tokens.joined(separator: " ").capitalized
    }

    private func isVersionToken(_ token: String) -> Bool {
        token.hasPrefix("ver") || token.hasPrefix("v") && token.dropFirst().allSatisfy(\.isNumber)
    }
}

// MARK: - Apple Music Playback

enum AppleMusicPlaybackOutcome {
    case playedFromLibrary
    case playedFromCatalog
}

enum AppleMusicLookupError: LocalizedError {
    case noCatalogMatch

    var errorDescription: String? {
        switch self {
        case .noCatalogMatch:
            return "No Apple Music catalog match was found for this song."
        }
    }
}

private struct ITunesSearchResponse: Decodable {
    let results: [ITunesTrack]
}

private struct ITunesTrack: Decodable {
    let artistName: String?
    let trackName: String?
    let trackViewUrl: URL?
}

final class AppleMusicCatalogService {
    func resolveTrackURL(for track: TrackInfo) throws -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: track.searchQuery),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "10")
        ]

        guard let requestURL = components?.url else {
            throw AppleMusicLookupError.noCatalogMatch
        }

        let fetchedData = try Data(contentsOf: requestURL)

        let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: fetchedData)
        if let exact = bestMatch(in: response.results, for: track), let url = exact.trackViewUrl {
            return stripTrackingParams(from: url)
        }

        if let fallback = response.results.first?.trackViewUrl {
            return stripTrackingParams(from: fallback)
        }

        throw AppleMusicLookupError.noCatalogMatch
    }

    private func bestMatch(in results: [ITunesTrack], for track: TrackInfo) -> ITunesTrack? {
        let normalizedTitle = normalize(track.title)
        let normalizedArtist = normalize(track.artist)

        return results.first { result in
            guard let trackName = result.trackName, let artistName = result.artistName else {
                return false
            }

            let resultTitle = normalize(trackName)
            let resultArtist = normalize(artistName)
            return resultTitle == normalizedTitle && resultArtist == normalizedArtist
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripTrackingParams(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.queryItems = components.queryItems?.filter { $0.name != "uo" }
        return components.url ?? url
    }
}

final class MusicPlaybackService {
    private let catalogService = AppleMusicCatalogService()

    func play(track: TrackInfo) throws -> AppleMusicPlaybackOutcome {
        let searchOutcome = try AppleScriptRunner.run(script: librarySearchScript, arguments: [track.searchQuery])

        if searchOutcome == "library" {
            return .playedFromLibrary
        }

        let catalogURL = try catalogService.resolveTrackURL(for: track)
        let musicURL = convertToMusicURL(catalogURL)
        _ = try AppleScriptRunner.run(script: catalogPlaybackScript, arguments: [musicURL.absoluteString])
        return .playedFromCatalog
    }

    private var librarySearchScript: String {
        #"""
on run argv
    set searchTerm to item 1 of argv

    tell application "Music"
        set matchingTracks to search playlist "Library" of source "Library" for searchTerm
        if (count of matchingTracks) > 0 then
            set matchedTrack to item 1 of matchingTracks
            play matchedTrack
            return "library"
        end if
    end tell

    return "catalog"
end run
"""#
    }

    private var catalogPlaybackScript: String {
        #"""
on run argv
    set targetURL to item 1 of argv

    tell application "Music"
        activate
        open location targetURL
        delay 1.2
        play
        return player state as text
    end tell
end run
"""#
    }

    private func convertToMusicURL(_ httpsURL: URL) -> URL {
        guard let absolute = URLComponents(url: httpsURL, resolvingAgainstBaseURL: false)?.string,
              absolute.hasPrefix("https://")
        else {
            return httpsURL
        }

        return URL(string: absolute.replacingOccurrences(of: "https://", with: "music://")) ?? httpsURL
    }
}

// MARK: - Multi-Provider Search Service

final class SearchService {
    func search(for track: TrackInfo, provider: SearchProvider? = nil) {
        let activeProvider = provider ?? Preferences.shared.searchProvider

        guard let encodedQuery = track.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        guard let url = URL(string: "\(activeProvider.baseSearchURL)\(encodedQuery)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func searchAll(for track: TrackInfo, providers: [SearchProvider]) {
        for provider in providers {
            search(for: track, provider: provider)
        }
    }
}

// MARK: - Clipboard Service

final class ClipboardService {
    func copyTrackInfo(_ track: TrackInfo) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(track.displayName, forType: .string)
    }

    func copySearchURL(_ track: TrackInfo, provider: SearchProvider = .ultimateGuitar) {
        guard let encoded = track.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let urlString = "\(provider.baseSearchURL)\(encoded)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urlString, forType: .string)
    }
}

// MARK: - Launch at Login

final class LaunchAtLoginService {
    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled
    }

    var needsApproval: Bool {
        service.status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}

// MARK: - Keyboard Shortcuts

enum HotKeyAction: UInt32 {
    case searchCurrentSong = 1
    case playUltimateGuitarTab = 2
    case copyTrackInfo = 3
    case searchSecondaryProvider = 4
}

final class HotKeyManager {
    private let signature: OSType = 0x54414243
    private let handler: (HotKeyAction) -> Void
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    init(handler: @escaping (HotKeyAction) -> Void) {
        self.handler = handler
    }

    deinit {
        for hotKeyRef in hotKeyRefs {
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func registerDefaultHotKeys() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(eventRef)
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        register(action: .searchCurrentSong, keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | optionKey))
        register(action: .playUltimateGuitarTab, keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey | optionKey))
        register(action: .copyTrackInfo, keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | optionKey | shiftKey))
        register(action: .searchSecondaryProvider, keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | optionKey))
    }

    private func register(action: HotKeyAction, keyCode: UInt32, modifiers: UInt32) {
        let hotKeyID = EventHotKeyID(signature: signature, id: action.rawValue)
        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        hotKeyRefs.append(hotKeyRef)
    }

    private func handleHotKeyEvent(_ eventRef: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == signature, let action = HotKeyAction(rawValue: hotKeyID.id) else {
            return noErr
        }

        handler(action)
        return noErr
    }
}

// MARK: - Status Bar Icon

enum StatusBarIcon {
    static func makeTemplateImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        let pick = NSBezierPath()
        pick.move(to: NSPoint(x: 9, y: 16))
        pick.curve(to: NSPoint(x: 3.5, y: 8.5), controlPoint1: NSPoint(x: 4.8, y: 15), controlPoint2: NSPoint(x: 2.2, y: 11.6))
        pick.curve(to: NSPoint(x: 9, y: 2), controlPoint1: NSPoint(x: 4.1, y: 5.1), controlPoint2: NSPoint(x: 6.3, y: 2.1))
        pick.curve(to: NSPoint(x: 14.5, y: 8.5), controlPoint1: NSPoint(x: 11.7, y: 1.9), controlPoint2: NSPoint(x: 13.9, y: 5.1))
        pick.curve(to: NSPoint(x: 9, y: 16), controlPoint1: NSPoint(x: 15.8, y: 11.6), controlPoint2: NSPoint(x: 13.2, y: 15))
        pick.close()

        NSColor.labelColor.setStroke()
        pick.lineWidth = 1.4
        pick.stroke()

        for x in [6.2, 9.0, 11.8] {
            let string = NSBezierPath()
            string.move(to: NSPoint(x: x, y: 5))
            string.line(to: NSPoint(x: x, y: 12.8))
            string.lineWidth = 1.1
            string.stroke()
        }

        let soundHole = NSBezierPath(ovalIn: NSRect(x: 7.3, y: 7.2, width: 3.4, height: 3.4))
        soundHole.lineWidth = 1.1
        soundHole.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

// MARK: - Notification Helper

@MainActor
enum NotificationHelper {
    static func showStatusBarFlash(_ statusItem: NSStatusItem?, message: String, duration: TimeInterval = 2.0) {
        guard let button = statusItem?.button else { return }
        let originalImage = button.image
        let originalTitle = button.title

        button.image = nil
        button.title = message
        button.font = NSFont.systemFont(ofSize: 10, weight: .medium)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            button.title = originalTitle
            button.image = originalImage
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let songLookupService = SongLookupService()
    private let searchService = SearchService()
    private let ultimateGuitarService = UltimateGuitarService()
    private let musicPlaybackService = MusicPlaybackService()
    private let launchAtLoginService = LaunchAtLoginService()
    private let clipboardService = ClipboardService()
    private let updateService = UpdateService()
    private let prefs = Preferences.shared

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var currentTrackItem: NSMenuItem?
    private var subtitleItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var hotKeyManager: HotKeyManager?
    private var pendingSingleClickWorkItem: DispatchWorkItem?
    private var autoRefreshTimer: Timer?

    // Preference menu items
    private var searchProviderMenu: NSMenu?
    private var notificationStyleMenu: NSMenu?
    private var browserPriorityMenu: NSMenu?
    private var showSongItem: NSMenuItem?
    private var checkUpdatesItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        hotKeyManager = HotKeyManager { [weak self] action in
            Task { @MainActor in
                self?.performHotKeyAction(action)
            }
        }
        hotKeyManager?.registerDefaultHotKeys()

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = StatusBarIcon.makeTemplateImage()
            button.imagePosition = .imageOnly
            button.toolTip = "Tabs & Chords — Single click: search tabs. Double click: play from UG tab. Right click: menu."
            button.target = self
            button.action = #selector(handleStatusBarClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        buildMenu()
        setupAutoRefresh()

        if prefs.checkForUpdatesOnLaunch {
            Task {
                await checkForUpdatesQuietly()
            }
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        let currentTrackItem = NSMenuItem(title: "Current song: Not checked yet", action: nil, keyEquivalent: "")
        currentTrackItem.isEnabled = false
        self.currentTrackItem = currentTrackItem
        menu.addItem(currentTrackItem)

        let shortcutHints = prefs.showKeyboardShortcutHints
            ? "  Shortcuts: ⌥⌘T (search), ⌥⌘P (play), ⌥⌘⇧C (copy), ⌥⌘S (alt search)"
            : ""
        let subtitleItem = NSMenuItem(title: "Single click: search tabs • Double click: play from tab\(shortcutHints)", action: nil, keyEquivalent: "")
        subtitleItem.isEnabled = false
        self.subtitleItem = subtitleItem
        menu.addItem(subtitleItem)

        menu.addItem(.separator())

        // Primary actions
        let playOpenTabItem = NSMenuItem(title: "Play open tab in Apple Music", action: #selector(playOpenUltimateGuitarTab), keyEquivalent: "p")
        playOpenTabItem.target = self
        playOpenTabItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(playOpenTabItem)

        let searchItem = NSMenuItem(title: "Search tabs for current song", action: #selector(searchCurrentSongFromMenu), keyEquivalent: "t")
        searchItem.target = self
        searchItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(searchItem)

        if prefs.secondarySearchProvider != nil {
            let secondaryItem = NSMenuItem(title: "Search with \(prefs.secondarySearchProvider!.rawValue)", action: #selector(searchSecondaryProvider), keyEquivalent: "s")
            secondaryItem.target = self
            secondaryItem.keyEquivalentModifierMask = [.command, .option]
            menu.addItem(secondaryItem)
        }

        let copyItem = NSMenuItem(title: "Copy track info to clipboard", action: #selector(copyCurrentTrack), keyEquivalent: "c")
        copyItem.target = self
        copyItem.keyEquivalentModifierMask = [.command, .option, .shift]
        menu.addItem(copyItem)

        let copyURLItem = NSMenuItem(title: "Copy search URL to clipboard", action: #selector(copySearchURL), keyEquivalent: "")
        copyURLItem.target = self
        menu.addItem(copyURLItem)

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh current song", action: #selector(refreshCurrentSong), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.keyEquivalentModifierMask = [.command]
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        // Preferences submenu
        let prefsSubmenu = NSMenu()

        // Search provider
        let providerSubmenu = NSMenu()
        for provider in SearchProvider.allCases {
            let item = NSMenuItem(title: provider.rawValue, action: #selector(setSearchProvider(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = provider.rawValue
            item.state = prefs.searchProvider == provider ? .on : .off
            providerSubmenu.addItem(item)
        }
        let providerItem = NSMenuItem(title: "Search Provider", action: nil, keyEquivalent: "")
        providerItem.submenu = providerSubmenu
        self.searchProviderMenu = providerSubmenu
        prefsSubmenu.addItem(providerItem)

        // Secondary search provider
        let secondaryProviderSubmenu = NSMenu()
        let noneItem = NSMenuItem(title: "None", action: #selector(setSecondaryProvider(_:)), keyEquivalent: "")
        noneItem.target = self
        noneItem.representedObject = "none"
        noneItem.state = prefs.secondarySearchProvider == nil ? .on : .off
        secondaryProviderSubmenu.addItem(noneItem)
        for provider in SearchProvider.allCases where provider != prefs.searchProvider {
            let item = NSMenuItem(title: provider.rawValue, action: #selector(setSecondaryProvider(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = provider.rawValue
            item.state = prefs.secondarySearchProvider == provider ? .on : .off
            secondaryProviderSubmenu.addItem(item)
        }
        let secondaryProviderItem = NSMenuItem(title: "Secondary Provider", action: nil, keyEquivalent: "")
        secondaryProviderItem.submenu = secondaryProviderSubmenu
        prefsSubmenu.addItem(secondaryProviderItem)

        prefsSubmenu.addItem(.separator())

        // Notification style
        let notifSubmenu = NSMenu()
        for style in NotificationStyle.allCases {
            let item = NSMenuItem(title: style.rawValue, action: #selector(setNotificationStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.state = prefs.notificationStyle == style ? .on : .off
            notifSubmenu.addItem(item)
        }
        let notifItem = NSMenuItem(title: "Feedback Style", action: nil, keyEquivalent: "")
        notifItem.submenu = notifSubmenu
        self.notificationStyleMenu = notifSubmenu
        prefsSubmenu.addItem(notifItem)

        prefsSubmenu.addItem(.separator())

        let showSongItem = NSMenuItem(title: "Show song in status bar", action: #selector(toggleShowSong), keyEquivalent: "")
        showSongItem.target = self
        showSongItem.state = prefs.showSongInStatusBar ? .on : .off
        self.showSongItem = showSongItem
        prefsSubmenu.addItem(showSongItem)

        let shortcutHintsItem = NSMenuItem(title: "Show shortcut hints in menu", action: #selector(toggleShortcutHints), keyEquivalent: "")
        shortcutHintsItem.target = self
        shortcutHintsItem.state = prefs.showKeyboardShortcutHints ? .on : .off
        prefsSubmenu.addItem(shortcutHintsItem)

        let checkUpdatesItem = NSMenuItem(title: "Check for updates on launch", action: #selector(toggleCheckUpdates), keyEquivalent: "")
        checkUpdatesItem.target = self
        checkUpdatesItem.state = prefs.checkForUpdatesOnLaunch ? .on : .off
        self.checkUpdatesItem = checkUpdatesItem
        prefsSubmenu.addItem(checkUpdatesItem)

        let prefsItem = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        prefsItem.submenu = prefsSubmenu
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        self.launchAtLoginItem = launchAtLoginItem
        menu.addItem(launchAtLoginItem)

        let checkForUpdatesItem = NSMenuItem(title: "Check for updates…", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "")
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Tabs & Chords", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu
        refreshMenuState()
    }

    // MARK: - Auto Refresh

    private func setupAutoRefresh() {
        autoRefreshTimer?.invalidate()
        let interval = prefs.autoRefreshInterval
        guard interval > 0 else { return }

        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMenuState()
            }
        }
    }

    // MARK: - Click Handling

    @objc private func handleStatusBarClick() {
        guard let event = NSApp.currentEvent else {
            scheduleSingleClickAction()
            return
        }

        if event.type == .rightMouseUp {
            refreshMenuState()

            guard let menu, let statusItem else {
                return
            }

            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }

        if event.type == .leftMouseUp, event.clickCount >= 2 {
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil
            playCurrentUltimateGuitarTab()
            return
        }

        scheduleSingleClickAction()
    }

    // MARK: - Menu Actions

    @objc private func searchCurrentSongFromMenu() {
        searchCurrentSong()
    }

    @objc private func playOpenUltimateGuitarTab() {
        playCurrentUltimateGuitarTab()
    }

    @objc private func refreshCurrentSong() {
        refreshMenuState()
        showFeedback("Refreshed")
    }

    @objc private func copyCurrentTrack() {
        do {
            let track = try songLookupService.currentTrack()
            clipboardService.copyTrackInfo(track)
            showFeedback("Copied: \(track.displayName)")
        } catch {
            showFeedback("Nothing playing")
        }
    }

    @objc private func copySearchURL() {
        do {
            let track = try songLookupService.currentTrack()
            clipboardService.copySearchURL(track, provider: prefs.searchProvider)
            showFeedback("URL copied")
        } catch {
            showFeedback("Nothing playing")
        }
    }

    @objc private func searchSecondaryProvider() {
        guard let provider = prefs.secondarySearchProvider else { return }
        do {
            let track = try songLookupService.currentTrack()
            searchService.search(for: track, provider: provider)
            showFeedback("Searching \(provider.rawValue)…")
        } catch {
            presentMissingSongAlert(message: error.localizedDescription)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let shouldEnable = !launchAtLoginService.isEnabled

        do {
            try launchAtLoginService.setEnabled(shouldEnable)
            refreshLaunchAtLoginState()

            if launchAtLoginService.needsApproval {
                presentLaunchAtLoginApprovalAlert()
            }
        } catch {
            refreshLaunchAtLoginState()
            presentAlert(title: "Could not update launch at login", message: error.localizedDescription)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Preference Actions

    @objc private func setSearchProvider(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let provider = SearchProvider(rawValue: rawValue)
        else { return }
        prefs.searchProvider = provider
        buildMenu()
    }

    @objc private func setSecondaryProvider(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String else { return }
        if rawValue == "none" {
            prefs.secondarySearchProvider = nil
        } else if let provider = SearchProvider(rawValue: rawValue) {
            prefs.secondarySearchProvider = provider
        }
        buildMenu()
    }

    @objc private func setNotificationStyle(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let style = NotificationStyle(rawValue: rawValue)
        else { return }
        prefs.notificationStyle = style
        notificationStyleMenu?.items.forEach { item in
            item.state = (item.representedObject as? String) == rawValue ? .on : .off
        }
    }

    @objc private func toggleShowSong() {
        prefs.showSongInStatusBar.toggle()
        showSongItem?.state = prefs.showSongInStatusBar ? .on : .off
        refreshMenuState()
    }

    @objc private func toggleShortcutHints() {
        prefs.showKeyboardShortcutHints.toggle()
        buildMenu()
    }

    @objc private func toggleCheckUpdates() {
        prefs.checkForUpdatesOnLaunch.toggle()
        checkUpdatesItem?.state = prefs.checkForUpdatesOnLaunch ? .on : .off
    }

    @objc private func checkForUpdatesFromMenu() {
        Task {
            let result = await updateService.checkForUpdates()
            switch result {
            case .upToDate:
                presentAlert(title: "You're up to date", message: "Tabs & Chords v\(updateService.currentVersion) is the latest version.")
            case .updateAvailable(let version, let url):
                let alert = NSAlert()
                alert.messageText = "Update available"
                alert.informativeText = "Version \(version) is available. You're running v\(updateService.currentVersion)."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(url)
                }
            case .error(let message):
                presentAlert(title: "Update check failed", message: message)
            }
        }
    }

    // MARK: - HotKey Handling

    private func performHotKeyAction(_ action: HotKeyAction) {
        switch action {
        case .searchCurrentSong:
            searchCurrentSong()
        case .playUltimateGuitarTab:
            playCurrentUltimateGuitarTab()
        case .copyTrackInfo:
            copyCurrentTrack()
        case .searchSecondaryProvider:
            searchSecondaryProvider()
        }
    }

    private func scheduleSingleClickAction() {
        pendingSingleClickWorkItem?.cancel()

        let action = DispatchWorkItem { [weak self] in
            self?.searchCurrentSong()
        }

        pendingSingleClickWorkItem = action
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: action)
    }

    // MARK: - State Management

    private func refreshMenuState() {
        refreshLaunchAtLoginState()

        do {
            let track = try songLookupService.currentTrack()
            currentTrackItem?.title = "Now playing: \(track.displayName)"

            if prefs.showSongInStatusBar {
                let truncated = track.displayName.count > 30
                    ? String(track.displayName.prefix(27)) + "…"
                    : track.displayName
                statusItem?.button?.title = " \(truncated)"
                statusItem?.button?.imagePosition = .imageLeft
            } else {
                statusItem?.button?.title = ""
                statusItem?.button?.imagePosition = .imageOnly
            }
        } catch {
            currentTrackItem?.title = "Now playing: Nothing detected"
            if prefs.showSongInStatusBar {
                statusItem?.button?.title = ""
                statusItem?.button?.imagePosition = .imageOnly
            }
        }
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginItem?.state = launchAtLoginService.isEnabled ? .on : .off

        if launchAtLoginService.needsApproval {
            launchAtLoginItem?.title = "Launch at login (needs approval)"
        } else {
            launchAtLoginItem?.title = "Launch at login"
        }
    }

    // MARK: - Core Actions

    private func searchCurrentSong() {
        do {
            let track = try songLookupService.currentTrack()
            currentTrackItem?.title = "Now playing: \(track.displayName)"
            searchService.search(for: track)
            showFeedback("Searching: \(track.displayName)")
        } catch {
            presentMissingSongAlert(message: error.localizedDescription)
        }
    }

    private func playCurrentUltimateGuitarTab() {
        do {
            let track = try ultimateGuitarService.currentTrackFromOpenTab()
            playInAppleMusic(track)
        } catch {
            presentAlert(title: "Could not use the current browser tab", message: error.localizedDescription)
        }
    }

    private func playInAppleMusic(_ track: TrackInfo) {
        currentTrackItem?.title = "Open tab: \(track.displayName)"

        do {
            let outcome = try musicPlaybackService.play(track: track)

            switch outcome {
            case .playedFromLibrary:
                showFeedback("Playing from library")
            case .playedFromCatalog:
                showFeedback("Playing: \(track.displayName)")
                currentTrackItem?.title = "Playing from tab: \(track.displayName)"
            }
        } catch {
            presentAlert(title: "Could not play in Apple Music", message: error.localizedDescription)
        }
    }

    // MARK: - Update Check

    private func checkForUpdatesQuietly() async {
        let result = await updateService.checkForUpdates()
        if case .updateAvailable(let version, _) = result {
            showFeedback("v\(version) available!")
        }
    }

    // MARK: - Feedback

    private func showFeedback(_ message: String) {
        switch prefs.notificationStyle {
        case .statusBar:
            NotificationHelper.showStatusBarFlash(statusItem, message: message)
        case .banner:
            break
        case .none:
            break
        }
    }

    // MARK: - Alerts

    private func presentMissingSongAlert(message: String) {
        presentAlert(title: "No playing song detected", message: message)
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentLaunchAtLoginApprovalAlert() {
        presentAlert(title: "Launch at login needs approval", message: "macOS may require you to allow Tabs & Chords in System Settings > General > Login Items.")
    }
}

// MARK: - App Entry Point

@main
struct TabsAndChordsApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
