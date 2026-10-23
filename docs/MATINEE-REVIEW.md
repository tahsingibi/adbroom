# Matinee incelemesi ve ADBroom kararları

İnceleme: 23 Ekim 2026. Referans: [Jarvis322/matinee](https://github.com/Jarvis322/matinee).

README ile birlikte özellikle şu kaynaklar incelendi:

- [SettingsStore.kt](https://github.com/Jarvis322/matinee/blob/main/app/src/main/java/com/tcltv/sahne/data/SettingsStore.kt): görünüm, modüller, uygulama tercihleri, PIN ve giriş tercihleri.
- [SettingsScreen.kt](https://github.com/Jarvis322/matinee/blob/main/app/src/main/java/com/tcltv/sahne/ui/settings/SettingsScreen.kt): ayar bölümleri ve sistem kısayolları.
- AppCustomization, AppCatalog, HomeApps, InputCatalog, Parental ve MediaHistory: uygulama düzenleme, klasörler, girişler ve medya yaklaşımı.

Matinee Kotlin/Compose kullanıyor. ADBroom’un uygulaması kendi Java/native Android bileşenleriyle bağımsız geliştirildi; Matinee kodu, görselleri veya native kütüphaneleri projeye alınmadı. Referans projenin lisansı GPL-3.0; ADBroom’un mevcut LICENSE dosyası korunuyor.

## Eklenen karşılıklar

| İhtiyaç | ADBroom uygulaması |
| --- | --- |
| Ana ekran düzeni | Geri dönüştürülen native ızgara ve yatay sıra; 4–8 sütun |
| Favoriler | İsteğe bağlı favori rafı; genel uygulama sırasını izler |
| Uygulama düzenleme | Uzun OK menüsü: taşı, favori, adlandır, klasöre/koleksiyona ata, gizle/göster, PIN kilidi, uygulama bilgisi |
| Klasörler | Adlandırılmış koleksiyon filtreleri; aynı uygulamalar Tümü altında da bulunur |
| Görünüm | 3 sabit tema, 3 vurgu rengi, ikon/TV banner kartları, adları göster/gizle |
| Duvar kâğıdı | TV sistem dosya seçicisinden içe aktarılan, küçültülerek özel depolamada saklanan fotoğraf |
| Saat/profil | 12/24 saat, saat/tarih anahtarları, profil adı, son odağı hatırlama, Türkçe/English/TV dili |
| Sistem modülleri | Ağ bağlantı türü, Live TV/HDMI girişleri, bağlı olmayan girişleri gizleme |
| Medya | İsteğe bağlı Son medya kartı; kullanıcı tarafından verilen bildirim erişimi üzerinden medya oturumu başlığı ve ilerleme anlık görüntüsü |
| Ebeveyn kontrolü | Salt ile PBKDF2 PIN özeti, uygulama kilitleri, ayar/düzenleme koruması, 5 yanlış denemede bekleme |
| Home yönlendirme | İsteğe bağlı erişilebilirlik hizmeti; Home tuşu ve diğer ana ekran paketlerini izler, pencere içeriği erişimi kapalıdır |
| Cihaz/ayar kısayolları | RAM/depolama bilgisi; ağ, Bluetooth, görüntü, ses, uygulama ve giriş ayarları |
| Bilgisayardan yönetim | Görünüm/modül tercihleri ve uygulama tercihleri; sürüm denetimli ortak ayar+sıra kaydı |
| Yedekleme | Mac’te JSON dışa/içe aktarma; içe aktarma önce taslak oluşturur, TV’ye kaydet ile uygulanır |

## Hız ve kapsam kararları

- `INTERNET` izni eklenmedi; `ACCESS_NETWORK_STATE` yalnızca bağlantı durumunu okumak için kullanılır. Hava durumu, indirme hız testi ve AirPlay alıcısı bu sürümde yok; bunlar ağ erişimi ve ayrı servis/bağımlılık gerektiriyor.
- Otomatik RAM temizleyici eklenmedi. Cihaz bilgisi talep üzerine okunuyor; launcher başka uygulamaları arka planda öldürmüyor.
- Animasyonlu duvar kâğıdı, blur/glass ve saniyelik saat yok. Odak anlık değişiyor; fotoğraf küçültülüp önbelleğe alınıyor.
- Bildirim kutusu ve Play Store uyarı toplayıcısı yok. Medya modülü bildirim metinlerini kaydetmiyor. Son başlık ve kaynak paket yalnızca TV’de tutuluyor.
- Özel uygulama görseli dosyası, iç içe klasörler ve çoklu kullanıcı profil yöneticisi eklenmedi; mevcut seçenekler ikon/banner ve tek düzey koleksiyonlardır. Android kullanıcılarının tercihleri birbirinden ayrıdır.
- PIN ve duvar kâğıdı dosyası ADB ayar profilinde veya JSON yedeğinde bulunmaz. Mac, ebeveyn PIN’ini ayarlamaz/okumaz. Launcher PIN’i sistem genelinde bir güvenlik sınırı değildir.
- Home hizmeti ve medya erişimi kendiliğinden açılmaz. Kullanıcı TV’nin sistem ekranında açıkça etkinleştirir. Üretici ve Android’in yan yükleme kısıtlamaları geçerlidir.
- HDMI ve medya, TV’nin sunduğu Android API’leriyle sınırlıdır. Gerçek donanım girişleri ve üreticiye özgü Home davranışı fiziksel TV’de ayrıca doğrulanmalıdır.

## Doğrulama

`apps/launcher/tests/features.py`: sürümlü profil okuma/yazma, doğrulama, ad/favori/gizleme/koleksiyon, TV ayarından ADB’ye değişiklik, yatay düzen, PIN akışları. `apps/launcher/tests/smoke.py`: kurulum, sıralama, çakışma koruması, süreç yeniden başlatma ve varsayılan HOME çözümleme. Swift testleri JSON ayar köprüsünü ve geçersiz profilleri denetler. Testler yalnızca geçici emülatörde çalıştırılır.
