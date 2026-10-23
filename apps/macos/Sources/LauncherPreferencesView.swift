import SwiftUI

struct LauncherPreferencesView: View {
    @Binding var configuration: LauncherConfiguration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoomHeader(title: L("Görünüm ve modüller", "Appearance & modules"), subtitle: L("Ana ekranını sana göre ayarla.", "Make your home screen feel like yours."), eyebrow: "LAUNCHER")
            Text(L("Değişiklikler taslak olarak tutulur. Kapatınca ana ekrandaki TV'ye kaydet düğmesiyle uygula.",
                   "Changes stay in your draft. Close this panel, then use Save to TV to apply them."))
                .font(.callout).foregroundStyle(.secondary)
            Form {
                SwiftUI.Section(L("Ana ekran ve görünüm", "Home and appearance")) {
                    TextField(L("Profil adı", "Profile name"), text: $configuration.profileName)
                    Picker(L("Düzen", "Layout"), selection: $configuration.layout) {
                        Text(L("Izgara", "Grid")).tag("grid")
                        Text(L("Yatay sıra", "Horizontal row")).tag("row")
                    }
                    Picker(L("Sütun sayısı", "Columns"), selection: $configuration.columns) {
                        ForEach(4...8, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Picker(L("Arka plan", "Background"), selection: $configuration.theme) {
                        Text(L("Gece", "Midnight")).tag("midnight")
                        Text(L("Orman", "Forest")).tag("forest")
                        Text(L("Sıcak", "Warm")).tag("warm")
                    }
                    Picker(L("Vurgu rengi", "Accent color"), selection: $configuration.accent) {
                        Text(L("Adaçayı", "Sage")).tag("sage")
                        Text(L("Mavi", "Blue")).tag("blue")
                        Text(L("Kehribar", "Amber")).tag("amber")
                    }
                    Picker(L("Kart görünümü", "Card style"), selection: $configuration.cardStyle) {
                        Text(L("İkon", "Icon")).tag("icon")
                        Text(L("TV görseli", "TV banner")).tag("banner")
                    }
                    Picker(L("Launcher dili", "Launcher language"), selection: $configuration.language) {
                        Text(L("TV dili", "TV language")).tag("system")
                        Text("Türkçe").tag("tr")
                        Text("English").tag("en")
                    }
                    Toggle(L("Uygulama adlarını göster", "Show app names"), isOn: $configuration.showLabels)
                    Toggle(L("Son odaklanan uygulamayı hatırla", "Remember focused app"), isOn: $configuration.rememberFocus)
                    Toggle(L("Telefon / sideload uygulamalarını göster", "Show phone / sideloaded apps"), isOn: $configuration.showSideloaded)
                }
                SwiftUI.Section(L("Modüller", "Modules")) {
                    Toggle(L("Favori rafı", "Favorites shelf"), isOn: $configuration.showFavorites)
                    Toggle(L("Saat", "Clock"), isOn: $configuration.showClock)
                    Toggle(L("24 saat biçimi", "24-hour clock"), isOn: $configuration.use24Hour)
                    Toggle(L("Tarih", "Date"), isOn: $configuration.showDate)
                    Toggle(L("Ağ durumu", "Network status"), isOn: $configuration.showNetwork)
                    Toggle(L("Canlı TV / HDMI girişleri", "Live TV / HDMI inputs"), isOn: $configuration.showInputs)
                    Toggle(L("Bağlı olmayan HDMI girişlerini gizle", "Hide disconnected HDMI inputs"), isOn: $configuration.hideDisconnectedInputs)
                    Toggle(L("Son medya", "Last media"), isOn: $configuration.showMedia)
                    Text(L("Medya için bildirim erişimini TV'de kendin açmalısın. Duvar kâğıdı ve ebeveyn PIN'i TV'nin Launcher ayarlarından yönetilir.",
                           "Enable notification access on the TV for media. Manage custom wallpaper and parental PIN in the TV's Launcher settings."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden)
            HStack {
                Spacer()
                Button(L("Tamam", "Done")) { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 600, height: 720).background(RoomTheme.canvas)
    }
}

struct LauncherAppPreferencesView: View {
    let app: LauncherApp
    @Binding var configuration: LauncherConfiguration
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                RoomAppIcon()
                RoomHeader(title: app.label, subtitle: app.package, eyebrow: L("UYGULAMA TERCİHLERİ", "APP PREFERENCES"))
            }
            Form {
                SwiftUI.Section(L("Kişiselleştir", "Personalize")) {
                    TextField(L("Görünen ad", "Display name"), text: Binding(
                        get: { configuration.labels[app.package] ?? "" },
                        set: { configuration.labels[app.package] = $0.isEmpty ? nil : $0 }))
                    TextField(L("Koleksiyon", "Collection"), text: Binding(
                        get: { configuration.groups[app.package] ?? "" },
                        set: { configuration.groups[app.package] = $0.isEmpty ? nil : $0 }))
                    Text(L("Özgün adı kullanmak veya koleksiyonu kaldırmak için boş bırak.", "Leave empty to keep the original name or remove the collection.")).font(.caption).foregroundStyle(.secondary)
                }
                SwiftUI.Section(L("Ana ekranda", "On the home screen")) {
                    Toggle(L("Favorilere ekle", "Add to favorites"), isOn: Binding(
                        get: { configuration.favorites.contains(app.package) },
                        set: { if $0 != configuration.favorites.contains(app.package) { configuration.toggle(app.package, favorite: true) } }))
                    Toggle(L("Uygulamayı gizle", "Hide app"), isOn: Binding(
                        get: { configuration.hidden.contains(app.package) },
                        set: { if $0 != configuration.hidden.contains(app.package) { configuration.toggle(app.package, favorite: false) } }))
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden)
            Text(L("Tercihler TV'ye kaydet ile uygulanır. Gizlemek uygulamayı TV'den silmez.", "Apply with Save to TV. Hiding does not uninstall the app.")).font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button(L("Tamam", "Done")) { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 520, height: 480).background(RoomTheme.canvas)
    }
}
