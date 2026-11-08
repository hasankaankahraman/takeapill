# AdMob: durum ve yapılacaklar

Son güncelleme: 9 Kasım 2026 · Dal: `feat/admob-ads` · Commit'ler: `dc2387a` (main birleştirmesi), `f7e11bd` (gizlilik ve beyanlar)

Reklamlı sürümün gizlilik ve mağaza beyan tarafının nerede durduğunu, hangi kararların verildiğini ve geriye ne kaldığını tek yerde tutar. Ayrıntılı form yanıtları beyan rehberlerinde: [App Store](../app-store/BEYAN.md), [Google Play](../google-play/BEYAN.md).

## Yayın sırası (değişmez kural)

1. iOS 1.0 (reklamsız) App Review'dan onay alır. 9 Kasım 2026 itibarıyla build 2 hızlandırılmış incelemede.
2. Ancak ondan sonra `feat/admob-ads` `main`'e birleştirilir.
3. Sonra Google Play'e reklamlı sürüm gönderilir (Play reklamlı sürümü ilk alır), ardından iOS reklamlı sürümü.

**Neden:** GitHub Pages `main` / `docs`'tan yayınlanıyor. Dal erken birleşirse canlı gizlilik politikası reklamlı metne döner; oysa Apple'a "reklam yok" ve "Data Not Collected" denildi.

## Verilen kararlar

| Konu | Karar |
|---|---|
| iOS takip (ATT) | ATT yok, `NSUserTrackingUsageDescription` yok, reklamlar kişiselleştirilmemiş. App Store etiketinde 7 veri tipinin hepsi **Used for tracking: No**. ATT ya da kişiselleştirilmiş reklam eklenirse bu karar geçersiz olur. |
| Veri sorumlusu / iletişim | Hasan Kaan Kahraman, `hasankaan.dev@gmail.com` (gizlilik politikası, destek sayfası, mağaza kayıtları) |
| Android reklam kimliği | `AD_ID` ve `ACCESS_ADSERVICES_*` izinleri manifestten kaldırıldı; Play'de "Advertising ID: No" |
| Android yedekleme | Google bulut yedeği uygulama verisini almaz ([data_extraction_rules.xml](../../android/app/src/main/res/xml/data_extraction_rules.xml), `fullBackupContent="false"`). Cihazdan cihaza aktarım **bilerek açık**: kapatılırsa telefon değiştiren kullanıcı ilaç listesini kaybeder. |
| Play veri silme sorusu | **No**: uygulamanın kendi verisi yalnızca cihazda, AdMob'un topladığını geliştirici silemez. |
| Play "Shared" | **Yes**: Google'ın kendi beyan sayfası "toplanır ve paylaşılır" diyor. |
| Play hedef kitle | 18+, çocuklara yönelik değil |
| Tam ekran bildirim | `main`'de bilerek kullanılıyor; Play'de "Alarm" olarak beyan edilir |
| `app-ads.txt` barındırma | Kullanıcı `hasankaankahraman.github.io` reposunu kendisi açacak; şablon ve adımlar hazır |

## Yapılanlar

- **Dal güncellendi:** `main` reklam dalına birleştirildi. Ayarlar → Destek'te "Gizlilik Politikası" her zaman, "Reklam gizlilik seçenekleri" AB/BK/İsviçre'de görünür.
- **Gizlilik politikası** ([docs/privacy.html](../../docs/privacy.html)): veri sorumlusu ve e-posta; iOS ve Android izinleri tek tek; yedekleme; AdMob'un topladıkları; takip yapılmadığı; ilaç verisinin reklamda kullanılmadığı; yurt dışına aktarım; saklama ve silme; KVKK/GDPR hakları.
- **Destek sayfası** ([docs/support.html](../../docs/support.html)): e-posta ve "Reklamlar neden var, ilaçlarımı görüyor mu?" sorusu.
- **App Store rehberi** ([BEYAN.md](../app-store/BEYAN.md)): gizlilik etiketi tablosu, ilgili inceleme kuralları (5.1.3 sağlık verisi, reklam yerleşimi), yaş derecelendirmesi, yayın öncesi kontrol listesi.
- **App Review notu** ([REVIEW_NOTES_ADS.md](../app-store/REVIEW_NOTES_ADS.md)): reklamlı sürüm için İngilizce. [REVIEW_REPLY.md](../app-store/REVIEW_REPLY.md) yalnızca reklamsız 1.0.0 için geçerli.
- **Google Play rehberi** ([BEYAN.md](../google-play/BEYAN.md)): Data safety soru soru, Ads, Advertising ID, hedef kitle, IARC, Health apps, exact alarm ve tam ekran bildirim beyanları, reklam politikası notları.
- **`app-ads.txt`**: [şablon](app-ads.txt) ve [adımlar](README.md).
- **README**: tam ekran alarm açıklaması düzeltildi, reklam ve yedekleme davranışı eklendi.
- **Doğrulama:** `flutter analyze` temiz, 94 test geçti; birleşik Android manifestinde `AD_ID`/`ADSERVICES` yok, yedekleme kuralları devrede.

