import SwiftUI
import UniformTypeIdentifiers

struct LauncherInvitation: View {
    @EnvironmentObject var tv: TVModel
    @AppStorage("launcherInvitationDismissed") private var dismissed = false

    var body: some View {
        if !dismissed && !tv.launcherInstalled {
            GroupBox {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "square.grid.2x2.fill").font(.title).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("ADBroom'un kendine ait launcher'ını denemek ister misin?",
                               "Would you like to try ADBroom's own launcher?")).font(.headline)
                        Text(L("Sade, native, reklamsız. Uygulama sırasını Mac'ten veya TV kumandasından düzenle.",
                               "Simple, native, ad-free. Arrange apps from your Mac or TV remote."))
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button(L("Evet, yükle ve dene", "Yes, install and try")) { Task { await tv.installLauncher() } }
                                .buttonStyle(.borderedProminent)
                                .disabled(tv.launcherLoading || tv.managingApps)
                            Button(L("Şimdi değil", "Not now")) { dismissed = true }
                        }
                        Text(L("Varsayılan ana ekranını daha sonra kendin seçebilirsin. Launcher sekmesinden her zaman ulaşabilirsin.",
                               "Choose your default home app afterward. You can always find this in the Launcher tab."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(4)
            }
        }
    }
}

struct LauncherView: View {
    @EnvironmentObject var tv: TVModel
    @State private var draft: [LauncherApp] = []
    @State private var draftRevision: Int64?
    @State private var dragging: String?
    @State private var draftConfiguration = LauncherConfiguration()
    @State private var preferencesOpen = false
    @State private var editingApp: LauncherApp?
    private var dirty: Bool {
        guard !tv.launcherLoading, draftRevision != nil else { return false }
        return draft != tv.launcherApps || (tv.launcherConfiguration.map { draftConfiguration != $0 } ?? false)
    }
    @State private var confirmRefresh = false
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                RoomHeader(title: L("TV'ne kendi düzenini ver.", "Make your TV your own."), subtitle: L("Uygulamaların sırası, görünümü ve tercihleri burada.", "Your app order, appearance and preferences, all here."), eyebrow: "LAUNCHER")
                Button {
                    if dirty { confirmRefresh = true } else { Task { await refresh() } }
                } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(tv.launcherLoading || tv.managingApps).help(L("Yenile", "Refresh"))
            }
            if tv.launcherLoading && !tv.launcherInstalled {
                ProgressView(L("Launcher yükleniyor…", "Loading launcher…")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !tv.launcherInstalled {
                RoomCard(L("ADBroom Launcher ile tanış.", "Meet ADBroom Launcher."), icon: "house") {
                    Text(L("ADBroom'un kendine ait launcher'ını denemek ister misin?", "Would you like to try ADBroom's own launcher?")).font(.title3.weight(.semibold))
                    Text(L("Native, reklamsız ve hızlı. Uygulamalarını Mac'ten ya da TV kumandasından düzenle.", "Native, ad-free and fast. Arrange your apps from Mac or your TV remote.")).foregroundStyle(.secondary)
                    Button(L("Evet, yükle ve dene", "Yes, install and try")) { Task { await tv.installLauncher(); syncDraft() } }.buttonStyle(.borderedProminent).controlSize(.large)
                    Text(L("GitHub'dan ayrı APK indirilir. Yerel APK için Uygulamalar sayfasını kullanabilirsin.", "Downloads the separate APK from GitHub. Use Apps for a local APK.")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            } else {
                HStack(spacing: 14) {
                    RoomAppIcon(icon: "house.fill")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ADBroom Launcher").font(.headline)
                        RoomBadge(text: tv.currentHome.hasPrefix(LauncherBridge.package + "/") ? L("Varsayılan ana ekran", "Default home app") : L("TV'ye kurulu", "Installed on TV"), color: .green)
                    }
                    Spacer(minLength: 0)
                    Button(L("TV'de aç", "Open on TV")) { Task { await tv.previewLauncher() } }
                    Menu {
                        Button(L("Launcher'ı güncelle", "Update launcher")) { Task { await tv.installLauncher(); syncDraft() } }.disabled(dirty)
                        Button(L("Varsayılan yap", "Set default")) { Task { await tv.makeLauncherDefault() } }.disabled(tv.currentHome.hasPrefix(LauncherBridge.package + "/"))
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22).help(L("Launcher işlemleri", "Launcher actions"))
                }.padding(18).roomSurface()
                HStack(spacing: 12) {
                    Text(L("Ana ekran düzeni", "Home screen order")).font(.headline)
                    RoomBadge(text: String(draft.count))
                    if tv.launcherLoading { ProgressView().controlSize(.small) }
                    Spacer()
                    Menu {
                        Button(L("Dışa aktar…", "Export…")) { exportProfile() }
                        Button(L("İçe aktar…", "Import…")) { importProfile() }
                    } label: { Label(L("Yedek", "Backup"), systemImage: "arrow.up.arrow.down") }.disabled(tv.launcherConfiguration == nil)
                    Button { preferencesOpen = true } label: { Label(L("Görünüm ve modüller", "Appearance & modules"), systemImage: "slider.horizontal.3") }.disabled(tv.launcherConfiguration == nil)
                }
                if !tv.launcherError.isEmpty {
                    Label(tv.launcherError, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
                if !draftConfiguration.valid {
                    Text(L("Ad uzunluklarını kontrol et: profil 40, uygulama 60, koleksiyon 30 karakter.", "Check name lengths: profile 40, app 60, collection 30 characters.")).font(.caption).foregroundStyle(.orange)
                }
                ScrollView {
                    if draft.isEmpty {
                        if tv.launcherLoading { ProgressView().padding(36) }
                        else { ContentUnavailableView(L("Henüz uygulama yok", "No apps yet"), systemImage: "square.grid.2x2", description: Text(L("Listeyi yenilemeyi dene.", "Try refreshing the list."))).padding(24) }
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(draft.enumerated()), id: \.element.id) { index, app in
                                HStack(spacing: 12) {
                                    Image(systemName: "line.3.horizontal").font(.caption).foregroundStyle(.tertiary)
                                    Text(String(index + 1)).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary).frame(width: 20)
                                    RoomAppIcon(icon: draftConfiguration.hidden.contains(app.package) ? "eye.slash" : roomAppSymbol(app.package), color: roomAppColor(app.package))
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(draftConfiguration.labels[app.package] ?? app.label).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                            if draftConfiguration.favorites.contains(app.package) { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.orange) }
                                            if let group = draftConfiguration.groups[app.package] { Text(group).font(.caption2).foregroundStyle(.secondary) }
                                        }
                                        Text(app.package).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 6)
                                    Button { editingApp = app } label: { Image(systemName: "slider.horizontal.3") }.help(L("Uygulama tercihleri", "App preferences")).disabled(tv.launcherConfiguration == nil)
                                    Button { move(app.package, offset: -1) } label: { Image(systemName: "chevron.up") }.help(L("Yukarı taşı", "Move up")).disabled(index == 0)
                                    Button { move(app.package, offset: 1) } label: { Image(systemName: "chevron.down") }.help(L("Aşağı taşı", "Move down")).disabled(index == draft.count - 1)
                                }.padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
                                .onDrag { dragging = app.package; return NSItemProvider(object: app.package as NSString) }
                                .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                                    guard let source = dragging, let from = draft.firstIndex(where: { $0.package == source }),
                                          let to = draft.firstIndex(where: { $0.package == app.package }), from != to else { return false }
                                    draft.insert(draft.remove(at: from), at: to); dragging = nil; return true
                                }
                                if index < draft.count - 1 { Divider().padding(.leading, 106) }
                            }
                        }
                    }
                }.frame(minHeight: 100, maxHeight: 360).roomSurface().disabled(tv.launcherLoading)
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(dirty ? L("Kaydedilmemiş değişiklikler", "Unsaved changes") : L("TV ile eşleşiyor", "In sync with your TV"), systemImage: dirty ? "circle.fill" : "checkmark.circle")
                            .font(.caption.weight(.medium)).foregroundStyle(dirty ? Color.orange : Color.secondary)
                        Text(L("Satırları sürükle veya oklarla taşı. TV'de uzun OK ile düzenle.", "Drag rows or use arrows. On TV, hold OK to edit.")).font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    Button(L("Geri al", "Discard")) { syncDraft() }.disabled(!dirty)
                    Button {
                        guard let revision = draftRevision else { return }; saving = true
                        Task {
                            let result = await tv.saveLauncherOrder(draft, revision: revision, configuration: tv.launcherConfiguration == nil ? nil : draftConfiguration)
                            saving = false; if result != .failed { syncDraft() }
                        }
                    } label: { Label(L("TV'ye kaydet", "Save to TV"), systemImage: "checkmark") }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(!dirty || draftRevision == nil || !draftConfiguration.valid)
                }.disabled(tv.launcherLoading)
            }
        }.padding(28).frame(maxWidth: 1120).frame(maxWidth: .infinity, alignment: .top)
        .disabled(tv.managingApps || saving)
        .task { await Task.yield(); await refresh() }
        .sheet(isPresented: $preferencesOpen) { LauncherPreferencesView(configuration: $draftConfiguration) }
        .sheet(item: $editingApp) { app in LauncherAppPreferencesView(app: app, configuration: $draftConfiguration) }
        .confirmationDialog(L("Kaydedilmemiş değişiklikler silinip TV'deki sıra yüklensin mi?", "Discard unsaved edits and load the TV order?"), isPresented: $confirmRefresh) {
            Button(L("Yenile", "Refresh"), role: .destructive) { Task { await refresh() } }
        }
    }

    private func refresh() async {
        async let launcher: Void = tv.loadLauncher()
        async let defaults: Void = tv.loadDefaults()
        _ = await (launcher, defaults)
        syncDraft()
    }
    private func syncDraft() {
        draft = tv.launcherApps; draftRevision = tv.launcherRevision
        draftConfiguration = tv.launcherConfiguration ?? LauncherConfiguration()
    }
    private func exportProfile() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "adbroom-launcher.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let profile = LauncherProfile(settings: draftConfiguration, order: draft.map(\.package))
            guard profile.valid else { throw CocoaError(.fileWriteUnknown) }
            try encoder.encode(profile).write(to: url, options: .atomic)
            tv.lastMessage = L("Launcher tercihleri dışa aktarıldı. PIN ve yerel duvar kâğıdı bu dosyaya eklenmez.", "Launcher preferences exported. PIN and local wallpaper are excluded.")
        } catch { tv.lastMessage = error.localizedDescription }
    }
    private func importProfile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: 131_073) ?? Data()
            guard data.count <= 131_072 else { throw CocoaError(.fileReadCorruptFile) }
            let profile = try JSONDecoder().decode(LauncherProfile.self, from: data)
            guard profile.valid else { throw CocoaError(.fileReadCorruptFile) }
            let apps = Dictionary(uniqueKeysWithValues: tv.launcherApps.map { ($0.package, $0) })
            let ordered = profile.order.compactMap { apps[$0] }
            draft = ordered + tv.launcherApps.filter { !profile.order.contains($0.package) }
            draftConfiguration = profile.settings
            tv.lastMessage = L("Yedek taslağa alındı. Uygulamak için TV'ye kaydet'i seç.", "Backup loaded into your draft. Choose Save to TV to apply.")
        } catch { tv.lastMessage = L("Yedek okunamadı: ", "Could not read backup: ") + error.localizedDescription }
    }

    private func move(_ package: String, offset: Int) {
        guard let from = draft.firstIndex(where: { $0.package == package }), draft.indices.contains(from + offset) else { return }
        draft.insert(draft.remove(at: from), at: from + offset)
    }
}
