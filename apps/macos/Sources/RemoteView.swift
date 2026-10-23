import SwiftUI

struct RemoteView: View {
    @EnvironmentObject var tv: TVModel
    @State private var text = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    RoomHeader(title: L("Kontrol sende.", "You're in control."), subtitle: L("TV'n için tek bir kumanda. Klavyen de yanında.", "One remote for your TV. Your keyboard, too."), eyebrow: L("KUMANDA", "REMOTE"))
                    RoomBadge(text: L("Bağlı", "Connected"), color: .green)
                }
                HStack(alignment: .top, spacing: 20) {
                    RoomCard(L("Gezinme", "Navigation"), icon: "dot.radiowaves.left.and.right") {
                        VStack(spacing: 22) {
                            HStack(spacing: 10) {
                                Btn(L("Aç", "On"), "power", tint: .green) { Task { await tv.powerOn() } }
                                Btn(L("Kapat", "Off"), "power", tint: .red) { tv.powerOff() }
                                Btn(L("Kaynak", "Input"), "rectangle.on.rectangle") { tv.key("KEYCODE_TV_INPUT") }
                            }
                            DPad().padding(.vertical, 8)
                            HStack(spacing: 10) {
                                Btn(L("Geri", "Back"), "arrow.uturn.backward") { tv.key("KEYCODE_BACK") }.keyboardShortcut(.delete, modifiers: [])
                                Btn(L("Ana ekran", "Home"), "house") { tv.key("KEYCODE_HOME") }.keyboardShortcut("h", modifiers: [])
                                Btn(L("Menü", "Menu"), "line.3.horizontal") { tv.key("KEYCODE_MENU") }
                            }
                        }.frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 20) {
                        RoomCard(L("Ses ve kanal", "Volume & channels"), icon: "slider.horizontal.3") {
                            HStack(spacing: 24) {
                                RockerView(title: L("Ses", "Volume"), up: "KEYCODE_VOLUME_UP", down: "KEYCODE_VOLUME_DOWN", upKey: "=", downKey: "-")
                                Divider().frame(height: 100)
                                RockerView(title: L("Kanal", "Channel"), up: "KEYCODE_CHANNEL_UP", down: "KEYCODE_CHANNEL_DOWN", upKey: "]", downKey: "[")
                            }.frame(maxWidth: .infinity)
                            Btn(L("Sessiz", "Mute"), "speaker.slash") { tv.key("KEYCODE_VOLUME_MUTE") }.keyboardShortcut("m", modifiers: [])
                        }
                        RoomCard(L("Medya", "Playback"), icon: "play.rectangle") {
                            HStack(spacing: 8) {
                                Round("backward.fill", size: 48) { tv.key("KEYCODE_MEDIA_REWIND") }.help(L("Geri sar", "Rewind"))
                                Round("playpause.fill", prominent: true, size: 56) { tv.key("KEYCODE_MEDIA_PLAY_PAUSE") }.keyboardShortcut(.space, modifiers: [])
                                Round("forward.fill", size: 48) { tv.key("KEYCODE_MEDIA_FAST_FORWARD") }.help(L("İleri sar", "Fast forward"))
                            }.frame(maxWidth: .infinity)
                            HStack {
                                Btn(L("Ayarlar", "Settings"), "gearshape") { tv.key("KEYCODE_SETTINGS") }
                                Btn(L("Asistan", "Assistant"), "mic") { tv.key("KEYCODE_SEARCH") }
                            }
                        }
                    }.frame(width: 260)
                }
                RoomCard(L("TV'ye yaz", "Type on your TV"), icon: "keyboard") {
                    HStack(spacing: 10) {
                        TextField(L("Arama veya mesaj yaz…", "Write a search or message…"), text: $text)
                            .textFieldStyle(.roundedBorder).controlSize(.large).onSubmit(send)
                        Button(action: send) { Label(L("Gönder", "Send"), systemImage: "arrow.up.right") }
                            .buttonStyle(.borderedProminent).controlSize(.large).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button { tv.key("KEYCODE_DEL") } label: { Image(systemName: "delete.left") }.help(L("TV'deki son karakteri sil", "Delete the last character on TV"))
                    }
                    Text(L("Metin, TV'deki seçili yazı alanına gönderilir.", "Text is sent to the focused text field on your TV.")).font(.caption).foregroundStyle(.secondary)
                }
                Label(L("Oklar: gezin · Enter: OK · ⌫: geri · H: ana ekran · Boşluk: oynat/durdur", "Arrows: navigate · Enter: OK · ⌫: back · H: home · Space: play/pause"), systemImage: "command")
                    .font(.caption).foregroundStyle(.secondary)
            }.roomPage()
        }
    }
    private func send() { guard !text.isEmpty else { return }; tv.sendText(text); text = "" }
}

