import SwiftUI

@main
struct ADBroomApp: App {
    @NSApplicationDelegateAdaptor(ADBroomAppDelegate.self) private var appDelegate
    @StateObject private var tv = TVModel()
    @StateObject private var updates = UpdateModel()
    @StateObject private var navigation = AppNavigation()
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        Window("ADBroom", id: "main") {
            ContentView()
                .environmentObject(tv)
                .environmentObject(updates)
                .environmentObject(navigation)
                .tint(RoomTheme.accent)
                .groupBoxStyle(RoomGroupBoxStyle())
                .controlSize(.regular)
                .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
                .task {
                    await Task.yield()
                    await tv.connectSavedTargetIfNeeded()
                }
                .task {
                    await Task.yield()
                    await updates.checkIfDue()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await updates.checkIfDue() }
                }
                .frame(minWidth: 980, minHeight: 700)
                .id(tv.lang)  // re-render every text when the language changes
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1160, height: 820)
        .windowToolbarStyle(.unifiedCompact)
        .commands { AppCommands(updates: updates, navigation: navigation) }
    }
}

final class ADBroomAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load this bundle's artwork directly: NSWorkspace/Dock may still have
        // the previous icon cached after an in-place development update.
        guard let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
              let resources = Bundle.main.resourceURL,
              let icon = NSImage(contentsOf: resources.appendingPathComponent(name)) else { return }
        NSApplication.shared.applicationIconImage = icon
    }
}

