import Foundation
import AppKit

struct TVApp: Identifiable, Hashable {
    let package: String
    let component: String
    var id: String { component }
}

struct PackageRow: Identifiable, Hashable {
    let package: String
    let system: Bool
    var disabled: Bool
    var id: String { package }
}

struct DeviceInfo {
    var id = ""
    var manufacturer = ""
    var model = ""
    var sdk = 0
    var release = ""
    var title: String { "\(manufacturer) \(model)".trimmingCharacters(in: .whitespaces) }
}

enum ConnState { case idle, connecting, connected, unauthorized, offline }

@MainActor
final class TVModel: ObservableObject {
    // MARK: Settings
    @Published var lang: Lang = Lang.current {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") }
    }
    @Published var target: String = UserDefaults.standard.string(forKey: "target") ?? "" {
        didSet { UserDefaults.standard.set(target, forKey: "target") }
    }

    // MARK: Connection
    @Published var state: ConnState = .idle
    @Published var device = DeviceInfo()
    @Published var lastMessage = ""
    @Published var toolsMissing = ADB.adbPath == nil
    var connected: Bool { state == .connected }

    // MARK: Screen
    @Published var screenshot: NSImage?
    @Published var quality: Quality = Quality(rawValue: UserDefaults.standard.string(forKey: "quality") ?? "") ?? .medium {
        didSet { UserDefaults.standard.set(quality.rawValue, forKey: "quality") }
    }
    @Published var watching = false
    private var mirrorProcess: Process?

    // MARK: Apps / packages / system
    @Published var apps: [TVApp] = []
    @Published var packages: [PackageRow] = []
    @Published var liveProtected: [String: PackageDB.Protect] = [:]
    @Published var records: [String] = []
    @Published var logText = ""
    @Published var systemInfo = ""
    @Published var busy = false

    private var statusTimer: Timer?

    /// "192.168.1.20" → "192.168.1.20:5555"; "ip:port" and USB serials are used as-is.
    var serial: String {
        let t = target.trimmingCharacters(in: .whitespaces)
        return (t.contains(":") || !t.contains(".")) ? t : "\(t):5555"
    }
    private var host: String { serial.components(separatedBy: ":").first ?? serial }

