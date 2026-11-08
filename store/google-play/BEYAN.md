# Take a Pill: Google Play beyan rehberi

Paket: `com.takeapill.takeapill` · Tek dil: tr-TR · Sunucu, hesap, analitik yok · Reklam: Google AdMob (kişiselleştirilmemiş banner).

## 1. Uygulama nasıl çalışır

Tüm veri cihazda SQLite'ta (drift) durur. Hatırlatmalar yerel bildirimle yapılır. Tek ağ trafiği AdMob reklam SDK'sınındır; hatırlatmalar ona bağlı değildir.

1. **Onboarding** ([welcome_screen.dart](../../lib/ui/welcome_screen.dart)): ad (isteğe bağlı), yemek saatleri, hatırlatma şekli (bildirim ya da alarm), bildirim izni, "Alarmlar ve hatırlatıcılar" izni.
2. **İlaç ekleme** ([medication_form.dart](../../lib/ui/medication_form.dart)): ad, tür, doz, yemek ilişkisi, program, kür tarihleri.
3. **Planlama** ([notification_planner.dart](../../lib/core/notifications/notification_planner.dart)): 14 günlük pencere, en fazla 120 bildirim; her açılışta, değişiklikte ve bildirim butonunda yenilenir. Plan bitince "uygulamayı aç" hatırlatması kurulur.
4. **Doz saatinde** ([notification_service.dart](../../lib/core/notifications/notification_service.dart)):
   - Bildirim modu: `doses` kanalı, "Aldım / Ertele / Atla" butonları.
   - Alarm modu: `dose_alarms` kanalı; telefonun alarm sesi **alarm ses akışında** çalar (sessiz/titreşimde de duyulur), `FLAG_INSISTENT` ile tekrar eder, en fazla 5 dakika sonra susar. Kilitliyken tam ekran bildirim olarak açılır ([MainActivity.kt](../../android/app/src/main/kotlin/com/takeapill/takeapill/MainActivity.kt) kilit ekranı üstünde gösterir, ekranı yakar). Butonlar: "Ertele" / "Aç".
5. **Bugün / Geçmiş**: dozu işaretleme, uyum oranı.
6. **Puan isteği** ([review.dart](../../lib/core/review.dart)): Play In-App Review, 3 ardışık tam günden sonra, en fazla 3 kez.
7. **Reklam** ([ads.dart](../../lib/core/ads.dart), [ad_banner.dart](../../lib/ui/ad_banner.dart)): alt menünün üstünde 320×50 banner; yalnızca onboarding'den sonra. AB/BK'da önce UMP izin formu. Alarm uygulamayı kilit ekranı üstünde açtığında banner kaldırılır (Play "Lockscreen Monetization" kuralı).

## 2. Bileşen adları

| Katman | Bileşen | Görevi |
|---|---|---|
| Android | `MainActivity` | Flutter aktivitesi; alarm bildiriminden açılınca `setShowWhenLocked` + `setTurnScreenOn` |
| Manifest | `ScheduledNotificationReceiver` | zamanlanmış bildirimi tetikler |
| Manifest | `ScheduledNotificationBootReceiver` | yeniden başlatma / güncelleme sonrası alarmları yeniden kurar (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`) |
| Manifest | `ActionBroadcastReceiver` | bildirim butonları (Aldım/Ertele/Atla) |
| Kanallar | `doses`, `dose_alarms` | bildirim / alarm (eski `calls`, `call_alarms` açılışta silinir) |
| Dart | `NotificationService`, `planNotifications`, `AppDatabase` (`Medications`, `Schedules`, `DoseEvents`, `Settings`), `DoseGenerator`, `RuleCodec`, `maybeRequestReview` | iOS rehberindeki ile aynı |
| Paketler | `flutter_local_notifications`, `timezone`, `flutter_timezone`, `drift`, `sqlite3_flutter_libs`, `in_app_review`, `google_mobile_ads`, `url_launcher` | |

**İzinler** ([AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml)): `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `VIBRATE`, `USE_FULL_SCREEN_INTENT`. AdMob SDK'sı birleştirilmiş manifeste `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE` ekler. `AD_ID` ve `ACCESS_ADSERVICES_*` izinleri manifestte bilerek kaldırılmıştır.

## 3. Play Console: beyan edilecekler

### Data safety (Uygulama içeriği → Veri güvenliği)

Kaynak: Google'ın [AdMob Play veri beyanı sayfası](https://developers.google.com/admob/android/privacy/play-data-disclosure) (SDK 25.x): IP adresi, uygulama etkileşimleri, teşhis bilgisi ve cihaz kimlikleri "otomatik olarak toplanır ve paylaşılır", amaç reklam, analiz ve sahtecilik önleme. Google "paylaşılır" dediği için aşağıda **Shared: Yes** seçilir (temkinli ve Google'ın beyanıyla tutarlı).