## Yapılacaklar

**AdMob konsolu**
- [ ] iOS ve Android uygulamalarını ve banner birimlerini oluştur; birimleri [ads.dart](../../lib/core/ads.dart)'a, App ID'leri `Info.plist` (`GADApplicationIdentifier`) ve `AndroidManifest.xml` (`APPLICATION_ID`) içine yaz. Şu an test App ID'leri var ve birimler boş: release derlemesi reklam göstermez.
- [ ] Uygulamaları mağaza kayıtlarına bağla.
- [ ] Privacy & messaging → European regulations mesajını yayınla (yoksa AB/BK'da form açılmaz, reklam gelmez).
- [ ] Hassas kategorileri engelle: ilaç/eczane, takviye, kilo verme, doğum kontrolü/cinsel sağlık, kumar, alkol, flört.
- [ ] En yüksek reklam içerik derecesi: PG.

**`app-ads.txt`**
- [ ] Yayıncı kimliğini (`pub-…`) [app-ads.txt](app-ads.txt)'ye yaz.
- [ ] `hasankaankahraman.github.io` reposunu aç, dosyayı köküne koy, Pages'i aç, AdMob'dan doğrulat.

**Mağazalar (iOS onayından sonra)**
- [ ] `feat/admob-ads` → `main` birleştir (politika canlıya çıkar).
- [ ] Play: [BEYAN.md](../google-play/BEYAN.md) §3'teki formları doldur; iletişim e-postası ve web sitesi.
- [ ] App Store: gizlilik etiketini **reklamlı build'i gönderirken** güncelle (etiket hemen yayına girer), yaş derecelendirmesindeki reklam sorusu, Review Notes'a [REVIEW_NOTES_ADS.md](../app-store/REVIEW_NOTES_ADS.md).
- [ ] `06-gizlilik` ekran görüntülerini yenileriyle değiştir.

**Derleme ve test**
- [ ] `android/key.properties` ile gerçek yükleme anahtarı.
- [ ] Gerçek Android cihazda: alarm modunda kilit ekranı üstünde banner görünmemeli; Android 14+ izinleri.
- [ ] iOS: `flutter build ipa` sonrası Xcode → Generate Privacy Report çıktısını sakla.

## Açık riskler

- **KVKK yurt dışına aktarım:** Politika bunu yalnızca bilgi olarak söylüyor, hangi hukuki sebebe dayandığını belirtmiyor. Emin olmak için bir hukukçuya gösterilebilir.
- **Xcode Privacy Report:** SDK manifesti Device ID'yi "tracking" olarak gösterebilir. ATT izni olmadan iOS 17+ SDK'nın takip alan adlarını zaten engeller; etiket uygulamanın gerçek davranışına göre "No" doldurulur.
- **Tam ekran bildirim:** Play beyanı reddedilirse izin Android 14+'ta iptal edilir; alarm yüksek öncelikli sesli bildirim olarak çalışmaya devam eder.
- **Banner ve kilit ekranı:** Banner kilit kontrolü tamamlanana kadar çok kısa bir an görünebilir; gerçek cihazda bakılmalı.

## Kaynaklar

- Google, AdMob Play veri beyanı: https://developers.google.com/admob/android/privacy/play-data-disclosure
- Google, AdMob iOS veri beyanı: https://developers.google.com/admob/ios/privacy/data-disclosure
- Apple, yaş derecelendirmeleri: https://developer.apple.com/help/app-store-connect/reference/age-ratings
- Yaş derecelendirmesi değişikliği: https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/ · https://trysonar.app/blog/app-store-age-rating
