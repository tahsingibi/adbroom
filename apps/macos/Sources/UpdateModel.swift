import Foundation
import SwiftUI

@MainActor
final class UpdateModel: ObservableObject {
    enum Status { case idle, checking, current, available, noRelease, failed(UpdateError) }
    @Published private(set) var status: Status = .idle
    @Published private(set) var release: GitHubRelease?
    @Published private(set) var lastChecked: Date?
    @Published var automaticChecks: Bool {
        didSet { defaults.set(automaticChecks, forKey: "updates.automaticChecks") }
    }
    let currentVersion: String
    let build: String
    private let defaults: UserDefaults
    private let client: UpdateClient
    init(defaults: UserDefaults = .standard, client: UpdateClient = UpdateClient(), bundle: Bundle = .main) {
        self.defaults = defaults; self.client = client
        currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "5"
        automaticChecks = defaults.object(forKey: "updates.automaticChecks") as? Bool ?? true
        lastChecked = defaults.object(forKey: "updates.lastSuccess") as? Date
    }
    var checking: Bool { if case .checking = status { return true }; return false }
    var updateAvailable: Bool { if case .available = status { return true }; return false }
    func checkIfDue() async {
        guard automaticChecks, !checking else { return }
        if let last = defaults.object(forKey: "updates.lastAttempt") as? Date,
           Date().timeIntervalSince(last) >= 0 && Date().timeIntervalSince(last) < 86_400 { return }
        await check()
    }
    func check() async {
        guard !checking else { return }
        status = .checking
        defaults.set(Date(), forKey: "updates.lastAttempt")
        do {
            let latest = try await client.latest()
            guard let installed = AppVersion(currentVersion), let published = latest.version(for: .macOS) else { throw UpdateError.invalidVersion }
            release = latest
            status = published > installed ? .available : .current
            lastChecked = Date(); defaults.set(lastChecked, forKey: "updates.lastSuccess")
        } catch is CancellationError { status = .idle }
        catch let error as UpdateError {
            release = nil
            if error == .noRelease {
                status = .noRelease
                lastChecked = Date(); defaults.set(lastChecked, forKey: "updates.lastSuccess")
            } else { status = .failed(error) }
        } catch { status = .failed(.invalidResponse); release = nil }
    }
    var title: String {
        switch status {
        case .idle: L("Güncellemeleri kontrol et", "Check for updates")
        case .checking: L("GitHub kontrol ediliyor…", "Checking GitHub…")
        case .current: L("En yeni sürümü kullanıyorsun", "You're up to date")
        case .available: L("Yeni sürüm hazır", "An update is available")
        case .noRelease: L("İndirilebilir Mac sürümü bulunamadı", "No downloadable Mac release found")
        case .failed: L("Güncellemeler kontrol edilemedi", "Could not check for updates")
        }
    }
    var detail: String {
        switch status {
        case .idle: L("GitHub'daki en son kararlı ADBroom sürümünü kontrol et.", "Check the latest stable ADBroom release on GitHub.")
        case .checking: L("Bu işlem TV bağlantısını etkilemez.", "This does not affect your TV connection.")
        case .current: L("Yayınlanmış daha yeni bir kararlı sürüm bulunamadı.", "No newer stable release was found.")
        case .available: L("Yeni sürümün notlarını aşağıda okuyup GitHub'dan indirebilirsin.", "Read the release notes below and download the update from GitHub.")
        case .noRelease: L("Kararlı bir Mac sürümü DMG paketiyle yayınlandığında burada görünecek.", "A stable Mac release will appear here once its DMG is published.")
        case .failed(let error):
            switch error {
            case .offline: L("İnternet bağlantını kontrol edip tekrar dene.", "Check your internet connection and try again.")
            case .rateLimited: L("GitHub istek sınırına ulaşıldı. Bir süre sonra tekrar dene.", "GitHub's request limit was reached. Try again later.")
            case .server(let code): L("GitHub şu an yanıt veremiyor (\(code)). Daha sonra tekrar dene.", "GitHub is unavailable (\(code)). Try again later.")
            default: L("GitHub sürüm bilgisi doğrulanamadı. Yayınlar sayfasını kontrol edebilirsin.", "The GitHub release information could not be verified. You can check the releases page.")
            }
        }
    }
}
