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

**App Privacy (Gizlilik Etiketleri)**
- **"Data Not Collected" artık seçilemez.** Ad ve ilaç bilgisi cihazdan çıkmaz, ama AdMob SDK'sı veri toplar. SDK'nın kendi manifestine (`GoogleMobileAds.framework/PrivacyInfo.xcprivacy`, SDK 13.11) göre:

| Veri tipi | Kullanıcıya bağlı | Takip | Amaç |
|---|---|---|---|
| Coarse Location | Evet | Hayır | Third-Party Advertising, Developer Advertising, Analytics |
| Device ID | Evet | **Evet** (bkz. aşağıda) | Third-Party Advertising, Developer Advertising, Analytics |
| Advertising Data | Evet | Hayır | Third-Party Advertising, Developer Advertising, Analytics |
| Product Interaction | Evet | Hayır | Third-Party Advertising, Developer Advertising, Analytics |
| Performance Data | Hayır | Hayır | Third-Party Advertising, Developer Advertising, Analytics |
| Other Diagnostic Data | Hayır | Hayır | Third-Party Advertising, Developer Advertising, Analytics |
| Crash Data | Hayır | Hayır | Analytics |

- **Tracking: açık karar.** Uygulama ATT izni istemez, `NSUserTrackingUsageDescription` yoktur, reklamlar kişiselleştirilmez; bu yüzden IDFA'ya erişilmez ve uygulamanın kendi `PrivacyInfo.xcprivacy` dosyası `NSPrivacyTracking=false` kalır. Ancak SDK manifesti Device ID'yi "takip" olarak işaretliyor. Yüklemeden önce Xcode'un Privacy Report çıktısına ve Google'ın [veri beyanı sayfasına](https://developers.google.com/admob/ios/privacy/data-disclosure) bakıp son kararı verin. Takip beyan edilirse Apple ATT penceresi de bekler.
- Privacy Policy URL zorunlu: `https://hasankaankahraman.github.io/takeapill/privacy.html` (GitHub Pages, `main` / `docs`). Aynı sayfa uygulamada Ayarlar > Destek > "Gizlilik Politikası" satırından açılır (Guideline 5.1.1(i)). Göndermeden önce sayfanın açıldığını doğrulayın.
- Yaş derecelendirme anketinde "uygulamada reklam var" işaretleyin.

**Required Reason API** (`PrivacyInfo.xcprivacy`'de zaten var): `FileTimestamp` (C617.1) ve `DiskSpace` (E174.1), sqlite için. Sürüm yüklemeden önce `flutter build ipa` çıktısında uyarı olmadığını kontrol edin.

**Export Compliance**: `ITSAppUsesNonExemptEncryption = false`. Yalnızca standart sistem şifrelemesi kullanılıyor, belge istenmez.

**Age Rating**: Tıbbi/tedavi bilgisi sorusuna dikkat. Uygulama bilgi vermiyor, hatırlatıyor; "Medical/Treatment Information" için yalnızca kullanıcı girdisi olduğunu işaretleyin (sıklık "Infrequent/None" mantığıyla). Yeni 2025 yaş derecelendirme anketini doldurun.

**Info.plist kullanım metni**: `NSAlarmKitUsageDescription` dolu ve gerçek amacı anlatıyor. AlarmKit izin penceresi bu metni gösterir.

**Review Notes** (Apple'a not):
- "Alarm modu iOS 26+ cihazda AlarmKit kullanır; kilit ekranında test için onboarding'de 'Alarm' seçin, bir ilacı 2 dakika sonrasına kurun."
- "Hesap yok, giriş gerekmez."
- "Uygulama Google AdMob ile kişiselleştirilmemiş banner gösterir; ATT istenmez, ilaç bilgisi reklam ağına gönderilmez."
- Bildirim izni onboarding'de açıklamayla istenir.

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

- **AdMob:** Uygulamayı ve banner birimini oluşturun; birimi `iosBannerUnit`'e ([ads.dart](../../lib/core/ads.dart)), App ID'yi `GADApplicationIdentifier`'a ([Info.plist](../../ios/Runner/Info.plist)) yazın. Şu an Google'ın test App ID'si durur ve birim boştur: release derlemesinde reklam gösterilmez.
- **AdMob konsolu:** GDPR mesajını yayınlayın (yoksa AB/BK'da izin formu açılmaz, reklam da gelmez); ilaç, takviye ve doğum kontrolü gibi hassas reklam kategorilerini engelleyin.
- [REVIEW_REPLY.md](REVIEW_REPLY.md) yalnızca reklamsız 1.0.0 (build 1) için geçerlidir; reklamlı build'de "advertising: none" diyen 4. maddesi yanlış olur.
- `06-gizlilik` ekran görüntüleri "reklam yok" demeyecek şekilde yenilendi; yüklerken eskilerini değiştirin.
- `appStoreId` ([review.dart](../../lib/core/review.dart)) hâlâ boş: Apple ID alınınca doldurun, yoksa "Uygulamayı değerlendir" satırı iOS'ta gizli kalır.
- iOS 26 gerektiren AlarmKit kodu `#available(iOS 26.0, *)` arkasında; eski sürümde derleme sorunu çıkarmaz.
- Ekran görüntüleri [store/app-store/](./) altında (6.9" iPhone, 13" iPad).
