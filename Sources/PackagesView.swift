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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Paketler", "Packages")).font(.headline)
                    Text(L("Yalnızca kapatır (pm disable-user); asla silmez. Her şey tek tıkla geri açılır. Kritik paketler kilitlidir.",
                           "Only disables (pm disable-user); never uninstalls. Everything can be re-enabled in one click. Critical packages are locked."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if tv.busy { ProgressView().controlSize(.small) }
                Button(L("Yenile", "Refresh")) { Task { await tv.loadPackages() } }
                Button(showLog ? L("Listeyi göster", "Show list") : L("Kayıt", "Log")) { showLog.toggle() }
                Button(L("Tümünü geri al (\(tv.records.count))…", "Revert all (\(tv.records.count))…"), role: .destructive) {
                    confirmRevert = true
                }
                .disabled(tv.records.isEmpty || tv.busy)
            }

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
                    TextField(L("Ara…", "Search…"), text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    Spacer()
                    Text("\(rows.count)").font(.caption).foregroundStyle(.secondary)
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
                            Text(row.package).font(.system(.body, design: .monospaced))
                            if let info = PackageDB.info(row.package) {
                                Text((info.caution ? "⚠︎ " : "") + info.text).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    TableColumn(L("Tür", "Type")) { row in
                        Text(row.system ? L("Sistem", "System") : L("Kullanıcı", "User")).font(.caption)
                    }
                    .width(70)
                    TableColumn("") { row in action(row) }
                        .width(150)
                }
            }
        }
        .padding(20)
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
