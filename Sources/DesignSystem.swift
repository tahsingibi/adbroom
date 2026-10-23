import SwiftUI

enum RoomArtwork {
    static let icon: NSImage = {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           let resources = Bundle.main.resourceURL,
           let image = NSImage(contentsOf: resources.appendingPathComponent(name)) { return image }
        return NSApplication.shared.applicationIconImage
    }()
}

enum RoomTheme {
    static let accent = Color(red: 0.35, green: 0.40, blue: 0.96)
    static let canvas = Color(nsColor: .underPageBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let line = Color.primary.opacity(0.075)
}

struct RoomHeader: View {
    let title: String
    let subtitle: String
    var eyebrow: String = "ADBROOM"
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow).font(.system(size: 10, weight: .bold)).tracking(1.8).foregroundStyle(RoomTheme.accent)
            Text(title).font(.system(size: 28, weight: .bold, design: .rounded)).tracking(-0.6)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RoomSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.background(RoomTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RoomTheme.line))
    }
}

struct RoomPage: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(28).frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

extension View {
    func roomSurface() -> some View { modifier(RoomSurface()) }
    func roomPage() -> some View { modifier(RoomPage()) }
}

struct RoomGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label.font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
            configuration.content.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).roomSurface()
    }
}

struct RoomCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    init(_ title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.icon = icon; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary).labelStyle(.titleAndIcon)
            content
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).roomSurface()
    }
}

struct RoomBadge: View {
    let text: String
    var color: Color = RoomTheme.accent
    var body: some View {
        HStack(spacing: 5) { Circle().fill(color).frame(width: 5, height: 5); Text(text) }
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.10), in: Capsule())
    }
}

struct RoomSearch: View {
    @Binding var text: String
    var prompt = L("Uygulama ara", "Search apps")
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(prompt, text: $text).textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).help(L("Aramayı temizle", "Clear search"))
            }
        }.padding(10).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct RoomAppIcon: View {
    var icon = "app.fill"
    var color: Color = RoomTheme.accent
    var body: some View {
        Image(systemName: icon).font(.system(size: 18, weight: .medium))
            .foregroundStyle(color).frame(width: 42, height: 42)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}

struct RoomKeyStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    var prominent = false
    var color: Color = RoomTheme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.4)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? color : Color.primary.opacity(configuration.isPressed ? 0.12 : 0.055), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(RoomTheme.line))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

func roomAppName(_ package: String, launcherApps: [LauncherApp]) -> String {
    if let app = launcherApps.first(where: { $0.package == package }) { return app.label }
    let names = ["com.google.android.youtube.tv": "YouTube", "com.android.vending": "Google Play",
                 "com.amazon.amazonvideo.livingroom": "Prime Video", "io.github.adbroom.launcher": "ADBroom Launcher",
                 "com.google.android.youtube.tvmusic": "YouTube Music", "com.netflix.ninja": "Netflix"]
    return names[package] ?? package
}

func roomAppSymbol(_ package: String) -> String {
    if package == LauncherBridge.package { return "house.fill" }
    if package.contains("music") { return "music.note" }
    if package.contains("vending") { return "bag.fill" }
    if package.contains("tvcenter") { return "antenna.radiowaves.left.and.right" }
    if package.contains("androidbox") { return "airplay.video" }
    if package.contains("mediaplayer") { return "play.circle.fill" }
    if package.contains("youtube") || package.contains("amazonvideo") || package.contains("netflix") || package.contains("TV") { return "play.rectangle.fill" }
    return "square.stack"
}

func roomAppColor(_ package: String) -> Color {
    if package.contains("music") { return .pink }
    if package.contains("youtube") || package.contains("netflix") { return .red }
    if package.contains("amazon") { return .cyan }
    if package.contains("vending") { return .green }
    return RoomTheme.accent
}
