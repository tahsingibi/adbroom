import SwiftUI

@main
struct ADBroomApp: App {
    @StateObject private var tv = TVModel()

    var body: some Scene {
        WindowGroup("ADBroom") {
            ContentView()
                .environmentObject(tv)
                .frame(minWidth: 860, minHeight: 620)
                .id(tv.lang)  // re-render every text when the language changes
        }
        .windowResizability(.contentMinSize)
    }
}

enum Section: String, CaseIterable, Identifiable {
    case remote, screen, apps, packages, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .remote: L("Kumanda", "Remote")
        case .screen: L("Ekran", "Screen")
        case .apps: L("Uygulamalar", "Apps")
        case .packages: L("Paketler", "Packages")
        case .system: L("Sistem", "System")
        }
    }
    var icon: String {
        switch self {
        case .remote: "av.remote"
        case .screen: "tv"
        case .apps: "square.grid.2x2"
        case .packages: "shippingbox"
        case .system: "gauge.with.dots.needle.33percent"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var tv: TVModel
    @State private var section: Section? = .remote

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { s in
                Label(s.title, systemImage: s.icon).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .safeAreaInset(edge: .bottom) { SidebarFooter().padding(10) }
        } detail: {
            VStack(spacing: 0) {
                if tv.toolsMissing {
                    SetupView()
                } else if !tv.connected {
                    ConnectHelpView()
                } else {
                    Group {
                        switch section ?? .remote {
                        case .remote: RemoteView()
                        case .screen: ScreenView()
                        case .apps: AppsView()
                        case .packages: PackagesView()
                        case .system: SystemView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if !tv.lastMessage.isEmpty {
                    Divider()
                    Text(tv.lastMessage)
                        .font(.callout).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(statusText).font(.caption).lineLimit(1)
            }
            TextField(L("TV IP adresi", "TV IP address"), text: $tv.target)
                .textFieldStyle(.roundedBorder).font(.caption)
                .onSubmit { Task { await tv.connect() } }
            HStack {
                Button(L("Bağlan", "Connect")) { Task { await tv.connect() } }
                Button(L("Eşleştir…", "Pair…")) { showPair = true }
            }
            .controlSize(.small)
            Picker(selection: $tv.lang) {
                ForEach(Lang.allCases) { Text($0.label).tag($0) }
            } label: {
                Image(systemName: "globe")
            }
            .controlSize(.small)
        }
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
            Text(L("Kablosuz hata ayıklama ile eşleştir", "Pair with Wireless debugging")).font(.headline)
            Text(L("""
                Yalnızca TV eşleştirme kodu istiyorsa gerekir (çoğu Android 11+ / Google TV).
                TV'de: Ayarlar → Sistem → Geliştirici seçenekleri → Kablosuz hata ayıklama → "Cihazı eşleştirme koduyla eşle". Ekranda görünen IP:bağlantı noktası ve 6 haneli kodu gir.
                """, """
                Only needed if the TV asks for a pairing code (most Android 11+ / Google TV).
                On the TV: Settings → System → Developer options → Wireless debugging → "Pair device with pairing code". Enter the IP:port and 6-digit code shown.
                """))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField(L("IP:bağlantı noktası (ör. 192.168.1.20:37215)", "IP:port (e.g. 192.168.1.20:37215)"), text: $hostPort)
                .textFieldStyle(.roundedBorder)
            TextField(L("Eşleştirme kodu", "Pairing code"), text: $code)
                .textFieldStyle(.roundedBorder)
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
        .padding(20)
        .frame(width: 460)
    }
}

// MARK: - Onboarding

struct SetupView: View {
    @EnvironmentObject var tv: TVModel
    private let command = "brew install android-platform-tools scrcpy"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L("Gerekli araçlar eksik", "Required tools missing"), systemImage: "wrench.and.screwdriver")
                .font(.title2.bold())
            Text(L("ADBroom, TV ile konuşmak için Google'ın **adb** aracını ve ekranı izlemek için **scrcpy**'yi kullanır. İkisi de ücretsiz ve açık kaynak. Homebrew ile kur:",
                   "ADBroom uses Google's **adb** to talk to the TV and **scrcpy** to watch the screen. Both are free and open source. Install them with Homebrew:"))
            HStack {
                Text(command).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .padding(8).background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.12)))
                Button(L("Kopyala", "Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                }
            }
            Text(L("Homebrew yoksa önce https://brew.sh adresindeki tek satırlık komutu çalıştır.",
                   "No Homebrew? Run the one-line installer from https://brew.sh first."))
                .font(.callout).foregroundStyle(.secondary)
            Button(L("Tekrar kontrol et", "Check again")) { tv.recheckTools(); Task { await tv.connect() } }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ConnectHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label(L("TV'ye bağlan", "Connect to your TV"), systemImage: "tv.and.mediabox").font(.title2.bold())
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
            Text(.init(text)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
