import SwiftUI

struct UpdatesView: View {
    @EnvironmentObject var updates: UpdateModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                RoomAppIcon(icon: updates.updateAvailable ? "arrow.down.circle" : "checkmark.shield", color: updates.updateAvailable ? RoomTheme.accent : .green)
                VStack(alignment: .leading, spacing: 4) {
                    Text(updates.title).font(.system(size: 15, weight: .semibold))
                    Text(updates.detail).font(.callout).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if updates.checking { ProgressView().controlSize(.small) }
            }
            if let release = updates.release, updates.updateAvailable {
                Text(release.name?.isEmpty == false ? release.name! : release.tagName).font(.headline)
                ScrollView {
                    Text(release.body?.isEmpty == false ? release.body! : L("Bu sürüm için not eklenmemiş.", "No notes were provided for this release."))
                        .font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12).frame(minHeight: 100, maxHeight: 220)
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
                HStack {
                    if let download = release.downloadURL {
                        Link(L("Yeni sürümü indir", "Download update"), destination: download).buttonStyle(.borderedProminent)
                    }
                    Link(L("GitHub'da sürümü aç", "View release on GitHub"), destination: release.htmlURL)
                }
                Text(L("DMG'yi açıp yeni ADBroom'u Uygulamalar'a taşı. Launcher bağımsız olarak GitHub'dan indirilebilir.",
                       "Open the DMG and drag ADBroom to Applications. The launcher is available separately from GitHub."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Toggle(L("Günde bir kez otomatik kontrol et", "Check automatically once a day"), isOn: $updates.automaticChecks)
                .toggleStyle(.switch)
                .onChange(of: updates.automaticChecks) { _, enabled in if enabled { Task { await updates.checkIfDue() } } }
            Text(L("Yalnızca GitHub'ın herkese açık sürüm bilgisi sorgulanır. TV bilgileri ve uygulama listen gönderilmez. Kurulumu sen başlatırsın.",
                   "Only GitHub's public release information is requested. TV details and your app list are not sent. You start the installation."))
                .font(.caption).foregroundStyle(.secondary)
            if let checked = updates.lastChecked {
                Text(L("Son başarılı kontrol: ", "Last successful check: ") + checked.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Link(L("GitHub yayınları", "GitHub releases"), destination: UpdateClient.releasesURL)
                Spacer()
                Button(L("Şimdi kontrol et", "Check now")) { Task { await updates.check() } }
                    .buttonStyle(.borderedProminent).disabled(updates.checking)
            }
        }
    }
}