**Genel sorular**
| Soru | Yanıt |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (SDK trafiği TLS) |
| Do you provide a way for users to request that their data is deleted? | **No**. Uygulamanın kendi verisi yalnızca cihazdadır ve uygulama silinince silinir; AdMob'un topladığı veriyi geliştirici silemez, Google'ın kendi araçlarıyla yönetilir. Hesap olmadığı için silme URL'si zorunlu değildir. |
| Hesap oluşturma | Uygulamada hesap yok |

**Veri tipleri** (yalnızca bunları işaretleyin)
| Kategori → Tip | Collected | Shared | Ephemeral | Required / Optional | Amaçlar |
|---|---|---|---|---|---|
| Location → **Approximate location** (IP'den) | Yes | Yes | No | Required | Advertising or marketing, Analytics, Fraud prevention, security, and compliance |
| App activity → **App interactions** | Yes | Yes | No | Required | Advertising or marketing, Analytics, Fraud prevention, security, and compliance |
| App info and performance → **Crash logs** | Yes | Yes | No | Required | Advertising or marketing, Analytics, Fraud prevention, security, and compliance |
| App info and performance → **Diagnostics** | Yes | Yes | No | Required | Advertising or marketing, Analytics, Fraud prevention, security, and compliance |
| Device or other IDs → **Device or other IDs** (app set ID; reklam kimliği izni kaldırıldı) | Yes | Yes | No | Required | Advertising or marketing, Analytics, Fraud prevention, security, and compliance |

"Required": SDK bu verileri kullanıcının kapatabileceği bir ayar olmadan toplar (AB'deki UMP izni yalnızca kişiselleştirmeyi ve depolamayı etkiler).

**İşaretlenmeyecekler**: Health and fitness, Personal info (ad), Messages, Photos, Files, Contacts, Calendar, Precise location, Financial info, Web browsing. İlaç verisi, ad ve geçmiş cihazdan çıkmaz; Android bulut yedeği de kapalı ([data_extraction_rules.xml](../../android/app/src/main/res/xml/data_extraction_rules.xml)).

### Diğer Uygulama içeriği formları
| Form | Yanıt |
|---|---|
| **Privacy policy** | `https://hasankaankahraman.github.io/takeapill/privacy.html`. Sayfa Android izinlerini, AdMob'u, veri sorumlusunu ve iletişim adresini içerir; uygulamada Ayarlar → Destek'ten de açılır. |
| **Ads** | Contains ads: **Yes** |
| **Advertising ID** | Does your app use advertising ID? **No**. `AD_ID` izni birleştirilmiş manifestten `tools:node="remove"` ile kaldırılmıştır; yüklemeden önce `aapt dump permissions` ya da Play Console → App bundle explorer → Permissions'ta görünmediğini doğrulayın. Bu yanıtla izin uyuşmazsa Play yüklemeyi reddeder. |
| **Target audience and content** | Yaş grupları: **18 ve üzeri**. "Çocukların ilgisini çekebilir mi?": **Hayır**. Families politikası kapsamı dışında. |
| **Content rating (IARC)** | Kategori: Utility/Productivity ya da Health. Şiddet, cinsellik, kumar, kullanıcı etkileşimi/sohbet, konum paylaşımı, dijital satın alma: **Hayır**. Reklam varlığı Ads formunda beyan edilir. |
| **Health apps** | Kategori: ilaç ve tedavi yönetimi (medication reminder). Tıbbi cihaz / klinik karar desteği: **Hayır**. Sağlık verisi cihazda kalır, reklamda kullanılmaz. |
| **Financial features / Government / News / COVID-19** | Hayır / uygulanamaz |

### Özel izin beyanları (Uygulama içeriği → Hassas izinler)
1. **Exact alarm (`SCHEDULE_EXACT_ALARM`)**: Kullanım amacı "ilaç saatinde zamanında hatırlatma; gecikme sağlığı etkileyebilir". Bu izin kullanıcıya bağlı (Android 14+ varsayılan kapalı); uygulama izin yoksa esnek moda düşer ve Ayarlar'da uyarır. `USE_EXACT_ALARM` kullanılmaz, bu yüzden "alarm/takvim uygulaması" şartı yoktur.
2. **Full-screen intent (`USE_FULL_SCREEN_INTENT`)**: `main`'de bilerek kullanılıyor (`c8efd2e`): kullanıcı "Alarm" modunu seçtiğinde ilaç alarmı kilitliyken saat alarmı gibi tam ekran açılır; izin ekranına gitmeden önce nedeni bir pencereyle anlatılır ([permission_prompts.dart](../../lib/ui/permission_prompts.dart)). Beyan seçeneği: **Alarm** ("kullanıcının kurduğu alarmlar"). Beyan metni: "Users set their own medication alarms. In Alarm mode, a due dose rings like a clock alarm and opens full screen over the lock screen so it is not missed; notification mode does not use full-screen intents." Play reddederse izin Android 14+'ta otomatik iptal edilir, alarm yüksek öncelikli sesli bildirim olarak çalışmaya devam eder.
3. **Foreground service, arka plan konumu, SMS, kişiler, depolama**: uygulama kullanmaz. `FOREGROUND_SERVICE` ve `WAKE_LOCK` AdMob/Play Services bağımlılıklarından gelir; Console foreground service türü sorarsa uygulamanın kendi servisi olmadığını yazın.

### Reklam politikası (Developer Program Policies → Ads)
- **Lockscreen monetization**: Alarm uygulamayı kilit ekranı üstünde açtığında banner kaldırılır ([ad_banner.dart](../../lib/ui/ad_banner.dart)). Gerçek cihazda doğrulayın.
- **Disruptive / unexpected ads**: Yalnızca sabit banner; geçiş (interstitial), ödüllü ya da açılış reklamı yok. Onboarding, izin pencereleri, bildirimler ve alarm ekranında reklam yok.
- **Ads in health apps**: AdMob'da hassas kategorileri ve en yüksek içerik derecesini kısıtlayın (bkz. §5).
- **Store listing**: Açıklama reklam içerdiğini söylüyor ([full_description.txt](metadata/tr-TR/full_description.txt)); "reklamsız" ifadesi geçmemeli.

## 4. Beyan ETMEMENİZ gerekenler (yanlış beyan riski)

- **İlaç verisini toplanmış gibi beyan etmeyin.** "Health info" ve "Personal info (ad)" cihazda kalır. Reklam SDK'sının topladıkları yukarıdaki Data safety bölümünde.
- **`USE_EXACT_ALARM` ekleme ve beyan etmeyin.** Bu izin yalnızca ana işlevi alarm saati/takvim olan uygulamalara yasak olmadan verilir; "ilaç hatırlatıcı" bu şartı garanti etmez ve politika ihlaline yol açabilir. Mevcut `SCHEDULE_EXACT_ALARM` yeterli.
- **Tıbbi cihaz, teşhis, tedavi, doz önerisi, ilaç etkileşimi iddiası yok.** Health apps formunda "tıbbi cihaz / klinik karar destek" işaretlemeyin; mağaza metninde de kullanmayın.
- **Health Connect kullanmıyorsunuz.** İzin, Health Connect beyanı ya da Health Connect Data safety satırı eklemeyin.
- **Arka plan / foreground service özelliği beyan etmeyin.** Uygulamanın kendi kullanımı yok; `WAKE_LOCK` ve `FOREGROUND_SERVICE` reklam SDK'sının bağımlılıklarından gelir. Console soru sorarsa buna göre yanıtlayın.
- **Uygulama içi satın alma, abonelik, hesap silme akışı beyan etmeyin.** Yok; hesap olmadığı için "hesap silme URL'si" gerekmez.
- **Bulut yedekleme / cihazlar arası senkron iddia etmeyin.** Yok. Android otomatik bulut yedeği uygulama verisini dışarıda bırakır ([data_extraction_rules.xml](../../android/app/src/main/res/xml/data_extraction_rules.xml), Android 11 ve öncesi için `fullBackupContent="false"`); kullanıcının başlattığı cihazdan cihaza aktarım açıktır.
- **"Rahatsız Etmeyin'i aşar" garantisi vermeyin.** Alarm akışı DND'de varsayılan olarak çalar, ama kullanıcı "alarmlara izin ver"i kapatmış olabilir.

## 5. Riskler ve yayın öncesi kontrol

Sıra: Google Play reklamlı sürümü ilk alır, ama Pages `main`'den yayınlandığı için `feat/admob-ads` iOS 1.0 (reklamsız) onaylanana kadar `main`'e birleştirilmez. Play'e reklamlı sürümü gönderirken canlı gizlilik politikası reklamlı metni göstermeli; yani önce iOS onayı, sonra birleştirme, sonra Play gönderimi.

**AdMob konsolu**
- Android uygulamasını ve banner birimini oluşturun; birimi `androidBannerUnit`'e ([ads.dart](../../lib/core/ads.dart)), App ID'yi `APPLICATION_ID` meta-data'sına ([AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml)) yazın. Şu an Google'ın test App ID'si durur ve birim boştur: release derlemesinde reklam gösterilmez.
- Uygulamayı Play kaydına bağlayın; `app-ads.txt` için [store/admob/README.md](../admob/README.md).
- Privacy & messaging → **European regulations** mesajını yayınlayın (yoksa AB/BK'da izin formu açılmaz, reklam da gelmez).
- Blocking controls → Sensitive categories: ilaç/eczane, takviye, kilo verme, doğum kontrolü/cinsel sağlık, kumar, alkol, flört. Maximum ad content rating: **PG**.

**Play Console**
- Store listing → Contact details: e-posta `hasankaan.dev@gmail.com`, web sitesi `https://hasankaankahraman.github.io/takeapill/` (AdMob `app-ads.txt`'yi bu alan adının kökünde arar).
- §3'teki Data safety, Ads, Advertising ID, Target audience, Content rating, Health apps ve Full-screen intent formlarını aynı sürümle gönderin.

**Derleme ve cihaz testi**
- Release imzası `android/key.properties` yoksa debug anahtarıyla atılır; Play'e yüklemeden önce gerçek keystore tanımlayın.
- Birleştirilmiş manifestte `com.google.android.gms.permission.AD_ID` olmadığını doğrulayın (Advertising ID = No yanıtı buna bağlı).
- Gerçek Android cihazda: alarm modunda kilit ekranında alarm açılınca banner görünmemeli; Android 14+ ilk kurulumda "Alarmlar ve hatırlatıcılar" ve tam ekran izinleri kapalı olabilir (Ayarlar → Uygulamalar → Take a Pill).
- Ekran görüntüleri ve grafikler [store/google-play/](./) altında hazır.
