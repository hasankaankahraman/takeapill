# Take a Pill: App Store beyan rehberi

Bundle ID: `com.takeapill.takeapill` · Tek dil: Türkçe · Sunucu, hesap, analitik yok · Reklam: Google AdMob (kişiselleştirilmemiş banner).

## 1. Uygulama nasıl çalışır

Tüm veri cihazda SQLite'ta (drift) durur. Hatırlatmalar yerel bildirim ya da alarmla yapılır. Tek ağ trafiği AdMob reklam SDK'sınındır; hatırlatmalar ona bağlı değildir.

1. **Karşılama / onboarding** ([welcome_screen.dart](../../lib/ui/welcome_screen.dart)): ad (isteğe bağlı), yemek saatleri, hatırlatma şekli (bildirim ya da alarm), izinler.
2. **İlaç ekleme** ([medication_form.dart](../../lib/ui/medication_form.dart)): ad, tür, doz, yemekle ilişki, program (günlük, X saatte bir, gerektiğinde), başlangıç/bitiş tarihi.
3. **Planlama** ([notification_planner.dart](../../lib/core/notifications/notification_planner.dart)): önümüzdeki 14 gün için saf bir planlayıcı "önce / zamanında / tekrar (Aldın mı?) / erteleme" bildirimlerini üretir. iOS en fazla 64 bekleyen bildirime izin verdiği için en yakın 60 tanesi kurulur. Plan her açılışta ve her değişiklikte yenilenir.
4. **Doz saatinde** ([notification_service.dart](../../lib/core/notifications/notification_service.dart)):
   - Bildirim modu: "Aldım / Ertele / Atla" butonlu yerel bildirim.
   - Alarm modu, iOS 26+: AlarmKit alarmı ([CallAlarms.swift](../../ios/Runner/CallAlarms.swift)); kilit ekranı ve Dynamic Island, "Ertele / Aç".
   - Alarm modu, iOS 26 öncesi ya da alarm izni yok: `alarm.caf` sesli normal bildirim.
5. **Bugün / Geçmiş** ([today_screen.dart](../../lib/ui/today_screen.dart), [history_screen.dart](../../lib/ui/history_screen.dart)): dozu alındı/atlandı işaretleme, uyum oranı.
6. **Puan isteği** ([review.dart](../../lib/core/review.dart)): 3 ardışık tam günden sonra sistemin `SKStoreReviewController` penceresi; en fazla 3 kez, 120 gün arayla.
7. **Reklam** ([ads.dart](../../lib/core/ads.dart), [ad_banner.dart](../../lib/ui/ad_banner.dart)): alt menünün üstünde 320×50 banner; yalnızca onboarding'den sonra. AB/BK'da önce UMP izin formu. Doz işaretleme ya da alarm akışında reklam yoktur.

## 2. Bileşen adları

| Katman | Bileşen | Görevi |
|---|---|---|
| iOS native | `CallAlarms` (`CallAlarms.swift`) | AlarmKit: izin, alarm kurma, buton eylemlerini UserDefaults'a yazma |
| iOS native | `AppDelegate`, `SceneDelegate` | Flutter başlatma, `takeapill/call` method channel kaydı |
| iOS kaynak | `alarm.caf`, `PrivacyInfo.xcprivacy` | alarm sesi, gizlilik manifesti |
| Dart | `NotificationService` | izinler, senkron, alarm eylemlerini işleme |
| Dart | `planNotifications` / `PlannedNotification` | saf planlama |
| Dart | `AppDatabase` (drift): `Medications`, `Schedules`, `DoseEvents`, `Settings` | yerel depo |
| Dart | `DoseGenerator`, `RuleCodec` | kural → doz saatleri |
| Dart | `maybeRequestReview` | akıllı puan isteği |
| Dart | `gatherAdConsent`, `AdBanner` | reklam izni ve banner |
| Paketler | `flutter_local_notifications`, `timezone`, `flutter_timezone`, `drift`, `sqlite3_flutter_libs`, `in_app_review`, `google_mobile_ads`, `url_launcher`, `flutter_riverpod`, `go_router`, `liquid_glass_widgets`, `path_provider` | |
| Kanal | `takeapill/call` | Dart ↔ Swift köprüsü |

## 3. App Store Connect: beyan edilecekler

**App Privacy (Gizlilik Etiketleri)**: App Store Connect → App Privacy → Data Collection

"Do you or your third-party partners collect data from this app?" → **Yes**. Ad ve ilaç bilgisi cihazdan çıkmaz, ama AdMob SDK'sı veri toplar. Aşağıdaki yedi veri tipini seçin; listede olmayan hiçbir tipi işaretlemeyin. Bağlılık ve amaçlar SDK'nın kendi manifestinden (`GoogleMobileAds.framework/PrivacyInfo.xcprivacy`, SDK 13.11) alınmıştır.

