import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob'daki banner reklam birimleri. Boşken release derlemesinde reklam
/// gösterilmez ve SDK başlatılmaz. Doldururken AndroidManifest.xml ve
/// Info.plist'teki test App ID'leri de gerçekleriyle değiştirilmeli.
const androidBannerUnit = '';
const iosBannerUnit = '';

/// Google'ın test birimleri; debug'da gerçek reklam istenmez.
const _testAndroidBannerUnit = 'ca-app-pub-3940256099942544/9214589741';
const _testIosBannerUnit = 'ca-app-pub-3940256099942544/2435281174';

/// Bu platformdaki reklam birimi; reklam gösterilmeyecekse null.
String? bannerAdUnit(TargetPlatform platform, {bool debug = kDebugMode}) {
  final unit = switch (platform) {
    TargetPlatform.android =>
      debug ? _testAndroidBannerUnit : androidBannerUnit,
    TargetPlatform.iOS => debug ? _testIosBannerUnit : iosBannerUnit,
    _ => '',
  };
  return unit.isEmpty ? null : unit;
}

/// Sağlık uygulaması: reklamlar kişiselleştirilmez, isteğe uygulama verisi
/// (ilaç adı, anahtar kelime, içerik adresi) eklenmez.
const adRequest = AdRequest(nonPersonalizedAds: true);

Future<bool>? _consent;

/// Reklam izni akışını (AB/BK'daki izin formu dahil) açılış başına bir kez
/// yürütür ve SDK'yı başlatır; reklam istenebiliyorsa true. Olmadıysa (ör.
/// çevrimdışı) bir sonraki çağrı yeniden dener.
Future<bool> gatherAdConsent() => _consent ??= _gatherConsent().then((ok) {
  if (!ok) _consent = null;
  return ok;
});

Future<bool> _gatherConsent() async {
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () async {
      try {
        await ConsentForm.loadAndShowConsentFormIfRequired((e) {
          if (e != null) debugPrint('Reklam izin formu: ${e.message}');
        });
      } finally {
        done.complete();
      }
    },
    // Hata olursa önceki oturumdaki izin geçerli kalır.
    (e) {
      debugPrint('Reklam izni güncellenemedi: ${e.message}');
      done.complete();
    },
  );
  await done.future;
  if (!await ConsentInformation.instance.canRequestAds()) return false;
  await MobileAds.instance.initialize();
  return true;
}

/// Ayarlar'daki gizlilik seçenekleri satırı gerekiyor mu (AB/BK).
Future<bool> adPrivacyOptionsRequired() async {
  await gatherAdConsent();
  return await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;
}

Future<void> showAdPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((e) {
  if (e != null) debugPrint('Reklam gizlilik seçenekleri: ${e.message}');
});
