# Take a Pill: Google Play beyan rehberi

Paket: `com.takeapill.takeapill` · Tek dil: tr-TR · Sunucu, hesap, reklam, analitik yok.

## 1. Uygulama nasıl çalışır

Tüm veri cihazda SQLite'ta (drift) durur. Hatırlatmalar yerel bildirimle yapılır; ağ isteği yoktur.

1. **Onboarding** ([welcome_screen.dart](../../lib/ui/welcome_screen.dart)): ad (isteğe bağlı), yemek saatleri, hatırlatma şekli (bildirim ya da alarm), bildirim izni, "Alarmlar ve hatırlatıcılar" izni.
2. **İlaç ekleme** ([medication_form.dart](../../lib/ui/medication_form.dart)): ad, tür, doz, yemek ilişkisi, program, kür tarihleri.
3. **Planlama** ([notification_planner.dart](../../lib/core/notifications/notification_planner.dart)): 14 günlük pencere, en fazla 120 bildirim; her açılışta, değişiklikte ve bildirim butonunda yenilenir. Plan bitince "uygulamayı aç" hatırlatması kurulur.
4. **Doz saatinde** ([notification_service.dart](../../lib/core/notifications/notification_service.dart)):
   - Bildirim modu: `doses` kanalı, "Aldım / Ertele / Atla" butonları.
   - Alarm modu: `dose_alarms` kanalı; telefonun alarm sesi **alarm ses akışında** çalar (sessiz/titreşimde de duyulur), `FLAG_INSISTENT` ile tekrar eder, en fazla 5 dakika sonra susar. Kilitliyken tam ekran bildirim olarak açılır ([MainActivity.kt](../../android/app/src/main/kotlin/com/takeapill/takeapill/MainActivity.kt) kilit ekranı üstünde gösterir, ekranı yakar). Butonlar: "Ertele" / "Aç".
5. **Bugün / Geçmiş**: dozu işaretleme, uyum oranı.
6. **Puan isteği** ([review.dart](../../lib/core/review.dart)): Play In-App Review, 3 ardışık tam günden sonra, en fazla 3 kez.

## 2. Bileşen adları

