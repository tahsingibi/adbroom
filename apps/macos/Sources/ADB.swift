import Foundation
import Darwin

/// Thin wrapper around the `adb` / `scrcpy` command-line tools.
/// GUI apps don't inherit the shell PATH, so the tools are looked up in well-known locations.
enum ADB {
    static let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        NSHomeDirectory() + "/Library/Android/sdk/platform-tools",
    ]

    static func tool(_ name: String) -> String? {
        searchPaths.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var adbPath: String? { tool("adb") }
    static var scrcpyPath: String? { tool("scrcpy") }

    /// Environment for child processes: PATH that includes Homebrew, and ADB for scrcpy.
    static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPaths.joined(separator: ":") + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        if let adb = adbPath { env["ADB"] = adb }
        return env
    }

    struct Result {
        let data: Data
        let code: Int32
        var text: String { String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r", with: "") }
        var ok: Bool { code == 0 }
        var lines: [String] {
            text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
    }

    /// Runs adb with the given arguments without blocking the main thread.
    static func run(_ args: [String], timeout: TimeInterval = 20) async -> Result {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: runSync(args, timeout: timeout))
            }
        }
    }

    static func runSync(_ args: [String], timeout: TimeInterval) -> Result {
        guard let adb = adbPath else {
            return Result(data: Data("adb not found".utf8), code: 127)
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: adb)
        p.arguments = args
        p.environment = environment
        // Redirect to a private temporary file instead of blocking on a pipe's EOF.
        // ADB can leave inherited pipe descriptors open after its own process exits,
        // which made readDataToEndOfFile hang indefinitely and stall page loading.
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("adbroom-adb-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil,
                                             attributes: [.posixPermissions: 0o600]),
              let output = try? FileHandle(forWritingTo: outputURL) else {
            return Result(data: Data("Could not create temporary ADB output file".utf8), code: 126)
        }
        defer {
            try? output.close()
            try? FileManager.default.removeItem(at: outputURL)
        }
        p.standardOutput = output
        p.standardError = output
        let finished = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in finished.signal() }
        do { try p.run() } catch {
            return Result(data: Data(error.localizedDescription.utf8), code: 126)
        }
        let timedOut = finished.wait(timeout: .now() + timeout) == .timedOut
        if timedOut {
            p.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut {
                _ = kill(p.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 1)
            }
        }
        if !p.isRunning { p.waitUntilExit() }
        try? output.synchronize()
        let data = (try? Data(contentsOf: outputURL)) ?? Data()
        return Result(data: data, code: timedOut ? 124 : p.terminationStatus)
    }

    /// Single-quotes a string for the device shell.
    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Accepts only valid Android package names (prevents shell injection).
    static func isPackageName(_ s: String) -> Bool {
        s.range(of: #"^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*$"#, options: .regularExpression) != nil
    }
}

/// Wake-on-LAN magic packet (tries to power on a TV in deep standby).
enum WakeOnLAN {
    static func send(mac: String) {
        let bytes = mac.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return }
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet += bytes }

        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return }
        defer { close(sock) }
        var on: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(9).bigEndian
        addr.sin_addr.s_addr = INADDR_BROADCAST
        _ = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(sock, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
}
