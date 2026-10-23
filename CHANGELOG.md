# Sürüm notları / Release notes

## 1.1.0 — 2026-10-23

### Mac uygulaması
- Mac ve TV launcher ayrı GitHub repolarına taşındı. Mac kaynakları kökte sadeleştirildi; launcher indirme ve sağlama toplamı doğrulaması `tahsingibi/adbroom-launcher` yayınlarını kullanır.
- Kenar çubuğu düğmesinin uzayan kapsül görünümü giderildi; kompakt native araç çubuğu ve sabit ikon boyutu kullanılır.
- Mac arayüzü baştan tasarlandı: ortak kart/başlık sistemi, yeni kenar çubuğu ve bağlantı paneli, kumanda çalışma alanı, ekran önizleme alanı, aranabilir uygulama listesi, sade launcher editörü ve yeni Genel/form ekranları.
- Paket içindeki ikon açılışta doğrudan Dock'a uygulanır; yerinde güncelleme sonrası eski ikon önbellekte kalmaz.
- Yeni Android TV / sihirli değnek ikonu; yuvarlatılmış kenarları korunan şeffaf görsel, Mac/launcher/TV görseli ve README'lerde ortak kullanılır.
- Türkçe/İngilizce ana README'ler ve ürün rehberleri güncel gezinme, derleme yolları ve bağımsız paketlere göre yenilendi.
- TV'ye APK ve bölünmüş APK yükleme; uygulamaları açma/durdurma ve desteklenen varsayılanları değiştirme.
- İsteğe bağlı native ADBroom Launcher: TV kumandası veya Mac'ten uygulama sırası ve tercihlerini düzenleme.
- Launcher için native ayarlar, favoriler, özel adlar, koleksiyonlar, gizleme, PIN ve isteğe bağlı TV modülleri.
- Hakkında, Sistem ve Güncellemeler tek sayfada.
- Mac uygulaması ve Android launcher bağımsız kaynak, derleme ve paketlere ayrıldı. Mac DMG'si JDK/Android SDK veya APK içermez.
- Launcher APK'sını tek başına indirme ya da TV bağlıyken GitHub'dan doğrulayıp ADB ile kurma/güncelleme.
- GitHub güncelleme kontrolü, bağımsız Mac/launcher kanalları ve SHA-256 doğrulaması.
- Launcher sayfası ADB yanıtlarını beklerken arayüzün kilitlenmemesi için süreç çıktısı dosyaya yönlendirilir; istekler paralel ve süre sınırıyla çalışır.
- Kenar çubuğu pencere boyutlarıyla sınırlandırılan bağımsız bir sütuna taşındı; Launcher açılırken menünün ve bağlantı alanının boş kalmasına yol açan NavigationSplitView/safe-area yerleşimi kaldırıldı.
- Launcher uygulama listesindeki sınırsız yükseklik kaldırıldı; AppKit layout döngüsüne neden olan iç içe ölçüm düzeltildi.
- Mac derlemesi başarısız olduğunda son doğrulanmış uygulama korunur.
- Swift modül önbelleği build klasöründe tutulur; kullanıcı önbelleğine yazma izni gerektirmez.

### English
- Shared Android TV / magic wand artwork across Mac, launcher, TV banner and documentation, with transparent rounded edges.
- Updated English/Turkish and product READMEs for current navigation, build paths and separate packages.
- Install APKs and split APK sets on a TV; launch/stop apps and change supported defaults.
- Optional native ADBroom Launcher, configurable from the TV remote or Mac.
- Native launcher settings, favorites, aliases, collections, hidden apps, PIN and optional TV modules.
- A unified About page with System and Updates blocks.
- Independent Mac and Android launcher source/build/packages. The Mac DMG needs no Android tools and contains no APK.
- Download the standalone launcher APK or verify and install/update it over ADB from GitHub.
- GitHub update checks with separate Mac/launcher channels and SHA-256 verification.
- Failed Mac builds preserve the last verified app.
- Keep sidebar navigation and connection controls visible when opening Launcher using a window-bounded layout.
- Store the Swift module cache inside the build directory.

## 1.0.0 — GitHub'da yayımlandı / Published on GitHub
- İlk yayımlanmış Mac sürümü. / First published Mac release.

[Launcher sürüm notları](https://github.com/tahsingibi/adbroom-launcher/blob/main/CHANGELOG.md) / [Launcher release notes](https://github.com/tahsingibi/adbroom-launcher/blob/main/CHANGELOG.md)
