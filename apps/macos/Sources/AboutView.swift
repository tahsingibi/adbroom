import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppNavigation: ObservableObject {
    @Published var section: AppPage? = .remote
}

struct GeneralView: View {
    @EnvironmentObject var tv: TVModel
    @EnvironmentObject var updates: UpdateModel
    @State private var downloading = false
    @State private var downloadMessage = ""
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RoomHeader(title: L("Her şey yerli yerinde.", "Everything in its place."), subtitle: L("ADBroom hakkında, cihazın ve güncellemeler.", "About ADBroom, your device and updates."), eyebrow: L("GENEL", "GENERAL"))
                RoomCard(L("Hakkında", "About"), icon: "info.circle") {
                    HStack(spacing: 20) {
                        Image(nsImage: RoomArtwork.icon).resizable().frame(width: 84, height: 84)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("ADBroom").font(.system(size: 26, weight: .bold, design: .rounded))
                            Text(L("Android TV'n için daha iyi bir çalışma alanı.", "A better workspace for your Android TV.")).font(.callout).foregroundStyle(.secondary)
                            RoomBadge(text: "v\(updates.currentVersion) · " + L("Derleme \(updates.build)", "Build \(updates.build)"))
                        }
                        Spacer(minLength: 0)
                    }
                    Divider()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 12) {
                        Link(destination: URL(string: "https://sungur.dev")!) { Label("Tahsin Sungur", systemImage: "person.crop.circle") }
                        Link(destination: URL(string: "https://x.com/tahsingibi")!) { Label("X / tahsingibi", systemImage: "at") }
                        Link(destination: URL(string: "https://sungur.dev")!) { Label("sungur.dev", systemImage: "globe") }
                        Link(destination: URL(string: "https://github.com/tahsingibi/adbroom")!) { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
                    }.font(.callout)
                    Text(L("Mac uygulaması ve TV launcher'ı bağımsızdır. İhtiyacın olanı indir.", "The Mac companion and TV launcher are independent. Download what you need.")).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Link(destination: UpdateClient.macReleasesURL) { Label(L("Mac yayınları", "Mac releases"), systemImage: "laptopcomputer") }.buttonStyle(.bordered)
                        Button { Task { await saveLauncher() } } label: { Label(L("Launcher APK indir", "Download launcher APK"), systemImage: "arrow.down.to.line") }.buttonStyle(.borderedProminent).disabled(downloading)
                        if downloading { ProgressView().controlSize(.small) }
                        Spacer(minLength: 0)
                        Link(L("Launcher yayınları", "Launcher releases"), destination: UpdateClient.launcherReleasesURL).font(.caption)
                    }
                    if !downloadMessage.isEmpty { Text(downloadMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                    Divider()
                    HStack {
                        Label(L("Uygulama görünümü", "App appearance"), systemImage: "circle.lefthalf.filled").font(.callout.weight(.medium))
                        Spacer()
                        Picker(L("Görünüm", "Appearance"), selection: $appearance) {
                            Text(L("Sistem", "System")).tag("system")
                            Text(L("Açık", "Light")).tag("light")
                            Text(L("Koyu", "Dark")).tag("dark")
                        }.labelsHidden().pickerStyle(.segmented).frame(width: 240)
                    }
                }
                RoomCard(L("Sistem", "System"), icon: "desktopcomputer") {
                    HStack { Label("macOS", systemImage: "laptopcomputer").font(.callout.weight(.semibold)); Spacer(); Text(ProcessInfo.processInfo.operatingSystemVersionString).font(.caption).foregroundStyle(.secondary) }
                    Divider()
                    if tv.connected { SystemView().id(tv.serial) }
                    else {
                        Label(L("TV'ye bağlandığında cihaz bilgileri burada görünür.", "Connect a TV to see device information here."), systemImage: "tv").font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
                    }
                }
                RoomCard(L("Güncellemeler", "Updates"), icon: "arrow.triangle.2.circlepath") { UpdatesView() }
            }.roomPage()
        }
    }
    private func saveLauncher() async {
        downloading = true; downloadMessage = L("Launcher GitHub'dan indiriliyor…", "Downloading launcher from GitHub…")
        defer { downloading = false }
        do {
            let file = try await UpdateClient().downloadLauncher()
            defer { try? FileManager.default.removeItem(at: file.url) }
            let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "apk") ?? .data]
            panel.nameFieldStringValue = file.name
            guard panel.runModal() == .OK, let destination = panel.url else { downloadMessage = ""; return }
            try Data(contentsOf: file.url).write(to: destination, options: .atomic)
            downloadMessage = L("Launcher APK kaydedildi. TV'ye aktararak Mac uygulaması olmadan da kurabilirsin.",
                                "Launcher APK saved. Transfer it to your TV to install it without the Mac app.")
        } catch { downloadMessage = LauncherDownload.message(error) }
    }
}

struct AppCommands: Commands {
    @ObservedObject var updates: UpdateModel
    @ObservedObject var navigation: AppNavigation
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L("ADBroom Hakkında", "About ADBroom")) { showAbout() }
            Button(L("Güncellemeleri kontrol et…", "Check for Updates…")) {
                showAbout(); Task { await updates.check() }
            }.disabled(updates.checking)
        }
    }
    private func showAbout() { navigation.section = .general; openWindow(id: "main") }
}
