import SwiftUI

// MARK: - Screen

struct ScreenView: View {
    @EnvironmentObject var tv: TVModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("TV'yi izle", "Watch the TV")).font(.headline)
                Picker(L("Kalite", "Quality"), selection: $tv.quality) {
                    ForEach(TVModel.Quality.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                .disabled(tv.watching)
                Text(tv.quality.detail).font(.caption).foregroundStyle(.secondary)

                Button { tv.toggleWatch() } label: {
                    Label(tv.watching ? L("Durdur", "Stop") : L("İzle (ses + görüntü)", "Watch (video + audio)"),
                          systemImage: tv.watching ? "stop.fill" : "play.tv.fill")
                        .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .tint(tv.watching ? .red : .accentColor)

                Text(L("""
                    Görüntü ve ses ayrı bir pencerede birlikte gelir. Pencere yalnızca izlemek içindir; TV'yi Kumanda sekmesinden kontrol et.
                    • Akıcılık TV'nin donanımına bağlıdır. Donanımsal video kodlayıcısı olmayan TV'ler zorlanabilir; takılma olursa kaliteyi düşür.
                    • Android 11'de ses yakalanırken TV'de oynayan video bir anlığına duraklayabilir: önce izlemeyi başlat, sonra içeriği aç. Ses Android 11+ gerektirir.
                    • Anten/HDMI ve Netflix/Prime gibi şifreli (DRM) içerik siyah görünür.
                    """, """
                    Video and audio arrive together in a separate window. It is view-only; control the TV from the Remote tab.
                    • Smoothness depends on the TV's hardware. TVs without a hardware video encoder may struggle; lower the quality if it stutters.
                    • On Android 11, starting audio capture may briefly pause the video playing on the TV: start watching first, then open the content. Audio needs Android 11+.
                    • Antenna/HDMI and DRM-protected content (Netflix, Prime…) show as black.
                    """))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                HStack {
                    Button(L("Ekran görüntüsü al", "Take screenshot")) { Task { await tv.captureScreen() } }
                    if let img = tv.screenshot { Button(L("Kaydet…", "Save…")) { save(img) } }
                }
                if let img = tv.screenshot {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func save(_ img: NSImage) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "adbroom-screenshot.png"
        guard panel.runModal() == .OK, let url = panel.url,
              let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}

// MARK: - Apps

struct AppsView: View {
    @EnvironmentObject var tv: TVModel
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(L("TV'deki uygulamalar", "Apps on the TV")).font(.headline)
                Spacer()
                Button(L("Yenile", "Refresh")) { Task { await tv.loadApps() } }
            }
            List(tv.apps) { app in
                HStack {
                    Text(app.package).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(L("Aç", "Open")) { tv.launch(app) }
                    Button(L("Durdur", "Stop")) { tv.forceStop(app.package) }
                }
            }
        }
        .padding(20)
        .task { if tv.apps.isEmpty { await tv.loadApps() } }
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
            HStack {
                Button(L("Önbelleği temizle", "Clear caches")) { Task { await tv.trimCaches() } }
                Button(L("Animasyon: hızlı (0.5)", "Animations: fast (0.5)")) { Task { await tv.setAnimations("0.5") } }
                Button(L("Animasyon: normal (1.0)", "Animations: normal (1.0)")) { Task { await tv.setAnimations("1.0") } }
                Spacer()
                Button(L("Yeniden başlat…", "Reboot…"), role: .destructive) { confirmReboot = true }
            }
            Spacer()
        }
        .padding(20)
        .task { await tv.loadSystemInfo() }
        .confirmationDialog(L("TV yeniden başlatılsın mı?", "Reboot the TV?"), isPresented: $confirmReboot) {
            Button(L("Yeniden başlat", "Reboot"), role: .destructive) { tv.reboot() }
        }
    }
}