struct DPad: View {
    @EnvironmentObject var tv: TVModel
    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                Color.clear.frame(width: 62, height: 62)
                Round("chevron.up") { tv.key("KEYCODE_DPAD_UP") }.keyboardShortcut(.upArrow, modifiers: [])
                Color.clear.frame(width: 62, height: 62)
            }
            GridRow {
                Round("chevron.left") { tv.key("KEYCODE_DPAD_LEFT") }.keyboardShortcut(.leftArrow, modifiers: [])
                Round(nil, label: "OK", prominent: true) { tv.key("KEYCODE_DPAD_CENTER") }.keyboardShortcut(.return, modifiers: [])
                Round("chevron.right") { tv.key("KEYCODE_DPAD_RIGHT") }.keyboardShortcut(.rightArrow, modifiers: [])
            }
            GridRow {
                Color.clear.frame(width: 62, height: 62)
                Round("chevron.down") { tv.key("KEYCODE_DPAD_DOWN") }.keyboardShortcut(.downArrow, modifiers: [])
                Color.clear.frame(width: 62, height: 62)
            }
        }.padding(12).background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 28))
    }
}

struct RockerView: View {
    @EnvironmentObject var tv: TVModel
    let title: String, up: String, down: String
    let upKey: KeyEquivalent, downKey: KeyEquivalent
    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Round("plus", size: 46) { tv.key(up) }.keyboardShortcut(upKey, modifiers: []).accessibilityLabel(title + " " + L("artır", "up"))
            Round("minus", size: 46) { tv.key(down) }.keyboardShortcut(downKey, modifiers: []).accessibilityLabel(title + " " + L("azalt", "down"))
        }
    }
}

struct Round: View {
    let icon: String?
    var label = ""
    var prominent = false
    var size: CGFloat = 62
    let action: () -> Void
    init(_ icon: String?, label: String = "", prominent: Bool = false, size: CGFloat = 62, action: @escaping () -> Void) {
        self.icon = icon; self.label = label; self.prominent = prominent; self.size = size; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Group { if let icon { Image(systemName: icon).font(.system(size: 19, weight: .semibold)) } else { Text(label).font(.system(size: 17, weight: .bold)) } }
                .frame(width: size, height: size).contentShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(RoomKeyStyle(prominent: prominent)).accessibilityLabel(accessibleLabel)
    }
    private var accessibleLabel: String {
        switch icon {
        case "chevron.up": L("Yukarı", "Up")
        case "chevron.down": L("Aşağı", "Down")
        case "chevron.left": L("Sol", "Left")
        case "chevron.right": L("Sağ", "Right")
        case "playpause.fill": L("Oynat veya duraklat", "Play or pause")
        case "backward.fill": L("Geri sar", "Rewind")
        case "forward.fill": L("İleri sar", "Fast forward")
        case "plus": L("Artır", "Increase")
        case "minus": L("Azalt", "Decrease")
        default: label.isEmpty ? L("Tamam", "OK") : label
        }
    }
}

struct Btn: View {
    let title: String, icon: String
    var tint: Color?
    let action: () -> Void
    init(_ title: String, _ icon: String, tint: Color? = nil, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.tint = tint; self.action = action
    }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) { Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(tint ?? .primary); Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1) }
                .frame(maxWidth: .infinity).frame(height: 58)
        }.buttonStyle(RoomKeyStyle())
    }
}