enum AppPage: String, CaseIterable, Identifiable {
    case remote, screen, apps, launcher, packages, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .remote: L("Kumanda", "Remote")
        case .screen: L("Ekran", "Screen")
        case .apps: L("Uygulamalar", "Apps")
        case .launcher: "Launcher"
        case .packages: L("Paketler", "Packages")
        case .general: L("Genel", "General")
        }
    }
    var icon: String {
        switch self {
        case .remote: "av.remote"
        case .screen: "tv"
        case .apps: "square.grid.2x2"
        case .launcher: "house.fill"
        case .packages: "shippingbox"
        case .general: "gearshape.2"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var tv: TVModel
    @EnvironmentObject var updates: UpdateModel
    @EnvironmentObject var navigation: AppNavigation
    @State private var sidebarVisible = true

    var body: some View {
        // Keep both columns inside finite window bounds while launcher data loads.
        GeometryReader { bounds in
            HStack(spacing: 0) {
                if sidebarVisible {
                    sidebar.frame(width: 232)
                    Divider()
                }
                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: bounds.size.width, height: bounds.size.height)
            .background(RoomTheme.canvas)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { sidebarVisible.toggle() } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .regular))
                        .frame(width: 30, height: 28)
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .fixedSize()
                    .accessibilityLabel(sidebarVisible ? L("Kenar çubuğunu gizle", "Hide sidebar") : L("Kenar çubuğunu göster", "Show sidebar"))
                    .help(sidebarVisible ? L("Kenar çubuğunu gizle", "Hide sidebar") : L("Kenar çubuğunu göster", "Show sidebar"))
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: RoomArtwork.icon).resizable().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ADBroom").font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(L("TV çalışma alanın", "Your TV workspace")).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 26)
            ScrollView {
                VStack(spacing: 4) {
                    Text(L("ÇALIŞMA ALANI", "WORKSPACE")).font(.system(size: 9, weight: .bold)).tracking(1.4)
                        .foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 8)
                    ForEach(AppPage.allCases) { page in
                        Button { navigation.section = page } label: {
                            HStack(spacing: 10) {
                                Image(systemName: page.icon)
                                    .font(.system(size: 18)).frame(width: 24)
                                    .foregroundStyle(navigation.section == page ? RoomTheme.accent : Color.secondary)
                                Text(page.title).font(.system(size: 14, weight: .medium))
                                Spacer(minLength: 0)
                                if page == .general && updates.updateAvailable {
                                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                                }
                            }
                            .foregroundStyle(navigation.section == page ? RoomTheme.accent : Color.primary)
                            .padding(.horizontal, 12).padding(.vertical, 12)
                            .background(navigation.section == page ? RoomTheme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(navigation.section == page ? [.isSelected] : [])
                    }
                }.padding(.horizontal, 12)
            }
            SidebarFooter().padding(12).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }

    private var detail: some View {
            VStack(spacing: 0) {
                if updates.updateAvailable && navigation.section != .general {
                    HStack {
                        Label(L("Yeni ADBroom sürümü hazır: \(updates.release?.tagName ?? "")", "ADBroom update available: \(updates.release?.tagName ?? "")"), systemImage: "arrow.down.circle")
                            .font(.callout)
                        Spacer()
                        Button(L("Görüntüle", "View update")) { navigation.section = .general }
                    }.padding(12).background(Color.accentColor.opacity(0.1))
                    Divider()
                }
                if navigation.section == .general {
                    GeneralView()
                } else if tv.toolsMissing {
                    SetupView()
                } else if !tv.connected {
                    ConnectHelpView()
                } else {
                    Group {
                        switch navigation.section ?? .remote {
                        case .remote: RemoteView()
                        case .screen: ScreenView()
                        case .apps: AppsView()
                        case .launcher: LauncherView().id(tv.serial)
                        case .packages: PackagesView()
                        case .general: GeneralView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if !tv.lastMessage.isEmpty {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundStyle(RoomTheme.accent)
                        Text(tv.lastMessage).lineLimit(3)
                        Spacer(minLength: 0)
                        Button { tv.lastMessage = "" } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                            .help(L("Bildirimi kapat", "Dismiss message"))
                    }
                        .font(.caption).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
    }

}

// MARK: - Sidebar footer: connection + language

struct SidebarFooter: View {
    @EnvironmentObject var tv: TVModel
    @State private var showPair = false

    private var statusText: String {
        switch tv.state {
        case .idle: L("Bağlı değil", "Not connected")
        case .connecting: L("Bağlanıyor…", "Connecting…")
        case .connected: tv.device.title.isEmpty ? L("Bağlı", "Connected") : tv.device.title
        case .unauthorized: L("TV'de izin bekleniyor", "Waiting for approval on TV")
        case .offline: L("Bağlantı yok", "Offline")
        }
    }
    private var statusColor: Color {
        switch tv.state {
        case .connected: .green
        case .connecting, .unauthorized: .orange
        default: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tv").foregroundStyle(statusColor)
                Text(statusText).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 0)
                Circle().fill(statusColor).frame(width: 6, height: 6)
            }
            TextField(L("TV IP adresi", "TV IP address"), text: $tv.target)
                .textFieldStyle(.roundedBorder).font(.caption)
                .onSubmit { Task { await tv.connect() } }
                .disabled(tv.managingApps)
            HStack(spacing: 8) {
                Button { Task { await tv.connect() } } label: { Text(L("Bağlan", "Connect")).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                Button { showPair = true } label: { Image(systemName: "link") }.help(L("TV eşleştir", "Pair a TV"))
            }
            .controlSize(.small)
            .disabled(tv.managingApps)
            Divider()
            Picker(selection: $tv.lang) {
                ForEach(Lang.allCases) { Text($0.label).tag($0) }
            } label: {
                Image(systemName: "globe")
            }
            .controlSize(.small)
        }
        .padding(14).roomSurface()
        .sheet(isPresented: $showPair) { PairSheet() }
    }
}

struct PairSheet: View {
    @EnvironmentObject var tv: TVModel
    @Environment(\.dismiss) private var dismiss
    @State private var hostPort = ""
    @State private var code = ""
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoomHeader(title: L("TV ile eşleştir", "Pair your TV"), subtitle: L("TV ekranındaki bağlantı bilgilerini gir.", "Enter the pairing details shown on your TV."), eyebrow: L("BAĞLANTI", "CONNECTION"))
            Text(L("""
                Yalnızca TV eşleştirme kodu istiyorsa gerekir (çoğu Android 11+ / Google TV).
                TV'de: Ayarlar → Sistem → Geliştirici seçenekleri → Kablosuz hata ayıklama → "Cihazı eşleştirme koduyla eşle". Ekranda görünen IP:bağlantı noktası ve 6 haneli kodu gir.
                """, """
                Only needed if the TV asks for a pairing code (most Android 11+ / Google TV).
                On the TV: Settings → System → Developer options → Wireless debugging → "Pair device with pairing code". Enter the IP:port and 6-digit code shown.
                """))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 7) {
                Text(L("Eşleştirme adresi", "Pairing address")).font(.caption.weight(.semibold))
                TextField("192.168.1.20:37215", text: $hostPort).textFieldStyle(.roundedBorder).controlSize(.large)
            }.padding(.top, 8)
            VStack(alignment: .leading, spacing: 7) {
                Text(L("6 haneli eşleştirme kodu", "6-digit pairing code")).font(.caption.weight(.semibold))
                TextField("000000", text: $code).textFieldStyle(.roundedBorder).controlSize(.large)
            }
            HStack {
                Spacer()
                Button(L("İptal", "Cancel")) { dismiss() }
                Button(L("Eşleştir", "Pair")) {
                    working = true
                    Task {
                        let ok = await tv.pair(hostPort: hostPort, code: code)
                        working = false
                        if ok { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(hostPort.isEmpty || code.isEmpty || working)
            }
        }
        .padding(28)
        .frame(width: 520).background(RoomTheme.canvas)
    }
}

// MARK: - Onboarding

struct SetupView: View {
    @EnvironmentObject var tv: TVModel
    private let command = "brew install android-platform-tools scrcpy"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RoomHeader(title: L("İlk bağlantıya hazır ol.", "Get ready to connect."), subtitle: L("TV kontrolü için iki küçük araç gerekiyor.", "Two small tools bring your TV controls to life."), eyebrow: L("KURULUM", "SETUP"))
                RoomCard(L("Gerekli araçları kur", "Install the essentials"), icon: "wrench.and.screwdriver") {
                    Text(L("ADB, TV bağlantısını; scrcpy, sesli ekran izlemeyi sağlar. İkisini Homebrew ile kurabilirsin.", "ADB connects your TV; scrcpy handles screen and audio viewing. Install both with Homebrew.")).foregroundStyle(.secondary)
                    HStack {
                        Text(command).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        Spacer(minLength: 8)
                        Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string) } label: { Label(L("Kopyala", "Copy"), systemImage: "doc.on.doc") }
                    }.padding(14).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    Link(L("Homebrew kurulum rehberi", "Homebrew installation guide"), destination: URL(string: "https://brew.sh")!)
                    Divider()
                    Button { tv.recheckTools(); Task { await tv.connect() } } label: { Label(L("Kurulumu kontrol et", "Check installation"), systemImage: "arrow.clockwise") }.buttonStyle(.borderedProminent).controlSize(.large)
                }
            }.roomPage()
        }
    }
}