    init() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshState() }
        }
        if !target.isEmpty { Task { await connect() } }
    }

    // MARK: - Connection

    @discardableResult
    func shell(_ cmd: String, timeout: TimeInterval = 20) async -> ADB.Result {
        await ADB.run(["-s", serial, "shell", cmd], timeout: timeout)
    }

    func recheckTools() {
        toolsMissing = ADB.adbPath == nil
    }

    func connect() async {
        recheckTools()
        guard !toolsMissing, !target.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        state = .connecting
        device = DeviceInfo()
        var output = ""
        if serial.contains(".") {
            output = await ADB.run(["connect", serial], timeout: 8).text
        }
        await refreshState()
        if connected {
            lastMessage = ""
            await loadDevice()
        } else if state == .unauthorized {
            lastMessage = L("TV ekranındaki \"USB hata ayıklamaya izin ver\" sorusunu onayla.",
                            "Accept the \"Allow USB debugging?\" prompt on the TV.")
        } else {
            lastMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Android 11+ "Wireless debugging" pairing (host:port and 6-digit code shown on the TV).
    func pair(hostPort: String, code: String) async -> Bool {
        let r = await ADB.run(["pair", hostPort.trimmingCharacters(in: .whitespaces), code.trimmingCharacters(in: .whitespaces)], timeout: 20)
        let ok = r.text.localizedCaseInsensitiveContains("successfully paired")
        lastMessage = ok
            ? L("Eşleştirildi. Şimdi TV'deki \"IP adresi ve bağlantı noktası\"nı yukarıya yazıp Bağlan'a bas.",
                "Paired. Now enter the TV's \"IP address & port\" above and press Connect.")
            : r.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ok
    }

    func refreshState() async {
        guard !toolsMissing, !target.isEmpty else { state = .idle; return }
        let r = await ADB.run(["-s", serial, "get-state"], timeout: 4)
        let s = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if r.ok && s == "device" { state = .connected }
        else if s.contains("unauthorized") { state = .unauthorized }
        else if state != .connecting { state = .offline }
        if connected && device.id.isEmpty { await loadDevice() }
    }

    func loadDevice() async {
        let r = await shell("""
            getprop ro.serialno; getprop ro.product.manufacturer; getprop ro.product.model; \
            getprop ro.build.version.sdk; getprop ro.build.version.release; settings get secure android_id; \
            ip -o link 2>/dev/null | grep -oE 'ether [0-9a-f:]{17}' | cut -d' ' -f2
            """)
        let l = r.text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        func line(_ i: Int) -> String { i < l.count ? l[i] : "" }
        var id = line(0)
        if id.isEmpty || id == "unknown" || id == "0123456789ABCDEF" { id = line(5) }
        device = DeviceInfo(id: id.isEmpty ? host : id, manufacturer: line(1), model: line(2),
                            sdk: Int(line(3)) ?? 0, release: line(4))
        let macs = l.dropFirst(6).filter {
            $0.range(of: #"^([0-9a-f]{2}:){5}[0-9a-f]{2}$"#, options: .regularExpression) != nil && $0 != "00:00:00:00:00:00"
        }
        if !macs.isEmpty { UserDefaults.standard.set(Array(macs), forKey: "macs.\(host)") }
        loadRecords()
    }

    // MARK: - Remote

    func key(_ code: String) {
        Task { await shell("input keyevent \(code)", timeout: 5) }
    }

    func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        let escaped = text.replacingOccurrences(of: " ", with: "%s")
        Task { await shell("input text \(ADB.quote(escaped))", timeout: 10) }
    }

    func powerOff() {
        key("KEYCODE_SLEEP")
        lastMessage = L("TV bekleme moduna alındı.", "TV put into standby.")
    }

    func powerOn() async {
        for mac in UserDefaults.standard.stringArray(forKey: "macs.\(host)") ?? [] { WakeOnLAN.send(mac: mac) }
        if serial.contains(".") { _ = await ADB.run(["connect", serial], timeout: 5) }
        let r = await shell("input keyevent KEYCODE_WAKEUP", timeout: 5)
        await refreshState()
        lastMessage = r.ok
            ? L("Açma komutu gönderildi.", "Wake command sent.")
            : L("TV'ye ulaşılamadı. Derin uykudaysa kumandayla açman gerekebilir (Wake-on-LAN denendi).",
                "Couldn't reach the TV. If it's in deep standby, use the remote (Wake-on-LAN was tried).")
    }

    // MARK: - Screen

    enum Quality: String, CaseIterable, Identifiable {
        case low, medium, high, full
        var id: String { rawValue }
        var title: String {
            switch self {
            case .low: L("Düşük", "Low")
            case .medium: L("Orta", "Medium")
            case .high: L("Yüksek", "High")
            case .full: L("Tam", "Full")
            }
        }
        var detail: String {
            switch self {
            case .low: L("640p · 15 kare/sn", "640p · 15 fps")
            case .medium: L("960p · 24 kare/sn", "960p · 24 fps")
            case .high: L("1280p · 30 kare/sn", "1280p · 30 fps")
            case .full: L("Tam çözünürlük · 60 kare/sn", "Native resolution · 60 fps")
            }
        }
        var args: [String] {
            switch self {
            case .low: ["--max-size=640", "--max-fps=15", "--video-bit-rate=1M"]
            case .medium: ["--max-size=960", "--max-fps=24", "--video-bit-rate=2M"]
            case .high: ["--max-size=1280", "--max-fps=30", "--video-bit-rate=4M"]
            case .full: ["--max-fps=60", "--video-bit-rate=8M"]
            }
        }
    }

    /// Opens a view-only window with picture + sound at the selected quality.
    func toggleWatch() {
        if let p = mirrorProcess, p.isRunning {
            p.terminate()
            return
        }
        guard let scrcpy = ADB.scrcpyPath else {
            lastMessage = L("scrcpy bulunamadı. Terminalde: brew install scrcpy", "scrcpy not found. In Terminal: brew install scrcpy")
            return
        }
        var args = ["-s", serial, "--no-power-on", "--no-control", "--window-title", "ADBroom — \(device.title)"] + quality.args
        if device.sdk > 0 && device.sdk < 30 { args.append("--no-audio") }  // audio capture needs Android 11+
        let p = Process()
        p.executableURL = URL(fileURLWithPath: scrcpy)
        p.arguments = args
        p.environment = ADB.environment
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.watching = false; self?.mirrorProcess = nil }
        }
        do {
            try p.run()
            mirrorProcess = p
            watching = true
            lastMessage = L("İzleme penceresi açılıyor…", "Opening viewer window…")
        } catch {
            lastMessage = error.localizedDescription
        }
    }

    /// Raw (uncompressed) screenshot. Some vendor builds print driver messages before
    /// the data, so the 16-byte header [width, height, format, colorspace] is located
    /// by matching width × height × 4 against the remaining length.
    func captureScreen() async {
        let r = await ADB.run(["-s", serial, "exec-out", "screencap"], timeout: 15)
        if r.ok, let img = Self.decodeRaw(r.data) {
            screenshot = img
        } else {
            lastMessage = L("Görüntü alınamadı. Canlı TV/HDMI ve şifreli (DRM) içerik yakalanamaz.",
                            "Couldn't capture. Live TV/HDMI and DRM-protected content can't be captured.")
        }
    }

    nonisolated static func decodeRaw(_ data: Data) -> NSImage? {
        let bytes = [UInt8](data)
        guard bytes.count > 16 else { return nil }
        func u32(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o+1]) << 8 | Int(bytes[o+2]) << 16 | Int(bytes[o+3]) << 24 }
        for hdr in 0...min(4096, bytes.count - 16) {
            let w = u32(hdr), h = u32(hdr + 4)
            guard (320...7680).contains(w), (240...4320).contains(h), hdr + 16 + w * h * 4 == bytes.count else { continue }
            let pixels = Data(bytes[(hdr + 16)...])
            guard let provider = CGDataProvider(data: pixels as CFData),
                  let cg = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: w, height: h))
        }
        return nil
    }

    // MARK: - Apps

    func loadApps() async {
        let r = await shell("cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER")
        var seen = Set<String>()
        apps = r.lines.compactMap { s in
            guard s.contains("/"), !s.contains(" "), let pkg = s.split(separator: "/").first else { return nil }
            guard seen.insert(String(pkg)).inserted else { return nil }
            return TVApp(package: String(pkg), component: s)
        }.sorted { $0.package < $1.package }
    }

    func launch(_ app: TVApp) {
        Task { await shell("am start -n \(app.component)") }
    }

    func forceStop(_ pkg: String) {
        guard ADB.isPackageName(pkg) else { return }
        Task { await shell("am force-stop \(pkg)") }
        lastMessage = L("\(pkg) durduruldu.", "\(pkg) stopped.")
    }

    // MARK: - Packages (disable / enable — never uninstall)

    /// ~/Library/Application Support/ADBroom/devices/<device id>/
    var deviceDir: URL? {
        guard !device.id.isEmpty else { return nil }
        let safe = device.id.replacingOccurrences(of: #"[^A-Za-z0-9._-]"#, with: "_", options: .regularExpression)
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ADBroom/devices/\(safe)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var recordFile: URL? { deviceDir?.appendingPathComponent("disabled.txt") }
    private var logFile: URL? { deviceDir?.appendingPathComponent("log.md") }

    func loadRecords() {
        guard let recordFile else { records = []; logText = ""; return }
        let text = (try? String(contentsOf: recordFile, encoding: .utf8)) ?? ""
        records = text.split(separator: "\n").compactMap {
            let pkg = $0.components(separatedBy: "#")[0].trimmingCharacters(in: .whitespaces)
            return pkg.isEmpty ? nil : pkg
        }
        logText = logFile.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    private func saveRecords() {
        guard let recordFile else { return }
        let text = records.map { $0 + "\n" }.joined()
        try? text.write(to: recordFile, atomically: true, encoding: .utf8)
    }

    private func appendLog(_ line: String) {
        guard let logFile else { return }
        let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current,
                                                formatOptions: [.withFullDate, .withTime, .withColonSeparatorInTime])
        let entry = "- \(stamp) — \(line)\n"
        if let h = try? FileHandle(forWritingTo: logFile) {
            h.seekToEndOfFile()
            h.write(Data(entry.utf8))
            try? h.close()
        } else {
            try? ("# ADBroom — \(device.title) (\(device.id))\n\n" + entry).write(to: logFile, atomically: true, encoding: .utf8)
        }
        loadRecords()
    }

    func loadPackages() async {
        busy = true
        defer { busy = false }
        func names(_ r: ADB.Result) -> [String] { r.lines.map { $0.replacingOccurrences(of: "package:", with: "") } }
        let all = names(await shell("pm list packages"))
        let system = Set(names(await shell("pm list packages -s")))
        let disabled = Set(names(await shell("pm list packages -d")))
        packages = all.sorted().map { PackageRow(package: $0, system: system.contains($0), disabled: disabled.contains($0)) }
        await detectProtected()
    }

    /// Device-specific critical packages: current launcher, keyboards, TV input services
    /// and vendor Input/Source key handlers.
    private func detectProtected() async {
        var map: [String: PackageDB.Protect] = [:]
        let home = await shell("cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME")
        if let last = home.lines.last, last.contains("/"), let pkg = last.split(separator: "/").first {
            map[String(pkg)] = .home
        }
        for line in (await shell("ime list -s")).lines {
            if let pkg = line.split(separator: "/").first { map[String(pkg)] = .keyboard }
        }
        for line in (await shell("dumpsys tv_input | grep -o 'pkg=[A-Za-z0-9_.]*' | sort -u")).lines {
            let pkg = line.replacingOccurrences(of: "pkg=", with: "")
            if PackageDB.info(pkg) == nil { map[pkg] = .tvInput }  // known apps (e.g. Play Movies) also register inputs
        }
        // Activities registered for the vendor "Input" key action (e.g. MStar/MediaTek TVs).
        let keyHandlers = await shell("dumpsys package | awk '/TV_INPUT_BUTTON:/{f=1;next} f&&/:$/{f=0} f' | grep -oE '[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+' | cut -d/ -f1 | sort -u")
        for pkg in keyHandlers.lines where ADB.isPackageName(pkg) { map[pkg] = .inputKey }
        liveProtected = map
    }

    func protection(_ pkg: String) -> PackageDB.Protect? {
        liveProtected[pkg] ?? PackageDB.staticProtection(pkg)
    }

    func disable(_ pkg: String) async {
        guard ADB.isPackageName(pkg), protection(pkg) == nil else { return }
        busy = true
        defer { busy = false }
        let r = await shell("pm disable-user --user 0 \(pkg)")
        if r.text.contains("disabled-user") {
            if !records.contains(pkg) { records.append(pkg); saveRecords() }
            appendLog(L("`\(pkg)` kapatıldı. Geri al: `adb shell pm enable \(pkg)`",
                        "`\(pkg)` disabled. Undo: `adb shell pm enable \(pkg)`"))
            lastMessage = L("\(pkg) kapatıldı.", "\(pkg) disabled.")
            setRow(pkg, disabled: true)
        } else {
            lastMessage = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func enable(_ pkg: String) async {
        guard ADB.isPackageName(pkg) else { return }
        busy = true
        defer { busy = false }
        let r = await shell("pm enable \(pkg)")
        if r.text.contains("new state: enabled") {
            records.removeAll { $0 == pkg }
            saveRecords()
            appendLog(L("`\(pkg)` geri açıldı.", "`\(pkg)` re-enabled."))
            lastMessage = L("\(pkg) geri açıldı.", "\(pkg) re-enabled.")
            setRow(pkg, disabled: false)
        } else {
            lastMessage = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Re-enables every package ADBroom disabled on this TV.
    func revertAll() async {
        let all = records
        for pkg in all { await enable(pkg) }
        lastMessage = L("\(all.count) paket geri açıldı.", "\(all.count) packages re-enabled.")
    }

    private func setRow(_ pkg: String, disabled: Bool) {
        if let i = packages.firstIndex(where: { $0.package == pkg }) { packages[i].disabled = disabled }
    }

    // MARK: - System

    func loadSystemInfo() async {
        let r = await shell("""
            echo "$(getprop ro.product.manufacturer) $(getprop ro.product.model) · Android $(getprop ro.build.version.release)"; \
            u=$(cat /proc/uptime); echo "Uptime: $((${u%%.*}/60)) min"; \
            dumpsys meminfo | grep -E 'Total RAM|Free RAM|Used RAM'; \
            grep MemAvailable /proc/meminfo; \
            df -h /data | tail -1; \
            echo "Animation: $(settings get global window_animation_scale) / $(settings get global transition_animation_scale) / $(settings get global animator_duration_scale)"
            """)
        systemInfo = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reboot() {
        Task { _ = await ADB.run(["-s", serial, "reboot"], timeout: 10) }
        lastMessage = L("TV yeniden başlatılıyor…", "Rebooting TV…")
    }

    func trimCaches() async {
        await shell("pm trim-caches 999G", timeout: 60)
        lastMessage = L("Önbellek temizlendi.", "Caches cleared.")
        await loadSystemInfo()
    }

    func setAnimations(_ v: String) async {
        await shell("settings put global window_animation_scale \(v); settings put global transition_animation_scale \(v); settings put global animator_duration_scale \(v)")
        lastMessage = L("Animasyon ölçeği: \(v)", "Animation scale: \(v)")
        await loadSystemInfo()
    }
}
