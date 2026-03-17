import AppKit
import Foundation

enum SearchProvider: String, CaseIterable, Codable {
    case ultimateGuitar = "Ultimate Guitar"
    case songsterr = "Songsterr"
    case chordify = "Chordify"
    case musescore = "Musescore"

    var baseSearchURL: String {
        switch self {
        case .ultimateGuitar:
            return "https://www.ultimate-guitar.com/search.php?search_type=title&value="
        case .songsterr:
            return "https://www.songsterr.com/?pattern="
        case .chordify:
            return "https://chordify.net/search/"
        case .musescore:
            return "https://musescore.com/sheetmusic?text="
        }
    }

    var iconName: String {
        switch self {
        case .ultimateGuitar: return "guitars.fill"
        case .songsterr: return "waveform.path"
        case .chordify: return "music.note.list"
        case .musescore: return "doc.text"
        }
    }
}

enum NotificationStyle: String, CaseIterable, Codable {
    case banner = "Banner Notifications"
    case statusBar = "Status Bar Flash"
    case none = "None"
}

struct BrowserPriority: Codable, Equatable {
    var order: [String]

    static let defaultOrder = ["Safari", "Google Chrome", "Arc", "Brave Browser", "Microsoft Edge"]

    init(order: [String] = BrowserPriority.defaultOrder) {
        self.order = order
    }
}

final class Preferences: @unchecked Sendable {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    var searchProvider: SearchProvider {
        get {
            guard let raw = defaults.string(forKey: "searchProvider"),
                  let provider = SearchProvider(rawValue: raw)
            else { return .ultimateGuitar }
            return provider
        }
        set { defaults.set(newValue.rawValue, forKey: "searchProvider") }
    }

    var secondarySearchProvider: SearchProvider? {
        get {
            guard let raw = defaults.string(forKey: "secondarySearchProvider"),
                  let provider = SearchProvider(rawValue: raw)
            else { return nil }
            return provider
        }
        set { defaults.set(newValue?.rawValue, forKey: "secondarySearchProvider") }
    }

    var notificationStyle: NotificationStyle {
        get {
            guard let raw = defaults.string(forKey: "notificationStyle"),
                  let style = NotificationStyle(rawValue: raw)
            else { return .statusBar }
            return style
        }
        set { defaults.set(newValue.rawValue, forKey: "notificationStyle") }
    }

    var browserPriority: BrowserPriority {
        get {
            guard let data = defaults.data(forKey: "browserPriority"),
                  let priority = try? JSONDecoder().decode(BrowserPriority.self, from: data)
            else { return BrowserPriority() }
            return priority
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "browserPriority")
            }
        }
    }

    var showSongInStatusBar: Bool {
        get { defaults.object(forKey: "showSongInStatusBar") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showSongInStatusBar") }
    }

    var autoRefreshInterval: TimeInterval {
        get {
            let val = defaults.double(forKey: "autoRefreshInterval")
            return val > 0 ? val : 0
        }
        set { defaults.set(newValue, forKey: "autoRefreshInterval") }
    }

    var checkForUpdatesOnLaunch: Bool {
        get { defaults.object(forKey: "checkForUpdatesOnLaunch") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "checkForUpdatesOnLaunch") }
    }

    var preferAppleMusicPlayback: Bool {
        get { defaults.object(forKey: "preferAppleMusicPlayback") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "preferAppleMusicPlayback") }
    }

    var showKeyboardShortcutHints: Bool {
        get { defaults.object(forKey: "showKeyboardShortcutHints") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showKeyboardShortcutHints") }
    }

    var openInBackground: Bool {
        get { defaults.object(forKey: "openInBackground") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "openInBackground") }
    }
}
