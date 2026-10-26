# Take a Pill: App Store beyan rehberi

Bundle ID: `com.takeapill.takeapill` · Tek dil: Türkçe · Sunucu, hesap, reklam, analitik yok.

## 1. Uygulama nasıl çalışır

Tüm veri cihazda SQLite'ta (drift) durur. Hatırlatmalar yerel bildirim ya da alarmla yapılır. Ağ isteği yoktur.

1. **Karşılama / onboarding** ([welcome_screen.dart](../../lib/ui/welcome_screen.dart)): ad (isteğe bağlı), yemek saatleri, hatırlatma şekli (bildirim ya da alarm), izinler.
2. **İlaç ekleme** ([medication_form.dart](../../lib/ui/medication_form.dart)): ad, tür, doz, yemekle ilişki, program (günlük, X saatte bir, gerektiğinde), başlangıç/bitiş tarihi.
3. **Planlama** ([notification_planner.dart](../../lib/core/notifications/notification_planner.dart)): önümüzdeki 14 gün için saf bir planlayıcı "önce / zamanında / tekrar (Aldın mı?) / erteleme" bildirimlerini üretir. iOS en fazla 64 bekleyen bildirime izin verdiği için en yakın 60 tanesi kurulur. Plan her açılışta ve her değişiklikte yenilenir.
4. **Doz saatinde** ([notification_service.dart](../../lib/core/notifications/notification_service.dart)):
   - Bildirim modu: "Aldım / Ertele / Atla" butonlu yerel bildirim.
   - Alarm modu, iOS 26+: AlarmKit alarmı ([CallAlarms.swift](../../ios/Runner/CallAlarms.swift)); kilit ekranı ve Dynamic Island, "Ertele / Aç".
   - Alarm modu, iOS 26 öncesi ya da alarm izni yok: `alarm.caf` sesli normal bildirim.
5. **Bugün / Geçmiş** ([today_screen.dart](../../lib/ui/today_screen.dart), [history_screen.dart](../../lib/ui/history_screen.dart)): dozu alındı/atlandı işaretleme, uyum oranı.
6. **Puan isteği** ([review.dart](../../lib/core/review.dart)): 3 ardışık tam günden sonra sistemin `SKStoreReviewController` penceresi; en fazla 3 kez, 120 gün arayla.

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
| Paketler | `flutter_local_notifications`, `timezone`, `flutter_timezone`, `drift`, `sqlite3_flutter_libs`, `in_app_review`, `flutter_riverpod`, `go_router`, `liquid_glass_widgets`, `path_provider` | |
| Kanal | `takeapill/call` | Dart ↔ Swift köprüsü |

## 3. App Store Connect: beyan edilecekler

**App Privacy (Gizlilik Etiketleri)**
- "Data Not Collected" (Veri Toplanmıyor). Ad ve ilaç bilgisi cihazdan çıkmaz, bu yüzden "toplanan veri" sayılmaz.
- Tracking: Hayır. `PrivacyInfo.xcprivacy` zaten `NSPrivacyTracking=false`, toplanan veri tipi boş.
- Privacy Policy URL zorunlu: "veri toplamıyoruz, hepsi cihazda" diyen bir sayfa yayınlayın.

**Required Reason API** (`PrivacyInfo.xcprivacy`'de zaten var): `FileTimestamp` (C617.1) ve `DiskSpace` (E174.1), sqlite için. Sürüm yüklemeden önce `flutter build ipa` çıktısında uyarı olmadığını kontrol edin.

**Export Compliance**: `ITSAppUsesNonExemptEncryption = false`. Yalnızca standart sistem şifrelemesi kullanılıyor, belge istenmez.

**Age Rating**: Tıbbi/tedavi bilgisi sorusuna dikkat. Uygulama bilgi vermiyor, hatırlatıyor; "Medical/Treatment Information" için yalnızca kullanıcı girdisi olduğunu işaretleyin (sıklık "Infrequent/None" mantığıyla). Yeni 2025 yaş derecelendirme anketini doldurun.

**Info.plist kullanım metni**: `NSAlarmKitUsageDescription` dolu ve gerçek amacı anlatıyor. AlarmKit izin penceresi bu metni gösterir.

**Review Notes** (Apple'a not):
- "Alarm modu iOS 26+ cihazda AlarmKit kullanır; kilit ekranında test için onboarding'de 'Alarm' seçin, bir ilacı 2 dakika sonrasına kurun."
- "Hesap yok, giriş gerekmez."
- Bildirim izni onboarding'de açıklamayla istenir.

**Kategori**: Health & Fitness ya da Medical. Medical seçerseniz Apple daha sıkı bakar (klinik doğruluk iddiası beklenir); iddiası olmayan bir hatırlatıcı için **Health & Fitness** önerilir.

## 4. Beyan ETMEMENİZ gerekenler (yanlış beyan riski)

- **Veri toplama / izleme beyan etmeyin.** Veri toplanmadığı için "Health & Fitness data", "User Content", "Identifiers" gibi etiketleri işaretlemek yanlış beyan olur.
- **HealthKit kullanmıyorsunuz.** HealthKit yetkisi, `NSHealthShareUsageDescription` ya da "Health" capability'si eklemeyin, beyan etmeyin.
- **Tıbbi cihaz / SaMD iddiası yok.** Metinde "tedavi eder, teşhis eder, doz önerir, etkileşim kontrol eder" demeyin. Mevcut "ÖNEMLİ" bölümü (tıbbi tavsiye vermez) kalsın.
- **Kritik uyarı / Time Sensitive Notifications yetkisi yok.** `Critical Alerts` ve `Time Sensitive` entitlement'ı kullanılmıyor; başvurmayın, "sessiz modu aşar" cümlesi yalnızca AlarmKit alarmı için doğrudur, normal bildirim için değil.
- **Arka plan modu beyan etmeyin.** `UIBackgroundModes` yok; alarmlar sistem tarafından tetiklenir.
- **Sign in with Apple / hesap silme gerekmez.** Hesap sistemi yok.
- **Reklam, uygulama içi satın alma, abonelik beyan etmeyin.** Yok.
- **Kamera, konum, kişiler, mikrofon, Face ID izin metni eklemeyin.** Kullanılmıyor.
- **Sunucu / bulut yedekleme iddiası yok.** Yedekleme ve senkron özelliği yoktur; "cihazlar arası senkron" demeyin.

## 5. Yayın öncesi kontrol

- `appStoreId` ([review.dart](../../lib/core/review.dart)) hâlâ boş: Apple ID alınınca doldurun, yoksa "Uygulamayı değerlendir" satırı iOS'ta gizli kalır.
- iOS 26 gerektiren AlarmKit kodu `#available(iOS 26.0, *)` arkasında; eski sürümde derleme sorunu çıkarmaz.
- Ekran görüntüleri [store/app-store/](./) altında (6.9" iPhone, 13" iPad).
