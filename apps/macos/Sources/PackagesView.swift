import SwiftUI

/// Disable / re-enable packages on any Android TV. Never uninstalls.
struct PackagesView: View {
    @EnvironmentObject var tv: TVModel

    enum Filter: String, CaseIterable, Identifiable {
        case known, disabledByApp, disabled, system, user, all
        var id: String { rawValue }
        var title: String {
            switch self {
            case .known: L("Bilinen gereksizler", "Known bloat")
            case .disabledByApp: L("ADBroom'un kapattıkları", "Disabled by ADBroom")
            case .disabled: L("Tüm kapalılar", "All disabled")
            case .system: L("Sistem", "System")
            case .user: L("Kullanıcı", "User")
            case .all: L("Tümü", "All")
            }
        }
    }

    @State private var filter: Filter = .known
    @State private var search = ""
    @State private var pending: PackageRow?
    @State private var confirmRevert = false
    @State private var showLog = false

    private var rows: [PackageRow] {
        tv.packages.filter { row in
            let match: Bool
            switch filter {
            case .known: match = PackageDB.info(row.package) != nil
            case .disabledByApp: match = tv.records.contains(row.package)
            case .disabled: match = row.disabled
            case .system: match = row.system
            case .user: match = !row.system
            case .all: match = true
            }
            return match && (search.isEmpty || row.package.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                RoomHeader(title: L("Daha hafif bir TV.", "A lighter TV."), subtitle: L("Gereksiz paketleri kapat. İhtiyaç duyduğunda geri aç.", "Disable unwanted packages. Bring them back whenever you need."), eyebrow: L("PAKETLER", "PACKAGES"))
                if tv.busy { ProgressView().controlSize(.small) }
                Button { Task { await tv.loadPackages() } } label: { Image(systemName: "arrow.clockwise") }.help(L("Yenile", "Refresh"))
                Menu {
                    Button(showLog ? L("Listeyi göster", "Show list") : L("İşlem geçmişi", "Activity log")) { showLog.toggle() }
                    Button(L("Tümünü geri aç (\(tv.records.count))…", "Re-enable all (\(tv.records.count))…")) { confirmRevert = true }.disabled(tv.records.isEmpty || tv.busy)
                } label: { Label(L("İşlemler", "Actions"), systemImage: "ellipsis.circle") }
            }
            HStack(spacing: 16) {
                RoomBadge(text: L("\(tv.packages.filter { !$0.disabled }.count) açık", "\(tv.packages.filter { !$0.disabled }.count) enabled"), color: .green)
                RoomBadge(text: L("\(tv.packages.filter { $0.disabled }.count) kapalı", "\(tv.packages.filter { $0.disabled }.count) disabled"), color: .orange)
                Spacer()
                Label(L("Kritik paketler korunur", "Critical packages protected"), systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
            }.padding(16).roomSurface()

            if showLog {
                ScrollView {
                    Text(tv.logText.isEmpty ? L("Bu TV için henüz kayıt yok.", "No log for this TV yet.") : tv.logText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                if let dir = tv.deviceDir {
                    Button(L("Klasörü Finder'da göster", "Show folder in Finder")) { NSWorkspace.shared.open(dir) }
                }
            } else {
                HStack {
                    Picker("", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 240)
                    RoomSearch(text: $search, prompt: L("Paket ara", "Search packages")).frame(maxWidth: 300)
                    Spacer()
                    Text(L("\(rows.count) sonuç", "\(rows.count) results")).font(.caption).foregroundStyle(.secondary)
                }
                Table(rows) {
                    TableColumn(L("Durum", "State")) { row in
                        Label(row.disabled ? L("Kapalı", "Disabled") : L("Açık", "Enabled"),
                              systemImage: row.disabled ? "pause.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(row.disabled ? .orange : .green)
                    }
                    .width(90)
                    TableColumn(L("Paket", "Package")) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.package).font(.system(size: 11, weight: .medium, design: .monospaced)).lineLimit(1)
                            if let info = PackageDB.info(row.package) {
                                Text((info.caution ? "⚠︎ " : "") + info.text).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                    TableColumn(L("Tür", "Type")) { row in
                        Text(row.system ? L("Sistem", "System") : L("Kullanıcı", "User")).font(.caption)
                    }
                    .width(70)
                    TableColumn("") { row in action(row) }
                        .width(130)
                }.clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(RoomTheme.line))
            }
        }
        .padding(28)
        .task { if tv.packages.isEmpty { await tv.loadPackages() } }
        .confirmationDialog(pendingTitle, isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), presenting: pending) { row in
            Button(L("Kapat", "Disable"), role: .destructive) { Task { await tv.disable(row.package) } }
        } message: { row in
            Text(pendingMessage(row))
        }
        .confirmationDialog(L("ADBroom'un bu TV'de kapattığı \(tv.records.count) paketin hepsi geri açılsın mı?",
                              "Re-enable all \(tv.records.count) packages ADBroom disabled on this TV?"),
                            isPresented: $confirmRevert) {
            Button(L("Hepsini geri aç", "Re-enable all"), role: .destructive) { Task { await tv.revertAll() } }
        }
    }

    @ViewBuilder
    private func action(_ row: PackageRow) -> some View {
        if row.disabled {
            Button(L("Geri aç", "Enable")) { Task { await tv.enable(row.package) } }
                .disabled(tv.busy)
        } else if let reason = tv.protection(row.package) {
            Label(reason.text, systemImage: "lock.fill")
                .font(.caption).foregroundStyle(.secondary)
                .help(L("Bu paketi kapatmak TV'yi kullanılamaz hale getirebilir.", "Disabling this package can make the TV unusable."))
        } else {
            Button(L("Kapat…", "Disable…")) { pending = row }
                .disabled(tv.busy)
        }
    }

    private var pendingTitle: String {
        L("\(pending?.package ?? "") kapatılsın mı?", "Disable \(pending?.package ?? "")?")
    }

    private func pendingMessage(_ row: PackageRow) -> String {
        if let info = PackageDB.info(row.package) {
            return info.text + "\n\n" + L("İstediğin zaman \"Geri aç\" ile geri gelir.", "You can bring it back any time with \"Enable\".")
        }
        return L("Bu paketin ne yaptığı bilinmiyor. Kapattıktan sonra TV'yi test et (Kaynak tuşu, HDMI, ses, klavye, uygulamalar). Sorun olursa \"Geri aç\" ile geri al.",
                 "This package is not in ADBroom's database. After disabling, test the TV (Input key, HDMI, sound, keyboard, apps). If anything breaks, press \"Enable\".")
    }
}
