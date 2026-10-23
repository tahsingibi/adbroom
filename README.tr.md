<p align="center"><img src="assets/branding/adbroom-icon.png" width="128" alt="ADBroom"></p>
<h1 align="center">ADBroom Mac</h1>
<p align="center">Android TV'n için native çalışma alanı.<br><a href="README.md">English</a> · <b>Türkçe</b></p>

[Mac uygulamasını indir](https://github.com/tahsingibi/adbroom/releases) · [Bağımsız TV launcher'ı](https://github.com/tahsingibi/adbroom-launcher) · [Sürüm notları](CHANGELOG.md)

## Neler yapabilirsin?

- **Kumanda:** yön, ses, kanal, kaynak, medya, güç ve klavye; bilgisayar kısayollarıyla kontrol.
- **Ekran:** scrcpy ile sesli/görüntülü izleme, ekran görüntüsü alma ve PNG kaydetme.
- **Uygulamalar:** APK/split APK yükleme, ad/paket araması, açma/durdurma ve varsayılan ana ekran seçimi.
- **Launcher:** ayrı GitHub reposundan isteğe bağlı launcher kurma; sıralama, favoriler, özel adlar, koleksiyonlar, gizleme, görünüm/modüller ve JSON yedekleme.
- **Paketler:** geri alma kayıtları ve kritik paket korumasıyla gereksiz paketleri kapatma/geri açma.
- **Genel:** Hakkında → Sistem → Güncellemeler sırasıyla tek sayfa. Sistem/Açık/Koyu görünüm ve otomatik güncelleme kontrolü.
- Türkçe / English; native SwiftUI, tutarlı kartlar/formlar ve kalıcı TV bağlantı paneli.

## Kurulum ve TV bağlantısı

**macOS 14+**, Apple Silicon veya Intel gerekir. Bu reponun Releases bölümünden DMG'yi indir, aç ve ADBroom'u Uygulamalar'a taşı. Paket ad-hoc imzalıdır; notarize değildir. macOS **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** seçeneğini gösterebilir.

TV araçlarını kur:

```sh
brew install android-platform-tools scrcpy
```

TV'de geliştirici seçeneklerini ve USB/ağ/kablosuz hata ayıklamayı aç. TV ve Mac aynı ağdayken IP'yi bağlantı paneline gir; TV'deki izin sorusunu onayla. Eşleştirme kodu istenirse önce bağlantı simgesinden eşleştirme IP:port/koduyla eşleştir, sonra bağlantı IP:port'una bağlan.

## Launcher ayrı bir üründür

Launcher kaynakları, sürümleri, APK'ları ve yayınları kendi reposundadır:

**[tahsingibi/adbroom-launcher](https://github.com/tahsingibi/adbroom-launcher)**

Mac uygulaması olmadan kullanılabilir. Yalnızca TV ana ekranı istiyorsan APK yeterlidir. Bu repo yalnızca Mac uygulamasını derler; DMG'de APK bulunmaz, JDK/Android SDK gerekmez.

**Genel → Hakkında → Launcher APK indir** TV bağlantısı olmadan da dosyayı kaydeder. TV bağlıyken kurulum düğmesi veya **Launcher işlemleri → Launcher'ı güncelle**, kararlı APK'yı kendi reposundan indirir, SHA-256 doğrulamasından sonra ADB ile kurar. Yerel dosyalar için **Uygulamalar → APK yükle** kullanılır. Launcher editöründe sıralamayı/tercihleri düzenleyip **TV'ye kaydet** ile uygula; **Görünüm ve modüller** profili, **Yedek** JSON içe/dışa aktarmayı açar. Varsayılan ana ekran Uygulamalar veya Launcher işlem menüsünden seçilir.

## Klasörler ve derleme

```text
Sources/          Mac SwiftUI, ADB ve launcher köprüsü
Resources/        Mac uygulama ikonu
Tests/            Güncelleme/indirme ve launcher protokol testleri
assets/branding/  Özgün görsel ve şeffaf ikon
scripts/          Mac yayın ve ikon yardımcıları
docs/             Geliştirme, repo ve yayın rehberleri
VERSION           Mac sürümü
BUILD_NUMBER      Mac derleme numarası
build.sh          Yalnızca Mac universal derleme
build/            ADBroom.app ve derleyici önbelleği (Git dışında)
dist/             DMG ve SHA-256 (Git dışında)
```

```sh
./build.sh          # build/ADBroom.app
./build.sh --dmg    # ayrıca dist/ADBroom-<sürüm>.dmg ve .sha256
```

Xcode veya Command Line Tools yeterlidir. Başarısız derleme önceki doğrulanmış uygulamayı korur. Swift önbelleği `build/.module-cache` içindedir. `build/ADBroom.app` veya kurulu `/Applications/ADBroom.app` dosyasını aç.

[Geliştirme/test](docs/DEVELOPMENT.md) · [Yayınlama](docs/RELEASING.md) · [İki repo haritası](docs/REPOSITORIES.md) · [Görseller](assets/branding/README.md)

## Yayınlar ve güncellemeler

Mac güncellemeleri `tahsingibi/adbroom`, launcher APK'ları `tahsingibi/adbroom-launcher` üzerinden gelir. APK, Mac güncellemesi sayılmaz; başka repodan kurulum dosyası kabul edilmez. Kararlı Mac etiketleri `macos-v<sürüm>` biçimindedir; eski `v<sürüm>` Mac etiketleri de desteklenir. **Mac 1.1.0** yeni arayüzü, APK/varsayılan uygulama yönetimini ve bağımsız launcher entegrasyonunu içerir; [sürüm notlarına](CHANGELOG.md) bak.

GitHub CLI ile giriş yaptıktan sonra `./scripts/release.sh` taslak, `./scripts/release.sh --publish` herkese açık DMG/sağlama toplamı yayını oluşturur. Kaynak commit'i tek başına kurulum paketi değildir. Günlük kontrol Genel'den kapatılabilir; indirme/kurulumu kullanıcı başlatır. GitHub'a TV bilgisi veya uygulama listesi gönderilmez.

## Sınırlar ve teşekkürler

DRM, canlı TV ve HDMI siyah görünebilir. Zayıf TV'lerde izleme kalitesini düşürmek gerekebilir; ses için Android 11+ gerekir. Derin uykudan açma Wake-on-LAN desteğine bağlıdır. Ana ekran/HDMI/medya desteği üretici API'leriyle sınırlıdır. APK güncellemelerinde aynı imza kimliği korunmalıdır.

Tahsin Sungur · [X/tahsingibi](https://x.com/tahsingibi) · [sungur.dev](https://sungur.dev)

İlk TV temizleme akışı [Mert Çobanov'un rehberinden](https://tv.cobanov.dev/) yararlanır; izleme [scrcpy](https://github.com/Genymobile/scrcpy) kullanır. [MIT](LICENSE). Google veya TV üreticileriyle bağlantılı değildir. Android, Google LLC'nin ticari markasıdır. Android robotu Google'ın paylaştığı çalışmadan [Creative Commons 3.0 Atıf Lisansı](https://creativecommons.org/licenses/by/3.0/) koşullarıyla kullanılır.
