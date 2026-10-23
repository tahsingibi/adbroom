import Foundation
import CryptoKit

final class ReleaseProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    static var calls = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            Self.calls += 1
            let (code, data) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@main
struct UpdatesTests {
    static func release(_ changes: [String: Any] = [:]) -> Data {
        var object: [String: Any] = ["tag_name": "v9.0.0", "name": "ADBroom 9", "body": "Release notes",
            "html_url": "https://github.com/tahsingibi/adbroom/releases/tag/v9.0.0", "draft": false, "prerelease": false,
            "assets": [["name": "ADBroom-9.0.0.dmg", "browser_download_url": "https://github.com/tahsingibi/adbroom/releases/download/v9.0.0/ADBroom-9.0.0.dmg"]]]
        changes.forEach { object[$0] = $1 }
        return try! JSONSerialization.data(withJSONObject: [object])
    }
    static func expect(_ expected: UpdateError, client: UpdateClient) async {
        do { _ = try await client.latest(); preconditionFailure("Expected \(expected)") }
        catch { precondition(error as? UpdateError == expected, "Unexpected error: \(error)") }
    }
    @MainActor static func main() async throws {
        precondition(AppVersion("1.10.0")! > AppVersion("1.9.9")!)
        precondition(AppVersion("v1.3.0")! == AppVersion("1.3.0+build-4")!)
        precondition(AppVersion("1.3")! == AppVersion("1.3.0")!)
        for bad in ["", "latest", "1", "1.3.0-beta.1", "1.03.0", "-1.3.0", "1.3.0.1", "1.3.", "1.3.0+", String(repeating: "9", count: 100) + ".0.0"] {
            precondition(AppVersion(bad) == nil, "Accepted \(bad)")
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ReleaseProtocol.self]
        let client = UpdateClient(session: URLSession(configuration: config))
        ReleaseProtocol.handler = { request in
            precondition(request.url == UpdateClient.latestURL)
            precondition(request.value(forHTTPHeaderField: "Authorization") == nil)
            return (200, release())
        }
        let latest = try await client.latest()
        precondition(latest.downloadURL?.lastPathComponent == "ADBroom-9.0.0.dmg")
        for (status, error) in [(404, UpdateError.noRelease), (403, .rateLimited), (429, .rateLimited), (500, .server(500))] {
            ReleaseProtocol.handler = { _ in (status, Data()) }; await expect(error, client: client)
        }
        ReleaseProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }; await expect(.offline, client: client)
        ReleaseProtocol.handler = { _ in (200, Data("not json".utf8)) }; await expect(.invalidResponse, client: client)
        for change: [String: Any] in [["draft": true], ["prerelease": true], ["html_url": "https://example.com/release"]] {
            ReleaseProtocol.handler = { _ in (200, release(change)) }; await expect(.noRelease, client: client)
        }
        ReleaseProtocol.handler = { _ in (200, release(["tag_name": "nightly"])) }; await expect(.noRelease, client: client)
        for url in ["http://github.com/tahsingibi/adbroom/releases/tag/v9", "https://github.com/other/repo/releases/tag/v9", "https://github.com.evil.test/tahsingibi/adbroom/releases/tag/v9", "https://github.com/tahsingibi/adbroom/releases/tag/v9?token=x"] {
            precondition(!UpdateClient.isReleaseURL(URL(string: url)!))
        }
        ReleaseProtocol.handler = { _ in (200, release(["assets": [["name": "ADBroom-9.0.0.dmg", "browser_download_url": "https://example.com/evil.dmg"]]])) }
        await expect(.noRelease, client: client)
        // Independent tags/assets: a newer launcher must never become a Mac update.
        func object(_ changes: [String: Any]) -> [String: Any] {
            (try! JSONSerialization.jsonObject(with: release(changes)) as! [[String: Any]])[0]
        }
        let apkBytes = Data([0x50, 0x4b]) + Data("independent launcher".utf8)
        let checksum = SHA256.hash(data: apkBytes).map { String(format: "%02x", $0) }.joined()
        let apkURL = "https://github.com/tahsingibi/adbroom/releases/download/launcher-v9.0.0/ADBroomLauncher-9.0.0.apk"
        let apk: [String: Any] = ["name": "ADBroomLauncher-9.0.0.apk", "browser_download_url": apkURL, "size": apkBytes.count, "digest": "sha256:" + checksum]
        let launcher = object(["tag_name": "launcher-v9.0.0", "html_url": "https://github.com/tahsingibi/adbroom/releases/tag/launcher-v9.0.0", "assets": [apk]])
        let mac = object(["tag_name": "macos-v3.0.0", "html_url": "https://github.com/tahsingibi/adbroom/releases/tag/macos-v3.0.0"])
        ReleaseProtocol.handler = { _ in (200, try! JSONSerialization.data(withJSONObject: [launcher, mac])) }
        let selectedMac = try await client.latest(); precondition(selectedMac.tagName == "macos-v3.0.0")
        let selectedTV = try await client.latest(channel: .launcher); precondition(selectedTV.tagName == "launcher-v9.0.0")
        let file = try await client.downloadLauncher(using: { request in
            precondition(request.url?.absoluteString == apkURL)
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try apkBytes.write(to: temp)
            return (temp, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let downloadedBytes = try Data(contentsOf: file.url)
        precondition(downloadedBytes == apkBytes)
        try FileManager.default.removeItem(at: file.url)
        do {
            _ = try await client.downloadLauncher(using: { request in
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                var corrupted = apkBytes
                corrupted[corrupted.count - 1] ^= 1
                try corrupted.write(to: temp)
                return (temp, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }); preconditionFailure("Accepted corrupt APK")
        } catch { precondition(error is LauncherDownloadError) }
        // Older GitHub metadata can omit digest; use the separately published checksum.
        var withoutDigest = apk; withoutDigest.removeValue(forKey: "digest")
        var sidecarRelease = launcher
        sidecarRelease["assets"] = [withoutDigest, ["name": "ADBroomLauncher-9.0.0.apk.sha256", "browser_download_url": apkURL + ".sha256"]]
        ReleaseProtocol.handler = { request in
            if request.url?.host == "api.github.com" { return (200, try! JSONSerialization.data(withJSONObject: [sidecarRelease])) }
            return (200, Data((checksum + "  ADBroomLauncher-9.0.0.apk\n").utf8))
        }
        let sidecarFile = try await client.downloadLauncher(using: { request in
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try apkBytes.write(to: temp)
            return (temp, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        try FileManager.default.removeItem(at: sidecarFile.url)
        var noChecksum = launcher; noChecksum["assets"] = [withoutDigest]
        ReleaseProtocol.handler = { _ in (200, try! JSONSerialization.data(withJSONObject: [noChecksum])) }
        do { _ = try await client.downloadLauncher(); preconditionFailure("Accepted unverifiable APK") }
        catch { precondition(error as? LauncherDownloadError == .noChecksum) }
        // A missing channel on a full page must continue to the next page.
        ReleaseProtocol.handler = { request in
            if request.url!.absoluteString.hasSuffix("page=1") {
                return (200, try! JSONSerialization.data(withJSONObject: Array(repeating: mac, count: 100)))
            }
            return (200, try! JSONSerialization.data(withJSONObject: [launcher]))
        }
        let pagedTV = try await client.latest(channel: .launcher); precondition(pagedTV.tagName == "launcher-v9.0.0")
        let suite = "ADBroom.UpdatesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = UpdateModel(defaults: defaults, client: client)
        ReleaseProtocol.handler = { _ in (200, release()) }
        await model.checkIfDue(); precondition(model.updateAvailable && model.lastChecked != nil)
        let calls = ReleaseProtocol.calls
        await model.checkIfDue(); precondition(ReleaseProtocol.calls == calls, "Daily check repeated")
        ReleaseProtocol.handler = { _ in (200, release(["tag_name": "v1.0.0"])) }
        await model.check(); if case .current = model.status {} else { preconditionFailure("Offered a downgrade") }
        model.automaticChecks = false
        defaults.removeObject(forKey: "updates.lastAttempt")
        let count = ReleaseProtocol.calls; await model.checkIfDue(); precondition(count == ReleaseProtocol.calls)
        ReleaseProtocol.handler = { _ in (404, Data()) }
        await model.check(); if case .noRelease = model.status {} else { preconditionFailure("Empty release channel misreported") }
        ReleaseProtocol.handler = { _ in throw URLError(.timedOut) }
        await model.check(); if case .failed(.offline) = model.status {} else { preconditionFailure("Offline misreported as current") }
        if CommandLine.arguments.contains("--live") {
            let live = try await UpdateClient().latest()
            print("Live GitHub check: \(live.tagName), download available: \(live.downloadURL != nil)")
        }
        print("Updates: all version, network, state, rate limit, offline and daily-check tests passed")
    }
}
