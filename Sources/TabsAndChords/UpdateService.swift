import Foundation
import AppKit

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

enum UpdateResult {
    case upToDate
    case updateAvailable(version: String, url: URL)
    case error(String)
}

@MainActor
final class UpdateService {
    private let session = URLSession.shared
    private let repoURL = "https://api.github.com/repos/Tide-Trends/tabs-and-chords/releases/latest"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
    }

    func checkForUpdates() async -> UpdateResult {
        guard let url = URL(string: repoURL) else {
            return .error("Invalid update URL")
        }

        var request = URLRequest(url: url)
        request.setValue("TabsAndChordsApp", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .error("Failed to fetch latest release (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))")
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))

            if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                return .updateAvailable(version: latestVersion, url: release.htmlUrl)
            } else {
                return .upToDate
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
