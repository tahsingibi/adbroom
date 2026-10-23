<p align="center"><img src="assets/branding/adbroom-icon.png" width="128" alt="ADBroom"></p>
<h1 align="center">ADBroom</h1>
<p align="center">Native Mac uygulaması ve bağımsız Android TV launcher’ı.<br><a href="README.md">English</a> · <b>Türkçe</b></p>

## İndireceğin ürünü seç

| Ürün | Platform | İndirme | Diğer uygulama gerekli mi? |
| --- | --- | --- | --- |
| **ADBroom Mac** | macOS 14+, Apple Silicon / Intel | [Mac yayınları](https://github.com/tahsingibi/adbroom/releases?q=macos-v) — `ADBroom-<sürüm>.dmg` | Hayır |
| **ADBroom Launcher** | Android TV / Google TV / Fire TV, Android 6+ | [Launcher yayınları](https://github.com/tahsingibi/adbroom/releases?q=launcher-v) — `ADBroomLauncher-<sürüm>.apk` | Hayır |

İki ürünün sürümleri ve paketleri bağımsızdır. Yalnızca TV ana ekranı istiyorsan APK’yı indirmen yeterli; Mac uygulamasını kurman gerekmez. Mac uygulamasından launcher daha sonra indirilebilir; DMG’nin içinde APK yoktur. İndirme dosyaları ve SHA-256 kayıtları yayımlanan GitHub Release’in Assets bölümündedir; kaynak kod tek başına kurulum paketi değildir.

## Mac uygulaması

Arayüz; ortak başlıklar, kartlar ve bağlantı paneli etrafında yeniden tasarlandı. Kumanda bölümlü bir kontrol panelidir; Uygulamalar sayfasında ad/paket araması ve satır işlem menüsü, Launcher’da sade sıralama alanı bulunur. Genel → Hakkında alanında Sistem, Açık ve Koyu görünüm seçilebilir.

- Kumanda: yön, ses, kanal, Kaynak, medya, metin ve açma/kapatma.
- Ekran: scrcpy ile sesli/görüntülü izleme ve ekran görüntüsü; DRM/HDMI yakalama TV’ye bağlıdır.
- Uygulamalar: APK/split-APK yükleme, açma/durdurma, varsayılan ana ekran ve uygulama ayarları.
- Launcher editörü: sıralama, favori, ad, klasör, gizleme, görünüm/modüller ve JSON yedekleme.
- Paketler: kritik paket koruması ve geri alma kaydıyla kapatma/geri açma; asla kaldırmaz.
- **Genel:** Hakkında, Sistem ve Güncellemeler bloklarını bu sırayla gösteren tek sayfa.
- Türkçe / English.

Kenar çubuğunda sayfalar ve TV bağlantı kontrolleri birlikte bulunur; araç çubuğundaki düğmeyle gizlenip gösterilir. Launcher'da satırları sürükleyerek veya oklarla sırala, satırdaki ayar simgesinden uygulama tercihlerini aç ve **TV'ye kaydet** ile uygula. **Ayarlar** launcher profilini, **Yedek** JSON içe/dışa aktarmayı yönetir. TV verisi yenilenirken ve kaydedilirken ilgili düzenleme kontrolleri bekler.

DMG’yi açıp ADBroom’u Uygulamalar’a taşı. Paket ad-hoc imzalıdır, notarize değildir; ilk açılışta **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** gerekebilir. TV işlemleri için araçları kur:

```sh
brew install android-platform-tools scrcpy
```

TV’de geliştirici seçeneklerini ve USB/ağ/kablosuz hata ayıklamayı aç, Mac ile aynı ağa bağla, IP adresini ADBroom’a gir ve TV’deki izin sorusunu onayla. TV eşleştirme kodu istiyorsa önce **Eşleştir** ile IP:port/kodu kullan; sonra bağlantı IP:port’una bağlan.

## Mac gerektirmeyen TV launcher’ı

Native ızgara/yatay sıra, favoriler, özel adlar, klasörler, gizleme, duvar kâğıdı, saat, modüller ve isteğe bağlı ebeveyn PIN’i. INTERNET izni, reklam, WebView veya üçüncü taraf çalışma zamanı yok. Ayarlar ve tercihler TV kumandasından, Mac olmadan yönetilir.

APK’yı Launcher yayınlarından indirip TV’ye aktar. TV’nin APK yükleyicisiyle veya **herhangi bir** desteklenen bilgisayardan ADB ile kur:

```sh
adb connect <TV-IP>:5555
adb -s <TV-IP>:5555 install -r ADBroomLauncher-1.2.1.apk
```

TV’nin varsayılan ana ekran ayarlarından ADBroom’u seç. OK uygulamayı açar; uzun OK seçenekleri açar; Menü sıralamayı başlatır; yön tuşları taşır, OK kaydeder, Geri iptal eder. Gizli uygulamalara launcher ayarlarından ulaşılır. Bazı üreticiler Home seçimini kısıtlar; isteğe bağlı Home yönlendirme hizmeti ayarlarda açıklanır ve sistemden kullanıcı tarafından açılır. Medya erişimi de isteğe bağlıdır. PIN launcher girişlerini korur; Android’in tamamını kilitlemez.

Mac’te **Genel → Hakkında → Launcher APK indir** dosyayı TV bağlantısı olmadan da kaydeder. TV bağlıyken **Launcher → Yükle/Güncelle**, ayrı GitHub paketini indirir, sağlama toplamını doğrular ve ADB ile kurar. Yerel dosya için **Uygulamalar → APK yükle** kullanılabilir. Android güncellemelerinde aynı APK imza kimliği korunmalıdır.

## Güncellemeler ve sürüm notları

**ADBroom → ADBroom Hakkında** Genel sayfasını açar. Güncellemeler bloğu elle kontrol ve açılışta/etkinleşmede en fazla günde bir otomatik kontrol sunar. **ADBroom → Güncellemeleri kontrol et** de aynı sayfaya gider. Mac ve launcher yayınları ayrı filtrelenir; yeni bir APK, Mac güncellemesi olarak sunulmaz. GitHub’a TV verisi gönderilmez; indirme ve kurulumu kullanıcı başlatır.

**Mac 1.1.0 (yayınlanmadı):** Hakkında/Sistem/Güncellemeler bloklarıyla Genel sayfası, bağımsız paketler, doğrulanmış launcher indirme, düzeltilen Launcher/kenar çubuğu yerleşimi ve yeni ortak ikon. **v1.0.0**, önceki yayımlanmış Mac sürümüdür. **Launcher 1.2.1 (yayınlanmadı):** bağımsız sürümlü APK/SHA-256 dağıtımı ve eşleşen ikon/TV görseli. Yerel derleme GitHub'da sürüm yayımlamaz.

[Tüm Mac/proje sürüm notları](CHANGELOG.md) · [Launcher sürüm notları](apps/launcher/CHANGELOG.md) · [Yayın rehberi](docs/RELEASING.md)

## Klasörler ve derleme

```text
apps/
  macos/       Sources/, Resources/, Tests/, VERSION, BUILD_NUMBER, build.sh
  launcher/    src/, res/, tests/, AndroidManifest.xml, build.sh
assets/branding/ ortak şeffaf ikon ve özgün görsel
scripts/       release-notes.py, release.sh
docs/          yayın ve geliştirme notları
build/
  macos/       ADBroom.app
  ADBroom.app  macos/ADBroom.app için uyumluluk bağlantısı
  launcher/    geliştirme APK’sı
dist/
  macos/       sürümlü DMG + SHA-256
  launcher/    sürümlü APK + SHA-256
```

```sh
./build.sh                 # Yalnızca Mac; Xcode/Command Line Tools
./build.sh --dmg           # Mac + dist/macos altında DMG/sağlama toplamı
./build.sh --launcher      # Bağımsız APK; JDK 17+, Python 3, Android SDK
./build.sh --all --dmg     # İki ürünü ayrı paketler olarak hazırla
./scripts/release.sh macos # Derle ve GitHub taslak sürümü oluştur
./scripts/release.sh launcher
```

Mac derlemek için JDK/Android SDK gerekmez. Launcher derlemek için Swift/Xcode gerekmez. [Mac geliştirme](apps/macos/README.md) ve [launcher derleme/imzalama/test](apps/launcher/README.md) ayrıntılarına bak. Başarısız derleme önceki doğrulanmış uygulamayı korur. İmza anahtarları, kullanıcı verileri ve çıktılar depoya eklenmez.

Derlemeden sonra **`build/macos/ADBroom.app`** dosyasını aç. Eski `build/ADBroom.app` yolu da aynı güncel uygulamaya bağlanır. Swift modül önbelleği `build/macos/.module-cache` içindedir. Uygulamalar klasöründeki kopya çalışıyorsa yeni derlemeyle değiştirmeden önce onu kapat.

## Uygulama görselleri

Mac ikonu, bağımsız launcher ikonu, TV görseli ve README başlıkları aynı Android TV / sihirli değnek tasarımını kullanır. Şeffaf ana görsel, gönderilen ikonun yuvarlatılmış dış hatlarını korur; platform boyutları oran bozulmadan hazırlanır. Ayrıntılar: [görsel kaynakları](assets/branding/README.md).

GitHub yayınlamak için `brew install gh` ve `gh auth login` gerekir. Yayın betiği varsayılan olarak taslak oluşturur; hemen yayınlamak için `--publish` kullan. Ayrıntılar: [yayın rehberi](docs/RELEASING.md).

## Sınırlar ve teşekkürler

DRM’li içerik, canlı TV ve HDMI izleme penceresinde siyah görünebilir. Donanım kodlayıcısı olmayan TV’de takılma olursa kaliteyi düşür. Derin uykudan açma Wake-on-LAN desteğine bağlıdır. HDMI, medya ve Home modülleri TV/üretici API’leriyle sınırlıdır.

İlk TV temizleme akışı [Mert Çobanov’un rehberine](https://tv.cobanov.dev/) dayanır. Ekran izleme [scrcpy](https://github.com/Genymobile/scrcpy) kullanır.

[MIT](LICENSE). Kullanım sorumluluğu sana aittir. Google veya TV üreticileriyle bağlantılı değildir. Android, Google LLC’nin ticari markasıdır. Android robotu Google tarafından paylaşılan çalışmadan [Creative Commons 3.0 Atıf Lisansı](https://creativecommons.org/licenses/by/3.0/) koşullarıyla kullanılır.
