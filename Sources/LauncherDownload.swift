import Foundation
import CryptoKit

enum LauncherDownloadError: Error, Equatable { case noChecksum, integrity, tooLarge }

struct LauncherDownload {
    let url: URL
    let name: String
    static func message(_ error: Error) -> String {
        if let error = error as? UpdateError {
            switch error {
            case .noRelease: return L("GitHub'da henüz indirilebilir launcher yayını yok. İndirdiğin APK'yı APK yükle düğmesiyle kurabilirsin.", "No downloadable launcher release is available on GitHub yet. Install a local APK using Install APK.")
            case .offline: return L("Launcher indirilemedi. İnternet bağlantını kontrol et.", "Could not download the launcher. Check your internet connection.")
            case .rateLimited: return L("GitHub istek sınırına ulaşıldı. Daha sonra tekrar dene.", "GitHub's request limit was reached. Try again later.")
            default: break
            }
        }
        if error is LauncherDownloadError { return L("Launcher dosyası doğrulanamadı. GitHub yayınını kontrol et.", "The launcher file could not be verified. Check its GitHub release.") }
        return L("Launcher indirilemedi: ", "Could not download launcher: ") + error.localizedDescription
    }
    static func digest(_ text: String) -> String? {
        let value = text.lowercased()
        return value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil ? value : nil
    }
    static func verify(_ url: URL, expected: String, size: Int?) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let actual = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard actual > 0, actual <= 33_554_432 else { throw LauncherDownloadError.tooLarge }
        guard size == nil || size == actual, digest(expected) != nil else { throw LauncherDownloadError.integrity }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let magic = try handle.read(upToCount: 2)
        guard magic == Data([0x50, 0x4b]) else { throw LauncherDownloadError.integrity }
        try handle.seek(toOffset: 0)
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
        let checksum = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard checksum == expected.lowercased() else { throw LauncherDownloadError.integrity }
    }
}

extension UpdateClient {
    typealias FileDownload = (URLRequest) async throws -> (URL, URLResponse)
    func downloadLauncher(using download: FileDownload? = nil) async throws -> LauncherDownload {
        let release = try await latest(channel: .launcher)
        guard let asset = release.launcherAsset else { throw UpdateError.noRelease }
        guard asset.size == nil || (asset.size! > 0 && asset.size! <= 33_554_432) else { throw LauncherDownloadError.tooLarge }
        let expected: String
        if let digest = asset.digest, digest.hasPrefix("sha256:"), let checksum = LauncherDownload.digest(String(digest.dropFirst(7))) {
            expected = checksum
        } else {
            guard let sidecar = release.assets.first(where: { $0.name == asset.name + ".sha256" && Self.isReleaseURL($0.browserDownloadURL, download: true, channel: .launcher) }) else { throw LauncherDownloadError.noChecksum }
            let response = try await data(URLRequest(url: sidecar.browserDownloadURL), limit: 4096)
            let pieces = String(decoding: response, as: UTF8.self).split(whereSeparator: \.isWhitespace)
            guard let first = pieces.first, let checksum = LauncherDownload.digest(String(first)),
                  pieces.count == 2, String(pieces[1]).trimmingCharacters(in: CharacterSet(charactersIn: "*")) == asset.name else { throw LauncherDownloadError.integrity }
            expected = checksum
        }
        let location: URL; let response: URLResponse
        var request = URLRequest(url: asset.browserDownloadURL); request.timeoutInterval = 120
        do {
            if let download { (location, response) = try await download(request) }
            else { (location, response) = try await session.download(for: request) }
        } catch { throw UpdateError.offline }
        defer { try? FileManager.default.removeItem(at: location) }
        try Self.validate(response)
        // Verify and move the file off the main actor before handing it to ADB or a save panel.
        try LauncherDownload.verify(location, expected: expected, size: asset.size)
        let cached = FileManager.default.temporaryDirectory.appendingPathComponent("ADBroomLauncher-\(UUID().uuidString).apk")
        try FileManager.default.moveItem(at: location, to: cached)
        return LauncherDownload(url: cached, name: asset.name)
    }
}
