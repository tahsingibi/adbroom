import Foundation

@main
struct LauncherBridgeTests {
    static func main() {
        let label = Data("YouTube, Türkçe 📺".utf8).base64EncodedString()
        let text = "Row: 0 package=__meta__, label64=, revision=7\nRow: 1 package=com.example.tv, label64=\(label), revision=7\n"
        let snapshot = LauncherBridge.parse(text)!
        precondition(snapshot.revision == 7)
        precondition(snapshot.apps == [LauncherApp(package: "com.example.tv", label: "YouTube, Türkçe 📺")])
        precondition(LauncherBridge.parse("Row: 0 package=__meta__, label64=, revision=0")!.apps.isEmpty)
        for bad in ["Error: provider missing", "", text + "Row: 2 package=com.example.tv, label64=\(label), revision=7",
                    text + "Row: 2 package=com.other, label64=\(label), revision=8",
                    "Row: 0 package=com.a;reboot, label64=\(label), revision=0",
                    "Row: 0 package=com.a, label64=???, revision=0",
                    "Row: 0 package=__meta__, label64=, revision=-1"] {
            precondition(LauncherBridge.parse(bad) == nil, "Accepted malformed bridge output: \(bad)")
        }
        var config = LauncherConfiguration()
        config.profileName = "Türkçe 📺"
        config.favorites = ["com.example.tv"]
        config.labels = ["com.example.tv": "TV, film"]
        let data = try! JSONEncoder().encode(config)
        let settingsText = "Row: 0 config64=\(data.base64EncodedString()), revision=8"
        let settings = LauncherBridge.parseSettings(settingsText)!
        precondition(settings.revision == 8 && settings.configuration == config)
        precondition(LauncherBridge.parseSettings(settingsText + "\n" + settingsText) == nil)
        config.columns = 9
        precondition(!config.valid)
        config.columns = 6; config.favorites = ["com.a", "com.a"]
        precondition(!config.valid)
        config.favorites = []; config.groups = ["com.a": String(repeating: "x", count: 31)]
        precondition(!config.valid)
        precondition(!LauncherProfile(settings: LauncherConfiguration(), order: ["com.a", "com.a"]).valid)
        print("LauncherBridge: all tests passed")
    }
}