struct ConnectHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                RoomHeader(title: L("TV'ni çalışma alanına ekle.", "Bring your TV into your workspace."), subtitle: L("Aynı ağda, birkaç adımda bağlan.", "Connect on the same network in a few steps."), eyebrow: L("HOŞ GELDİN", "WELCOME"))
                step(1, L("TV'de **Ayarlar → Cihaz Tercihleri → Hakkında**'ya gir ve **Derleme / Build** satırına 7 kez bas. \"Artık geliştiricisiniz\" mesajı çıkar.",
                          "On the TV open **Settings → Device Preferences → About** and press **Build** 7 times until \"You are now a developer\"."))
                step(2, L("**Geliştirici seçenekleri**'nde **USB hata ayıklama**'yı (bazı TV'lerde **Ağ üzerinden hata ayıklama / Kablosuz hata ayıklama**) aç.",
                          "In **Developer options**, turn on **USB debugging** (on some TVs **Network debugging / Wireless debugging**)."))
                step(3, L("TV'nin IP adresini bul: **Ayarlar → Ağ ve İnternet →** bağlı ağın ayrıntıları. Mac ile TV aynı ağda olmalı.",
                          "Find the TV's IP: **Settings → Network & Internet →** your network's details. The Mac and TV must be on the same network."))
                step(4, L("IP'yi sol alttaki kutuya yaz ve **Bağlan**'a bas. TV'de çıkan \"hata ayıklamaya izin ver\" sorusunu **Her zaman izin ver** işaretleyerek onayla.",
                          "Type the IP in the box at the bottom left and press **Connect**. On the TV, accept the \"Allow debugging?\" prompt and tick **Always allow**."))
                step(5, L("TV eşleştirme kodu istiyorsa (Android 11+ Kablosuz hata ayıklama) önce **Eşleştir…**'i kullan, sonra TV'de görünen **IP:bağlantı noktası** ile bağlan.",
                          "If the TV asks for a pairing code (Android 11+ Wireless debugging), use **Pair…** first, then connect with the **IP:port** shown on the TV."))
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.headline).frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor.opacity(0.18)))
            Text(.init(text)).font(.callout).fixedSize(horizontal: false, vertical: true)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).roomSurface()
    }
}
