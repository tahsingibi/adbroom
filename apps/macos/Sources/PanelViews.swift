import SwiftUI
import UniformTypeIdentifiers

struct ScreenView: View {
    @EnvironmentObject var tv: TVModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RoomHeader(title: L("Büyük ekran, Mac'inde.", "Your big screen, on Mac."), subtitle: L("TV'yi izle veya o anı bir ekran görüntüsüyle sakla.", "Watch your TV or save the moment with a screenshot."), eyebrow: L("EKRAN", "SCREEN"))
                RoomCard(L("Canlı görüntü", "Live view"), icon: "play.tv") {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.075, green: 0.085, blue: 0.12))
                        VStack(spacing: 14) {
                            Image(systemName: tv.watching ? "waveform" : "tv").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(.white.opacity(0.75))
                            Text(tv.watching ? L("İzleme penceresi açık", "Viewing window is open") : L("TV'ni buraya getir.", "Bring your TV here.")).font(.title3.weight(.semibold)).foregroundStyle(.white)
                            Text(L("Ses ve görüntü ayrı bir pencerede açılır.", "Video and audio open in a separate window.")).font(.caption).foregroundStyle(.white.opacity(0.5))
                            Button { tv.toggleWatch() } label: {
                                Label(tv.watching ? L("İzlemeyi durdur", "Stop watching") : L("İzlemeye başla", "Start watching"), systemImage: tv.watching ? "stop.fill" : "play.fill")
                            }.buttonStyle(.borderedProminent).controlSize(.large).tint(tv.watching ? .red : RoomTheme.accent)
                        }.padding(24)
                    }.frame(height: 250)
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Görüntü kalitesi", "Picture quality")).font(.callout.weight(.semibold))
                            Text(tv.quality.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker(L("Kalite", "Quality"), selection: $tv.quality) {
                            ForEach(TVModel.Quality.allCases) { Text($0.title).tag($0) }
                        }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: 360).disabled(tv.watching)
                    }
                }
                RoomCard(L("Ekran görüntüsü", "Screenshot"), icon: "camera") {
                    HStack {
                        Text(L("TV'deki son kareyi al ve PNG olarak kaydet.", "Capture the current TV frame and save it as PNG.")).font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button { Task { await tv.captureScreen() } } label: { Label(L("Görüntü al", "Capture"), systemImage: "camera") }
                        if let img = tv.screenshot { Button(L("Kaydet…", "Save…")) { save(img) }.buttonStyle(.borderedProminent) }
                    }
                    if let img = tv.screenshot {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 340).clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Label(L("Henüz ekran görüntüsü yok", "No screenshot yet"), systemImage: "photo")
                            .font(.callout).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.vertical, 28)
                    }
                }
                DisclosureGroup(L("İzleme hakkında", "About screen viewing")) {
                    Text(L("Akıcılık TV'nin donanımına bağlıdır. Takılma olursa kaliteyi düşür. Ses için Android 11+ gerekir; Android 11'de önce izlemeyi başlat, sonra içeriği aç. DRM korumalı içerik, anten ve HDMI siyah görünebilir. TV'yi Kumanda sayfasından kontrol edebilirsin.", "Smoothness depends on TV hardware; lower quality if needed. Audio needs Android 11+; on Android 11 start viewing before opening content. DRM, antenna and HDMI may appear black. Control the TV from the Remote page."))
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }.padding(18).roomSurface()
            }.roomPage()
        }
    }
    private func save(_ img: NSImage) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "adbroom-screenshot.png"
        guard panel.runModal() == .OK, let url = panel.url,
              let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}

