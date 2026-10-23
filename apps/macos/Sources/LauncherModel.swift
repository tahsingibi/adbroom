import Foundation

enum LauncherSaveOutcome { case saved, conflict, failed }

extension TVModel {
    func loadLauncher() async {
        guard connected, !launcherLoading else { return }
        launcherLoading = true
        defer { launcherLoading = false }
        let destination = serial
        let installed = await ADB.run(["-s", destination, "shell", "pm path --user current \(LauncherBridge.package)"], timeout: 8)
        guard destination == serial else { return }
        launcherInstalled = installed.ok && installed.lines.contains { $0.hasPrefix("package:") }
        launcherApps = []
        launcherRevision = nil
        launcherUserID = nil
        launcherConfiguration = nil
        launcherError = ""
        guard launcherInstalled else { return }
        let user = await ADB.run(["-s", destination, "shell", "am get-current-user"], timeout: 8)
        guard user.ok, let userID = Int(user.text.trimmingCharacters(in: .whitespacesAndNewlines)), userID >= 0,
              destination == serial else {
            launcherError = L("TV kullanıcısı belirlenemedi.", "Could not identify the current TV user.")
            return
        }
        let result = await ADB.run(["-s", destination, "shell", "content query --user \(userID) --uri \(LauncherBridge.uri)"], timeout: 12)
        guard destination == serial else { return }
        guard result.ok, let snapshot = LauncherBridge.parse(result.text) else {
            launcherError = L("Launcher sırası okunamadı. Yenile'yi dene.\n", "Could not read launcher order. Try Refresh.\n") + result.text
            return
        }
        launcherApps = snapshot.apps
        launcherRevision = snapshot.revision
        launcherUserID = userID
        let settingsResult = await ADB.run(["-s", destination, "shell", "content query --user \(userID) --uri \(LauncherBridge.settingsURI)"], timeout: 12)
        guard destination == serial else { return }
        if settingsResult.ok, let settings = LauncherBridge.parseSettings(settingsResult.text), settings.revision == snapshot.revision {
            launcherConfiguration = settings.configuration
        } else {
            launcherError = L("Ayarlar okunamadı veya TV'de değişti. Yenile'yi dene; eski launcher sürümü yüklüyse Launcher'ı güncelle'yi seç.",
                              "Settings could not be read or changed on the TV. Try Refresh; if an older launcher is installed, choose Update launcher.")
        }
    }

    func installLauncher() async {
        guard connected, !managingApps, !launcherLoading else { return }
        let destination = serial
        managingApps = true
        lastMessage = L("Launcher GitHub'dan indiriliyor…", "Downloading launcher from GitHub…")
        do {
            let apk = try await UpdateClient().downloadLauncher()
            defer { try? FileManager.default.removeItem(at: apk.url) }
            managingApps = false
            guard destination == serial else { return }
            let success = await installAPKs([apk.url])
            guard success, destination == serial else { return }
            await loadLauncher()
            if launcherInstalled { await previewLauncher() }
        } catch {
            managingApps = false
            lastMessage = LauncherDownload.message(error)
        }
    }

    func previewLauncher() async {
        guard connected, launcherInstalled, !managingApps else { return }
        let result = await shell("am start --user current -n \(LauncherBridge.component)")
        lastMessage = result.ok && !result.text.contains("Error:") && !result.text.contains("Exception")
            ? L("ADBroom Launcher TV'de açıldı. Beğenirsen Varsayılan yap'ı seç.",
                "ADBroom Launcher opened on the TV. Choose Set default if you like it.")
            : result.text
    }

    func saveLauncherOrder(_ ordered: [LauncherApp], revision: Int64, configuration: LauncherConfiguration? = nil) async -> LauncherSaveOutcome {
        guard connected, launcherInstalled, !managingApps, !launcherLoading,
              launcherRevision == revision, let userID = launcherUserID, Set(ordered.map(\.package)) == Set(launcherApps.map(\.package)),
              ordered.count == launcherApps.count, ordered.allSatisfy({ ADB.isPackageName($0.package) }) else { return .failed }
        managingApps = true
        let destination = serial
        let currentUser = await ADB.run(["-s", destination, "shell", "am get-current-user"])
        guard currentUser.ok, Int(currentUser.text.trimmingCharacters(in: .whitespacesAndNewlines)) == userID else {
            managingApps = false
            lastMessage = L("TV kullanıcısı değişti. Sırayı yenile ve tekrar dene.", "The TV user changed. Refresh the order and try again.")
            await loadLauncher()
            return .failed
        }
        var method = "setOrder"
        var value = "\(revision):" + ordered.map(\.package).joined(separator: ",")
        if let configuration {
            let profile = LauncherProfile(settings: configuration, order: ordered.map(\.package))
            guard profile.valid, let encoded = try? JSONEncoder().encode(profile) else {
                managingApps = false
                lastMessage = L("Launcher ayarları geçersiz.", "Invalid launcher settings.")
                return .failed
            }
            method = "setProfile"
            value = "\(revision):" + encoded.base64EncodedString()
            guard value.utf8.count < 120_000 else { managingApps = false; return .failed }
        }
        let result = await ADB.run(["-s", destination, "shell",
                                   "content call --user \(userID) --uri \(LauncherBridge.uri) --method \(method) --arg \(ADB.quote(value))"])
        managingApps = false
        guard destination == serial else { return .failed }
        let success = result.ok && result.text.contains("status=ok")
        if result.text.contains("status=conflict") {
            lastMessage = L("Sıra TV'de değişmiş. Güncel sıra yüklendi; düzenlemeni yeniden uygula.",
                            "The order changed on the TV. The latest order was loaded; apply your edits again.")
        } else {
            lastMessage = success
                ? L("Uygulama sırası TV'ye kaydedildi.", "App order saved on the TV.")
                : L("Sıra kaydedilemedi: ", "Could not save order: ") + result.text
        }
        let conflict = result.text.contains("status=conflict")
        if success || conflict { await loadLauncher() }
        return success ? .saved : conflict ? .conflict : .failed
    }

    func makeLauncherDefault() async {
        await loadDefaults()
        guard let home = homeApps.first(where: { $0.package == LauncherBridge.package }) else {
            lastMessage = L("Launcher ana ekran adayı olarak bulunamadı. Önce yükle ve yeniden dene.",
                            "Launcher is not available as a home app. Install it first and try again.")
            return
        }
        await setDefaultHome(home.component)
    }
}
