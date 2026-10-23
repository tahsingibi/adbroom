import Foundation

struct LauncherApp: Identifiable, Equatable {
    let package: String
    let label: String
    var id: String { package }
}

/// The launcher bridge carries only local app names and order over the existing ADB connection.
enum LauncherBridge {
    static let package = "io.github.adbroom.launcher"
    static let component = package + "/.HomeActivity"
    static let uri = "content://" + package + ".order/apps"

    struct Snapshot {
        let apps: [LauncherApp]
        let revision: Int64
    }

    static func parse(_ text: String) -> Snapshot? {
        var apps: [LauncherApp] = []
        var revision: Int64?
        var seen = Set<String>()
        for line in text.split(separator: "\n") where line.hasPrefix("Row: ") {
            guard let start = line.range(of: "package=") else { return nil }
            let fields = line[start.lowerBound...].components(separatedBy: ", ")
            guard fields.count == 3, fields[1].hasPrefix("label64="), fields[2].hasPrefix("revision="),
                  let rowRevision = Int64(fields[2].dropFirst("revision=".count)), rowRevision >= 0 else { return nil }
            if let revision, revision != rowRevision { return nil }
            revision = rowRevision
            let pkg = String(fields[0].dropFirst("package=".count))
            if pkg == "__meta__" { continue }
            guard ADB.isPackageName(pkg), seen.insert(pkg).inserted,
                  let labelData = Data(base64Encoded: String(fields[1].dropFirst("label64=".count))),
                  let label = String(data: labelData, encoding: .utf8) else { return nil }
            apps.append(LauncherApp(package: pkg, label: label))
        }
        guard let revision else { return nil }
        return Snapshot(apps: apps, revision: revision)
    }
}

struct LauncherConfiguration: Codable, Equatable {
    var schema = 1
    var columns = 6
    var layout = "grid"
    var theme = "midnight"
    var accent = "sage"
    var cardStyle = "icon"
    var language = "system"
    var profileName = ""
    var showClock = true
    var use24Hour = true
    var showDate = true
    var showNetwork = true
    var showInputs = true
    var hideDisconnectedInputs = true
    var showFavorites = true
    var showLabels = true
    var rememberFocus = true
    var showSideloaded = true
    var showMedia = false
    var favorites: [String] = []
    var hidden: [String] = []
    var labels: [String: String] = [:]
    var groups: [String: String] = [:]

    var valid: Bool {
        schema == 1 && (4...8).contains(columns)
        && ["grid", "row"].contains(layout) && ["midnight", "forest", "warm"].contains(theme)
        && ["sage", "blue", "amber"].contains(accent) && ["icon", "banner"].contains(cardStyle)
        && ["system", "tr", "en"].contains(language) && profileName.utf16.count <= 40
        && favorites.count <= 512 && hidden.count <= 512 && labels.count <= 512 && groups.count <= 512
        && Set(favorites).count == favorites.count && Set(hidden).count == hidden.count
        && (favorites + hidden + Array(labels.keys) + Array(groups.keys)).allSatisfy(ADB.isPackageName)
        && labels.values.allSatisfy { $0.utf16.count <= 60 && !$0.contains("\0") }
        && groups.values.allSatisfy { $0.utf16.count <= 30 && !$0.contains("\0") }
        && !profileName.contains("\0")
    }
    mutating func toggle(_ package: String, favorite: Bool) {
        if favorite {
            if favorites.contains(package) { favorites.removeAll { $0 == package } } else { favorites.append(package) }
        } else {
            if hidden.contains(package) { hidden.removeAll { $0 == package } } else { hidden.append(package) }
        }
    }
}

struct LauncherProfile: Codable {
    let settings: LauncherConfiguration
    let order: [String]
    var valid: Bool {
        settings.valid && order.count <= 512 && Set(order).count == order.count && order.allSatisfy(ADB.isPackageName)
    }
}

extension LauncherBridge {
    static let settingsURI = "content://" + package + ".order/settings"
    struct SettingsSnapshot {
        let configuration: LauncherConfiguration
        let revision: Int64
    }
    static func parseSettings(_ text: String) -> SettingsSnapshot? {
        let rows = text.split(separator: "\n").filter { $0.hasPrefix("Row: ") }
        guard rows.count == 1, let start = rows[0].range(of: "config64=") else { return nil }
        let fields = rows[0][start.lowerBound...].components(separatedBy: ", ")
        guard fields.count == 2, fields[1].hasPrefix("revision="),
              let revision = Int64(fields[1].dropFirst("revision=".count)), revision >= 0,
              let data = Data(base64Encoded: String(fields[0].dropFirst("config64=".count))),
              let config = try? JSONDecoder().decode(LauncherConfiguration.self, from: data), config.valid else { return nil }
        return SettingsSnapshot(configuration: config, revision: revision)
    }
}