struct AppsView: View {
    @EnvironmentObject var tv: TVModel
    @State private var selectedHome = ""
    @State private var choosingAPK = false
    @State private var search = ""
    @State private var defaultsOpen = false
    @State private var loading = true
    private var apps: [TVApp] {
        tv.apps.filter { search.isEmpty || $0.package.localizedCaseInsensitiveContains(search) || roomAppName($0.package, launcherApps: tv.launcherApps).localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    RoomHeader(title: L("Uygulamaların, bir arada.", "All your apps, together."), subtitle: L("Yükle, aç ve TV'ndeki uygulamaları yönet.", "Install, launch and manage the apps on your TV."), eyebrow: L("UYGULAMALAR", "APPS"))
                    Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }.help(L("Yenile", "Refresh"))
                    Button { choosingAPK = true } label: { Label(L("APK yükle", "Install APK"), systemImage: "plus") }.buttonStyle(.borderedProminent).controlSize(.large)
                }
                HStack(spacing: 14) {
                    RoomAppIcon(icon: "shippingbox")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Yeni bir uygulamaya yer aç.", "Make room for something new.")).font(.headline)
                        Text(L("APK veya aynı uygulamaya ait base ve split APK dosyalarını seç. Güncellemelerde veriler korunur.", "Choose an APK or the base and split APKs for one app. Updates preserve app data.")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }.padding(18).roomSurface()
                if !loading { LauncherInvitation() }
                DisclosureGroup(isExpanded: $defaultsOpen) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(tv.currentHome.isEmpty ? L("Ana ekran bilgisi alınamadı", "Home app unavailable") : tv.currentHome)
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                        HStack {
                            Picker(L("Ana ekran", "Home app"), selection: $selectedHome) {
                                Text(L("Uygulama seç…", "Choose an app…")).tag("")
                                ForEach(tv.homeApps) { Text(roomAppName($0.package, launcherApps: tv.launcherApps)).tag($0.component) }
                            }
                            Button(L("Varsayılan yap", "Set default")) { Task { await tv.setDefaultHome(selectedHome) } }.disabled(selectedHome.isEmpty || selectedHome == tv.currentHome)
                        }
                        Button(L("TV'de varsayılan uygulama ayarlarını aç", "Open default app settings on TV")) { Task { await tv.openDefaultSettings() } }
                        Text(L("Diğer varsayılanları ve bağlantı tercihlerini TV ayarlarından değiştirebilirsin.", "Change other defaults and link preferences in TV settings.")).font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 14)
                } label: {
                    HStack { Label(L("Varsayılan uygulamalar", "Default apps"), systemImage: "checkmark.circle").font(.headline); Spacer(); Text(L("Ana ekran ve bağlantılar", "Home & links")).font(.caption).foregroundStyle(.secondary) }
                }.padding(18).roomSurface()
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text(L("Yüklü uygulamalar", "Installed apps")).font(.headline)
                        RoomBadge(text: search.isEmpty ? String(tv.apps.count) : "\(apps.count) / \(tv.apps.count)")
                        Spacer()
                        if tv.managingApps || loading { ProgressView().controlSize(.small) }
                        RoomSearch(text: $search).frame(maxWidth: 260)
                    }.padding(18)
                    Divider()
                    if apps.isEmpty && loading {
                        ProgressView(L("Uygulamalar yükleniyor…", "Loading apps…")).frame(maxWidth: .infinity).padding(36)
                    } else if apps.isEmpty {
                        ContentUnavailableView(search.isEmpty ? L("Uygulama bulunamadı", "No apps found") : L("Eşleşme yok", "No matches"), systemImage: "square.grid.2x2", description: Text(L("Listeyi yenile veya farklı bir arama yap.", "Refresh the list or try a different search."))).padding(20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(apps) { app in
                                HStack(spacing: 14) {
                                    RoomAppIcon(icon: roomAppSymbol(app.package), color: roomAppColor(app.package))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(roomAppName(app.package, launcherApps: tv.launcherApps)).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                        Text(app.package).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).textSelection(.enabled)
                                    }
                                    Spacer(minLength: 10)
                                    Button { tv.launch(app) } label: { Label(L("Aç", "Open"), systemImage: "arrow.up.right") }
                                    Menu {
                                        Button(L("Durdur", "Stop")) { tv.forceStop(app.package) }
                                        Button(L("TV'de ayarları aç", "Open settings on TV")) { Task { await tv.openDefaultSettings(package: app.package) } }
                                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24).help(L("Uygulama işlemleri", "App actions"))
                                }.padding(.horizontal, 18).padding(.vertical, 14)
                                if app.id != apps.last?.id { Divider().padding(.leading, 74) }
                            }
                        }
                    }
                }.roomSurface()
            }.roomPage()
        }
        .disabled(tv.managingApps)
        .task { await reload() }
        .onChange(of: tv.currentHome) { _, value in selectedHome = tv.homeApps.contains(where: { $0.component == value }) ? value : "" }
        .fileImporter(isPresented: $choosingAPK, allowedContentTypes: [UTType(filenameExtension: "apk") ?? .data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task {
                let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
                defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
                await tv.installAPKs(urls)
            }
            case .failure(let error): tv.lastMessage = error.localizedDescription
            }
        }
    }
    private func reload() async {
        loading = true
        defer { loading = false }
        await tv.loadApps()
        async let defaults: Void = tv.loadDefaults()
        async let launcher: Void = tv.loadLauncher()
        _ = await (defaults, launcher)
    }
}

// MARK: - System

struct SystemView: View {
    @EnvironmentObject var tv: TVModel
    @State private var confirmReboot = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("TV durumu", "TV status")).font(.headline)
                Spacer()
                Button(L("Yenile", "Refresh")) { Task { await tv.loadSystemInfo() } }
            }
            Text(tv.systemInfo.isEmpty ? L("Yükleniyor…", "Loading…") : tv.systemInfo)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            HStack(spacing: 10) {
                Button { Task { await tv.trimCaches() } } label: { Label(L("Önbelleği temizle", "Clear caches"), systemImage: "sparkles") }
                Menu {
                    Button(L("Hızlı · 0.5×", "Fast · 0.5×")) { Task { await tv.setAnimations("0.5") } }
                    Button(L("Normal · 1×", "Normal · 1×")) { Task { await tv.setAnimations("1.0") } }
                } label: { Label(L("TV animasyonları", "TV animations"), systemImage: "speedometer") }
                Spacer(minLength: 0)
                Button { confirmReboot = true } label: { Label(L("Yeniden başlat", "Reboot"), systemImage: "restart") }.tint(.red)
            }

        }
        .task { await tv.loadSystemInfo() }
        .confirmationDialog(L("TV yeniden başlatılsın mı?", "Reboot the TV?"), isPresented: $confirmReboot) {
            Button(L("Yeniden başlat", "Reboot"), role: .destructive) { tv.reboot() }
        }
    }
}
