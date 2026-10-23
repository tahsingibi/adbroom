import Foundation

/// Stable release tags use SemVer. Build metadata never causes an update or downgrade.
struct AppVersion: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int
    init?(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let parts = version.split(separator: "+", omittingEmptySubsequences: false)
        guard parts.count <= 2, !parts[0].contains("-"),
              parts.count == 1 || parts[1].range(of: #"^[0-9A-Za-z.-]+$"#, options: .regularExpression) != nil else { return nil }
        let numbers = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(numbers.count), numbers.allSatisfy({
            !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) && ($0.count == 1 || !$0.hasPrefix("0"))
        }), let major = Int(numbers[0]), let minor = Int(numbers[1]),
              let patch = numbers.count == 3 ? Int(numbers[2]) : 0 else { return nil }
        self.major = major; self.minor = minor; self.patch = patch
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

struct GitHubRelease: Decodable, Equatable {
    struct Asset: Decodable, Equatable {
        let name: String
        let browserDownloadURL: URL
        let size: Int?
        let digest: String?
        enum CodingKeys: String, CodingKey { case name, size, digest; case browserDownloadURL = "browser_download_url" }
    }
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name", htmlURL = "html_url", name, body, draft, prerelease, assets
    }
    var macAsset: Asset? {
        assets.first { $0.name.hasPrefix("ADBroom-") && $0.name.hasSuffix(".dmg")
            && UpdateClient.isReleaseURL($0.browserDownloadURL, download: true) }
    }
    var launcherAsset: Asset? {
        assets.first { $0.name.hasPrefix("ADBroomLauncher-") && $0.name.hasSuffix(".apk")
            && UpdateClient.isReleaseURL($0.browserDownloadURL, download: true) }
    }
    var downloadURL: URL? { macAsset?.browserDownloadURL }
    func version(for channel: ReleaseChannel) -> AppVersion? {
        switch channel {
        case .macOS:
            return AppVersion(tagName.hasPrefix("macos-") ? String(tagName.dropFirst(6)) : tagName)
        case .launcher:
            guard tagName.hasPrefix("launcher-") else { return nil }
            return AppVersion(String(tagName.dropFirst(9)))
        }
    }
}

enum ReleaseChannel { case macOS, launcher }

enum UpdateError: Error, Equatable {
    case noRelease, rateLimited, server(Int), invalidResponse, invalidVersion, offline
}

struct UpdateClient {
    static let repository = "tahsingibi/adbroom"
    static let releasesURL = URL(string: "https://github.com/\(repository)/releases")!
    static let latestURL = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=100&page=1")!
    static let macReleasesURL = URL(string: "https://github.com/\(repository)/releases?q=macos-v")!
    static let launcherReleasesURL = URL(string: "https://github.com/\(repository)/releases?q=launcher-v")!
    let session: URLSession
    init(session: URLSession? = nil) {
        if let session { self.session = session; return }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        self.session = URLSession(configuration: config)
    }
    static func isReleaseURL(_ url: URL, download: Bool = false) -> Bool {
        guard url.scheme == "https", url.host == "github.com", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return false }
        let prefix = "/\(repository)/releases/" + (download ? "download/" : "tag/")
        return url.path.hasPrefix(prefix) && url.path.count > prefix.count
    }
    static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("ADBroom-update-checker", forHTTPHeaderField: "User-Agent")
        return request
    }
    func data(_ request: URLRequest, limit: Int) async throws -> Data {
        let data: Data; let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw UpdateError.offline }
        try Self.validate(response)
        guard data.count <= limit else { throw UpdateError.invalidResponse }
        return data
    }
    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw UpdateError.invalidResponse }
        switch http.statusCode {
        case 200: return
        case 404: throw UpdateError.noRelease
        case 403, 429: throw UpdateError.rateLimited
        default: throw UpdateError.server(http.statusCode)
        }
    }
    /// Asset and tag filters keep an independent launcher release out of Mac update checks.
    func latest(channel: ReleaseChannel = .macOS) async throws -> GitHubRelease {
        for page in 1...5 {
            let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases?per_page=100&page=\(page)")!
            let response = try await data(Self.request(url), limit: 4_194_304)
            guard let releases = try? JSONDecoder().decode([GitHubRelease].self, from: response) else { throw UpdateError.invalidResponse }
            let eligible = releases.filter { release in
                !release.draft && !release.prerelease && Self.isReleaseURL(release.htmlURL)
                && release.version(for: channel) != nil
                && (channel == .macOS ? release.macAsset != nil : release.launcherAsset != nil)
            }
            if let newest = eligible.max(by: { $0.version(for: channel)! < $1.version(for: channel)! }) { return newest }
            if releases.count < 100 { break }
        }
        throw UpdateError.noRelease
    }
}