| Veri tipi (ASC'deki adı) | Linked to user | Used for tracking | Amaçlar |
|---|---|---|---|
| Location → **Coarse Location** | Yes | **No** | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Identifiers → **Device ID** | Yes | **No** | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Usage Data → **Advertising Data** | Yes | **No** | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Usage Data → **Product Interaction** | Yes | **No** | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Diagnostics → **Performance Data** | No | **No** | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Diagnostics → **Other Diagnostic Data** | No | **No** | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Diagnostics → **Crash Data** | No | **No** | Analytics |

Sonuç etiketi: "Data Linked to You" + "Data Not Linked to You"; **"Data Used to Track You" boş.**

**Tracking: Hayır (karar verildi, 2026-11-09).**
- Uygulama ATT izni istemez, `NSUserTrackingUsageDescription` yoktur, `AppTrackingTransparency` çağrılmaz. ATT izni olmadan iOS IDFA'yı sıfır döndürür; reklamlar `nonPersonalizedAds: true` ile istenir ([ads.dart](../../lib/core/ads.dart)). Apple'ın tanımındaki takip (uygulama verisini başka şirketlerin verisiyle birleştirip hedefli reklam ya da veri simsarı) yapılmaz.
- Uygulamanın kendi `PrivacyInfo.xcprivacy` dosyası `NSPrivacyTracking=false` ve toplanan veri listesi boş kalır; SDK'nın topladıkları SDK'nın kendi manifestindedir.
- Xcode → Archive → **Generate Privacy Report** çıktısında SDK manifesti yüzünden Device ID yanında "tracking" görülebilir. Bu, SDK'nın ATT izni verilirse yapabileceklerini anlatır. ATT izni olmadığında iOS 17+ SDK'nın `NSPrivacyTrackingDomains` alan adlarına giden istekleri zaten engeller. ASC etiketi uygulamanın gerçek davranışına göre doldurulur.
- **Uygulamaya ATT penceresi ya da kişiselleştirilmiş reklam eklenirse bu karar geçersiz olur:** Device ID ve Advertising Data "Used for tracking: Yes" olur ve `NSUserTrackingUsageDescription` gerekir.

**Privacy Policy URL** (zorunlu): `https://hasankaankahraman.github.io/takeapill/privacy.html` (GitHub Pages, `main` / `docs`). Aynı sayfa uygulamada Ayarlar → Destek → "Gizlilik Politikası" satırından açılır (Guideline 5.1.1(i)). Sayfada veri sorumlusu ve iletişim adresi (`hasankaan.dev@gmail.com`), AdMob'un topladıkları, takip yapılmadığı, iOS/Android izinleri, yedekleme, saklama/silme ve KVKK/GDPR hakları yer alır. **Reklamlı politika yalnızca reklamlı sürüm incelemeye gönderilirken `main`'e girmeli** (Pages `main`'den yayınlanır).

**Guideline 5.1.3(i) (sağlık verisi reklamda kullanılamaz)**: İlaç adı, doz, program ve geçmiş reklam isteklerine eklenmez (`AdRequest` boş, anahtar kelime ya da içerik URL'si yok). Review Notes'ta bunu açıkça yazın (aşağıda).

**Guideline 5.1.1(ix) / 2.3.12 (açıklama)**: Mağaza açıklaması ve tanıtım metni reklam olduğunu söylüyor ([description.txt](metadata/tr/description.txt)); "reklamsız" ifadesi geçmemeli.

**Guideline 2.5.18 / 4.0 (reklam yerleşimi)**: Banner yalnızca alt menünün üstünde; onboarding, izin pencereleri, doz işaretleme butonları ve AlarmKit alarmı üzerinde reklam yoktur. Banner kazara dokunmaya yol açacak şekilde butonlara yapışık değildir.

**Avrupa (GDPR / DMA)**: AB/BK/İsviçre'de UMP izin formu açılır, Ayarlar → Destek → "Reklam gizlilik seçenekleri" satırı görünür. AdMob → Privacy & messaging → **European regulations** mesajını yayınlayın; yoksa bu bölgelerde form açılmaz ve reklam gelmez.

**Required Reason API** (`PrivacyInfo.xcprivacy`'de zaten var): `FileTimestamp` (C617.1) ve `DiskSpace` (E174.1), sqlite için. Sürüm yüklemeden önce `flutter build ipa` çıktısında uyarı olmadığını kontrol edin.

**Export Compliance**: `ITSAppUsesNonExemptEncryption = false`. Yalnızca standart sistem şifrelemesi kullanılıyor, belge istenmez.

**Age Rating**: Tıbbi/tedavi bilgisi sorusuna dikkat. Uygulama bilgi vermiyor, hatırlatıyor; "Medical/Treatment Information" için yalnızca kullanıcı girdisi olduğunu işaretleyin (sıklık "Infrequent/None" mantığıyla). 2025 anketindeki reklamla ilgili soruyu (uygulamada reklam var mı) **Evet** yanıtlayın; reklamlar uygulamanın yaş derecesine uygun olmalı (AdMob'da en yüksek reklam içerik derecesini "PG" yapın, aşağıda).

**Info.plist kullanım metni**: `NSAlarmKitUsageDescription` dolu ve gerçek amacı anlatıyor. AlarmKit izin penceresi bu metni gösterir.

**Review Notes** (Apple'a not): reklamlı sürüm için İngilizce metin [REVIEW_NOTES_ADS.md](REVIEW_NOTES_ADS.md) içinde. [REVIEW_REPLY.md](REVIEW_REPLY.md) yalnızca reklamsız 1.0.0 içindir.

**Kategori**: Health & Fitness ya da Medical. Medical seçerseniz Apple daha sıkı bakar (klinik doğruluk iddiası beklenir); iddiası olmayan bir hatırlatıcı için **Health & Fitness** önerilir.

## 4. Beyan ETMEMENİZ gerekenler (yanlış beyan riski)

- **İlaç verisini toplanmış gibi beyan etmeyin.** "Health & Fitness data" ve "User Content" cihazdan çıkmaz; bu etiketleri işaretlemek yanlış beyan olur. Reklam SDK'sının topladıkları yukarıdaki tabloda.
- **HealthKit kullanmıyorsunuz.** HealthKit yetkisi, `NSHealthShareUsageDescription` ya da "Health" capability'si eklemeyin, beyan etmeyin.
- **Tıbbi cihaz / SaMD iddiası yok.** Metinde "tedavi eder, teşhis eder, doz önerir, etkileşim kontrol eder" demeyin. Mevcut "ÖNEMLİ" bölümü (tıbbi tavsiye vermez) kalsın.
- **Kritik uyarı / Time Sensitive Notifications yetkisi yok.** `Critical Alerts` ve `Time Sensitive` entitlement'ı kullanılmıyor; başvurmayın, "sessiz modu aşar" cümlesi yalnızca AlarmKit alarmı için doğrudur, normal bildirim için değil.
- **Arka plan modu beyan etmeyin.** `UIBackgroundModes` yok; alarmlar sistem tarafından tetiklenir.
- **Sign in with Apple / hesap silme gerekmez.** Hesap sistemi yok.
- **Uygulama içi satın alma, abonelik beyan etmeyin.** Yok.
- **Kamera, konum, kişiler, mikrofon, Face ID izin metni eklemeyin.** Kullanılmıyor.
- **Sunucu / bulut yedekleme iddiası yok.** Yedekleme ve senkron özelliği yoktur; "cihazlar arası senkron" demeyin.

## 5. Yayın öncesi kontrol

Sıra önemli: iOS 1.0 (reklamsız) onaylanmadan `feat/admob-ads` `main`'e birleştirilmez ve bu daldan iOS derlemesi yüklenmez. Pages `main`'den yayınlandığı için birleştirme canlı gizlilik politikasını hemen reklamlı sürümle değiştirir.

**AdMob konsolu**
- Uygulamayı (iOS) ve banner birimini oluşturun; birimi `iosBannerUnit`'e ([ads.dart](../../lib/core/ads.dart)), App ID'yi `GADApplicationIdentifier`'a ([Info.plist](../../ios/Runner/Info.plist)) yazın. Şu an Google'ın test App ID'si durur ve birim boştur: release derlemesinde reklam gösterilmez.
- Uygulamayı App Store kaydına bağlayın (App settings → Link to app store); `app-ads.txt` doğrulaması bunun için gerekir.
- Privacy & messaging → **European regulations** (GDPR) mesajını yayınlayın. İsteğe bağlı: **US state regulations** mesajı (reklamlar zaten kişiselleştirilmemiş).
- Blocking controls → Sensitive categories: ilaç/eczane, takviye, kilo verme, doğum kontrolü/cinsel sağlık, kumar, alkol, flört kategorilerini engelleyin. Sağlık uygulamasında ilaç reklamı görünmesi hem yanıltıcı hem inceleme riski.
- Blocking controls → **Maximum ad content rating: PG**.
- `app-ads.txt`: [store/admob/README.md](../admob/README.md).

**App Store Connect**
- App Privacy etiketini yukarıdaki tabloyla güncelleyin ve **yayınlayın** (etiket sürümden bağımsızdır; reklamlı sürüm onaylanmadan önce değiştirmek mevcut reklamsız sürüm için yanlış beyan olur, bu yüzden reklamlı build'i incelemeye gönderirken güncelleyin).
- Yaş derecelendirme anketindeki reklam sorusunu güncelleyin.
- Review Notes'a [REVIEW_NOTES_ADS.md](REVIEW_NOTES_ADS.md) metnini yapıştırın.
- Marketing URL / Support URL: `https://hasankaankahraman.github.io/takeapill/` ve `.../support.html`. AdMob `app-ads.txt`'yi bu alan adının kökünde arar.
- `06-gizlilik` ekran görüntüleri "reklam yok" demeyecek şekilde yenilendi; yüklerken eskilerini değiştirin.

**Derleme**
- `flutter build ipa` sonrası Xcode Organizer → Generate Privacy Report çıktısını saklayın; SDK manifestleri ve Required Reason API'ler orada görünür.
- iOS 26 gerektiren AlarmKit kodu `#available(iOS 26.0, *)` arkasında; eski sürümde derleme sorunu çıkarmaz.
- Ekran görüntüleri [store/app-store/](./) altında (6.9" iPhone, 13" iPad).