| Katman | Bileşen | Görevi |
|---|---|---|
| Android | `MainActivity` | Flutter aktivitesi; alarm bildiriminden açılınca `setShowWhenLocked` + `setTurnScreenOn` |
| Manifest | `ScheduledNotificationReceiver` | zamanlanmış bildirimi tetikler |
| Manifest | `ScheduledNotificationBootReceiver` | yeniden başlatma / güncelleme sonrası alarmları yeniden kurar (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`) |
| Manifest | `ActionBroadcastReceiver` | bildirim butonları (Aldım/Ertele/Atla) |
| Kanallar | `doses`, `dose_alarms` | bildirim / alarm (eski `calls`, `call_alarms` açılışta silinir) |
| Dart | `NotificationService`, `planNotifications`, `AppDatabase` (`Medications`, `Schedules`, `DoseEvents`, `Settings`), `DoseGenerator`, `RuleCodec`, `maybeRequestReview` | iOS rehberindeki ile aynı |
| Paketler | `flutter_local_notifications`, `timezone`, `flutter_timezone`, `drift`, `sqlite3_flutter_libs`, `in_app_review` | |

**İzinler** ([AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml)): `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `VIBRATE`, `USE_FULL_SCREEN_INTENT`. İnternet izni yok.

## 3. Play Console: beyan edilecekler

**Data safety**
- "Veri toplamıyor ve paylaşmıyor." Tüm veri cihazda, sunucuya gitmiyor.
- Şifreleme aktarımda: uygulama ağ kullanmadığı için "uygulanmaz".
- Veri silme: hesap yok; uygulama silinince veri silinir.
- Gizlilik politikası URL'si zorunlu.

**App content**
- **Health apps / Sağlık uygulamaları beyanı**: uygulama sağlık kategorisinde (ilaç hatırlatıcı). Formda "Medication & Treatment" benzeri seçenekte, "ilaç hatırlatma/takip", tıbbi cihaz **değil**, klinik özellik yok olarak işaretleyin.
- **Reklam**: yok. **Hedef kitle**: 18+ (çocuklara yönelik değil).
- **Hükümet / finans / haber uygulaması**: hayır.

**Özel izin beyanları (Policy → App content)**
1. **Exact alarm (`SCHEDULE_EXACT_ALARM`)**: Kullanım amacı "ilaç saatinde zamanında hatırlatma; gecikme sağlığı etkileyebilir". Bu izin kullanıcıya bağlı (Android 14+ varsayılan kapalı); uygulama izin yoksa esnek moda düşer ve uyarır. `USE_EXACT_ALARM` kullanmıyoruz; bu yüzden daha sıkı "alarm/takvim uygulaması" şartı yok.
2. **Full-screen intent (`USE_FULL_SCREEN_INTENT`)**: Play, bu izni yalnızca **alarm veya arama** gibi çekirdek işlevi tam ekran gerektiren uygulamalara verir. Android 14+ için Console'da beyan istenir ve uygun görülmezse izin otomatik iptal edilir. Beyan metni: "Kullanıcının kendi kurduğu ilaç alarmı, telefon kilitliyken alarm saati gibi tam ekran açılır; kullanıcı bunu onboarding'de 'Alarm' modunu seçerek açar." **Bu beyan reddedilebilir (aşağıda risk bölümü).**
3. **Foreground service, arka plan konumu, SMS, kişiler vb.**: kullanılmıyor, form açmayın.

**Foreground service**: yok. Alarm sesi bildirim kanalından çalar.

## 4. Beyan ETMEMENİZ gerekenler (yanlış beyan riski)

- **Veri toplama beyan etmeyin.** "Health info", "Personal info (ad)", "App activity" gibi satırları toplanıyor diye işaretlemek yanlış olur; hepsi cihazda kalır.
- **`USE_EXACT_ALARM` ekleme ve beyan etmeyin.** Bu izin yalnızca ana işlevi alarm saati/takvim olan uygulamalara yasak olmadan verilir; "ilaç hatırlatıcı" bu şartı garanti etmez ve politika ihlaline yol açabilir. Mevcut `SCHEDULE_EXACT_ALARM` yeterli.
- **Tıbbi cihaz, teşhis, tedavi, doz önerisi, ilaç etkileşimi iddiası yok.** Health apps formunda "tıbbi cihaz / klinik karar destek" işaretlemeyin; mağaza metninde de kullanmayın.
- **Health Connect kullanmıyorsunuz.** İzin, Health Connect beyanı ya da Health Connect Data safety satırı eklemeyin.
- **Arka plan / foreground service / `WAKE_LOCK` beyan etmeyin.** Yok.
- **Reklam, uygulama içi satın alma, abonelik, hesap silme akışı beyan etmeyin.** Yok; hesap olmadığı için "hesap silme URL'si" gerekmez.
- **Bulut yedekleme / cihazlar arası senkron iddia etmeyin.** Yok. (Manifest'te `allowBackup` kapatılmadıysa Android otomatik yedeği veritabanını Google Drive'a yedekleyebilir; bkz. aşağıda.)
- **"Rahatsız Etmeyin'i aşar" garantisi vermeyin.** Alarm akışı DND'de varsayılan olarak çalar, ama kullanıcı "alarmlara izin ver"i kapatmış olabilir.

## 5. Riskler ve yayın öncesi kontrol

- **USE_FULL_SCREEN_INTENT çelişkisi.** Önceki commit (`ced57ca`) bu izni Play politikası gereği bilerek kaldırmıştı; bu çalışmada alarmın kilit ekranında iOS gibi açılması için geri eklendi. Seçenekler: (a) izni tutup Console beyanını yukarıdaki gibi yapmak ve reddedilirse geri almak, (b) izni kaldırıp alarmı yalnızca yüksek öncelikli, sesli bildirim olarak bırakmak. Karar sizin; (b) en düşük inceleme riskidir.
- [README.md](../../README.md) hâlâ "60 sn sonra susar, tam ekran alarm yok" diyor; karar verince güncelleyin.
- `android:allowBackup` manifestte açıkça belirtilmemiş (varsayılan true). İlaç verisinin Google yedeğine girmesini istemiyorsanız `android:allowBackup="false"` ekleyin; mevcut "veri yalnızca cihazda" metniyle tutarlı kalmak için önerilir.
- Release imzası `android/key.properties` yoksa debug anahtarıyla atılır; Play'e yüklemeden önce gerçek keystore tanımlayın.
- Android 14+ ilk kurulumda "Alarmlar ve hatırlatıcılar" ve (reddedilmemişse) tam ekran izni kapalı olabilir; test cihazında Ayarlar → Uygulamalar → Take a Pill'den kontrol edin.
- Ekran görüntüleri ve grafikler [store/google-play/](./) altında hazır.
