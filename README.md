# Take a Pill

İlaç hatırlatıcı (Flutter, iOS + Android). Tüm veriler cihazda, SQLite'ta
(drift) tutulur; hatırlatmalar yerel bildirimlerle yapılır, sunucu yoktur.

## Yapı

```
lib/
  bootstrap.dart, app.dart        açılış, yönlendirme, tema, yerelleştirme
  core/
    db/                           drift şeması (app_database.g.dart üretilir)
    notifications/
      notification_planner.dart   saf planlama: önce / zamanında / tekrar / erteleme
      notification_service.dart   eklenti, izinler, senkron, bildirim butonları
    labels.dart                   Türkçe etiketler ve saat biçimleri
    settings_store.dart           yemek saatleri, bildirim tercihleri, ertelemeler
  features/schedule/
    domain/                       kurallar (günlük, X saatte bir, gerektiğinde), doz üretici
    data/schedule_repository.dart ilaç planları ve günün doz görünümleri
  ui/                             ekranlar, provider'lar, ortak widget'lar
```

Önemli davranışlar:

- iOS en fazla 64 bekleyen bildirime izin verir; plan her açılışta, her
  değişiklikte ve her bildirim butonunda en yakın 60 bildirimle (Android'de
  120) yeniden kurulur (`syncNotifications`). Plan sonraki dozları
  kapsamıyorsa son bildirimden sonra "uygulamayı aç" hatırlatması kurulur.
- Bildirim izni kapalıysa Bugün ve Ayarlar ekranlarında uyarı çıkar; dokununca
  sistemin bildirim ayarları açılır.
- Android 14+ cihazlarda "Alarmlar ve hatırlatıcılar" izni varsayılan olarak
  kapalıdır. İzin yoksa bildirimler esnek modda kurulur (birkaç dakika
  gecikebilir) ve Ayarlar ekranında uyarı görünür. Kullanıcı izin ekranına
  gönderilmeden önce nedeni bir pencereyle anlatılır.
- "Ertele" kalıcıdır: Settings tablosunda saklanır, plan yenilense de korunur.
- Hatırlatma şekli (onboarding'de seçilir, Ayarlar'dan değişir): bildirim ya
  da arama. Arama modunda doz saati ve erteleme hatırlatması "Reddet /
  Kabul et" ile çalar: Reddet ertelenir, Kabul et uygulamayı Bugün ekranında
  açar (doz orada işaretlenir).
  - iOS 26+ (alarm izni varsa): AlarmKit alarmı (`ios/Runner/CallAlarms.swift`);
    Dynamic Island'da ve kilit ekranında çıkar, sessiz modu ve Odak'ı aşar.
    Reddet uygulamayı açmadan erteleme alarmı kurar. Butonlar UserDefaults'a
    yazılır, Dart açılışta, öne gelince ve her bildirim butonundan önce işler
    (`applyAlarmActions`). Alarm başlığında yemek notu da yer alır.
  - Android: telefonun zil sesi alarm akışında çalar (`call_alarms` kanalı),
    böylece sessiz/titreşim modunda da duyulur; 60 sn sonra susar. Tam ekran
    arama yok (`USE_FULL_SCREEN_INTENT` Play politikası gereği kaldırıldı).
  - Daha eski iOS ya da izin yoksa: `ios/Runner/ring.caf` sesli bildirim;
    sessiz modda yalnızca titrer.

## Geliştirme

```sh
flutter pub get
dart run build_runner build      # yalnızca DB şeması değişince
flutter analyze
flutter test                     # birim + widget testleri
```

Uçtan uca test (gerçek bildirim teslimini de bekler, ~4 dk):

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  --dart-define=PROVISIONAL_NOTIFICATIONS=true -d <simülatör>
```

Mağaza görselleri: `flutter test tool/store/store_assets_test.dart` ve ardından
`tool/store/finalize.sh` (çıktılar `store/` altında).

Mağaza metinleri (ad, alt başlık, anahtar kelimeler, açıklamalar) fastlane
yapısında `store/app-store/metadata/tr/` ve `store/google-play/metadata/tr-TR/`
altında; karakter sınırlarını `flutter test tool/store/metadata_test.dart` denetler.

## Yayın

Sürüm `pubspec.yaml` içindeki `version: x.y.z+build` satırından gelir; her
yüklemede build numarasını artır.

**Android (Google Play)**

1. Yükleme anahtarı oluştur ve `android/key.properties` dosyasını yaz (git'e girmez):

   ```properties
   storeFile=/mutlak/yol/upload-keystore.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

   Bu dosya yoksa release derlemesi debug anahtarıyla imzalanır ve Play kabul etmez.
2. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`

**iOS (App Store)**

1. Xcode'da Runner → Signing: takım `8L3Z8YPD56`, paket kimliği `com.takeapill.takeapill`.
2. `flutter build ipa --release` → `build/ios/ipa/` (Transporter veya Xcode Organizer ile yükle).

**Mağaza formları (konsolda elle)**

- Gizlilik politikası URL'si: iki mağaza da istiyor (sağlık kategorisinde zorunlu).
- App Store gizlilik etiketi: "Veri toplanmıyor". Play veri güvenliği: veri
  toplanmıyor ve paylaşılmıyor.
- Play Console → Uygulama içeriği → Sağlık uygulamaları beyanı:
  ilaç hatırlatıcısı, tıbbi tavsiye vermez.
- Uygulama yalnızca Türkçe; iki mağazada da birincil dil Türkçe olmalı.
