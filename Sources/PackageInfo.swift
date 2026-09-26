import Foundation

/// Knowledge about Android TV packages: which are known bloat (safe to disable)
/// and which must never be disabled. Works across brands; per-device critical
/// packages (launcher, keyboard, TV inputs) are also detected live from the TV.
enum PackageDB {
    struct Known {
        let tr: String
        let en: String
        /// true → disabling has a visible side effect (shown as a warning)
        var caution = false
        var text: String { L(tr, en) }
    }

    static let known: [String: Known] = [
        "tv.anoki.acr.controller": Known(tr: "ACR: izlediğin içeriği tanıyıp reklam amacıyla raporlar.", en: "ACR: recognizes what you watch and reports it for advertising."),
        "com.google.android.feedback": Known(tr: "Google'a hata raporu gönderir.", en: "Sends bug reports to Google."),
        "com.android.dreams.basic": Known(tr: "Basit ekran koruyucu.", en: "Basic screensaver."),
        "com.google.android.backdrop": Known(tr: "Ambient (fotoğraflı) ekran koruyucu.", en: "Ambient (photo) screensaver."),
        "com.android.printspooler": Known(tr: "Yazdırma servisi.", en: "Print service."),
        "com.google.android.play.games": Known(tr: "Play Oyunlar.", en: "Play Games."),
        "com.google.android.syncadapters.calendar": Known(tr: "Google Takvim eşitleme.", en: "Google Calendar sync."),
        "com.google.android.tvrecommendations": Known(tr: "Ana ekrandaki öneri şeritlerini besler.", en: "Feeds the recommendation rows on the home screen."),
        "com.mediatek.android.leanbacklauncher.partnercustomizer": Known(tr: "Üreticinin ana ekrana eklediği reklam/öneri kanalları.", en: "Vendor ad/recommendation channels on the home screen."),
        "com.mediatek.android.leanbacklauncher.partnercustomizer.overlay": Known(tr: "Yukarıdakinin kaynak dosyası.", en: "Resources for the vendor customizer."),
        "com.google.android.videos": Known(tr: "Google TV / Play Filmler.", en: "Google TV / Play Movies."),
        "com.google.android.youtube.tvmusic": Known(tr: "YouTube Music.", en: "YouTube Music."),
        "com.amazon.amazonvideo.livingroom": Known(tr: "Prime Video.", en: "Prime Video."),
        "com.mubi": Known(tr: "MUBI.", en: "MUBI."),
        "com.google.android.marvin.talkback": Known(tr: "TalkBack ekran okuyucu (erişilebilirlik).", en: "TalkBack screen reader (accessibility)."),
        "com.google.android.katniss": Known(tr: "Google Asistan / sesli arama. Kapatınca mikrofon tuşu çalışmaz.", en: "Google Assistant / voice search. The mic button stops working.", caution: true),
        "com.google.android.apps.mediashell": Known(tr: "Chromecast (telefondan TV'ye yayın). Kapatınca yayın yapılamaz.", en: "Chromecast built-in. Casting stops working.", caution: true),
        "com.google.android.tungsten.setupwraith": Known(tr: "İlk kurulum sihirbazı. Sıfırlama/güncelleme sonrası sorun çıkarabilir.", en: "Setup wizard. May cause issues after reset/updates.", caution: true),
        "com.google.android.tvlauncher": Known(tr: "Android TV ana ekranı. Başka bir ana ekran kurmadan kapatma.", en: "Android TV home screen. Don't disable without another launcher.", caution: true),
        "com.google.android.apps.tv.launcherx": Known(tr: "Google TV ana ekranı. Başka bir ana ekran kurmadan kapatma.", en: "Google TV home screen. Don't disable without another launcher.", caution: true),
    ]

    static func info(_ pkg: String) -> Known? {
        if let k = known[pkg] { return k }
        if pkg.hasPrefix("android.autoinstalls.config.") {
            return Known(tr: "Fabrika uygulamalarını kendiliğinden kurar.", en: "Auto-installs vendor apps.")
        }
        return nil
    }

    enum Protect {
        case core, playServices, keyboard, remote, tvInput, inputKey, home

        var text: String {
            switch self {
            case .core: L("Sistem çekirdeği", "Core system")
            case .playServices: L("Play Servisleri / Store", "Play Services / Store")
            case .keyboard: L("Klavye", "Keyboard")
            case .remote: L("Kumanda / Bluetooth", "Remote / Bluetooth")
            case .tvInput: L("TV girişleri (HDMI/anten)", "TV inputs (HDMI/antenna)")
            case .inputKey: L("Kaynak (Input) menüsü", "Input/Source menu")
            case .home: L("Şu anki ana ekran", "Current home screen")
            }
        }
    }

    private static let coreExact: Set<String> = [
        "android", "com.android.systemui", "com.android.settings", "com.android.tv.settings",
        "com.android.location.fused", "com.android.shell", "com.android.packageinstaller",
        "com.google.android.packageinstaller", "com.android.permissioncontroller",
        "com.google.android.permissioncontroller", "com.google.android.webview", "com.android.webview",
        "com.android.inputdevices", "com.android.externalstorage", "com.android.keychain", "com.android.se",
        "com.android.certinstaller", "com.android.media.module", "com.android.vpndialogs",
        "com.google.android.ext.services", "com.google.android.ext.shared", "com.google.android.modulemetadata",
        "com.google.android.tv.frameworkpackagestubs",
    ]
    private static let corePrefixes = ["com.android.providers.", "com.android.networkstack", "com.android.wifi", "com.android.bluetooth"]

    /// Static rules; the model adds live-detected packages (home, IMEs, TV inputs).
    static func staticProtection(_ pkg: String) -> Protect? {
        if coreExact.contains(pkg) || corePrefixes.contains(where: pkg.hasPrefix) || pkg.contains("auto_generated_rro") {
            return .core
        }
        if ["com.google.android.gms", "com.google.android.gsf", "com.android.vending"].contains(pkg) { return .playServices }
        if pkg.contains("inputmethod") { return .keyboard }
        if ["remote", "autopair", "bt_rcu", ".rcu"].contains(where: pkg.contains) { return .remote }
        if ["tvinput", "tv.service", "tvcenter", "com.tcl.tv"].contains(where: pkg.contains) { return .tvInput }
        // Brand "Input/Source" key handlers with misleading names.
        if ["com.tcl.suspension", "fusion.android.tv.demo"].contains(pkg) { return .inputKey }
        return nil
    }
}
