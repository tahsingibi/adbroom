import SwiftUI

struct RemoteView: View {
    @EnvironmentObject var tv: TVModel
    @State private var text = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 12) {
                    Btn(L("Aç", "On"), "power", tint: .green) { Task { await tv.powerOn() } }
                    Btn(L("Kapat", "Off"), "power", tint: .red) { tv.powerOff() }
                    Btn(L("Kaynak", "Input"), "rectangle.on.rectangle") { tv.key("KEYCODE_TV_INPUT") }
                    Btn(L("Ayarlar", "Settings"), "gearshape") { tv.key("KEYCODE_SETTINGS") }
                    Btn(L("Asistan", "Assistant"), "mic") { tv.key("KEYCODE_SEARCH") }
                }

                HStack(alignment: .center, spacing: 40) {
                    RockerView(title: L("Ses", "Volume"), up: "KEYCODE_VOLUME_UP", down: "KEYCODE_VOLUME_DOWN", upKey: "=", downKey: "-")
                    DPad()
                    RockerView(title: L("Kanal", "Channel"), up: "KEYCODE_CHANNEL_UP", down: "KEYCODE_CHANNEL_DOWN", upKey: "]", downKey: "[")
                }

                HStack(spacing: 12) {
                    Btn(L("Geri", "Back"), "arrow.uturn.backward") { tv.key("KEYCODE_BACK") }
                        .keyboardShortcut(.delete, modifiers: [])
                    Btn(L("Ana ekran", "Home"), "house") { tv.key("KEYCODE_HOME") }
                        .keyboardShortcut("h", modifiers: [])
                    Btn(L("Menü", "Menu"), "line.3.horizontal") { tv.key("KEYCODE_MENU") }
                    Btn(L("Sessiz", "Mute"), "speaker.slash") { tv.key("KEYCODE_VOLUME_MUTE") }
                        .keyboardShortcut("m", modifiers: [])
                }

                HStack(spacing: 12) {
                    Btn(L("Geri sar", "Rewind"), "backward") { tv.key("KEYCODE_MEDIA_REWIND") }
                    Btn(L("Oynat/Durdur", "Play/Pause"), "playpause") { tv.key("KEYCODE_MEDIA_PLAY_PAUSE") }
                        .keyboardShortcut(.space, modifiers: [])
                    Btn(L("İleri sar", "Forward"), "forward") { tv.key("KEYCODE_MEDIA_FAST_FORWARD") }
                }

                GroupBox(L("Klavye — TV'de açık bir yazı kutusuna gönderir", "Keyboard — types into the focused text field on the TV")) {
                    HStack {
                        TextField(L("Aranacak metin…", "Text to send…"), text: $text)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(send)
                        Button(L("Gönder", "Send"), action: send)
                        Button(L("Sil", "Delete")) { tv.key("KEYCODE_DEL") }
                    }
                    .padding(6)
                }
                .frame(maxWidth: 560)

                Text(L("Kısayollar: oklar = yön · Enter = Tamam · ⌫ = Geri · H = Ana ekran · Boşluk = Oynat/Durdur · − / = ses · [ / ] kanal · M = sessiz",
                       "Shortcuts: arrows = navigate · Enter = OK · ⌫ = Back · H = Home · Space = Play/Pause · − / = volume · [ / ] channel · M = mute"))
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private func send() {
        tv.sendText(text)
        text = ""
    }
}

struct DPad: View {
    @EnvironmentObject var tv: TVModel
    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(width: 64, height: 64)
                Round("chevron.up") { tv.key("KEYCODE_DPAD_UP") }.keyboardShortcut(.upArrow, modifiers: [])
                Color.clear.frame(width: 64, height: 64)
            }
            GridRow {
                Round("chevron.left") { tv.key("KEYCODE_DPAD_LEFT") }.keyboardShortcut(.leftArrow, modifiers: [])
                Round(nil, label: "OK", prominent: true) { tv.key("KEYCODE_DPAD_CENTER") }.keyboardShortcut(.return, modifiers: [])
                Round("chevron.right") { tv.key("KEYCODE_DPAD_RIGHT") }.keyboardShortcut(.rightArrow, modifiers: [])
            }
            GridRow {
                Color.clear.frame(width: 64, height: 64)
                Round("chevron.down") { tv.key("KEYCODE_DPAD_DOWN") }.keyboardShortcut(.downArrow, modifiers: [])
                Color.clear.frame(width: 64, height: 64)
            }
        }
    }
}

struct RockerView: View {
    @EnvironmentObject var tv: TVModel
    let title: String, up: String, down: String
    let upKey: KeyEquivalent, downKey: KeyEquivalent
    var body: some View {
        VStack(spacing: 8) {
            Round("plus") { tv.key(up) }.keyboardShortcut(upKey, modifiers: [])
            Text(title).font(.caption).foregroundStyle(.secondary)
            Round("minus") { tv.key(down) }.keyboardShortcut(downKey, modifiers: [])
        }
    }
}

struct Round: View {
    let icon: String?
    var label = ""
    var prominent = false
    let action: () -> Void
    init(_ icon: String?, label: String = "", prominent: Bool = false, action: @escaping () -> Void) {
        self.icon = icon; self.label = label; self.prominent = prominent; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Group {
                if let icon { Image(systemName: icon).font(.title2.weight(.semibold)) }
                else { Text(label).font(.title3.weight(.bold)) }
            }
            .frame(width: 64, height: 64)
            .background(Circle().fill(prominent ? Color.accentColor : Color.secondary.opacity(0.15)))
            .foregroundStyle(prominent ? .white : .primary)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
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
            Label(title, systemImage: icon).frame(minWidth: 96)
        }
        .controlSize(.large)
        .tint(tint)
        .buttonStyle(.bordered)
    }
}
